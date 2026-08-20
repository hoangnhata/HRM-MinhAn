/// Phiếu đánh giá điều dưỡng — đồng bộ `NursingEvaluationService.toMap` + mẫu MA 2026.
const kMa2026EvalTemplateCode = 'DD_KTV_HS_MA_2026';

/// Chuẩn công tháng dùng nhận diện thiếu công khi chấm (khớp web).
const kEvalStandardMonthWorkUnits = 26.0;

class NursingEvaluationRecord {
  NursingEvaluationRecord({required this.raw});
  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num).toInt();
  int? get employeeId => (raw['employeeId'] as num?)?.toInt();
  String? get employeeCode => raw['employeeCode'] as String?;
  String? get employeeName =>
      (raw['employeeName'] as String?) ?? (raw['fullName'] as String?);
  String? get departmentName => raw['departmentName'] as String?;
  String? get positionTitle => raw['positionTitle'] as String?;
  int get periodYear => (raw['periodYear'] as num?)?.toInt() ?? 0;
  int get periodMonth => (raw['periodMonth'] as num?)?.toInt() ?? 0;
  String get templateCode =>
      (raw['templateCode'] as String?) ?? kMa2026EvalTemplateCode;
  String get status => raw['status'] as String? ?? '';
  double? get totalScore => (raw['totalScore'] as num?)?.toDouble();
  String? get overallGrade => raw['overallGrade'] as String?;
  String? get comments => raw['comments'] as String?;
  String? get evaluatorUsername => raw['evaluatorUsername'] as String?;
  String? get evaluatorSignedAt => raw['evaluatorSignedAt'] as String?;
  String? get evaluatorSignatureUrl => raw['evaluatorSignatureUrl'] as String?;
  String? get headComment => raw['headComment'] as String?;
  String? get headReviewedAt => raw['headReviewedAt'] as String?;
  String? get headSignatureUrl => raw['headSignatureUrl'] as String?;
  String? get hrComment => raw['hrComment'] as String?;
  String? get hrReviewedAt => raw['hrReviewedAt'] as String?;
  String? get hrSignatureUrl => raw['hrSignatureUrl'] as String?;
  String? get directorComment => raw['directorComment'] as String?;
  String? get directorReviewedAt => raw['directorReviewedAt'] as String?;
  String? get directorSignatureUrl => raw['directorSignatureUrl'] as String?;
  DateTime? get createdAt =>
      raw['createdAt'] != null ? DateTime.tryParse(raw['createdAt'] as String) : null;
  Map<String, dynamic> get scores =>
      (raw['scores'] as Map?)?.cast<String, dynamic>() ?? {};

  double? scorePoints(String criterionId) {
    final part = scores[criterionId];
    if (part is! Map) return null;
    final p = part['points'] ?? part['truongKhoa'] ?? part['ddt'];
    if (p is num) return p.toDouble();
    return double.tryParse('$p');
  }

  String? scoreNote(String criterionId) {
    final part = scores[criterionId];
    if (part is! Map) return null;
    final n = part['note'] ?? part['truongKhoaNote'];
    if (n == null) return null;
    final s = '$n'.trim();
    return s.isEmpty ? null : s;
  }

  factory NursingEvaluationRecord.fromJson(Map<String, dynamic> json) =>
      NursingEvaluationRecord(raw: json);
}

class NursingEvalTemplate {
  NursingEvalTemplate({required this.raw});
  final Map<String, dynamic> raw;

  String get code => (raw['code'] as String?) ?? kMa2026EvalTemplateCode;
  String get name => (raw['name'] as String?) ?? '';
  int get version => (raw['version'] as num?)?.toInt() ?? 0;
  double get baseMaxPoints =>
      (raw['baseMaxPoints'] as num?)?.toDouble() ?? 100;
  String get note => (raw['note'] as String?) ?? '';

