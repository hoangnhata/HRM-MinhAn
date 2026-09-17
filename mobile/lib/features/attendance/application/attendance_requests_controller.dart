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
    this.historyMonth,
    this.historyLoading = false,
    this.historyLoaded = false,
  });

  final List<AttendanceWorkRequest> mine;
  final List<AttendanceWorkRequest> pending;

  /// Lịch sử đã xử lý của [historyMonth]. Chỉ tải khi người dùng mở tab
  /// "Đã xử lý" — endpoint này nặng nhất nên không kéo sẵn khi mở màn.
  final List<AttendanceWorkRequest> history;
  final bool loading;
  final String? error;

  /// Tháng (ngày 1) đang xem ở tab lịch sử; `null` khi chưa mở tab.
  final DateTime? historyMonth;
  final bool historyLoading;
  final bool historyLoaded;

  AttendanceRequestsState copyWith({
    List<AttendanceWorkRequest>? mine,
    List<AttendanceWorkRequest>? pending,
    List<AttendanceWorkRequest>? history,
    bool? loading,
    String? error,
    bool clearError = false,
    DateTime? historyMonth,
    bool? historyLoading,
    bool? historyLoaded,
  }) {
    return AttendanceRequestsState(
      mine: mine ?? this.mine,
      pending: pending ?? this.pending,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      historyMonth: historyMonth ?? this.historyMonth,
      historyLoading: historyLoading ?? this.historyLoading,
      historyLoaded: historyLoaded ?? this.historyLoaded,
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

  bool get _canApprove {
    final auth = _ref.read(authControllerProvider);
    return RoleGroups.canApproveAttendance(
      auth.role,
      directorApprovalEnabled:
          auth.currentUser?.directorApprovalEnabled ?? false,
    );
  }

  Future<void> refreshAll() async {
    state = state.copyWith(loading: true, clearError: true);
    await _load(showError: true);
  }

  /// Làm mới nền — không bật skeleton/loading để UI không nháy.
  Future<void> refreshQuietly() => _load(showError: false);

  Future<void> _load({required bool showError}) async {
    try {
      // Gọi song song thay vì chờ "đơn của tôi" xong mới gọi hàng đợi duyệt.
      // Backend trả 403 cho nhân viên thường ở pending — chỉ gọi khi có quyền.
      final canApprove = _canApprove;
      final results = await Future.wait([
        _repository.myRequests(),
        if (canApprove) _safeList(_repository.pendingRequests()),
      ]);
      final mine = results[0];
      final pending = canApprove ? results[1] : const <AttendanceWorkRequest>[];

      state = state.copyWith(
        mine: mine,
        pending: pending,
        loading: false,
        clearError: true,
      );
      // Lịch sử đã mở trước đó thì làm mới cùng tháng, không thì để dành.
      if (canApprove && state.historyLoaded && state.historyMonth != null) {
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
        error: showError ? 'Không tải được danh sách đơn' : state.error,
      );
    }
  }

  /// Tải lịch sử đã xử lý của một tháng (mặc định tháng hiện tại).
  ///
  /// Backend trả toàn bộ lịch sử nếu không truyền ngày, nên luôn gửi cửa sổ
  /// tháng — giống web, và là lý do chính màn đơn từng tải rất lâu.
  Future<void> loadHistory({DateTime? month}) async {
    if (!_canApprove) return;
    final now = DateTime.now();
    final target = DateTime(
      (month ?? state.historyMonth ?? now).year,
      (month ?? state.historyMonth ?? now).month,
    );
    state = state.copyWith(historyMonth: target, historyLoading: true);
    try {
      final rows = await _safeList(
        _repository.reviewHistory(
          from: target,
          to: DateTime(target.year, target.month + 1, 0),
        ),
      );
      // Người dùng đổi tháng trong lúc đang tải thì bỏ kết quả cũ.
      if (state.historyMonth != target) return;
      state = state.copyWith(
        history: rows,
        historyLoading: false,
        historyLoaded: true,
      );
    } catch (_) {
      if (state.historyMonth != target) return;
      state = state.copyWith(historyLoading: false, historyLoaded: true);
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
    bool? keepOriginalPunchTimes,
  }) async {
    final slug = AttendanceEnums.reviewEndpointFor(request.status);
    if (slug == null) {
      state = state.copyWith(error: 'Đơn không còn ở bước chờ duyệt của bạn');
      return false;
    }
    try {
      await _repository.review(
        request.id,
        slug,
        approved: approved,
        comment: comment,
        waiveForgotFine: waiveForgotFine,
        keepOriginalPunchTimes: keepOriginalPunchTimes,
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
    bool? keepOriginalPunchTimes,
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
        final applyWaive =
            approved &&
            waiveForgotFine != null &&
            AttendanceEnums.directorDecidesFine(request);
        final applyKeep =
            approved &&
            keepOriginalPunchTimes == true &&
            request.requestType == 'EXPLANATION' &&
            request.status == 'PENDING_DIRECTOR';
        await _repository.review(
          request.id,
          slug,
          approved: approved,
          comment: comment,
          waiveForgotFine: applyWaive ? waiveForgotFine : null,
          keepOriginalPunchTimes: applyKeep ? true : null,
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

final attendanceRequestsControllerProvider =
    StateNotifierProvider<
      AttendanceRequestsController,
      AttendanceRequestsState
    >((ref) {
      ref.watch(sessionEpochProvider);
      return AttendanceRequestsController(
        ref,
        ref.watch(attendanceRepositoryProvider),
      );
    });
