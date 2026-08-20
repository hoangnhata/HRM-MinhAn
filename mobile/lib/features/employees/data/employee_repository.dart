import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/paged_response.dart';

class EmployeeCreatePayload {
  const EmployeeCreatePayload({
    required this.role,
    required this.fullName,
    required this.phone,
    required this.departmentId,
    required this.attendanceCode,
    this.email,
    this.username,
    this.password,
    this.idCardNumber,
    this.dateOfBirth,
    this.address,
    this.gender,
    this.status,
    this.employmentType,
    this.hireDate,
    this.positionId,
    this.baseSalary,
    this.workUnitDetail,
    this.payrollDisplayName,
    this.degree,
    this.probationStartDate,
    this.officialStartDate,
    this.idCardIssueDate,
    this.specialty,
    this.professionalDiploma,
    this.practiceScope,
    this.practiceCertNumber,
    this.practiceCertDateRaw,
    this.otherTrainingCertificates,
    this.cki,
    this.bankAccount,
    this.bankName,
    this.insuranceParticipation,
    this.socialInsuranceBook,
    this.contractNumber,
    this.contractSignDate,
    this.contractTerm,
    this.ethnicity,
    this.placeOfOrigin,
    this.maritalStatus,
    this.bloodType,
    this.emergencyContact,
    this.emergencyPhone,
    this.dependentsInfo,
    this.workforceNotes,
  });

  final String role;
  final String fullName;
  final String phone;
  final int departmentId;
  final String attendanceCode;
  final String? email;
  final String? username;
  final String? password;
  final String? idCardNumber;
  final String? dateOfBirth;
  final String? address;
  final String? gender;
  final String? status;
  final String? employmentType;
  final String? hireDate;
  final int? positionId;
  final num? baseSalary;
  final String? workUnitDetail;
  final String? payrollDisplayName;
  final String? degree;
  final String? probationStartDate;
  final String? officialStartDate;
  final String? idCardIssueDate;
  final String? specialty;
  final String? professionalDiploma;
  final String? practiceScope;
  final String? practiceCertNumber;
  final String? practiceCertDateRaw;
  final String? otherTrainingCertificates;
  final String? cki;
  final String? bankAccount;
  final String? bankName;
  final String? insuranceParticipation;
  final String? socialInsuranceBook;
  final String? contractNumber;
  final String? contractSignDate;
  final String? contractTerm;
  final String? ethnicity;
  final String? placeOfOrigin;
  final String? maritalStatus;
  final String? bloodType;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? dependentsInfo;
  final String? workforceNotes;

  Map<String, dynamic> toJson() {
    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final workforce = <String, dynamic>{
      'attendanceCode': attendanceCode.trim(),
      if (clean(workUnitDetail) != null) 'workUnitDetail': clean(workUnitDetail),
      if (clean(payrollDisplayName) != null)
        'payrollDisplayName': clean(payrollDisplayName),
      if (clean(degree) != null) 'degree': clean(degree),
      if (clean(probationStartDate) != null)
        'probationStartDate': clean(probationStartDate),
      if (clean(officialStartDate) != null)
        'officialStartDate': clean(officialStartDate),
      if (clean(idCardIssueDate) != null)
        'idCardIssueDate': clean(idCardIssueDate),
      if (clean(specialty) != null) 'specialty': clean(specialty),
      if (clean(professionalDiploma) != null)
        'professionalDiploma': clean(professionalDiploma),
      if (clean(practiceScope) != null) 'practiceScope': clean(practiceScope),
      if (clean(practiceCertNumber) != null)
        'practiceCertNumber': clean(practiceCertNumber),
      if (clean(practiceCertDateRaw) != null)
        'practiceCertDateRaw': clean(practiceCertDateRaw),
      if (clean(otherTrainingCertificates) != null)
        'otherTrainingCertificates': clean(otherTrainingCertificates),
      if (clean(cki) != null) 'cki': clean(cki),
      if (clean(bankAccount) != null) 'bankAccount': clean(bankAccount),
      if (clean(bankName) != null) 'bankName': clean(bankName),
      if (clean(insuranceParticipation) != null)
        'insuranceParticipation': clean(insuranceParticipation),
      if (clean(socialInsuranceBook) != null)
        'socialInsuranceBook': clean(socialInsuranceBook),
      if (clean(contractNumber) != null) 'contractNumber': clean(contractNumber),
      if (clean(contractSignDate) != null)
        'contractSignDate': clean(contractSignDate),
      if (clean(contractTerm) != null) 'contractTerm': clean(contractTerm),
      if (clean(ethnicity) != null) 'ethnicity': clean(ethnicity),
      if (clean(placeOfOrigin) != null) 'placeOfOrigin': clean(placeOfOrigin),
      if (clean(maritalStatus) != null) 'maritalStatus': clean(maritalStatus),
      if (clean(bloodType) != null) 'bloodType': clean(bloodType),
      if (clean(emergencyContact) != null)
        'emergencyContact': clean(emergencyContact),
      if (clean(emergencyPhone) != null)
        'emergencyPhone': clean(emergencyPhone),
      if (clean(dependentsInfo) != null) 'dependentsInfo': clean(dependentsInfo),
      if (clean(workforceNotes) != null) 'workforceNotes': clean(workforceNotes),
    };

    return {
      'role': role,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'departmentId': departmentId,
      if (clean(email) != null) 'email': clean(email),
      if (clean(username) != null) 'username': clean(username),
      if (password != null && password!.isNotEmpty) 'password': password,
      if (clean(idCardNumber) != null) 'idCardNumber': clean(idCardNumber),
      if (clean(dateOfBirth) != null) 'dateOfBirth': clean(dateOfBirth),
      if (clean(address) != null) 'address': clean(address),
      if (clean(gender) != null) 'gender': clean(gender),
      if (clean(status) != null) 'status': clean(status),
      if (clean(employmentType) != null) 'employmentType': clean(employmentType),
      if (clean(hireDate) != null) 'hireDate': clean(hireDate),
      if (positionId != null) 'positionId': positionId,
      if (baseSalary != null) 'baseSalary': baseSalary,
      'workforce': workforce,
    };
  }

