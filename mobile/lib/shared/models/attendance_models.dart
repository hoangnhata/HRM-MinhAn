import '../../core/utils/user_role.dart';

/// Tom tat cong trong thang — mirror AttendanceSummaryService.buildSummary.
class AttendanceMonthSummary {
  AttendanceMonthSummary({required this.raw});
  final Map<String, dynamic> raw;

  int get periodYear => (raw['periodYear'] as num?)?.toInt() ?? 0;
  int get periodMonth => (raw['periodMonth'] as num?)?.toInt() ?? 0;
  double get attendanceWorkUnits => _num(raw['attendanceWorkUnits']);
  double get clockedWorkUnits =>
      _num(raw['clockedWorkUnits'] ?? raw['attendanceWorkUnits']);
  double get leaveWorkUnits => _num(raw['leaveWorkUnits']);
  double get totalWorkUnits => _num(raw['totalWorkUnits']);
  int get lateMinutesTotal => (raw['lateMinutesTotal'] as num?)?.toInt() ?? 0;
  double get latePenalty => _num(raw['latePenalty']);
  String? get latePenaltyTier => raw['latePenaltyTier'] as String?;
  int get forgotFineCount => (raw['forgotFineCount'] as num?)?.toInt() ?? 0;
  double get forgotPenalty => _num(raw['forgotPenalty']);
  double get dutyBonusTotal => _num(raw['dutyBonusTotal']);
  double get dutyPostPayTotal => _num(raw['dutyPostPayTotal']);
  double get dutyWorkUnitsTotal => _num(raw['dutyWorkUnitsTotal']);
  int get dutyShiftCount => (raw['dutyShiftCount'] as num?)?.toInt() ?? 0;
  double get mealAllowance => _num(raw['mealAllowance']);
  int get mealAllowancePresentDays =>
      (raw['mealAllowancePresentDays'] as num?)?.toInt() ?? 0;
  int get mealAllowanceMorningDays =>
      (raw['mealAllowanceMorningDays'] as num?)?.toInt() ?? 0;
  double get mealAllowanceDutyUnits => _num(raw['mealAllowanceDutyUnits']);
  double get seminarSupportTotal => _num(raw['seminarSupportTotal']);
  int get seminarSupportCount =>
      (raw['seminarSupportCount'] as num?)?.toInt() ?? 0;
  double get quangTrungAllowance => _num(raw['quangTrungAllowance']);
  int get quangTrungAllowanceCount =>
      (raw['quangTrungAllowanceCount'] as num?)?.toInt() ?? 0;
  double get quangTrungAllowanceRate => _num(raw['quangTrungAllowanceRate']);
  bool get requiresDiscipline => raw['requiresDiscipline'] as bool? ?? false;

  String get mealAllowanceSub {
    final parts = <String>[];
    if (mealAllowancePresentDays > 0) {
      parts.add('$mealAllowancePresentDays đủ công');
    }
    if (mealAllowanceMorningDays > 0) {
      parts.add('$mealAllowanceMorningDays sáng');
    }
    if (mealAllowanceDutyUnits > 0) {
      final dutyDays = mealAllowanceDutyUnits / 2;
      final text = dutyDays % 1 == 0
          ? dutyDays.toInt().toString()
          : dutyDays.toStringAsFixed(1).replaceAll('.', ',');
      parts.add('$text trực ×2');
    }
    return parts.isEmpty ? 'Theo ngày đủ công' : parts.join(' + ');
  }

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  factory AttendanceMonthSummary.fromJson(Map<String, dynamic> json) =>
      AttendanceMonthSummary(raw: json);
}

/// Mot ngay cong — mirror AttendanceService.toMap(AttendanceRecord).
class AttendanceDay {
  AttendanceDay({required this.raw});
  final Map<String, dynamic> raw;

  int? get employeeId => (raw['employeeId'] as num?)?.toInt();

  DateTime? get workDate => DateTime.tryParse(raw['workDate'] as String? ?? '');
  String? get checkIn => _time(raw['checkIn']);
  String? get checkOut => _time(raw['checkOut']);
  String? get morningCheckIn => _time(raw['morningCheckIn']);
  String? get morningCheckOut => _time(raw['morningCheckOut']);
  String? get afternoonCheckIn => _time(raw['afternoonCheckIn']);
  String? get afternoonCheckOut => _time(raw['afternoonCheckOut']);

