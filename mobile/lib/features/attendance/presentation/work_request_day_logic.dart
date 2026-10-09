import '../../../shared/models/attendance_models.dart';

/// Kết quả phát hiện cập nhật công — mirror `detectUpdateFromRow` (web).
class UpdateScenario {
  const UpdateScenario({
    required this.updateKind,
    required this.forgotUnits,
    this.partial = false,
    this.locked = false,
    this.twoPunch = false,
    this.continuous = false,
    this.missingMorningIn = false,
    this.missingMorningOut = false,
    this.missingAfternoonIn = false,
    this.missingAfternoonOut = false,
    this.existingMorningIn,
    this.existingMorningOut,
    this.existingAfternoonIn,
    this.existingAfternoonOut,
  });

  final String updateKind;
  final int forgotUnits;
  final bool partial;
  final bool locked;
  /// Ca chỉ cần vào sáng + ra chiều (phân quyền công).
  final bool twoPunch;
  /// Ca thông tầm: cũng chỉ 2 mốc vào/ra.
  final bool continuous;
  final bool missingMorningIn;
  final bool missingMorningOut;
  final bool missingAfternoonIn;
  final bool missingAfternoonOut;
  final String? existingMorningIn;
  final String? existingMorningOut;
  final String? existingAfternoonIn;
  final String? existingAfternoonOut;

  bool get needsUpdate =>
      missingMorningIn ||
      missingMorningOut ||
      missingAfternoonIn ||
      missingAfternoonOut ||
      forgotUnits > 0;
}

/// Mốc phạt muộn/sớm để giải trình — mirror `ExplanationPenaltySlot` (web).
class ExplanationPenaltySlot {
  const ExplanationPenaltySlot({
    required this.key,
    required this.label,
    required this.kind,
    required this.kindLabel,
    required this.current,
    required this.expected,
    required this.minutes,
  });

  /// morningIn | morningOut | afternoonIn | afternoonOut
  final String key;
  final String label;
  final String kind; // LATE | EARLY
  final String kindLabel;
  final String current;
  final String expected;
  final int minutes;

  String get explainedField => switch (key) {
        'morningIn' => 'explainedMorningIn',
        'morningOut' => 'explainedMorningOut',
        'afternoonIn' => 'explainedAfternoonIn',
        'afternoonOut' => 'explainedAfternoonOut',
        _ => 'explainedMorningIn',
      };
}

class WorkRequestDayLogic {
  WorkRequestDayLogic._();

  static const updateKindOptions = [
    (value: 'MORNING_SUPPLEMENT', label: 'Bổ sung ca sáng', forgotUnits: 2),
    (value: 'AFTERNOON_SUPPLEMENT', label: 'Bổ sung ca chiều', forgotUnits: 2),
    (value: 'FULL_DAY_SUPPLEMENT', label: 'Bổ sung cả ngày', forgotUnits: 4),
  ];

  static bool canExplain(AttendanceDay? day) {
    if (day == null) return false;
    return !day.lateMinutesExempt && day.lateMinutes > 0;
  }

  static bool needsUpdate(AttendanceDay? day) {
    if (day == null) return false;
    final date = day.workDate;
    if (date == null) return false;
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    if (d.isAfter(t)) return false;
    final status = day.status;
    if (status == 'ABSENT' || status == 'PARTIAL') return true;
    if (day.forgotShifts != null && day.forgotShifts!.isNotEmpty) return true;
    if (day.totalWorkUnits > 0 && day.totalWorkUnits < 0.99) return true;
    final anyPunch = [
      day.morningCheckInHm,
      day.morningCheckOutHm,
      day.afternoonCheckInHm,
      day.afternoonCheckOutHm,
    ].any((e) => e != null && e.isNotEmpty);
    return !anyPunch && day.totalWorkUnits == 0;
  }

