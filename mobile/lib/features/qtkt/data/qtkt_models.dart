enum QtktEvaluationStatus { draft, submitted, cancelled }

extension QtktEvaluationStatusX on QtktEvaluationStatus {
  static QtktEvaluationStatus fromApi(String? value) => switch (value) {
    'SUBMITTED' => QtktEvaluationStatus.submitted,
    'CANCELLED' => QtktEvaluationStatus.cancelled,
    _ => QtktEvaluationStatus.draft,
  };

  String get apiValue => switch (this) {
    QtktEvaluationStatus.draft => 'DRAFT',
    QtktEvaluationStatus.submitted => 'SUBMITTED',
    QtktEvaluationStatus.cancelled => 'CANCELLED',
  };

  String get label => switch (this) {
    QtktEvaluationStatus.draft => 'Nháp',
    QtktEvaluationStatus.submitted => 'Đã gửi',
    QtktEvaluationStatus.cancelled => 'Đã hủy',
  };
}

class QtktStep {
  const QtktStep({
    required this.id,
    required this.no,
    required this.title,
    required this.maxPoints,
    this.detail,
    this.required = false,
  });

  final String id;
  final int no;
  final String title;
  final String? detail;
  final double maxPoints;
  final bool required;

  factory QtktStep.fromJson(Map<String, dynamic> json) => QtktStep(
    id: _string(json['id']),
    no: _integer(json['no']),
    title: _string(json['title']),
    detail: _nullableString(json['detail']),
    maxPoints: _decimal(json['maxPoints']),
    required: json['required'] == true,
  );
}

class QtktSection {
  const QtktSection({
    required this.id,
    required this.title,
    required this.steps,
  });

  final String id;
  final String title;
  final List<QtktStep> steps;

  double get maxPoints =>
      steps.fold(0, (total, step) => total + step.maxPoints);

  factory QtktSection.fromJson(Map<String, dynamic> json) => QtktSection(
    id: _string(json['id']),
    title: _string(json['title']),
    steps: _mapList(json['steps']).map(QtktStep.fromJson).toList(),
  );
}

/// Một lựa chọn trong nhóm kiểm tra của quy trình.
class QtktCheckOption {
  const QtktCheckOption({required this.code, required this.label});

  final String code;
  final String label;

  factory QtktCheckOption.fromJson(Map<String, dynamic> json) =>
      QtktCheckOption(
        code: _string(json['code']),
        label: _string(json['label']),
      );
}

/// Nhóm lựa chọn bắt buộc của quy trình — ví dụ "Thời điểm rửa tay".
///
/// Backend từ chối lưu phiếu (400) nếu quy trình có `checkOptions` mà request
/// thiếu `checkContextCode`, nên phiếu phải chọn một mục trước khi gửi.
class QtktCheckOptions {
  const QtktCheckOptions({
    required this.label,
    required this.options,
    this.hint,
  });

  final String label;
  final String? hint;
  final List<QtktCheckOption> options;

  bool get isNotEmpty => options.isNotEmpty;

  String? labelForCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final option in options) {
      if (option.code == code) return option.label;
    }
    return null;
  }

  factory QtktCheckOptions.fromJson(Map<String, dynamic> json) =>
      QtktCheckOptions(
        label: _string(json['label']).isEmpty
            ? 'Nội dung kiểm tra'
            : _string(json['label']),
        hint: _nullableString(json['hint']),
        options: _mapList(
          json['options'],
        ).map(QtktCheckOption.fromJson).toList(),
      );
}

class QtktProcedure {
  const QtktProcedure({
    required this.code,
    required this.name,
    required this.durationMinutes,
    required this.maxTotal,
    required this.sections,
    this.note,
    this.requiresPatientCode = false,
    this.allowedDepartmentKeys = const [],
    this.checkOptions,
  });

  final String code;
  final String name;
  final int durationMinutes;
  final double maxTotal;
  final String? note;
  final bool requiresPatientCode;
  final List<String> allowedDepartmentKeys;
  final List<QtktSection> sections;

  /// Nhóm lựa chọn bắt buộc trước khi gửi phiếu (null nếu quy trình không có).
  final QtktCheckOptions? checkOptions;

  int get stepCount =>
      sections.fold(0, (total, section) => total + section.steps.length);

  Iterable<QtktStep> get allSteps sync* {
    for (final section in sections) {
      yield* section.steps;
    }
  }

  bool isAllowedForDepartment(String? departmentName) {
    if (allowedDepartmentKeys.isEmpty) return true;
    final normalized = normalizeDeptKey(departmentName);
    if (normalized.isEmpty) return false;
    for (final key in allowedDepartmentKeys) {
      final k = normalizeDeptKey(key);
      if (k.isNotEmpty && normalized.contains(k)) return true;
    }
    return false;
  }