  /// Giờ máy dạng `HH:mm` — dùng logic phát hiện muộn/thiếu ca (đồng bộ web).
  String? get morningCheckInHm => DayShiftSchedule.hhmm(raw['morningCheckIn']);
  String? get morningCheckOutHm => DayShiftSchedule.hhmm(raw['morningCheckOut']);
  String? get afternoonCheckInHm =>
      DayShiftSchedule.hhmm(raw['afternoonCheckIn']);
  String? get afternoonCheckOutHm =>
      DayShiftSchedule.hhmm(raw['afternoonCheckOut']);
  String? get checkInHm => DayShiftSchedule.hhmm(raw['checkIn']);
  String? get checkOutHm => DayShiftSchedule.hhmm(raw['checkOut']);

  double get morningWorkUnits => (raw['morningWorkUnits'] as num?)?.toDouble() ?? 0;
  double get afternoonWorkUnits =>
      (raw['afternoonWorkUnits'] as num?)?.toDouble() ?? 0;
  double get overtimeWorkUnits =>
      (raw['overtimeWorkUnits'] as num?)?.toDouble() ?? 0;
  double get totalWorkUnits => (raw['totalWorkUnits'] as num?)?.toDouble() ?? 0.0;
  int get lateMinutes => (raw['lateMinutes'] as num?)?.toInt() ?? 0;
  bool get lateMinutesExempt => raw['lateMinutesExempt'] as bool? ?? false;
  String? get forgotShifts => _emptyToNull(raw['forgotShifts']);
  String? get status => raw['status'] as String?;
  String? get note => raw['note'] as String?;
  bool get deployment => raw['deployment'] as bool? ?? false;
  bool get youngChild => raw['youngChild'] as bool? ?? false;
  bool get quangTrung => raw['quangTrung'] as bool? ?? false;
  bool get congHo => raw['congHo'] as bool? ?? false;

  bool get isLeaveDay =>
      status == 'LEAVE' || status == 'UNPAID_LEAVE';
  bool get isDeploymentDay =>
      deployment || status == 'DEPLOYMENT' || status == 'BUSINESS_TRIP';

  List<String> get punchTimes {
    final list = raw['punchTimes'];
    if (list is! List) return const [];
    return list
        .map((e) => _time(e))
        .whereType<String>()
        .toList();
  }

  /// Nhãn trạng thái đồng bộ web WorkPage STATUS_CHIP.
  String get statusLabel {
    return switch (status) {
      'PRESENT' => 'Đủ công',
      'PARTIAL' => 'Thiếu ca',
      'ABSENT' => 'Vắng',
      'LEAVE' => 'Phép',
      'UNPAID_LEAVE' => 'Không lương',
      'BUSINESS_TRIP' => 'Công tác',
      'SEMINAR' => 'Hội thảo',
      'DEPLOYMENT' => 'Điều động',
      _ => status?.isNotEmpty == true ? status! : 'Chưa có',
    };
  }

  static String? _emptyToNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Chuẩn hoá `HH:mm:ss` / `HH:mm` → `HHhmm` kiểu app (6h47).
  static String? _time(dynamic v) {
    final raw = _emptyToNull(v);
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1].padLeft(2, '0');
    return '${h}h$m';
  }

  factory AttendanceDay.fromJson(Map<String, dynamic> json) =>
      AttendanceDay(raw: json);
}

class LeaveBalance {
  LeaveBalance({required this.raw});
  final Map<String, dynamic> raw;

  int get year => (raw['year'] as num?)?.toInt() ?? DateTime.now().year;
  int get entitlementDays => (raw['entitlementDays'] as num?)?.toInt() ?? 0;
  int get usedDays => (raw['usedDays'] as num?)?.toInt() ?? 0;
  int get pendingDays => (raw['pendingDays'] as num?)?.toInt() ?? 0;
  int get remainingDays => (raw['remainingDays'] as num?)?.toInt() ?? 0;
  bool get overLimit => raw['overLimit'] as bool? ?? false;
  String? get warning => raw['warning'] as String?;

  factory LeaveBalance.fromJson(Map<String, dynamic> json) =>
      LeaveBalance(raw: json);
}

/// Lich ca cua mot ngay — mirror AttendanceShiftScheduleService.infoForDate.
class DayShiftSchedule {
  DayShiftSchedule({required this.raw});
  final Map<String, dynamic> raw;

  bool get summer => raw['summer'] as bool? ?? false;
  String? get seasonLabel => raw['seasonLabel'] as String?;
  String? get periodLabel => raw['periodLabel'] as String?;
  bool get continuousShift => raw['continuousShift'] as bool? ?? false;
  String? get continuousLabel => raw['continuousLabel'] as String?;
  String? get dayShiftKind => raw['dayShiftKind'] as String?;
  String? get dayShiftTypeName => raw['dayShiftTypeName'] as String?;
  String? get splitDayLabel => raw['splitDayLabel'] as String?;

