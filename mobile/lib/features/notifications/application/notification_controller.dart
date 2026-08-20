import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_epoch.dart';
import '../../../shared/models/app_notification.dart';
import '../data/notification_repository.dart';

class NotificationState {
  const NotificationState({
    this.items = const [],
    this.unreadCount = 0,
    this.loading = false,
    this.error,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final bool loading;
  final String? error;

  NotificationState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? loading,
    String? error,
  }) {
    return NotificationState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      loading: loading ?? this.loading,
      error: error,
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

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repository.fetchMine();
      final unread = items.where((n) => !n.read).length;
      state = state.copyWith(items: items, unreadCount: unread, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Không tải được thông báo');
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
        // Có thay đổi so với web → tải lại danh sách đầy đủ.
        final items = await _repository.fetchMine();
        final unread = items.where((n) => !n.read).length;
        state = state.copyWith(items: items, unreadCount: unread);
      } else {
        state = state.copyWith(unreadCount: count);
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
      state = state.copyWith(unreadCount: count);
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
      state = state.copyWith(
        items: updated,
        unreadCount: (state.unreadCount - 1).clamp(0, 999999),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      await refresh();
    } catch (_) {}
  }
}

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
  ref.watch(sessionEpochProvider);
  final controller =
      NotificationController(ref.watch(notificationRepositoryProvider));
  ref.onDispose(controller.disposePolling);
  return controller;
});
