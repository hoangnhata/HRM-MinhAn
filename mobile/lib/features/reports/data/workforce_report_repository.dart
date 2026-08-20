import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/workforce_report.dart';

class WorkforceReportRepository {
  WorkforceReportRepository(this._client);
  final ApiClient _client;

  Future<WorkforceReport> hospital() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/workforce-reports/hospital',
    );
    return WorkforceReport.fromJson(response.data ?? const {});
  }

  Future<WorkforceReport> daily(String dateIso) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/workforce-reports/daily',
      query: {'date': dateIso},
    );
    return WorkforceReport.fromJson(response.data ?? const {});
  }
}

final workforceReportRepositoryProvider =
    Provider<WorkforceReportRepository>((ref) {
  return WorkforceReportRepository(ref.watch(apiClientProvider));
});
