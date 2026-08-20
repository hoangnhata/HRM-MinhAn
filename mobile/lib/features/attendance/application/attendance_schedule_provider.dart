import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_epoch.dart';
import '../../../shared/models/attendance_models.dart';
import '../data/attendance_repository.dart';

class AttendanceScheduleKey {
  const AttendanceScheduleKey({
    required this.employeeId,
    required this.year,
    required this.month,
  });

  final int employeeId;
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is AttendanceScheduleKey &&
      other.employeeId == employeeId &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(employeeId, year, month);
}

class AttendanceScheduleView {
  const AttendanceScheduleView({
    required this.schedule,
    this.continuousDayCount = 0,
    this.splitDayCount = 0,
    this.continuousDates = const {},
    this.splitDates = const {},
  });

  final DayShiftSchedule schedule;
  final int continuousDayCount;
  final int splitDayCount;
  final Set<String> continuousDates;
  final Set<String> splitDates;

  int get assignedDayCount => continuousDayCount + splitDayCount;
}

/// Lịch ca theo NV + tháng — API `/v1/attendance/schedule` (+ ngày thông tầm).
final attendanceScheduleProvider = FutureProvider.autoDispose
    .family<AttendanceScheduleView, AttendanceScheduleKey>((ref, key) async {
  ref.watch(sessionEpochProvider);
  final repo = ref.watch(attendanceRepositoryProvider);
  final now = DateTime.now();
  final isCurrentMonth =
      now.year == key.year && now.month == key.month;
  final day = isCurrentMonth ? now.day.clamp(1, 28) : 15;
  final refDate = DateTime(key.year, key.month, day);

  final schedule = await repo.daySchedule(
    date: refDate,
    employeeId: key.employeeId,
  );

  var continuousCount = 0;
  var splitCount = 0;
  var continuousDates = <String>{};
  var splitDates = <String>{};
  try {
    final continuous = await repo.continuousShiftDays(
      employeeId: key.employeeId,
      year: key.year,
      month: key.month,
    );
    continuousCount = continuous.continuousDates.isNotEmpty
        ? continuous.continuousDates.length
        : continuous.days
            .where((d) => d.kind != ContinuousShiftKind.split)
            .length;
    splitCount = continuous.splitDates.isNotEmpty
        ? continuous.splitDates.length
        : continuous.days.where((d) => d.isSplit).length;
    continuousDates = continuous.continuousDates.isNotEmpty
        ? continuous.continuousDates.toSet()
        : continuous.days
            .where((d) => d.kind != ContinuousShiftKind.split)
            .map((d) => d.date)
            .toSet();
    splitDates = continuous.splitDates.isNotEmpty
        ? continuous.splitDates.toSet()
        : continuous.days
            .where((d) => d.isSplit)
            .map((d) => d.date)
            .toSet();
  } catch (_) {
    // Không chặn hiển thị lịch ca nếu API xếp ca lỗi quyền.
  }

  return AttendanceScheduleView(
    schedule: schedule,
    continuousDayCount: continuousCount,
    splitDayCount: splitCount,
    continuousDates: continuousDates,
    splitDates: splitDates,
  );
});