  bool get isSplitDay => dayShiftKind == 'SPLIT';
  bool get isContinuousDay =>
      continuousShift || dayShiftKind == 'CONTINUOUS';
  bool get youngChild => raw['youngChild'] as bool? ?? false;
  String? get youngChildLabel => raw['youngChildLabel'] as String?;
  num? get morningHours => raw['morningHours'] as num?;
  num? get afternoonHours => raw['afternoonHours'] as num?;
  num? get continuousHours => raw['continuousHours'] as num?;
  num? get totalHours => raw['totalHours'] as num?;
  num? get morningUnits => raw['morningUnits'] as num?;
  num? get afternoonUnits => raw['afternoonUnits'] as num?;
  num? get effectiveDayHours => raw['effectiveDayHours'] as num?;
  String? get morningUnitsLabel => raw['morningUnitsLabel'] as String?;
  String? get afternoonUnitsLabel => raw['afternoonUnitsLabel'] as String?;

  /// Giờ dạng `HH:mm` (backend trả `HH:mm:ss`).
  String? get morningStart => hhmm(raw['morningStart']);
  String? get morningEnd => hhmm(raw['morningEnd']);
  String? get afternoonStart => hhmm(raw['afternoonStart']);
  String? get afternoonEnd => hhmm(raw['afternoonEnd']);
  String? get continuousStart => hhmm(raw['continuousStart']);
  String? get continuousEnd => hhmm(raw['continuousEnd']);

  String get morningUnitsText =>
      morningUnitsLabel ?? _unitsFallback(morningUnits);
  String get afternoonUnitsText =>
      afternoonUnitsLabel ?? _unitsFallback(afternoonUnits);

  static String _unitsFallback(num? units) {
    if (units == null) return '0 công';
    final s = units.toStringAsFixed(2).replaceAll('.', ',');
    return '$s công';
  }

  static String? hhmm(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.length < 4) return null;
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  /// `6h45` từ `06:45`.
  static String? displayTime(String? hhmmValue) {
    if (hhmmValue == null || hhmmValue.length < 4) return null;
    final parts = hhmmValue.split(':');
    if (parts.length < 2) return hhmmValue;
    final h = int.tryParse(parts[0]) ?? 0;
    return '${h}h${parts[1]}';
  }

  factory DayShiftSchedule.fromJson(Map<String, dynamic> json) =>
      DayShiftSchedule(raw: json);
}

/// Kiểu ca theo ngày — mirror ContinuousShiftKind.
enum ContinuousShiftKind {
  continuous,
  split;

  static ContinuousShiftKind fromJson(Object? value) {
    if (value == 'SPLIT') return ContinuousShiftKind.split;
    return ContinuousShiftKind.continuous;
  }

  String get apiValue =>
      this == ContinuousShiftKind.split ? 'SPLIT' : 'CONTINUOUS';

  String get shortLabel => this == ContinuousShiftKind.split ? 'SC' : 'TT';

  String get defaultKindLabel =>
      this == ContinuousShiftKind.split ? 'Ca sáng–chiều' : 'Ca thông tầm';
}

/// Loại ca theo ngày — mirror ContinuousShiftType.
class ContinuousShiftType {
  ContinuousShiftType({
    required this.id,
    required this.name,
    required this.kind,
    required this.startTime,
    required this.endTime,
    this.kindLabel,
    this.morningStart,
    this.morningEnd,
    this.afternoonStart,
    this.afternoonEnd,
    this.active = true,
    this.hours = 0,
  });

  final int id;
  final String name;
  final ContinuousShiftKind kind;
  final String? kindLabel;
  final String startTime;
  final String endTime;
  final String? morningStart;
  final String? morningEnd;
  final String? afternoonStart;
  final String? afternoonEnd;
  final bool active;
  final num hours;

  bool get isSplit => kind == ContinuousShiftKind.split;

  String get startHm => DayShiftSchedule.hhmm(startTime) ?? startTime;
  String get endHm => DayShiftSchedule.hhmm(endTime) ?? endTime;
  String get morningStartHm =>
      DayShiftSchedule.hhmm(morningStart ?? startTime) ?? startTime;
  String get morningEndHm =>
      DayShiftSchedule.hhmm(morningEnd) ?? morningEnd ?? '';
  String get afternoonStartHm =>
      DayShiftSchedule.hhmm(afternoonStart) ?? afternoonStart ?? '';
  String get afternoonEndHm =>
      DayShiftSchedule.hhmm(afternoonEnd ?? endTime) ?? endTime;