  factory QtktProcedure.fromJson(Map<String, dynamic> json) => QtktProcedure(
    code: _string(json['code']),
    name: _string(json['name']),
    durationMinutes: _integer(json['durationMinutes']),
    maxTotal: _decimal(json['maxTotal']),
    note: _nullableString(json['note']),
    requiresPatientCode: json['requiresPatientCode'] == true,
    allowedDepartmentKeys: _stringList(json['allowedDepartmentKeys']),
    sections: _mapList(json['sections']).map(QtktSection.fromJson).toList(),
    checkOptions: json['checkOptions'] is Map
        ? QtktCheckOptions.fromJson(
            (json['checkOptions'] as Map).map(
              (key, value) => MapEntry('$key', value),
            ),
          )
        : null,
  );
}

String normalizeDeptKey(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  var s = raw.toUpperCase().replaceAll('Đ', 'D').replaceAll('đ', 'D');
  // Strip combining marks roughly for Vietnamese
  const accents = {
    'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ': 'A',
    'ÈÉẸẺẼÊỀẾỆỂỄ': 'E',
    'ÌÍỊỈĨ': 'I',
    'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ': 'O',
    'ÙÚỤỦŨƯỪỨỰỬỮ': 'U',
    'ỲÝỴỶỸ': 'Y',
  };
  accents.forEach((chars, repl) {
    for (final ch in chars.split('')) {
      s = s.replaceAll(ch, repl);
    }
  });
  s = s
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return s;
}

class QtktTemplate {
  const QtktTemplate({
    required this.version,
    required this.name,
    required this.procedures,
    this.note,
  });

  final int version;
  final String name;
  final String? note;
  final List<QtktProcedure> procedures;

  QtktProcedure? procedureByCode(String code) {
    for (final procedure in procedures) {
      if (procedure.code == code) return procedure;
    }
    return null;
  }

  factory QtktTemplate.fromJson(Map<String, dynamic> json) => QtktTemplate(
    version: _integer(json['version']),
    name: _string(json['name']),
    note: _nullableString(json['note']),
    procedures: _mapList(
      json['procedures'],
    ).map(QtktProcedure.fromJson).toList(),
  );
}

class QtktEmployee {
  const QtktEmployee({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.departmentId,
    this.departmentName,
    this.positionTitle,
  });

  final int id;
  final String fullName;
  final String? employeeCode;
  final int? departmentId;
  final String? departmentName;
  final String? positionTitle;

  String get subtitle => [
    if ((departmentName ?? '').isNotEmpty) departmentName!,
    if ((positionTitle ?? '').isNotEmpty) positionTitle!,
    if ((employeeCode ?? '').isNotEmpty) 'Mã $employeeCode',
  ].join(' · ');

  factory QtktEmployee.fromJson(Map<String, dynamic> json) => QtktEmployee(
    id: _integer(json['id']),
    fullName: _string(json['fullName']),
    employeeCode: _nullableString(json['employeeCode']),
    departmentId: _nullableInteger(json['departmentId']),
    departmentName: _nullableString(json['departmentName']),
    positionTitle: _nullableString(json['positionTitle']),
  );
}

class QtktDepartment {
  const QtktDepartment({required this.id, required this.name, this.code});

  final int id;
  final String name;
  final String? code;

  factory QtktDepartment.fromJson(Map<String, dynamic> json) => QtktDepartment(
    id: _integer(json['id']),
    name: _string(json['name']),
    code: _nullableString(json['code']),
  );
}

