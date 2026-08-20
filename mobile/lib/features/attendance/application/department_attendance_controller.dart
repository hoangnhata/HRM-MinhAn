import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_epoch.dart';
import '../../../core/utils/user_role.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../data/attendance_repository.dart';

class DepartmentAttendanceState {
  const DepartmentAttendanceState({
    required this.year,
    required this.month,
    this.departmentId,
    this.query = '',
    this.matrix,
    this.loading = false,
    this.error,
  });

  final int year;
  final int month;
  final int? departmentId;
  final String query;
  final AttendanceMonthMatrix? matrix;
  final bool loading;
  final String? error;

  List<AttendanceMatrixRow> get visibleRows {
    final rows = matrix?.rows ?? const <AttendanceMatrixRow>[];
    final q = _fold(query);
    if (q.isEmpty) return rows;
    return [
      for (final r in rows)
        if (_fold(r.fullName).contains(q) ||
            _fold(r.employeeCode).contains(q) ||
            _fold(r.position).contains(q) ||
            _fold(r.department).contains(q))
          r,
    ];
  }

  DepartmentAttendanceState copyWith({
    int? year,
    int? month,
    int? departmentId,
    bool clearDepartment = false,
    String? query,
    AttendanceMonthMatrix? matrix,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearMatrix = false,
  }) {
    return DepartmentAttendanceState(
      year: year ?? this.year,
      month: month ?? this.month,
      departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
      query: query ?? this.query,
      matrix: clearMatrix ? null : (matrix ?? this.matrix),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

String _fold(String raw) {
  const map = {
    'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
    'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
    'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
    'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
    'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
    'đ': 'd',
  };
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

class DepartmentAttendanceController
    extends StateNotifier<DepartmentAttendanceState> {
  DepartmentAttendanceController(this._repository, {int? departmentId})
      : super(
          DepartmentAttendanceState(
            year: DateTime.now().year,
            month: DateTime.now().month,
            departmentId: departmentId,
          ),
        ) {
    load();
  }

  final AttendanceRepository _repository;
  int _gen = 0;

  Future<void> load() async {
    final gen = ++_gen;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final matrix = await _repository.monthMatrix(
        year: state.year,
        month: state.month,
        departmentId: state.departmentId,
      );
      if (!mounted || gen != _gen) return;
      state = state.copyWith(
        matrix: matrix,
        loading: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (!mounted || gen != _gen) return;
      state = state.copyWith(
        loading: false,
        error: e.message,
        clearMatrix: state.matrix == null,
      );
    } catch (_) {
      if (!mounted || gen != _gen) return;
      state = state.copyWith(
        loading: false,
        error: 'Không tải được bảng công theo khoa',
        clearMatrix: state.matrix == null,
      );
    }
  }

  Future<void> refreshQuietly() async {
    if (state.loading) return;
    try {
      final matrix = await _repository.monthMatrix(
        year: state.year,
        month: state.month,
        departmentId: state.departmentId,
      );
      if (!mounted) return;
      state = state.copyWith(matrix: matrix, clearError: true);
    } catch (_) {}
  }

  Future<void> setMonth(int year, int month) async {
    if (state.year == year && state.month == month) return;
    state = state.copyWith(year: year, month: month);
    await load();
  }

  Future<void> setDepartment(int? departmentId) async {
    if (state.departmentId == departmentId) return;
    state = state.copyWith(
      departmentId: departmentId,
      clearDepartment: departmentId == null,
    );
    await load();
  }

  void setQuery(String value) {
    state = state.copyWith(query: value.trim());
  }
}

final departmentAttendanceControllerProvider =
    StateNotifierProvider.autoDispose<DepartmentAttendanceController,
        DepartmentAttendanceState>((ref) {
  ref.watch(sessionEpochProvider);
  final auth = ref.watch(authControllerProvider);
  final locked = auth.role == UserRole.headDepartment &&
      auth.currentUser?.departmentId != null;
  return DepartmentAttendanceController(
    ref.watch(attendanceRepositoryProvider),
    departmentId: locked ? auth.currentUser!.departmentId : null,
  );
});