  String get timeLabel {
    if (isSplit) {
      return '$morningStartHm–$morningEndHm / $afternoonStartHm–$afternoonEndHm';
    }
    return '$startHm–$endHm';
  }

  String get displayLabel =>
      kindLabel?.trim().isNotEmpty == true ? kindLabel! : kind.defaultKindLabel;

  factory ContinuousShiftType.fromJson(Map<String, dynamic> json) {
    return ContinuousShiftType(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Ca làm việc',
      kind: ContinuousShiftKind.fromJson(json['kind']),
      kindLabel: json['kindLabel'] as String?,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      morningStart: json['morningStart'] as String?,
      morningEnd: json['morningEnd'] as String?,
      afternoonStart: json['afternoonStart'] as String?,
      afternoonEnd: json['afternoonEnd'] as String?,
      active: json['active'] as bool? ?? true,
      hours: json['hours'] as num? ?? 0,
    );
  }
}

/// Một ngày gắn ca theo danh mục (thông tầm hoặc sáng–chiều).
class ContinuousShiftDayInfo {
  ContinuousShiftDayInfo({
    required this.date,
    this.shiftTypeId,
    this.shiftTypeName,
    this.kind,
    this.kindLabel,
    this.continuousStart,
    this.continuousEnd,
    this.morningStart,
    this.morningEnd,
    this.afternoonStart,
    this.afternoonEnd,
  });

  final String date;
  final int? shiftTypeId;
  final String? shiftTypeName;
  final ContinuousShiftKind? kind;
  final String? kindLabel;
  final String? continuousStart;
  final String? continuousEnd;
  final String? morningStart;
  final String? morningEnd;
  final String? afternoonStart;
  final String? afternoonEnd;

  bool get isSplit => kind == ContinuousShiftKind.split;

  factory ContinuousShiftDayInfo.fromJson(Map<String, dynamic> json) {
    return ContinuousShiftDayInfo(
      date: json['date'] as String? ?? '',
      shiftTypeId: (json['shiftTypeId'] as num?)?.toInt(),
      shiftTypeName: json['shiftTypeName'] as String?,
      kind: json['kind'] == null
          ? null
          : ContinuousShiftKind.fromJson(json['kind']),
      kindLabel: json['kindLabel'] as String?,
      continuousStart: json['continuousStart'] as String?,
      continuousEnd: json['continuousEnd'] as String?,
      morningStart: json['morningStart'] as String?,
      morningEnd: json['morningEnd'] as String?,
      afternoonStart: json['afternoonStart'] as String?,
      afternoonEnd: json['afternoonEnd'] as String?,
    );
  }

  Map<String, dynamic> toPayload() => {
        'date': date,
        'shiftTypeId': shiftTypeId,
        'continuousStart': continuousStart,
        'continuousEnd': continuousEnd,
      };
}

class ContinuousShiftMonth {
  ContinuousShiftMonth({
    required this.employeeId,
    required this.periodYear,
    required this.periodMonth,
    required this.dates,
    required this.days,
    this.continuousDates = const [],
    this.splitDates = const [],
    this.continuousShift = false,
    this.dayCount = 0,
    this.recalculated = 0,
    this.recalculateWarning,
  });

  final int employeeId;
  final int periodYear;
  final int periodMonth;
  final List<String> dates;
  final List<ContinuousShiftDayInfo> days;
  final List<String> continuousDates;
  final List<String> splitDates;
  final bool continuousShift;
  final int dayCount;
  final int recalculated;
  final String? recalculateWarning;

  factory ContinuousShiftMonth.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? const [];
    final rawDates = json['dates'] as List<dynamic>? ?? const [];
    final rawContinuous =
        json['continuousDates'] as List<dynamic>? ?? const [];
    final rawSplit = json['splitDates'] as List<dynamic>? ?? const [];
    return ContinuousShiftMonth(
      employeeId: (json['employeeId'] as num?)?.toInt() ?? 0,
      periodYear: (json['periodYear'] as num?)?.toInt() ?? 0,
      periodMonth: (json['periodMonth'] as num?)?.toInt() ?? 0,
      dates: rawDates.map((e) => e.toString()).toList(),
      days: rawDays
          .map((e) => ContinuousShiftDayInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      continuousDates: rawContinuous.map((e) => e.toString()).toList(),
      splitDates: rawSplit.map((e) => e.toString()).toList(),
      continuousShift: json['continuousShift'] as bool? ?? false,
      dayCount: (json['dayCount'] as num?)?.toInt() ?? 0,
      recalculated: (json['recalculated'] as num?)?.toInt() ?? 0,
      recalculateWarning: json['recalculateWarning'] as String?,
    );
  }
}

