import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_epoch.dart';
import '../../../core/utils/app_icon_badge.dart';
import '../../../shared/models/app_notification.dart';
import '../data/notification_repository.dart';

class NotificationState {
  const NotificationState({
    this.items = const [],
    this.unreadCount = 0,
    this.loading = false,
    this.error,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
  });

  /// Các trang đã tải, nối tiếp nhau (chưa đọc trước, mới nhất trước).
  final List<AppNotification> items;
  final int unreadCount;
  final bool loading;
  final String? error;

  /// Trang cuối đã tải; `hasMore` cho biết còn trang sau để kéo thêm.
  final int page;
  final bool hasMore;
  final bool loadingMore;

  NotificationState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? loading,
    String? error,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return NotificationState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      loading: loading ?? this.loading,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class NotificationController extends StateNotifier<NotificationState> {
  NotificationController(this._repository) : super(const NotificationState()) {
    refresh();
    _startPolling();
  }

  final NotificationRepository _repository;
  Timer? _pollTimer;
  bool _pollInFlight = false;

  /// Đồng bộ định kỳ với web khi app đang mở (badge + danh sách nếu có tin mới).
  static const _pollInterval = Duration(seconds: 20);

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => pollQuietly());
  }

  void disposePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _applyUnread(int unread) {
    state = state.copyWith(unreadCount: unread);
    unawaited(AppIconBadge.sync(unread));
  }

  /// Tải lại từ trang đầu. Số chưa đọc lấy từ server, không đếm trên danh
  /// sách đã tải vì danh sách giờ chỉ là một phần.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final first = await _repository.fetchPage(0);
      state = state.copyWith(
        items: first.items,
        loading: false,
        page: 0,
        hasMore: first.hasMore,
        loadingMore: false,
      );
      _applyUnread(first.unread);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Không tải được thông báo');
    }
  }

  /// Tải trang kế tiếp, nối vào cuối danh sách.
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    final next = state.page + 1;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _repository.fetchPage(next);
      // Tin vừa đổi trạng thái đọc có thể trôi sang trang sau — bỏ trùng theo id.
      final seen = state.items.map((n) => n.id).toSet();
      state = state.copyWith(
        items: [
          ...state.items,
          ...result.items.where((n) => !seen.contains(n.id)),
        ],
        page: next,
        hasMore: result.hasMore,
        loadingMore: false,
      );
      _applyUnread(result.unread);
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Làm mới nhẹ — dùng khi resume app / nhận FCM / poll.
  Future<void> pollQuietly() async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final count = await _repository.fetchUnreadCount();
      final previous = state.unreadCount;
      if (count != previous) {
        // Có tin mới hoặc web vừa đọc bớt → tải lại trang đầu, không kéo cả bảng.
        final first = await _repository.fetchPage(0);
        state = state.copyWith(
          items: first.items,
          page: 0,
          hasMore: first.hasMore,
          loadingMore: false,
        );
        _applyUnread(first.unread);
      } else {
        _applyUnread(count);
      }
    } catch (_) {
      // Im lặng — poll nền không làm gián đoạn UI.
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> refreshUnreadCountOnly() async {
    try {
      final count = await _repository.fetchUnreadCount();
      _applyUnread(count);
    } catch (_) {}
  }

  Future<void> markRead(int id) async {
    final idx = state.items.indexWhere((n) => n.id == id);
    if (idx == -1 || state.items[idx].read) return;
    try {
      await _repository.markRead(id);
      final updated = [...state.items];
      final n = updated[idx];
      updated[idx] = AppNotification(
        id: n.id,
        category: n.category,
        title: n.title,
        message: n.message,
        read: true,
        createdAt: n.createdAt,
        relatedEmployeeId: n.relatedEmployeeId,
        relatedRequestId: n.relatedRequestId,
        sensitive: n.sensitive,
        actionPath: n.actionPath,
      );
      state = state.copyWith(items: updated);
      _applyUnread((state.unreadCount - 1).clamp(0, 999999));
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      await refresh();
    } catch (_) {}
  }

  Future<void> clearBadgeOnLogout() async {
    state = const NotificationState();
    await AppIconBadge.clear();
  }
}

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
      ref.watch(sessionEpochProvider);
      final controller = NotificationController(
        ref.watch(notificationRepositoryProvider),
      );
      ref.onDispose(controller.disposePolling);
      return controller;
    });