  static UpdateScenario detectUpdate(AttendanceDay? day) {
    final mIn = day?.morningCheckInHm ?? '';
    final mOut = day?.morningCheckOutHm ?? '';
    final aIn = day?.afternoonCheckInHm ?? '';
    final aOut = day?.afternoonCheckOutHm ?? '';
    final morningComplete = mIn.isNotEmpty && mOut.isNotEmpty;
    final afternoonComplete = aIn.isNotEmpty && aOut.isNotEmpty;
    final anyPunch =
        mIn.isNotEmpty || mOut.isNotEmpty || aIn.isNotEmpty || aOut.isNotEmpty;

    if (!anyPunch) {
      return const UpdateScenario(
        updateKind: 'FULL_DAY_SUPPLEMENT',
        forgotUnits: 4,
      );
    }

    if (morningComplete && !afternoonComplete) {
      final missing = (aIn.isEmpty ? 1 : 0) + (aOut.isEmpty ? 1 : 0);
      return UpdateScenario(
        updateKind: 'AFTERNOON_SUPPLEMENT',
        forgotUnits: missing == 0 ? 2 : missing,
        partial: missing == 1,
        locked: true,
        missingAfternoonIn: aIn.isEmpty,
        missingAfternoonOut: aOut.isEmpty,
        existingAfternoonIn: aIn.isEmpty ? null : aIn,
        existingAfternoonOut: aOut.isEmpty ? null : aOut,
      );
    }

    if (!morningComplete && afternoonComplete) {
      final missing = (mIn.isEmpty ? 1 : 0) + (mOut.isEmpty ? 1 : 0);
      return UpdateScenario(
        updateKind: 'MORNING_SUPPLEMENT',
        forgotUnits: missing == 0 ? 2 : missing,
        partial: missing == 1,
        locked: true,
        missingMorningIn: mIn.isEmpty,
        missingMorningOut: mOut.isEmpty,
        existingMorningIn: mIn.isEmpty ? null : mIn,
        existingMorningOut: mOut.isEmpty ? null : mOut,
      );
    }

    if (!morningComplete && !afternoonComplete) {
      final mMissing = (mIn.isEmpty ? 1 : 0) + (mOut.isEmpty ? 1 : 0);
      final aMissing = (aIn.isEmpty ? 1 : 0) + (aOut.isEmpty ? 1 : 0);
      if (mMissing > 0 && aMissing > 0) {
        final afternoonEmpty = aIn.isEmpty && aOut.isEmpty;
        final morningHadPunch = mIn.isNotEmpty || mOut.isNotEmpty;
        final preferMorningOnly = morningHadPunch && afternoonEmpty;
        return UpdateScenario(
          updateKind:
              preferMorningOnly ? 'MORNING_SUPPLEMENT' : 'FULL_DAY_SUPPLEMENT',
          forgotUnits:
              preferMorningOnly ? mMissing : mMissing + aMissing,
          partial: preferMorningOnly
              ? mMissing < 2
              : mMissing + aMissing < 4,
          missingMorningIn: mIn.isEmpty,
          missingMorningOut: mOut.isEmpty,
          missingAfternoonIn: aIn.isEmpty,
          missingAfternoonOut: aOut.isEmpty,
          existingMorningIn: mIn.isEmpty ? null : mIn,
          existingMorningOut: mOut.isEmpty ? null : mOut,
          existingAfternoonIn: aIn.isEmpty ? null : aIn,
          existingAfternoonOut: aOut.isEmpty ? null : aOut,
        );
      }
      if (mMissing > 0) {
        return UpdateScenario(
          updateKind: 'MORNING_SUPPLEMENT',
          forgotUnits: mMissing,
          partial: mMissing == 1,
          locked: true,
          missingMorningIn: mIn.isEmpty,
          missingMorningOut: mOut.isEmpty,
          existingMorningIn: mIn.isEmpty ? null : mIn,
          existingMorningOut: mOut.isEmpty ? null : mOut,
        );
      }
      return UpdateScenario(
        updateKind: 'AFTERNOON_SUPPLEMENT',
        forgotUnits: aMissing,
        partial: aMissing == 1,
        locked: true,
        missingAfternoonIn: aIn.isEmpty,
        missingAfternoonOut: aOut.isEmpty,
        existingAfternoonIn: aIn.isEmpty ? null : aIn,
        existingAfternoonOut: aOut.isEmpty ? null : aOut,
      );
    }

    return const UpdateScenario(
      updateKind: 'MORNING_SUPPLEMENT',
      forgotUnits: 2,
    );
  }

