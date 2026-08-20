import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/salary/salary_access_store.dart';
import '../../../shared/models/salary_models.dart';

class SalaryRepository {
  SalaryRepository(this._client, this._access);
  final ApiClient _client;
  final SalaryAccessStore _access;

  Future<SalaryProfile> profile(int employeeId) async {
    final response = await _client
        .get<Map<String, dynamic>>('/v1/salary-profiles/employees/$employeeId');
    return SalaryProfile.fromJson(response.data!);
  }

  Future<SalaryProfile> upsertProfile(
    int employeeId,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/v1/salary-profiles/employees/$employeeId',
      data: body,
    );
    return SalaryProfile.fromJson(response.data!);
  }

  Future<int> recalculateAll() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/salary-profiles/recalculate-all',
    );
    return (response.data?['recalculated'] as num?)?.toInt() ?? 0;
  }

  Future<SalaryGradeReviewReport> gradeReviews({
    required int year,
    required int month,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/salary-profiles/grade-reviews',
      query: {'year': year, 'month': month},
    );
    return SalaryGradeReviewReport.fromJson(response.data ?? const {});
  }

  Future<List<PayrollRow>> payroll(int employeeId) async {
    final response =
        await _client.get<List<dynamic>>('/v1/payroll/employees/$employeeId');
    return (response.data ?? [])
        .map((e) => PayrollRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `mine: true` — NV chỉ xem thang đúng đối tượng lương của mình (như web `/salary-scales/me`).
  Future<AllSalaryScales> scales({bool mine = true}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/salary-scales',
      query: mine ? {'mine': true} : null,
    );
    return AllSalaryScales.fromJson(response.data!);
  }

  Future<EmployeeScale> updateScaleBase({
    required String scaleType,
    required num baseTotalIncome,
    required String qualification,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/v1/salary-scales/employee/$scaleType/base',
      data: {
        'baseTotalIncome': baseTotalIncome,
        'qualification': qualification,
      },
    );
    return EmployeeScale.fromJson(response.data ?? const {});
  }

  Future<void> unlock(String password) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/salary-profiles/unlock',
      data: {'password': password},
    );
    final data = response.data ?? const <String, dynamic>{};
    final token = data['token'] as String? ?? '';
    final expiresRaw = data['expiresAt']?.toString();
    final expiresAt = DateTime.tryParse(expiresRaw ?? '') ??
        DateTime.now().add(const Duration(hours: 8));
    if (token.isEmpty) {
      throw StateError('Không nhận được token mở khóa');
    }
    _access.setGrant(token: token, expiresAt: expiresAt);
  }
}

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(
    ref.watch(apiClientProvider),
    ref.watch(salaryAccessStoreProvider),
  );
});
