class SalaryProfile {
  SalaryProfile({required this.raw});
  final Map<String, dynamic> raw;

  String? get salaryCategory => raw['salaryCategory'] as String?;
  String? get employeeBlock => raw['employeeBlock'] as String?;
  String? get qualification => raw['qualification'] as String?;
  num? get yearsOfService => raw['yearsOfService'] as num?;
  num? get seniorityYears => raw['seniorityYears'] as num?;
  num? get priorRaiseYears => raw['priorRaiseYears'] as num?;
  String? get salaryScaleStartDate => raw['salaryScaleStartDate'] as String?;
  String? get seniorityAsOfDate => raw['seniorityAsOfDate'] as String?;
  num? get baseSeniorityYears => raw['baseSeniorityYears'] as num?;
  bool get ldg => raw['ldg'] as bool? ?? false;
  Map<String, dynamic>? get computedGrade =>
      (raw['computedGrade'] as Map?)?.cast<String, dynamic>();
  num? get totalSalary => raw['totalSalary'] as num?;
  bool get canViewSensitive => raw['canViewSensitive'] as bool? ?? false;
  bool get canEdit => raw['canEdit'] as bool? ?? false;
  int get tierGroup => (raw['tierGroup'] as num?)?.toInt() ?? 3;
  String? get doctorQualificationCode =>
      raw['doctorQualificationCode'] as String?;
  String? get qualificationNote => raw['qualificationNote'] as String?;
  num? get degreeConversionYears => raw['degreeConversionYears'] as num?;
  num? get professionalAttractionSalary =>
      raw['professionalAttractionSalary'] as num?;
  num? get importedInsuranceSalary => raw['importedInsuranceSalary'] as num?;
  num? get importedProductSalary => raw['importedProductSalary'] as num?;

  String? get gradeLabel => computedGrade?['gradeLabel'] as String?;
  String? get yearsRange => computedGrade?['yearsRange'] as String?;
  num? get coefficient => computedGrade?['coefficient'] as num?;
  num? get scaleSalary => computedGrade?['scaleSalary'] as num?;
  num? get insuranceSalary => computedGrade?['insuranceSalary'] as num?;
  num? get productSalary => computedGrade?['productSalary'] as num?;
  int? get gradeLevel => (computedGrade?['gradeLevel'] as num?)?.toInt();

  List<EarlyRaiseConversion> get earlyRaiseConversions {
    final list = raw['earlyRaiseConversions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => EarlyRaiseConversion.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Nhãn đối tượng lương — đồng bộ web `salaryObjectLabel`.
  String get objectLabel {
    if (salaryCategory == 'DOCTOR') return 'Bác sĩ';
    if (salaryCategory == 'EMPLOYEE') {
      if (employeeBlock == 'INDIRECT') return 'Gián tiếp';
      if (employeeBlock == 'DIRECT') return 'Trực tiếp';
      return 'Nhân viên';
    }
    return '—';
  }

  /// Bậc + khoảng thâm niên, ví dụ `BẬC 3 · 4-6 năm`.
  String get displayGradeLabel {
    final label = gradeLabel;
    if (label == null || label == '—') return '—';
    final band = yearsRange;
    if (band == null || band.isEmpty || band == '—' || band == label) {
      return label;
    }
    return '$label · $band';
  }

  factory SalaryProfile.fromJson(Map<String, dynamic> json) =>
      SalaryProfile(raw: json);
}

class EarlyRaiseConversion {
  EarlyRaiseConversion({this.raiseDate, required this.years});

  final String? raiseDate;
  final num years;

  factory EarlyRaiseConversion.fromJson(Map<String, dynamic> json) {
    return EarlyRaiseConversion(
      raiseDate: json['raiseDate'] as String?,
      years: json['years'] as num? ?? 0,
    );
  }
}

class PayrollRow {
  PayrollRow({required this.raw});
  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num).toInt();
  int get periodYear => (raw['periodYear'] as num?)?.toInt() ?? 0;
  int get periodMonth => (raw['periodMonth'] as num?)?.toInt() ?? 0;
  num get workingDays => raw['workingDays'] as num? ?? 0;
  num get grossAmount => raw['grossAmount'] as num? ?? 0;
  num get deductionAmount => raw['deductionAmount'] as num? ?? 0;
  num get netAmount => raw['netAmount'] as num? ?? 0;
  String? get note => raw['note'] as String?;
  bool get finalized => raw['finalized'] as bool? ?? false;

  factory PayrollRow.fromJson(Map<String, dynamic> json) =>
      PayrollRow(raw: json);
}

class AllSalaryScales {
  AllSalaryScales({required this.raw});
  final Map<String, dynamic> raw;

  String get viewerScope => (raw['viewerScope'] as String?) ?? 'NONE';

