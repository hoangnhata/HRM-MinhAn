/// Báo cáo nhân lực — đồng bộ `frontend/src/services/workforceReportService.ts`.
class WorkforceReport {
  WorkforceReport({required this.raw});
  final Map<String, dynamic> raw;

  String get type => (raw['type'] as String?) ?? 'HOSPITAL';
  bool get isDaily => type == 'DAILY';
  String get reportDate => (raw['reportDate'] as String?) ?? '';
  String get generatedAt => (raw['generatedAt'] as String?) ?? '';
  int get grandTotal => (raw['grandTotal'] as num?)?.toInt() ?? 0;
  int get departmentCount => (raw['departmentCount'] as num?)?.toInt() ?? 0;

  List<WorkforceCategory> get categories {
    final list = raw['categories'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => WorkforceCategory.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  List<WorkforceDepartmentRow> get rows {
    final list = raw['rows'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => WorkforceDepartmentRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Map<String, int> get totals => _intMap(raw['totals']);

  List<WorkforceDetailRow> get details {
    final list = raw['details'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => WorkforceDetailRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  WorkforceCategory? get topCategory {
    if (categories.isEmpty) return null;
    final ranked = [
      for (final c in categories) (c, totals[c.key] ?? 0),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked.first.$1;
  }

  int get topCategoryCount {
    final top = topCategory;
    if (top == null) return 0;
    return totals[top.key] ?? 0;
  }

  factory WorkforceReport.fromJson(Map<String, dynamic> json) =>
      WorkforceReport(raw: json);
}

class WorkforceCategory {
  WorkforceCategory({required this.key, required this.label});
  final String key;
  final String label;

  factory WorkforceCategory.fromJson(Map<String, dynamic> json) =>
      WorkforceCategory(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

class WorkforceDepartmentRow {
  WorkforceDepartmentRow({required this.raw});
  final Map<String, dynamic> raw;

  int get departmentId => (raw['departmentId'] as num?)?.toInt() ?? 0;
  String get departmentName => (raw['departmentName'] as String?) ?? '';
  int get total => (raw['total'] as num?)?.toInt() ?? 0;
  Map<String, int> get counts => _intMap(raw['counts']);

  factory WorkforceDepartmentRow.fromJson(Map<String, dynamic> json) =>
      WorkforceDepartmentRow(raw: json);
}

class WorkforceDetailRow {
  WorkforceDetailRow({required this.raw});
  final Map<String, dynamic> raw;

  int get employeeId => (raw['employeeId'] as num?)?.toInt() ?? 0;
  String get employeeCode => (raw['employeeCode'] as String?) ?? '';
  String get fullName => (raw['fullName'] as String?) ?? '';
  int get departmentId => (raw['departmentId'] as num?)?.toInt() ?? 0;
  String get departmentName => (raw['departmentName'] as String?) ?? '';
  String get positionTitle => (raw['positionTitle'] as String?) ?? '';
  String get category => (raw['category'] as String?) ?? '';
  String get categoryLabel => (raw['categoryLabel'] as String?) ?? '';
  String get employeeStatus => (raw['employeeStatus'] as String?) ?? '';
  String get employmentType => (raw['employmentType'] as String?) ?? '';
  String get hireDate => (raw['hireDate'] as String?) ?? '';
  String get attendanceStatus => (raw['attendanceStatus'] as String?) ?? '';
  String get checkIn => (raw['checkIn'] as String?) ?? '';
  String get checkOut => (raw['checkOut'] as String?) ?? '';
  String get morningCheckIn => (raw['morningCheckIn'] as String?) ?? '';
  String get morningCheckOut => (raw['morningCheckOut'] as String?) ?? '';
  String get afternoonCheckIn => (raw['afternoonCheckIn'] as String?) ?? '';
  String get afternoonCheckOut => (raw['afternoonCheckOut'] as String?) ?? '';
  num get workUnits => raw['workUnits'] as num? ?? 0;
  int get lateMinutes => (raw['lateMinutes'] as num?)?.toInt() ?? 0;

  /// Giờ vào báo cáo: check-in sáng — khớp web `displayCheckIn`.
  String get displayCheckIn {
    final v = morningCheckIn.isNotEmpty ? morningCheckIn : checkIn;
    return v.isEmpty ? '—' : v;
  }

  /// Giờ ra báo cáo — khớp web `displayCheckOut`.
  String get displayCheckOut {
    final inn = morningCheckIn.isNotEmpty ? morningCheckIn : checkIn;
    final out = afternoonCheckOut.isNotEmpty ? afternoonCheckOut : checkOut;
    if (out.isEmpty) return '—';
    if (inn.isEmpty) return out;
    if (out.compareTo(inn) <= 0) return '—';
    final inParts = inn.split(':');
    final outParts = out.split(':');
    if (inParts.length < 2 || outParts.length < 2) return out;
    final ih = int.tryParse(inParts[0]);
    final im = int.tryParse(inParts[1]);
    final oh = int.tryParse(outParts[0]);
    final om = int.tryParse(outParts[1]);
    if (ih == null || im == null || oh == null || om == null) return out;
    if (oh * 60 + om - (ih * 60 + im) < 120) return '—';
    return out;
  }

  String get employeeStatusLabel => switch (employeeStatus) {
        'ACTIVE' => 'Chính thức',
        'PROBATION' => 'Thử việc',
        'INTERN' => 'Thực tập',
        'ON_LEAVE' => 'Tạm nghỉ',
        _ => employeeStatus.isEmpty ? '—' : employeeStatus,
      };

  String get attendanceStatusLabel => switch (attendanceStatus) {
        'PRESENT' => 'Đi làm đủ',
        'PARTIAL' => 'Đi làm thiếu ca',
        'SEMINAR' => 'Hội thảo + đi làm',
        'ABSENT' => 'Đã check-in',
        _ => attendanceStatus.isEmpty ? '—' : attendanceStatus,
      };

  factory WorkforceDetailRow.fromJson(Map<String, dynamic> json) =>
      WorkforceDetailRow(raw: json);
}

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      e.key.toString(): (e.value as num?)?.toInt() ?? 0,
  };
}