  List<NursingEvalCriterion> get criteriaGroups {
    final list = raw['criteriaGroups'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => NursingEvalCriterion(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<NursingEvalGradeScale> get gradingScale {
    final list = raw['gradingScale'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => NursingEvalGradeScale(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory NursingEvalTemplate.fromJson(Map<String, dynamic> json) =>
      NursingEvalTemplate(raw: json);
}

class NursingEvalCriterion {
  NursingEvalCriterion(this.raw);
  final Map<String, dynamic> raw;

  String get id => (raw['id'] as String?) ?? '';
  String get section => (raw['section'] as String?) ?? 'Khác';
  double? get sectionPoints => (raw['sectionPoints'] as num?)?.toDouble();
  String get no => (raw['no'] as String?) ?? '';
  String get title => (raw['title'] as String?) ?? '';
  double? get maxPoints => (raw['maxPoints'] as num?)?.toDouble();
  bool get bonus =>
      raw['bonus'] == true || id.startsWith('VI_');
  bool get penalty =>
      raw['penalty'] == true || id.startsWith('VII_');
  bool get isExtra => bonus || penalty;

  List<NursingEvalOption> get options {
    final list = raw['options'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => NursingEvalOption(Map<String, dynamic>.from(e)))
        .toList();
  }
}

class NursingEvalOption {
  NursingEvalOption(this.raw);
  final Map<String, dynamic> raw;

  String get label => (raw['label'] as String?) ?? '';
  double get points => (raw['points'] as num?)?.toDouble() ?? 0;
}

class NursingEvalGradeScale {
  NursingEvalGradeScale(this.raw);
  final Map<String, dynamic> raw;

  double get min => (raw['min'] as num?)?.toDouble() ?? 0;
  String get label => (raw['label'] as String?) ?? '';
  String get proposal => (raw['proposal'] as String?) ?? '';
}

class NursingPeriodStatus {
  NursingPeriodStatus({required this.raw});
  final Map<String, dynamic> raw;

  int get employeeId => (raw['employeeId'] as num?)?.toInt() ?? 0;
  int? get evaluationId => (raw['evaluationId'] as num?)?.toInt();
  String get status => (raw['status'] as String?) ?? 'NONE';
  double? get totalScore => (raw['totalScore'] as num?)?.toDouble();
  String? get overallGrade => raw['overallGrade'] as String?;

  factory NursingPeriodStatus.fromJson(Map<String, dynamic> json) =>
      NursingPeriodStatus(raw: json);
}

class NursingEvalSummaryRow {
  NursingEvalSummaryRow({required this.raw});
  final Map<String, dynamic> raw;

  int get evaluationId => (raw['evaluationId'] as num?)?.toInt() ?? 0;
  int get employeeId => (raw['employeeId'] as num?)?.toInt() ?? 0;
  String get employeeCode => (raw['employeeCode'] as String?) ?? '';
  String get fullName => (raw['fullName'] as String?) ?? '';
  String get departmentName => (raw['departmentName'] as String?) ?? '';
  int get periodYear => (raw['periodYear'] as num?)?.toInt() ?? 0;
  int get periodMonth => (raw['periodMonth'] as num?)?.toInt() ?? 0;
  String get status => (raw['status'] as String?) ?? '';
  double? get totalScore => (raw['totalScore'] as num?)?.toDouble();
  String? get overallGrade => raw['overallGrade'] as String?;
  String get evaluatorUsername => (raw['evaluatorUsername'] as String?) ?? '';

  factory NursingEvalSummaryRow.fromJson(Map<String, dynamic> json) =>
      NursingEvalSummaryRow(raw: json);
}

class NursingEvalAttendanceStats {
  const NursingEvalAttendanceStats({
    required this.totalWorkUnits,
    required this.lateMinutesTotal,
    required this.lateEarlyTimes,
    required this.missingWorkUnits,
    required this.isShortWork,
  });

  final double totalWorkUnits;
  final int lateMinutesTotal;
  final int lateEarlyTimes;
  final double missingWorkUnits;
  final bool isShortWork;
}
