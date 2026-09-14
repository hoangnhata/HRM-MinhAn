import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'nursing_daily_report_models.dart';

class NursingDailyReportRepository {
  NursingDailyReportRepository(this._client);
  final ApiClient _client;

  Future<List<NursingDailyDepartment>> departments() async {
    final response = await _client.get<List<dynamic>>(
      '/v1/nursing-daily-reports/departments',
    );
    return _maps(response.data).map(NursingDailyDepartment.fromJson).toList();
  }

  Future<List<NursingDailyReportRow>> dayRows(
    String date, {
    int? departmentId,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/nursing-daily-reports',
      query: {'date': date, 'departmentId': ?departmentId},
    );
    return _maps(response.data).map(NursingDailyReportRow.fromJson).toList();
  }

  Future<List<NursingDailyReportRow>> monthRows(
    String yearMonth, {
    int? departmentId,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/nursing-daily-reports/month',
      query: {'yearMonth': yearMonth, 'departmentId': ?departmentId},
    );
    return _maps(response.data).map(NursingDailyReportRow.fromJson).toList();
  }

  Future<NursingDailyReport?> byDeptDate(int departmentId, String date) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/nursing-daily-reports/by',
      query: {'departmentId': departmentId, 'date': date},
    );
    final data = response.data;
    return data == null ? null : NursingDailyReport.fromJson(data);
  }

  Future<NursingDailyReport> getById(int id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/nursing-daily-reports/$id',
    );
    return NursingDailyReport.fromJson(response.data ?? const {});
  }

  Future<NursingDailyReport> create(Map<String, dynamic> body) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/nursing-daily-reports',
      data: body,
    );
    return NursingDailyReport.fromJson(response.data ?? const {});
  }

  Future<NursingDailyReport> update(int id, Map<String, dynamic> body) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/v1/nursing-daily-reports/$id',
      data: body,
    );
    return NursingDailyReport.fromJson(response.data ?? const {});
  }

  Future<NursingDailyReport> recall(int id) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/nursing-daily-reports/$id/recall',
    );
    return NursingDailyReport.fromJson(response.data ?? const {});
  }

  Future<void> delete(int id) async {
    await _client.delete<void>('/v1/nursing-daily-reports/$id');
  }
}

List<Map<String, dynamic>> _maps(List<dynamic>? value) => (value ?? const [])
    .whereType<Map>()
    .map((item) => item.map((key, value) => MapEntry('$key', value)))
    .toList();

final nursingDailyReportRepositoryProvider =
    Provider<NursingDailyReportRepository>((ref) {
      return NursingDailyReportRepository(ref.watch(apiClientProvider));
    });
