import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_epoch.dart';
import '../../../core/utils/user_role.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../../auth/application/auth_controller.dart';
import '../data/evaluation_repository.dart';

class EvaluationState {
  const EvaluationState({
    this.mine = const [],
    this.pending = const [],
    this.history = const [],
    this.loading = false,
    this.mineError,
    this.queueError,
    this.mineUnavailable = false,
  });

  final List<NursingEvaluationRecord> mine;
  final List<NursingEvaluationRecord> pending;
  final List<NursingEvaluationRecord> history;
  final bool loading;
  final String? mineError;
  final String? queueError;

  /// Tài khoản không có / không gắn được hồ sơ NV — không hiện tab "Của tôi".
  final bool mineUnavailable;

  String? get error => queueError ?? mineError;

  EvaluationState copyWith({
    List<NursingEvaluationRecord>? mine,
    List<NursingEvaluationRecord>? pending,
    List<NursingEvaluationRecord>? history,
    bool? loading,
    String? mineError,
    String? queueError,
    bool? mineUnavailable,
    bool clearMineError = false,
    bool clearQueueError = false,
  }) {
    return EvaluationState(
      mine: mine ?? this.mine,
      pending: pending ?? this.pending,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      mineError: clearMineError ? null : (mineError ?? this.mineError),
      queueError: clearQueueError ? null : (queueError ?? this.queueError),
      mineUnavailable: mineUnavailable ?? this.mineUnavailable,
    );
  }
}

bool _isUnlinkedMessage(String? raw) {
  final e = (raw ?? '').toLowerCase();
  return e.contains('chưa liên kết') ||
      e.contains('lien ket') ||
      e.contains('liên kết hồ sơ');
}

class EvaluationController extends StateNotifier<EvaluationState> {
  EvaluationController(this._repository, this._ref)
      : super(const EvaluationState()) {
    refreshAll();
  }

  final EvaluationRepository _repository;
  final Ref _ref;

  bool get _hasEmployeeId =>
      (_ref.read(authControllerProvider).employeeId ?? 0) > 0;

  bool get _canApprove {
    final auth = _ref.read(authControllerProvider);
    return RoleGroups.canApproveNursingEval(
      auth.role,
      directorApprovalEnabled:
          auth.currentUser?.directorApprovalEnabled ?? false,
    );
  }

  Future<void> refreshAll() async {
    state = state.copyWith(
      loading: true,
      clearMineError: true,
      clearQueueError: true,
    );
    await _load(showError: true);
  }

  Future<void> refreshQuietly() => _load(showError: false);

  Future<void> _load({required bool showError}) async {
    var mine = const <NursingEvaluationRecord>[];
    var pending = const <NursingEvaluationRecord>[];
    var history = const <NursingEvaluationRecord>[];
    String? mineError;
    String? queueError;
    var mineUnavailable = !_hasEmployeeId;

    if (_hasEmployeeId) {
      try {
        mine = await _repository.mine();
        mineUnavailable = false;
      } on ApiException catch (e) {
        if (_isUnlinkedMessage(e.message)) {
          mineUnavailable = true;
          mine = const [];
        } else {
          mineError = e.message;
        }
      } catch (_) {
        mineError = 'Không tải được phiếu của bạn';
      }
    }

    if (_canApprove) {
      // Tách pending / history — một API lỗi không làm hỏng cả hàng chờ.
      try {
        pending = await _repository.pending();
      } on ApiException catch (e) {
        if (!_isUnlinkedMessage(e.message)) {
          queueError = e.message;
        }
      } catch (_) {
        queueError = 'Không tải được phiếu chờ duyệt';
      }

      try {
        history = await _repository.history();
      } on ApiException catch (e) {
        if (!_isUnlinkedMessage(e.message)) {
          queueError ??= e.message;
        }
      } catch (_) {
        queueError ??= 'Không tải được lịch sử duyệt';
      }
    }

    state = state.copyWith(
      mine: mine,
      pending: pending,
      history: history,
      loading: false,
      mineUnavailable: mineUnavailable,
      mineError: showError ? mineError : state.mineError,
      queueError: showError ? queueError : state.queueError,
      clearMineError: showError && mineError == null,
      clearQueueError: showError && queueError == null,
    );
  }

  Future<NursingEvaluationRecord?> fetchById(int id) async {
    try {
      return await _repository.byId(id);
    } catch (_) {
      return null;
    }
  }

  String? stageFor(String status) {
    switch (status) {
      case 'PENDING_NURSING_HEAD':
        return 'nursing-head';
      case 'PENDING_HR':
        return 'hr';
      case 'PENDING_DIRECTOR':
        return 'director';
      default:
        return null;
    }
  }

  Future<bool> review(
    NursingEvaluationRecord record, {
    required bool approved,
    String? comment,
  }) async {
    final stage = stageFor(record.status);
    if (stage == null) {
      state = state.copyWith(
        queueError: 'Phiếu không còn ở bước chờ duyệt của bạn',
      );
      return false;
    }
    try {
      await _repository.review(
        record.id,
        stage,
        approved: approved,
        comment: comment,
      );
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(queueError: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(queueError: 'Thao tác thất bại');
      return false;
    }
  }
}

final evaluationControllerProvider =
    StateNotifierProvider<EvaluationController, EvaluationState>((ref) {
  ref.watch(sessionEpochProvider);
  return EvaluationController(ref.watch(evaluationRepositoryProvider), ref);
});
