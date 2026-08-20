import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;

  Future<DashboardStats> stats() async {
    final response =
        await _client.get<Map<String, dynamic>>('/v1/dashboard/stats');
    return DashboardStats.fromJson(response.data ?? const {});
  }

  Future<NursingDashboardStats> nursingStats() async {
    final response =
        await _client.get<Map<String, dynamic>>('/v1/dashboard/nursing-stats');
    return NursingDashboardStats.fromJson(response.data ?? const {});
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});