  /// PQ công / ca thông tầm: chỉ vào sáng và ra chiều, tối đa 2 lần quên chấm.
  static UpdateScenario detectTwoSlot(
    AttendanceDay? day, {
    bool twoPunch = true,
    String? morningStart,
    String? afternoonEnd,
  }) {
    var dayIn = day?.morningCheckInHm ?? '';
    var dayOut = day?.afternoonCheckOutHm ?? '';
    if (twoPunch) {
      final inAnchor = (morningStart != null && morningStart.isNotEmpty)
          ? morningStart
          : '06:45';
      final outAnchor = (afternoonEnd != null && afternoonEnd.isNotEmpty)
          ? afternoonEnd
          : '17:00';
      final punches = _punchList(day);
      if (dayIn.isNotEmpty && !_inWindow(dayIn, inAnchor, 60, 120)) dayIn = '';
      if (dayOut.isNotEmpty && !_inWindow(dayOut, outAnchor, 60, 60)) {
        dayOut = '';
      }
      if (dayIn.isEmpty) {
        for (final t in punches) {
          if (_inWindow(t, inAnchor, 60, 120)) {
            dayIn = t;
            break;
          }
        }
      }
      if (dayOut.isEmpty) {
        for (final t in punches.reversed) {
          if (t != dayIn && _inWindow(t, outAnchor, 60, 60)) {
            dayOut = t;
            break;
          }
        }
      }
    } else if (dayIn.isEmpty && dayOut.isEmpty) {
      final punches = (day?.punchTimes ?? const <String>[])
          .map((t) => t.length >= 5 ? t.substring(0, 5) : t)
          .where((t) => t.isNotEmpty)
          .toList()
        ..sort();
      if (punches.length == 1) {
        if (_looksLikeAfternoonOut(punches.first)) {
          dayOut = punches.first;
        } else {
          dayIn = punches.first;
        }
      } else if (punches.isNotEmpty) {
        dayIn = punches.first;
        dayOut = punches.last;
      }
    }
    if (!twoPunch &&
        dayIn.isNotEmpty &&
        dayOut.isEmpty &&
        _looksLikeAfternoonOut(dayIn)) {
      dayOut = dayIn;
      dayIn = '';
    }
    if (dayIn.isNotEmpty && dayIn == dayOut) {
      if (_looksLikeAfternoonOut(dayIn)) {
        dayIn = '';
      } else {
        dayOut = '';
      }
    }
    final missingIn = dayIn.isEmpty;
    final missingOut = dayOut.isEmpty;
    final missing = (missingIn ? 1 : 0) + (missingOut ? 1 : 0);
    return UpdateScenario(
      updateKind: 'FULL_DAY_SUPPLEMENT',
      forgotUnits: missing,
      partial: missing == 1,
      locked: true,
      twoPunch: twoPunch,
      continuous: !twoPunch,
      missingMorningIn: missingIn,
      missingAfternoonOut: missingOut,
      existingMorningIn: dayIn.isEmpty ? null : dayIn,
      existingAfternoonOut: dayOut.isEmpty ? null : dayOut,
    );
  }

  static List<String> _punchList(AttendanceDay? day) {
    final punches = (day?.punchTimes ?? const <String>[])
        .map((t) => t.length >= 5 ? t.substring(0, 5) : t)
        .where((t) => t.isNotEmpty)
        .toList()
      ..sort();
    return punches;
  }

  static bool _inWindow(String time, String anchor, int beforeMin, int afterMin) {
    final t = _minutes(time);
    final a = _minutes(anchor);
    return t >= a - beforeMin && t <= a + afterMin;
  }