/// Ca trực — mirror DutyShiftEntry trên web.
class DutyShiftEntry {
  DutyShiftEntry({required this.raw});
  final Map<String, dynamic> raw;

  String get workDate => raw['workDate'] as String? ?? '';
  String? get shiftTypeCode => raw['shiftTypeCode'] as String?;
  String? get shiftTypeLabel => raw['shiftTypeLabel'] as String?;
  String? get roleTierCode => raw['roleTier'] as String?;
  String? get roleTierLabel => raw['roleTierLabel'] as String?;
  double get workUnits => (raw['workUnits'] as num?)?.toDouble() ?? 0;
  double get bonusAmount => (raw['bonusAmount'] as num?)?.toDouble() ?? 0;
  double get postDutyPay => (raw['postDutyPay'] as num?)?.toDouble() ?? 0;
  String? get note => raw['note'] as String?;

  factory DutyShiftEntry.fromJson(Map<String, dynamic> json) =>
      DutyShiftEntry(raw: json);
}

/// Loại ca trực dùng để hiển thị lựa chọn khi bổ sung / cập nhật công trực.
/// Mirror `/v1/attendance/duty-shifts/types`.
class DutyShiftTypeOption {
  DutyShiftTypeOption({required this.code, required this.label, this.grantsWorkUnits = false, required this.roleTiers});

  final String code;
  final String label;
  final bool grantsWorkUnits;
  final List<DutyShiftRoleTierOption> roleTiers;

  factory DutyShiftTypeOption.fromJson(Map<String, dynamic> json) {
    final roleTiersRaw = json['roleTiers'];
    final roleTiers = roleTiersRaw is List
        ? roleTiersRaw
            .whereType<Map>()
            .map((e) => DutyShiftRoleTierOption.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DutyShiftRoleTierOption>[];

    return DutyShiftTypeOption(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      grantsWorkUnits: json['grantsWorkUnits'] as bool? ?? false,
      roleTiers: roleTiers,
    );
  }
}

class DutyShiftRoleTierOption {
  DutyShiftRoleTierOption({required this.code, required this.label});
  final String code;
  final String label;

