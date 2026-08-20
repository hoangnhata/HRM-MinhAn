import '../../core/utils/user_role.dart';

class EmployeeSummary {
  EmployeeSummary({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.departmentName,
    this.workUnitDetail,
    this.positionTitle,
    this.role,
    this.status,
    this.employmentType,
    this.hireDate,
    this.avatarUrl,
    this.maternityLeave = false,
    this.mainDutyAuthorized = false,
    this.onTraining = false,
    this.probationOverdue = false,
  });

  final int id;
  final String fullName;
  final String? employeeCode;
  final String? departmentName;
  final String? workUnitDetail;
  final String? positionTitle;
  final UserRole? role;
  final String? status;
  final String? employmentType;
  final String? hireDate;
  final String? avatarUrl;
  final bool maternityLeave;
  final bool mainDutyAuthorized;
  final bool onTraining;
  final bool probationOverdue;

  bool get isTrialEmployee {
    final s = (status ?? '').toUpperCase();
    final code = (employeeCode ?? '').toUpperCase();
    return s == 'PROBATION' ||
        s == 'INTERN' ||
        s == 'TRIAL' ||
        code.startsWith('TV-');
  }

  factory EmployeeSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeSummary(
      id: (json['id'] as num).toInt(),
      fullName: json['fullName'] as String? ?? '',
      employeeCode: json['employeeCode'] as String?,
      departmentName: json['departmentName'] as String?,
      workUnitDetail: json['workUnitDetail'] as String?,
      positionTitle: json['positionTitle'] as String?,
      role: json['role'] != null
          ? UserRoleX.fromApi(json['role'] as String?)
          : null,
      status: json['status'] as String?,
      employmentType: json['employmentType'] as String?,
      hireDate: json['hireDate'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      maternityLeave: json['maternityLeave'] == true,
      mainDutyAuthorized: json['mainDutyAuthorized'] == true,
      onTraining: json['onTraining'] == true,
      probationOverdue: json['probationOverdue'] == true,
    );
  }
}

class EmployeeDetail {
  EmployeeDetail({
    required this.summary,
    this.email,
    this.phone,
    this.idCardNumber,
    this.dateOfBirth,
    this.address,
    this.gender,
    this.workforceProfile = const {},
    this.contracts = const [],
    this.raw,
  });

  final EmployeeSummary summary;
  final String? email;
  final String? phone;
  final String? idCardNumber;
  final String? dateOfBirth;
  final String? address;
  final String? gender;
  final Map<String, dynamic> workforceProfile;
  final List<EmployeeContract> contracts;
  final Map<String, dynamic>? raw;

  bool get isTrialEmployee => summary.isTrialEmployee;

  bool get isMaternityLeave {
    final insurance = profileString('insuranceParticipation')?.toLowerCase() ?? '';
    return summary.maternityLeave ||
        insurance.contains('thai sản') ||
        insurance.contains('thai san');
  }

  String? profileString(String key) {
    final value = workforceProfile[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? get attendanceCode => profileString('attendanceCode');

  String? get degree => profileString('degree');

  String? get trialTypeRaw => profileString('trialType');

  String? get probationStartDate => profileString('probationStartDate');

  String? get workUnitFromProfile =>
      profileString('workUnitDetail') ?? summary.workUnitDetail;

  String? get trialTypeLabel {
    final type = trialTypeRaw?.toUpperCase();
    if (type == 'BOTH') return 'Thử việc + Thực hành';
    if (type == 'THUC_HANH' || summary.status?.toUpperCase() == 'INTERN') {
      return 'Thực hành / Thực tập';
    }
    if (isTrialEmployee) return 'Thử việc';
    return null;
  }

  String? get salaryFromNotes {
    final notes = profileString('workforceNotes');
    if (notes == null || !notes.contains('Mức lương:')) return null;
    return notes.split('Mức lương:').last.split('|').first.trim();
  }

  String? get noteOnly {
    final notes = profileString('workforceNotes');
    if (notes == null) return null;
    final cleaned =
        notes.replaceFirst(RegExp(r'\s*\|\s*Mức lương:.*$'), '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  int? get departmentId {
    final v = raw?['departmentId'];
    if (v is num) return v.toInt();
    return null;
  }

  int? get positionId {
    final v = raw?['positionId'];
    if (v is num) return v.toInt();
    return null;
  }

  factory EmployeeDetail.fromJson(Map<String, dynamic> json) {
    final profileRaw = json['workforceProfile'];
    final profile = <String, dynamic>{};
    if (profileRaw is Map) {
      profile.addAll(Map<String, dynamic>.from(profileRaw));
    }

    // Một số bản ghi trả workUnitDetail ở root thay vì trong profile.
    final rootUnit = json['workUnitDetail'] as String?;
    if (rootUnit != null &&
        rootUnit.trim().isNotEmpty &&
        (profile['workUnitDetail'] == null ||
            profile['workUnitDetail'].toString().trim().isEmpty)) {
      profile['workUnitDetail'] = rootUnit;
    }

    final contracts = <EmployeeContract>[];
    final contractsRaw = json['contracts'];
    if (contractsRaw is List) {
      for (final item in contractsRaw) {
        if (item is Map) {
          contracts.add(
            EmployeeContract.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return EmployeeDetail(
      summary: EmployeeSummary.fromJson(json),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      idCardNumber: json['idCardNumber'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      address: json['address'] as String?,
      gender: json['gender'] as String?,
      workforceProfile: profile,
      contracts: contracts,
      raw: json,
    );
  }
}

class EmployeeContract {
  const EmployeeContract({
    required this.id,
    required this.contractType,
    required this.startDate,
    this.endDate,
  });

  final int id;
  final String contractType;
  final String startDate;
  final String? endDate;

  factory EmployeeContract.fromJson(Map<String, dynamic> json) {
    return EmployeeContract(
      id: (json['id'] as num?)?.toInt() ?? 0,
      contractType: json['contractType']?.toString() ?? 'Hợp đồng',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString(),
    );
  }
}