  static int _minutes(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  static bool _looksLikeAfternoonOut(String time) {
    final hour = int.tryParse(time.split(':').first) ?? 0;
    return hour >= 12;
  }

  static int forgotUnitsForChoice(String updateKind, UpdateScenario? scenario) {
    if (scenario == null) return defaultForgotUnits(updateKind);
    if ((scenario.twoPunch || scenario.continuous) &&
        updateKind == 'FULL_DAY_SUPPLEMENT') {
      return (scenario.missingMorningIn ? 1 : 0) +
          (scenario.missingAfternoonOut ? 1 : 0);
    }
    if (updateKind == 'MORNING_SUPPLEMENT') {
      final n = (scenario.missingMorningIn ? 1 : 0) +
          (scenario.missingMorningOut ? 1 : 0);
      return n > 0 ? n : defaultForgotUnits(updateKind);
    }
    if (updateKind == 'AFTERNOON_SUPPLEMENT') {
      final n = (scenario.missingAfternoonIn ? 1 : 0) +
          (scenario.missingAfternoonOut ? 1 : 0);
      return n > 0 ? n : defaultForgotUnits(updateKind);
    }
    if (updateKind == 'FULL_DAY_SUPPLEMENT') {
      final n = (scenario.missingMorningIn ? 1 : 0) +
          (scenario.missingMorningOut ? 1 : 0) +
          (scenario.missingAfternoonIn ? 1 : 0) +
          (scenario.missingAfternoonOut ? 1 : 0);
      return n > 0 ? n : defaultForgotUnits(updateKind);
    }
    return defaultForgotUnits(updateKind);
  }

  static int defaultForgotUnits(String kind) {
    for (final o in updateKindOptions) {
      if (o.value == kind) return o.forgotUnits;
    }
    return 2;
  }

  static List<ExplanationPenaltySlot> detectExplanationSlots({
    required AttendanceDay? day,
    required DayShiftSchedule? schedule,
  }) {
    if (day == null || schedule == null) return const [];
    final continuous = schedule.continuousShift;
    final slots = <ExplanationPenaltySlot>[];

    if (continuous) {
      final dayIn = day.morningCheckInHm ?? day.checkInHm ?? '';
      final dayOut = day.afternoonCheckOutHm ?? day.checkOutHm ?? '';
      final expectedIn =
          schedule.continuousStart ?? schedule.morningStart ?? '';
      final expectedOut =
          schedule.continuousEnd ?? schedule.afternoonEnd ?? '';
      final late = dayIn.isEmpty ? 0 : minutesLate(dayIn, expectedIn);
      final early =
          dayIn.isEmpty || dayOut.isEmpty ? 0 : minutesEarly(dayOut, expectedOut);
      if (late > 0) {
        slots.add(
          ExplanationPenaltySlot(
            key: 'morningIn',
            label: 'Giờ vào (thông tầm)',
            kind: 'LATE',
            kindLabel: 'Đi muộn',
            current: dayIn,
            expected: expectedIn,
            minutes: late,
          ),
        );
      }
      if (early > 0) {
        slots.add(
          ExplanationPenaltySlot(
            key: 'afternoonOut',
            label: 'Giờ ra (thông tầm)',
            kind: 'EARLY',
            kindLabel: 'Về sớm',
            current: dayOut,
            expected: expectedOut,
            minutes: early,
          ),
        );
      }
      return slots;
    }

    final mIn = day.morningCheckInHm ?? '';
    final mOut = day.morningCheckOutHm ?? '';
    final aIn = day.afternoonCheckInHm ?? '';
    final aOut = day.afternoonCheckOutHm ?? '';
    final mStart = schedule.morningStart ?? '';
    final mEnd = schedule.morningEnd ?? '';
    final aStart = schedule.afternoonStart ?? '';
    final aEnd = schedule.afternoonEnd ?? '';

    final lateM = mIn.isEmpty ? 0 : minutesLate(mIn, mStart);
    if (lateM > 0) {
      slots.add(
        ExplanationPenaltySlot(
          key: 'morningIn',
          label: 'Ca sáng — giờ vào',
          kind: 'LATE',
          kindLabel: 'Đi muộn',
          current: mIn,
          expected: mStart,
          minutes: lateM,
        ),
      );
    }
    final earlyM =
        mIn.isEmpty || mOut.isEmpty ? 0 : minutesEarly(mOut, mEnd);
    if (earlyM > 0) {
      slots.add(
        ExplanationPenaltySlot(
          key: 'morningOut',
          label: 'Ca sáng — giờ ra',
          kind: 'EARLY',
          kindLabel: 'Về sớm',
          current: mOut,
          expected: mEnd,
          minutes: earlyM,
        ),
      );
    }
    final lateA = aIn.isEmpty ? 0 : minutesLate(aIn, aStart);
    if (lateA > 0) {
      slots.add(
        ExplanationPenaltySlot(
          key: 'afternoonIn',
          label: 'Ca chiều — giờ vào',
          kind: 'LATE',
          kindLabel: 'Đi muộn',
          current: aIn,
          expected: aStart,
          minutes: lateA,
        ),
      );
    }
    final earlyA =
        aIn.isEmpty || aOut.isEmpty ? 0 : minutesEarly(aOut, aEnd);
    if (earlyA > 0) {
      slots.add(
        ExplanationPenaltySlot(
          key: 'afternoonOut',
          label: 'Ca chiều — giờ ra',
          kind: 'EARLY',
          kindLabel: 'Về sớm',
          current: aOut,
          expected: aEnd,
          minutes: earlyA,
        ),
      );
    }
    return slots;
  }

  static String shiftScopeFromExplanationKeys(Iterable<String> keys) {
    final morning =
        keys.any((k) => k == 'morningIn' || k == 'morningOut');
    final afternoon =
        keys.any((k) => k == 'afternoonIn' || k == 'afternoonOut');
    if (morning && afternoon) return 'FULL_DAY';
    if (afternoon) return 'AFTERNOON';
    return 'MORNING';
  }

  static String shiftScopeFromUpdateKind(String kind) {
    if (kind == 'AFTERNOON_SUPPLEMENT') return 'AFTERNOON';
    if (kind == 'FULL_DAY_SUPPLEMENT') return 'FULL_DAY';
    return 'MORNING';
  }

  static int? parseHmMinutes(String? value) {
    if (value == null || value.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (m == null) return null;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  static int minutesLate(String actual, String expected) {
    final a = parseHmMinutes(actual);
    final e = parseHmMinutes(expected);
    if (a == null || e == null) return 0;
    return a > e ? a - e : 0;
  }

  static int minutesEarly(String actual, String expected) {
    final a = parseHmMinutes(actual);
    final e = parseHmMinutes(expected);
    if (a == null || e == null) return 0;
    return a < e ? e - a : 0;
  }

  static TimeOfDayParts? parseTimeOfDay(String? hhmm) {
    final mins = parseHmMinutes(hhmm);
    if (mins == null) return null;
    return TimeOfDayParts(hour: mins ~/ 60, minute: mins % 60);
  }
}

class TimeOfDayParts {
  const TimeOfDayParts({required this.hour, required this.minute});
  final int hour;
  final int minute;
}
