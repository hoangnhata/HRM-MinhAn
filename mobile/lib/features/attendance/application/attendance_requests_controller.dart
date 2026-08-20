import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_epoch.dart';
import '../../../core/utils/user_role.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../data/attendance_repository.dart';
import '../presentation/attendance_enums.dart';

enum AttendanceRequestListKind { mine, pending, history }

class AttendanceRequestsState {
  const AttendanceRequestsState({
    this.mine = const [],
    this.pending = const [],
    this.history = const [],
    this.loading = false,
    this.error,
  });

  final List<AttendanceWorkRequest> mine;
  final List<AttendanceWorkRequest> pending;
  final List<AttendanceWorkRequest> history;
  final bool loading;
  final String? error;

  AttendanceRequestsState copyWith({
    List<AttendanceWorkRequest>? mine,
    List<AttendanceWorkRequest>? pending,
    List<AttendanceWorkRequest>? history,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceRequestsState(
      mine: mine ?? this.mine,
      pending: pending ?? this.pending,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AttendanceRequestsController
    extends StateNotifier<AttendanceRequestsState> {
  AttendanceRequestsController(this._ref, this._repository)
      : super(const AttendanceRequestsState()) {
    refreshAll();
  }

  final Ref _ref;
  final AttendanceRepository _repository;

  bool get _canApprove => RoleGroups.isIn(
        _ref.read(authControllerProvider).role,
        RoleGroups.approvalManagers,
      );

  Future<void> refreshAll() async {
    state = state.copyWith(loading: true, clearError: true);
    await _load(showError: true);
  }

  /// Làm mới nền — không bật skeleton/loading để UI không nháy.
  Future<void> refreshQuietly() => _load(showError: false);

  Future<void> _load({required bool showError}) async {
    try {
      final mine = await _repository.myRequests();

      var pending = const <AttendanceWorkRequest>[];
      var history = const <AttendanceWorkRequest>[];

      // Backend trả 403 cho nhân viên thường ở pending/review-history —
      // chỉ gọi khi có quyền duyệt (giống web).
      if (_canApprove) {
        final results = await Future.wait([
          _safeList(_repository.pendingRequests()),
          _safeList(_repository.reviewHistory()),
        ]);
        pending = results[0];
        history = results[1];
      }

      state = state.copyWith(
        mine: mine,
        pending: pending,
        history: history,
        loading: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        loading: false,
        error: showError ? e.message : state.error,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: showError ? 'Không tải được danh sách đơn' : state.error,
      );
    }
  }

  /// Nuốt 403 để một endpoint duyệt lỗi không làm sập cả màn.
  Future<List<AttendanceWorkRequest>> _safeList(
    Future<List<AttendanceWorkRequest>> future,
  ) async {
    try {
      return await future;
    } on ApiException catch (e) {
      if (e.statusCode == 403) return const [];
      rethrow;
    }
  }

  Future<bool> submit(Map<String, dynamic> payload) async {
    try {
      await _repository.createRequest(payload);
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Gửi đơn thất bại');
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> payload) async {
    try {
      await _repository.updateRequest(id, payload);
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Cập nhật đơn thất bại');
      return false;
    }
  }

  Future<bool> withdraw(int id) async {
    try {
      await _repository.withdraw(id);
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Rút đơn thất bại');
      return false;
    }
  }

  Future<bool> review(
    AttendanceWorkRequest request, {
    required bool approved,
    String? comment,
    bool? waiveForgotFine,
  }) async {
    final slug = AttendanceEnums.reviewEndpointFor(request.status);
    if (slug == null) {
      state = state.copyWith(
        error: 'Đơn không còn ở bước chờ duyệt của bạn',
      );
      return false;
    }
    try {
      await _repository.review(
        request.id,
        slug,
        approved: approved,
        comment: comment,
        waiveForgotFine: waiveForgotFine,
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

  /// Duyệt / từ chối hàng loạt — gọi lần lượt cùng endpoint từng đơn như web.
  Future<({int succeeded, int failed, String? lastError})> bulkReview(
    List<AttendanceWorkRequest> requests, {
    required bool approved,
    String? comment,
    bool? waiveForgotFine,
  }) async {
    var succeeded = 0;
    var failed = 0;
    String? lastError;

    for (final request in requests) {
      final slug = AttendanceEnums.reviewEndpointFor(request.status);
      if (slug == null) {
        failed++;
        lastError = 'Đơn #${request.id} không còn ở bước chờ duyệt';
        continue;
      }
      try {
        final applyWaive = approved &&
            waiveForgotFine != null &&
            (request.status == 'PENDING_HR' ||
                request.status == 'PENDING_DIRECTOR') &&
            (request.requestType == 'UPDATE' ||
                request.requestType == 'EXPLANATION');
        await _repository.review(
          request.id,
          slug,
          approved: approved,
          comment: comment,
          waiveForgotFine: applyWaive ? waiveForgotFine : null,
        );
        succeeded++;
      } on ApiException catch (e) {
        failed++;
        lastError = e.message;
      } catch (_) {
        failed++;
        lastError = 'Thao tác thất bại';
      }
    }

    await refreshAll();
    return (succeeded: succeeded, failed: failed, lastError: lastError);
  }
}

final attendanceRequestsControllerProvider = StateNotifierProvider<
    AttendanceRequestsController, AttendanceRequestsState>((ref) {
  ref.watch(sessionEpochProvider);
  return AttendanceRequestsController(
    ref,
    ref.watch(attendanceRepositoryProvider),
  );
});