  /// Body `PUT /v1/employees/{id}` — `status` bắt buộc.
  Map<String, dynamic> toUpdateJson() {
    final create = toJson();
    create.remove('username');
    create.remove('password');
    create.remove('role');
    // status bắt buộc trên backend
    create['status'] = (status ?? 'ACTIVE').trim();
    return create;
  }
}

class EmployeeRepository {
  EmployeeRepository(this._client);
  final ApiClient _client;

  /// [statusGroup]: TRIAL | OFFICIAL | TERMINATED | WORKING.
  Future<PagedResponse<EmployeeSummary>> list({
    int page = 0,
    int size = 20,
    String? query,
    int? departmentId,
    String? workUnit,
    String? statusGroup,
    String? officialWorkFilter,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/employees',
      query: {
        'page': page,
        'size': size,
        'sort': 'id,desc',
        if (query != null && query.isNotEmpty) 'q': query,
        'departmentId': ?departmentId,
        if (workUnit != null && workUnit.isNotEmpty) 'workUnit': workUnit,
        if (statusGroup != null && statusGroup.isNotEmpty)
          'statusGroup': statusGroup,
        if (officialWorkFilter != null && officialWorkFilter.isNotEmpty)
          'officialWorkFilter': officialWorkFilter,
      },
    );
    return PagedResponse.fromJson(response.data!, EmployeeSummary.fromJson);
  }

  Future<EmployeeDetail> me() async {
    final response = await _client.get<Map<String, dynamic>>('/v1/employees/me');
    return EmployeeDetail.fromJson(response.data!);
  }

  Future<EmployeeDetail> detail(int id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/v1/employees/$id');
    return EmployeeDetail.fromJson(response.data!);
  }

  Future<EmployeeDetail> create(EmployeeCreatePayload payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/employees',
      data: payload.toJson(),
    );
    return EmployeeDetail.fromJson(response.data!);
  }

  Future<EmployeeDetail> update(int id, EmployeeCreatePayload payload) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/v1/employees/$id',
      data: payload.toUpdateJson(),
    );
    return EmployeeDetail.fromJson(response.data!);
  }

  /// Cập nhật SĐT/email khi lập đơn lên chính thức — nuốt lỗi nếu không có quyền HR.
  Future<void> updateContact(
    int id, {
    required String status,
    required String fullName,
    String? phone,
    String? email,
  }) async {
    await _client.put<Map<String, dynamic>>(
      '/v1/employees/$id',
      data: {
        'status': status,
        'fullName': fullName,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
  }

  /// Nghỉ việc — `DELETE /v1/employees/{id}` (khóa tài khoản, giải phóng SĐT/CCCD).
  Future<void> terminate(int id) async {
    await _client.delete<void>('/v1/employees/$id');
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(apiClientProvider));
});
