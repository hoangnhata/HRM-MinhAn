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
  });

  final List<Map<String, dynamic>> related;
  final List<PendingItem> pending;
  final List<Map<String, dynamic>> history;
  final bool loading;
  final String? error;

  GenericRequestState copyWith({
    List<Map<String, dynamic>>? related,
    List<PendingItem>? pending,
    List<Map<String, dynamic>>? history,
    bool? loading,
    String? error,
  }) {
    return GenericRequestState(
      related: related ?? this.related,
      pending: pending ?? this.pending,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class GenericRequestController extends StateNotifier<GenericRequestState> {
  GenericRequestController(this._ref, this._repository, this.config) : super(const GenericRequestState()) {
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
      final role = _ref.read(authControllerProvider).role;
      final reviewStages = config.stagesFor(role);
      final isListViewer = config.listViewerRoles.contains(role);

      // Nuốt 403/lỗi từng endpoint — giống đơn công: một API lỗi không sập cả màn.
      final related = await _safeList(() => _repository.related(config));
      final history = (reviewStages.isNotEmpty || isListViewer)
          ? await _safeList(() => _repository.history(config))
          : const <Map<String, dynamic>>[];

      final pendingLists = await Future.wait([
        for (final stage in reviewStages)
          _safeList(() => _repository.pendingForStage(config, stage)),
      ]);

      final pending = <PendingItem>[];
      for (var i = 0; i < reviewStages.length; i++) {
        for (final raw in pendingLists[i]) {
          pending.add(PendingItem(raw: raw, stage: reviewStages[i]));
        }
      }

      state = state.copyWith(
        related: related,
        pending: pending,
        history: history,
        loading: false,
        error: null,
      );
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
    StateNotifierProvider.family<GenericRequestController, GenericRequestState, String>((ref, typeKey) {
  ref.watch(sessionEpochProvider);
  final config = RequestTypeConfig.byKey(typeKey);
  return GenericRequestController(ref, ref.watch(genericRequestRepositoryProvider), config);
});
