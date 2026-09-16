import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_epoch.dart';
import '../../auth/application/auth_controller.dart';
import '../data/generic_request_repository.dart';
import '../data/request_type_config.dart';

class PendingItem {
  const PendingItem({required this.raw, required this.stage});
  final Map<String, dynamic> raw;
  final RequestReviewStage stage;
}

class GenericRequestState {
  const GenericRequestState({
    this.related = const [],
    this.pending = const [],
    this.history = const [],
    this.loading = false,
    this.error,
    this.historyMonth,
    this.historyLoading = false,
    this.historyLoaded = false,
  });

  final List<Map<String, dynamic>> related;
  final List<PendingItem> pending;

  /// Lịch sử đã xử lý của [historyMonth] — tải lười khi mở tab "Đã xử lý".
  final List<Map<String, dynamic>> history;
  final bool loading;
  final String? error;
  final DateTime? historyMonth;
  final bool historyLoading;
  final bool historyLoaded;

  GenericRequestState copyWith({
    List<Map<String, dynamic>>? related,
    List<PendingItem>? pending,
    List<Map<String, dynamic>>? history,
    bool? loading,
    String? error,
    DateTime? historyMonth,
    bool? historyLoading,
    bool? historyLoaded,
  }) {
    return GenericRequestState(
      related: related ?? this.related,
      pending: pending ?? this.pending,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      error: error,
      historyMonth: historyMonth ?? this.historyMonth,
      historyLoading: historyLoading ?? this.historyLoading,
      historyLoaded: historyLoaded ?? this.historyLoaded,
    );
  }
}

class GenericRequestController extends StateNotifier<GenericRequestState> {
  GenericRequestController(this._ref, this._repository, this.config)
    : super(const GenericRequestState()) {
    refreshAll();
  }

  final Ref _ref;
  final GenericRequestRepository _repository;
  final RequestTypeConfig config;

  Future<void> refreshAll() async {
    state = state.copyWith(loading: true, error: null);
    await _load(showError: true);
  }

  /// Làm mới nền — không bật loading để tránh nháy UI.
  Future<void> refreshQuietly() => _load(showError: false);

  Future<void> _load({required bool showError}) async {
    try {
      final auth = _ref.read(authControllerProvider);
      final role = auth.role;
      final directorApproval =
          auth.currentUser?.directorApprovalEnabled ?? false;
      final reviewStages = config.stagesFor(
        role,
        directorApprovalEnabled: directorApproval,
      );
      // Nuốt 403/lỗi từng endpoint — giống đơn công: một API lỗi không sập cả màn.
      // Gọi song song: trước đây "liên quan" xong mới đến từng hàng đợi, và
      // lịch sử được kéo toàn bộ ngay khi mở màn. Giờ lịch sử tải lười theo tháng.
      final results = await Future.wait([
        _safeList(() => _repository.related(config)),
        for (final stage in reviewStages)
          _safeList(() => _repository.pendingForStage(config, stage)),
      ]);
      final related = results.first;

      final pending = <PendingItem>[];
      for (var i = 0; i < reviewStages.length; i++) {
        for (final raw in results[i + 1]) {
          pending.add(PendingItem(raw: raw, stage: reviewStages[i]));
        }
      }

      state = state.copyWith(
        related: related,
        pending: pending,
        loading: false,
        error: null,
      );
      if (state.historyLoaded && state.historyMonth != null) {
        await loadHistory(month: state.historyMonth);
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        loading: false,
        error: showError ? e.message : state.error,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: showError ? 'Không tải được dữ liệu' : state.error,
      );
    }
  }

  /// Lịch sử đã xử lý của một tháng (mặc định tháng hiện tại), chỉ cho người
  /// có quyền duyệt hoặc xem danh sách.
  Future<void> loadHistory({DateTime? month}) async {
    final auth = _ref.read(authControllerProvider);
    final canSee =
        config
            .stagesFor(
              auth.role,
              directorApprovalEnabled:
                  auth.currentUser?.directorApprovalEnabled ?? false,
            )
            .isNotEmpty ||
        config.canListView(auth.role);
    if (!canSee) return;
    final now = DateTime.now();
    final base = month ?? state.historyMonth ?? now;
    final target = DateTime(base.year, base.month);
    state = state.copyWith(historyMonth: target, historyLoading: true);
    final rows = await _safeList(
      () => _repository.history(
        config,
        from: target,
        to: DateTime(target.year, target.month + 1, 0),
      ),
    );
    if (state.historyMonth != target) return;
    state = state.copyWith(
      history: rows,
      historyLoading: false,
      historyLoaded: true,
    );
  }

  Future<List<Map<String, dynamic>>> _safeList(
    Future<List<Map<String, dynamic>>> Function() load,
  ) async {
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }

  /// Tai mot don chua co trong danh sach (mo sau tu thong bao).
  Future<Map<String, dynamic>?> fetchById(int id) async {
    try {
      final row = await _repository.byId(config, id);
      return row.isEmpty ? null : row;
    } catch (_) {
      return null;
    }
  }

  Future<bool> review(
    PendingItem item, {
    required bool approved,
    String? comment,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      final id = (item.raw['id'] as num).toInt();
      await _repository.review(
        config,
        id,
        item.stage.reviewSlug,
        approved: approved,
        comment: comment,
        extra: extra,
      );
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Thao tác thất bại');
      return false;
    }
  }

  Future<bool> cancel(int id) async {
    try {
      await _repository.cancel(config, id);
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Huỷ đơn thất bại');
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> body) async {
    try {
      await _repository.update(config, id, body);
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Lưu thay đổi thất bại');
      return false;
    }
  }
}

final genericRequestControllerProvider =
    StateNotifierProvider.family<
      GenericRequestController,
      GenericRequestState,
      String
    >((ref, typeKey) {
      ref.watch(sessionEpochProvider);
      final config = RequestTypeConfig.byKey(typeKey);
      return GenericRequestController(
        ref,
        ref.watch(genericRequestRepositoryProvider),
        config,
      );
    });