  EmployeeScale get employeeDirect => EmployeeScale.fromJson(
        (raw['employeeDirect'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  EmployeeScale get employeeIndirect => EmployeeScale.fromJson(
        (raw['employeeIndirect'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  List<DoctorScaleEntry> get doctor {
    final list = raw['doctor'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => DoctorScaleEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  factory AllSalaryScales.fromJson(Map<String, dynamic> json) =>
      AllSalaryScales(raw: json);
}

class EmployeeScale {
  EmployeeScale({required this.raw});
  final Map<String, dynamic> raw;

  String get scaleType => (raw['scaleType'] as String?) ?? '';
  String get title => (raw['title'] as String?) ?? '';
  num get baseTotalAtCoef1 => raw['baseTotalAtCoef1'] as num? ?? 0;

  List<EmployeeScaleTier> get tiers {
    final list = raw['tiers'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => EmployeeScaleTier.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  factory EmployeeScale.fromJson(Map<String, dynamic> json) =>
      EmployeeScale(raw: json);
}

class EmployeeScaleTier {
  EmployeeScaleTier({required this.raw});
  final Map<String, dynamic> raw;

  int get tierGroup => (raw['tierGroup'] as num?)?.toInt() ?? 0;
  String get tierLabel => (raw['tierLabel'] as String?) ?? '';

  List<EmployeeScaleGrade> get grades {
    final list = raw['grades'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => EmployeeScaleGrade.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  factory EmployeeScaleTier.fromJson(Map<String, dynamic> json) =>
      EmployeeScaleTier(raw: json);
}

class EmployeeScaleGrade {
  EmployeeScaleGrade({required this.raw});
  final Map<String, dynamic> raw;

  int get gradeLevel => (raw['gradeLevel'] as num?)?.toInt() ?? 0;
  String get gradeLabel => (raw['gradeLabel'] as String?) ?? '';
  String get yearsRange => (raw['yearsRange'] as String?) ?? '';
  num get coefficient => raw['coefficient'] as num? ?? 0;
  num get insuranceSalary => raw['insuranceSalary'] as num? ?? 0;
  num get productSalary => raw['productSalary'] as num? ?? 0;
  num get totalIncome => raw['totalIncome'] as num? ?? 0;

  factory EmployeeScaleGrade.fromJson(Map<String, dynamic> json) =>
      EmployeeScaleGrade(raw: json);
}

class DoctorScaleEntry {
  DoctorScaleEntry({required this.raw});
  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get qualificationCode => (raw['qualificationCode'] as String?) ?? '';
  String get qualificationName => (raw['qualificationName'] as String?) ?? '';
  String get timeLabel => (raw['timeLabel'] as String?) ?? '';
  num get totalSalary => raw['totalSalary'] as num? ?? 0;

  factory DoctorScaleEntry.fromJson(Map<String, dynamic> json) =>
      DoctorScaleEntry(raw: json);
}

class SalaryGradeReviewReport {
  SalaryGradeReviewReport({required this.raw});
  final Map<String, dynamic> raw;

  int get year => (raw['year'] as num?)?.toInt() ?? 0;
  int get month => (raw['month'] as num?)?.toInt() ?? 0;
  int get total => (raw['total'] as num?)?.toInt() ?? 0;
  int get upcoming => (raw['upcoming'] as num?)?.toInt() ?? 0;
  int get today => (raw['today'] as num?)?.toInt() ?? 0;
  int get passed => (raw['passed'] as num?)?.toInt() ?? 0;
  num get increaseTotal => raw['increaseTotal'] as num? ?? 0;

  List<SalaryGradeReviewRow> get rows {
    final list = raw['rows'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => SalaryGradeReviewRow(e.cast<String, dynamic>()))
        .toList();
  }

  factory SalaryGradeReviewReport.fromJson(Map<String, dynamic> json) =>
      SalaryGradeReviewReport(raw: json);
}

class SalaryGradeReviewRow {
  SalaryGradeReviewRow(this.raw);
  final Map<String, dynamic> raw;

  int get employeeId => (raw['employeeId'] as num?)?.toInt() ?? 0;
  String get employeeCode => (raw['employeeCode'] as String?) ?? '';
  String get fullName => (raw['fullName'] as String?) ?? '';
  String get department => (raw['department'] as String?) ?? '';
  String get position => (raw['position'] as String?) ?? '';
  String get salaryCategory => (raw['salaryCategory'] as String?) ?? '';
  String get employeeBlock => (raw['employeeBlock'] as String?) ?? '';
  String get qualification => (raw['qualification'] as String?) ?? '';
  String get effectiveDate => (raw['effectiveDate'] as String?) ?? '';
  num get seniorityYears => raw['seniorityYears'] as num? ?? 0;
  String get currentGrade => (raw['currentGrade'] as String?) ?? '';
  String get nextGrade => (raw['nextGrade'] as String?) ?? '';
  num get currentSalary => raw['currentSalary'] as num? ?? 0;
  num get nextSalary => raw['nextSalary'] as num? ?? 0;
  num get increaseAmount => raw['increaseAmount'] as num? ?? 0;
  num get increasePercent => raw['increasePercent'] as num? ?? 0;
  int get daysUntil => (raw['daysUntil'] as num?)?.toInt() ?? 0;
  String get timingStatus => (raw['timingStatus'] as String?) ?? '';
  String get reviewSource => (raw['reviewSource'] as String?) ?? '';

  String get objectLabel {
    if (salaryCategory == 'DOCTOR') return 'Bác sĩ';
    if (employeeBlock == 'INDIRECT') return 'NV gián tiếp';
    if (employeeBlock == 'DIRECT') return 'NV trực tiếp';
    return salaryCategory.isEmpty ? '—' : salaryCategory;
  }
}