class QtktEvaluation {
  const QtktEvaluation({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.departmentId,
    required this.departmentName,
    required this.procedureCode,
    required this.procedureName,
    required this.evalDate,
    required this.scores,
    required this.totalScore,
    required this.maxScore,
    required this.status,
    this.employeeCode,
    this.note,
    this.patientCode,
    this.checkContextCode,
    this.checkContextLabel,
    this.submittedAt,
    this.createdByUsername,
    this.createdByName,
    this.updatedByUsername,
    this.updatedByName,
    this.createdAt,
    this.updatedAt,
    this.canEdit = false,
    this.canRecall = false,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String? employeeCode;
  final int departmentId;
  final String departmentName;
  final String procedureCode;
  final String procedureName;
  final String evalDate;
  final Map<String, double> scores;
  final double totalScore;
  final double maxScore;
  final String? note;
  final String? patientCode;

  /// Lựa chọn kiểm tra đã chấm — ví dụ thời điểm rửa tay.
  final String? checkContextCode;
  final String? checkContextLabel;
  final QtktEvaluationStatus status;
  final String? submittedAt;
  final String? createdByUsername;
  final String? createdByName;
  final String? updatedByUsername;
  final String? updatedByName;
  final String? createdAt;
  final String? updatedAt;
  final bool canEdit;
  final bool canRecall;

  double get percent => maxScore <= 0 ? 0 : totalScore / maxScore;

  factory QtktEvaluation.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'];
    final scores = <String, double>{};
    if (rawScores is Map) {
      for (final entry in rawScores.entries) {
        scores[entry.key.toString()] = _decimal(entry.value);
      }
    }
    return QtktEvaluation(
      id: _integer(json['id']),
      employeeId: _integer(json['employeeId']),
      employeeName: _string(json['employeeName']),
      employeeCode: _nullableString(json['employeeCode']),
      departmentId: _integer(json['departmentId']),
      departmentName: _string(json['departmentName']),
      procedureCode: _string(json['procedureCode']),
      procedureName: _string(json['procedureName']),
      evalDate: _string(json['evalDate']),
      scores: scores,
      totalScore: _decimal(json['totalScore']),
      maxScore: _decimal(json['maxScore']),
      note: _nullableString(json['note']),
      patientCode: _nullableString(json['patientCode']),
      checkContextCode: _nullableString(json['checkContextCode']),
      checkContextLabel: _nullableString(json['checkContextLabel']),
      status: QtktEvaluationStatusX.fromApi(json['status']?.toString()),
      submittedAt: _nullableString(json['submittedAt']),
      createdByUsername: _nullableString(json['createdByUsername']),
      createdByName: _nullableString(json['createdByName']),
      updatedByUsername: _nullableString(json['updatedByUsername']),
      updatedByName: _nullableString(json['updatedByName']),
      createdAt: _nullableString(json['createdAt']),
      updatedAt: _nullableString(json['updatedAt']),
      canEdit: json['canEdit'] == true,
      canRecall: json['canRecall'] == true,
    );
  }
}

class QtktProcedureSummary {
  const QtktProcedureSummary({
    required this.procedureCode,
    required this.procedureName,
    required this.count,
    required this.avgScore,
    required this.maxScore,
  });

  final String procedureCode;
  final String procedureName;
  final int count;
  final double avgScore;
  final double maxScore;

  factory QtktProcedureSummary.fromJson(Map<String, dynamic> json) =>
      QtktProcedureSummary(
        procedureCode: _string(json['procedureCode']),
        procedureName: _string(json['procedureName']),
        count: _integer(json['count']),
        avgScore: _decimal(json['avgScore']),
        maxScore: _decimal(json['maxScore']),
      );
}

class QtktDepartmentSummary {
  const QtktDepartmentSummary({
    required this.departmentId,
    required this.departmentName,
    required this.count,
    required this.avgScore,
  });

  final int departmentId;
  final String departmentName;
  final int count;
  final double avgScore;

  factory QtktDepartmentSummary.fromJson(Map<String, dynamic> json) =>
      QtktDepartmentSummary(
        departmentId: _integer(json['departmentId']),
        departmentName: _string(json['departmentName']),
        count: _integer(json['count']),
        avgScore: _decimal(json['avgScore']),
      );
}

class QtktSummary {
  const QtktSummary({
    required this.yearMonth,
    required this.from,
    required this.to,
    required this.totalSubmitted,
    required this.byProcedure,
    required this.byDepartment,
  });

  final String yearMonth;
  final String from;
  final String to;
  final int totalSubmitted;
  final List<QtktProcedureSummary> byProcedure;
  final List<QtktDepartmentSummary> byDepartment;

  factory QtktSummary.fromJson(Map<String, dynamic> json) => QtktSummary(
    yearMonth: _string(json['yearMonth']),
    from: _string(json['from']),
    to: _string(json['to']),
    totalSubmitted: _integer(json['totalSubmitted']),
    byProcedure: _mapList(
      json['byProcedure'],
    ).map(QtktProcedureSummary.fromJson).toList(),
    byDepartment: _mapList(
      json['byDepartment'],
    ).map(QtktDepartmentSummary.fromJson).toList(),
  );
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((e) => e.toString())
      .where((e) => e.trim().isNotEmpty)
      .toList();
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

int? _nullableInteger(Object? value) {
  if (value == null) return null;
  return _integer(value);
}

double _decimal(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

/// Hiển thị điểm QTKT: bỏ số 0 thừa ở phần thập phân, giữ nguyên phần nguyên.
///
/// `0 -> "0"`, `0.5 -> "0.5"`, `1.25 -> "1.25"`, `9.75 -> "9.75"`, `10 -> "10"`.
/// Điểm quan trọng: chỉ cắt số 0 nằm sau dấu chấm. Cắt số 0 ở cuối chuỗi nói
/// chung sẽ biến 10 thành "1" và 0 thành chuỗi rỗng.
String formatQtktScore(double value) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
