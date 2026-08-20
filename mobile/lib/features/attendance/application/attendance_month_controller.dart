import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_epoch.dart';
import '../../../shared/models/attendance_models.dart';
import '../data/attendance_repository.dart';

class AttendanceMonthState {
  const AttendanceMonthState({
    required this.employeeId,
    required this.year,
    required this.month,
    this.summary,
    this.days = const [],
    this.dutyShifts = const [],
    this.loading = false,
    this.error,
  });

  final int employeeId;
  final int year;
  final int month;
  final AttendanceMonthSummary? summary;
  final List<AttendanceDay> days;
  final List<DutyShiftEntry> dutyShifts;
  final bool loading;
  final String? error;

  Map<String, DutyShiftEntry> get dutyByDate {
    final map = <String, DutyShiftEntry>{};
    for (final d in dutyShifts) {
      if (d.workDate.isNotEmpty) map[d.workDate] = d;
    }
    return map;
  }

  int get deploymentDayCount =>
      days.where((d) => d.isDeploymentDay).length;

  double get deploymentOvertimeUnits => days
      .where((d) => d.isDeploymentDay)
      .fold<double>(0, (sum, d) => sum + d.overtimeWorkUnits);

  AttendanceMonthState copyWith({
    int? employeeId,
    int? year,
    int? month,
    AttendanceMonthSummary? summary,
    List<AttendanceDay>? days,
    List<DutyShiftEntry>? dutyShifts,
    bool? loading,
    String? error,
    bool clearSummary = false,
  }) {
    return AttendanceMonthState(
      employeeId: employeeId ?? this.employeeId,
      year: year ?? this.year,
      month: month ?? this.month,
      summary: clearSummary ? null : (summary ?? this.summary),
      days: days ?? this.days,
      dutyShifts: dutyShifts ?? this.dutyShifts,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AttendanceMonthController extends StateNotifier<AttendanceMonthState> {
  AttendanceMonthController(
    this._repository, {
    required int employeeId,
    int? year,
    int? month,
  }) : super(
          AttendanceMonthState(
            employeeId: employeeId,
            year: year ?? DateTime.now().year,
            month: month ?? DateTime.now().month,
          ),
        ) {
    load();
  }

  final AttendanceRepository _repository;

  Future<void> load() => _fetch(showLoading: true);

  /// Làm mới nền khi đã có dữ liệu — không bật skeleton.
  Future<void> refreshQuietly() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    final empId = state.employeeId;
    if (empId <= 0) {
      state = state.copyWith(
        loading: false,
        error: 'Chưa chọn nhân viên',
        clearSummary: true,
        days: const [],
        dutyShifts: const [],
      );
      return;
    }
    if (showLoading) {
      state = state.copyWith(loading: true, error: null);
    }
    try {
      final firstDay = DateTime(state.year, state.month, 1);
      final lastDay = DateTime(state.year, state.month + 1, 0);
      final results = await Future.wait([
        _repository.monthDetail(empId, state.year, state.month),
        _repository
            .dutyShifts(employeeId: empId, from: firstDay, to: lastDay)
            .catchError((_) => <DutyShiftEntry>[]),
      ]);
      final detail =
          results[0] as ({AttendanceMonthSummary summary, List<AttendanceDay> days});
      final duties = results[1] as List<DutyShiftEntry>;
      state = state.copyWith(
        summary: detail.summary,
        days: detail.days,
        dutyShifts: duties,
        loading: false,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: showLoading
            ? 'Không tải được dữ liệu chấm công'
            : state.error,
      );
    }
  }

  void changeMonth(int delta) {
    var year = state.year;
    var month = state.month + delta;
    if (month < 1) {
      month = 12;
      year -= 1;
    } else if (month > 12) {
      month = 1;
      year += 1;
    }
    setMonth(year, month);
  }

  /// Chọn tháng/năm trực tiếp — không cho vượt tháng hiện tại.
  void setMonth(int year, int month) {
    final now = DateTime.now();
    var y = year;
    var m = month.clamp(1, 12);
    if (y > now.year || (y == now.year && m > now.month)) {
      y = now.year;
      m = now.month;
    }
    if (state.year == y && state.month == m) return;
    state = state.copyWith(year: y, month: m);
    load();
  }
}

final attendanceMonthControllerProvider = StateNotifierProvider.autoDispose
    .family<AttendanceMonthController, AttendanceMonthState, int>(
        (ref, employeeId) {
  ref.watch(sessionEpochProvider);
  return AttendanceMonthController(
    ref.watch(attendanceRepositoryProvider),
    employeeId: employeeId,
  );
});