  factory DutyShiftRoleTierOption.fromJson(Map<String, dynamic> json) {
    return DutyShiftRoleTierOption(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

/// View công Quang Trung theo ngày.
/// Mirror `/v1/attendance/employees/{id}/quang-trung-supplement`.
class QuangTrungSupplementView {
  QuangTrungSupplementView({required this.raw});
  final Map<String, dynamic> raw;

  bool get exists => raw['exists'] as bool? ?? false;
  String get updateKind => raw['updateKind']?.toString() ?? '';
  String? get reason => (raw['reason'] as String?)?.trim();

  String? get morningCheckIn => raw['morningCheckIn'] as String?;
  String? get morningCheckOut => raw['morningCheckOut'] as String?;
  String? get afternoonCheckIn => raw['afternoonCheckIn'] as String?;
  String? get afternoonCheckOut => raw['afternoonCheckOut'] as String?;

  /// Backend trả giờ dạng `HH:mm` — parse sang (hour, minute) để bắn lên UI.
  static ({int hour, int minute})? parseHm(String? hhmm) {
    final text = hhmm?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (hour: h, minute: m);
  }
}

/// Don cong — mirror AttendanceWorkRequestService.toMap.
class AttendanceWorkRequest {
  AttendanceWorkRequest({required this.raw});
  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num).toInt();
  int? get employeeId => (raw['employeeId'] as num?)?.toInt();
  String? get employeeName => raw['employeeName'] as String?;
  String? get positionTitle => raw['positionTitle'] as String?;
  String? get department => raw['department'] as String?;
  String get requestType => raw['requestType'] as String? ?? '';
  DateTime? get workDate => DateTime.tryParse(raw['workDate'] as String? ?? '');
  DateTime? get endDate =>
      raw['endDate'] != null ? DateTime.tryParse(raw['endDate'] as String) : null;
  double? get leaveDays => (raw['leaveDays'] as num?)?.toDouble();
  double? get tripDays => (raw['tripDays'] as num?)?.toDouble();
  String? get shiftScope {
    final v = raw['shiftScope']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get updateKind {
    final v = raw['updateKind']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get reason => raw['reason'] as String?;
  String? get location {
    final v = raw['location']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get explanationKind {
    final v = raw['explanationKind']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }
  String get status => raw['status'] as String? ?? '';
  String? get headComment => raw['headComment'] as String?;
  String? get nursingHeadComment => raw['nursingHeadComment'] as String?;
  String? get hrComment => raw['hrComment'] as String?;
  String? get directorComment => raw['directorComment'] as String?;
  String? get headSignatureUrl => _emptyToNull(raw['headSignatureUrl']);
  String? get nursingHeadSignatureUrl =>
      _emptyToNull(raw['nursingHeadSignatureUrl']);
  String? get hrSignatureUrl => _emptyToNull(raw['hrSignatureUrl']);
  String? get directorSignatureUrl => _emptyToNull(raw['directorSignatureUrl']);
  String? get headReviewerUsername =>
      _emptyToNull(raw['headReviewerUsername']);
  String? get nursingHeadReviewerUsername =>
      _emptyToNull(raw['nursingHeadReviewerUsername']);
  String? get hrReviewerUsername => _emptyToNull(raw['hrReviewerUsername']);
  String? get directorReviewerUsername =>
      _emptyToNull(raw['directorReviewerUsername']);
  String? get headReviewerName => _emptyToNull(raw['headReviewerName']);
  String? get nursingHeadReviewerName =>
      _emptyToNull(raw['nursingHeadReviewerName']);
  String? get hrReviewerName => _emptyToNull(raw['hrReviewerName']);
  String? get directorReviewerName =>
      _emptyToNull(raw['directorReviewerName']);
  String? get flowSubmitterName => _emptyToNull(raw['flowSubmitterName']);
  String? get flowHeadName => _emptyToNull(raw['flowHeadName']);
  String? get flowNursingHeadName =>
      _emptyToNull(raw['flowNursingHeadName']);
  String? get flowHrName => _emptyToNull(raw['flowHrName']);
  String? get flowDirectorName => _emptyToNull(raw['flowDirectorName']);
  String? get requestedByUsername => _emptyToNull(raw['requestedByUsername']);
  DateTime? get headReviewedAt => _parseDt(raw['headReviewedAt']);
  DateTime? get nursingHeadReviewedAt => _parseDt(raw['nursingHeadReviewedAt']);
  DateTime? get hrReviewedAt => _parseDt(raw['hrReviewedAt']);
  DateTime? get directorReviewedAt => _parseDt(raw['directorReviewedAt']);
  DateTime? get createdAt => _parseDt(raw['createdAt']);
  bool get hrWaiveForgotFine => raw['hrWaiveForgotFine'] as bool? ?? false;

  String? get requestedStart => _hhmm(raw['requestedStart']);
  String? get requestedEnd => _hhmm(raw['requestedEnd']);
  String? get requestedAfternoonStart => _hhmm(raw['requestedAfternoonStart']);
  String? get requestedAfternoonEnd => _hhmm(raw['requestedAfternoonEnd']);
  String? get explainedMorningIn => _hhmm(raw['explainedMorningIn']);
  String? get explainedMorningOut => _hhmm(raw['explainedMorningOut']);
  String? get explainedAfternoonIn => _hhmm(raw['explainedAfternoonIn']);
  String? get explainedAfternoonOut => _hhmm(raw['explainedAfternoonOut']);
  String? get originalMorningIn => _hhmm(raw['originalMorningIn']);
  String? get originalMorningOut => _hhmm(raw['originalMorningOut']);
  String? get originalAfternoonIn => _hhmm(raw['originalAfternoonIn']);
  String? get originalAfternoonOut => _hhmm(raw['originalAfternoonOut']);
  double? get deploymentActualHours =>
      (raw['deploymentActualHours'] as num?)?.toDouble();
  double? get deploymentCreditedHours =>
      (raw['deploymentCreditedHours'] as num?)?.toDouble();
  bool get deploymentInsideShift =>
      raw['deploymentInsideShift'] as bool? ?? false;

  bool get canWithdraw => false; // Đơn đã gửi: người gửi không thu hồi (chỉ ADMIN trên web)

  /// Chỉnh sửa đơn đang chờ duyệt — khớp quyền backend `ensureCanEditWorkRequest`.
  bool canEditPending({
    required int? myEmployeeId,
    required String? myUsername,
    required UserRole role,
  }) {
    if (!status.startsWith('PENDING_')) return false;
    if (role == UserRole.admin) return true;
    if (requestType == 'DEPLOYMENT') {
      final head = headReviewerUsername?.trim();
      final me = myUsername?.trim();
      return head != null && head.isNotEmpty && me != null && me == head;
    }
    if (requestType == 'LEAVE' ||
        requestType == 'UNPAID_LEAVE' ||
        requestType == 'EXPLANATION' ||
        requestType == 'UPDATE') {
      return myEmployeeId != null && employeeId == myEmployeeId;
    }
    return false;
  }

  static String? _emptyToNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _parseDt(dynamic v) {
    final s = _emptyToNull(v);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static String? _hhmm(dynamic v) {
    final s = _emptyToNull(v);
    if (s == null || s.length < 4) return null;
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  factory AttendanceWorkRequest.fromJson(Map<String, dynamic> json) =>
      AttendanceWorkRequest(raw: json);
}

/// Ma trận bảng công theo khoa — `GET /v1/attendance/report/matrix`.
class AttendanceMonthMatrix {
  AttendanceMonthMatrix({required this.raw});
  final Map<String, dynamic> raw;

  int get year => (raw['year'] as num?)?.toInt() ?? 0;
  int get month => (raw['month'] as num?)?.toInt() ?? 0;
  int get daysInMonth => (raw['daysInMonth'] as num?)?.toInt() ?? 0;
  int? get departmentId => (raw['departmentId'] as num?)?.toInt();
  String get departmentName =>
      (raw['departmentName'] as String?)?.trim().isNotEmpty == true
          ? (raw['departmentName'] as String).trim()
          : 'Toàn bệnh viện';

  List<AttendanceMatrixRow> get rows {
    final list = raw['rows'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => AttendanceMatrixRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory AttendanceMonthMatrix.fromJson(Map<String, dynamic> json) =>
      AttendanceMonthMatrix(raw: json);
}

class AttendanceMatrixRow {
  AttendanceMatrixRow(this.raw);
  final Map<String, dynamic> raw;

  int get employeeId => (raw['employeeId'] as num?)?.toInt() ?? 0;
  String get employeeCode => (raw['employeeCode'] as String?)?.trim() ?? '';
  String get fullName => (raw['fullName'] as String?)?.trim() ?? '';
  String get department => (raw['department'] as String?)?.trim() ?? '';
  int? get departmentId => (raw['departmentId'] as num?)?.toInt();
  String get position => (raw['position'] as String?)?.trim() ?? '';
  String? get employeeStatus => raw['employeeStatus'] as String?;
  String? get phone => raw['phone'] as String?;

  double get attendanceWorkUnits => _n(raw['attendanceWorkUnits']);
  double get clockedWorkUnits =>
      _n(raw['clockedWorkUnits'] ?? raw['attendanceWorkUnits']);
  double get leaveWorkUnits => _n(raw['leaveWorkUnits']);
  double get totalWorkUnits =>
      _n(raw['totalWorkUnits'] ?? attendanceWorkUnits + dutyWorkUnitsTotal);
  int get lateMinutesTotal => (raw['lateMinutesTotal'] as num?)?.toInt() ?? 0;
  int get dutyShiftCount => (raw['dutyShiftCount'] as num?)?.toInt() ?? 0;
  double get dutyWorkUnitsTotal => _n(raw['dutyWorkUnitsTotal']);
  double get dutyBonusTotal => _n(raw['dutyBonusTotal']);
  double get dutyPostPayTotal => _n(raw['dutyPostPayTotal']);
  double get quangTrungAllowance => _n(raw['quangTrungAllowance']);
  int get quangTrungAllowanceCount =>
      (raw['quangTrungAllowanceCount'] as num?)?.toInt() ?? 0;
  double get quangTrungAllowanceRate => _n(raw['quangTrungAllowanceRate']);

  List<AttendanceMatrixDay> get days {
    final list = raw['days'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => AttendanceMatrixDay(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<AttendanceMatrixDutyDay> get dutyDays {
    final list = raw['dutyDays'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => AttendanceMatrixDutyDay(Map<String, dynamic>.from(e)))
        .toList();
  }

  Map<String, AttendanceMatrixDay> get dayByDate {
    final map = <String, AttendanceMatrixDay>{};
    for (final d in days) {
      if (d.workDate.isNotEmpty) map[d.workDate] = d;
    }
    return map;
  }

  Map<String, AttendanceMatrixDutyDay> get dutyByDate {
    final map = <String, AttendanceMatrixDutyDay>{};
    for (final d in dutyDays) {
      if (d.workDate.isNotEmpty) map[d.workDate] = d;
    }
    return map;
  }

  AttendanceMatrixStats stats(int daysInMonth) =>
      AttendanceMatrixStats.fromRow(this, daysInMonth);

  static double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

class AttendanceMatrixDay {
  AttendanceMatrixDay(this.raw);
  final Map<String, dynamic> raw;

  String get workDate => (raw['workDate'] as String?)?.trim() ?? '';
  String? get status => raw['status'] as String?;
  String? get note => raw['note'] as String?;
  bool get youngChild => raw['youngChild'] == true;
  bool get quangTrung => raw['quangTrung'] == true;
  bool get lateMinutesExempt => raw['lateMinutesExempt'] == true;
  int get lateMinutes => (raw['lateMinutes'] as num?)?.toInt() ?? 0;
  double get morningWorkUnits => _n(raw['morningWorkUnits']);
  double get afternoonWorkUnits => _n(raw['afternoonWorkUnits']);
  double get overtimeWorkUnits => _n(raw['overtimeWorkUnits']);
  double get totalWorkUnits => _n(raw['totalWorkUnits']);

  String? get morningCheckIn => _hm(raw['morningCheckIn']);
  String? get morningCheckOut => _hm(raw['morningCheckOut']);
  String? get afternoonCheckIn => _hm(raw['afternoonCheckIn']);
  String? get afternoonCheckOut => _hm(raw['afternoonCheckOut']);

  bool get isLeave =>
      status == 'LEAVE' || status == 'UNPAID_LEAVE' || status == 'ABSENT';

  String? get morningRange => _range(morningCheckIn, morningCheckOut);
  String? get afternoonRange => _range(afternoonCheckIn, afternoonCheckOut);

  static double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;

  static String? _hm(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  static String? _range(String? a, String? b) {
    if (a == null && b == null) return null;
    if (a != null && b != null) return '$a–$b';
    return a ?? b;
  }
}

class AttendanceMatrixDutyDay {
  AttendanceMatrixDutyDay(this.raw);
  final Map<String, dynamic> raw;

  String get workDate => (raw['workDate'] as String?)?.trim() ?? '';
  String get shiftTypeCode =>
      (raw['shiftTypeCode'] as String? ??
              raw['shiftType'] as String? ??
              raw['shiftTypeLabel'] as String? ??
              '')
          .trim();
  String get shiftTypeLabel => (raw['shiftTypeLabel'] as String?)?.trim() ?? '';
  String? get roleTierLabel => (raw['roleTierLabel'] as String?)?.trim();
  double get workUnits => (raw['workUnits'] as num?)?.toDouble() ?? 0;
  String? get note => raw['note'] as String?;

  String get displayShort {
    final code = shiftTypeCode.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return switch (code) {
      'tructoichinh' => 'Trực chính',
      'tc1' => 'Trực cọc 1',
      'tcc' => 'Trực đa khoa',
      'tk' => 'Trực kèm',
      _ => shiftTypeLabel.isNotEmpty
          ? shiftTypeLabel
          : (shiftTypeCode.isEmpty ? 'Ca trực' : shiftTypeCode),
    };
  }
}

class AttendanceMatrixStats {
  const AttendanceMatrixStats({
    required this.attendanceUnits,
    required this.dutyUnits,
    required this.totalUnits,
    required this.leaveDays,
    required this.missingUnits,
    required this.lateCount,
    required this.lateMinutes,
    required this.dutyCount,
    required this.quangTrungDays,
    required this.quangTrungUnits,
  });

  final double attendanceUnits;
  final double dutyUnits;
  final double totalUnits;
  final int leaveDays;
  final double missingUnits;
  final int lateCount;
  final int lateMinutes;
  final int dutyCount;
  final int quangTrungDays;
  final double quangTrungUnits;

  factory AttendanceMatrixStats.fromRow(
    AttendanceMatrixRow row,
    int daysInMonth,
  ) {
    var leaveDays = 0;
    var lateCount = 0;
    var quangTrungDays = 0;
    var quangTrungUnits = 0.0;
    for (final d in row.days) {
      if (d.isLeave) leaveDays += 1;
      if (d.lateMinutes > 0 && !d.lateMinutesExempt) lateCount += 1;
      if (d.quangTrung) {
        quangTrungDays += 1;
        quangTrungUnits += d.totalWorkUnits;
      }
    }
    final attendance = row.attendanceWorkUnits;
    final missing = (daysInMonth - leaveDays - attendance)
        .clamp(0, double.infinity)
        .toDouble();
    return AttendanceMatrixStats(
      attendanceUnits: attendance,
      dutyUnits: row.dutyWorkUnitsTotal,
      totalUnits: row.totalWorkUnits,
      leaveDays: leaveDays,
      missingUnits: (missing * 100).round() / 100,
      lateCount: lateCount,
      lateMinutes: row.lateMinutesTotal,
      dutyCount: row.dutyShiftCount,
      quangTrungDays: quangTrungDays,
      quangTrungUnits: quangTrungUnits,
    );
  }
}
