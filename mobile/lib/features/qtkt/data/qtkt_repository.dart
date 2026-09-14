import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'qtkt_models.dart';

class QtktRepository {
  QtktRepository(this._client);

  final ApiClient _client;

  Future<QtktTemplate> template() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/qtkt-evaluations/template',
    );
    return QtktTemplate.fromJson(response.data ?? const {});
  }

  Future<List<QtktEmployee>> employees() async {
    final response = await _client.get<List<dynamic>>(
      '/v1/qtkt-evaluations/employees',
    );
    return _maps(response.data).map(QtktEmployee.fromJson).toList();
  }

  Future<List<QtktDepartment>> departments() async {
    final response = await _client.get<List<dynamic>>(
      '/v1/qtkt-evaluations/departments',
    );
    return _maps(response.data).map(QtktDepartment.fromJson).toList();
  }

  Future<List<QtktEvaluation>> evaluations({
    String? from,
    String? to,
    int? departmentId,
    String? procedureCode,
    QtktEvaluationStatus? status,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/qtkt-evaluations',
      query: {
        'from': ?from,
        'to': ?to,
        'departmentId': ?departmentId,
        if (procedureCode != null && procedureCode.isNotEmpty)
          'procedureCode': procedureCode,
        if (status != null) 'status': status.apiValue,
      },
    );
    return _maps(response.data).map(QtktEvaluation.fromJson).toList();
  }

  Future<QtktSummary> summary(String yearMonth) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/qtkt-evaluations/summary',
      query: {'yearMonth': yearMonth},
    );
    return QtktSummary.fromJson(response.data ?? const {});
  }

  Future<QtktEvaluation> getById(int id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/qtkt-evaluations/$id',
    );
    return QtktEvaluation.fromJson(response.data ?? const {});
  }

  Future<QtktEvaluation> create(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/qtkt-evaluations',
      data: payload,
    );
    return QtktEvaluation.fromJson(response.data ?? const {});
  }

  Future<QtktEvaluation> update(int id, Map<String, dynamic> payload) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/v1/qtkt-evaluations/$id',
      data: payload,
    );
    return QtktEvaluation.fromJson(response.data ?? const {});
  }

  Future<QtktEvaluation> submit(int id) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/qtkt-evaluations/$id/submit',
    );
    return QtktEvaluation.fromJson(response.data ?? const {});
  }

  Future<QtktEvaluation> recall(int id) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/qtkt-evaluations/$id/recall',
    );
    return QtktEvaluation.fromJson(response.data ?? const {});
  }

  Future<QtktEvaluation> cancel(int id) => recall(id);
}

List<Map<String, dynamic>> _maps(List<dynamic>? value) => (value ?? const [])
    .whereType<Map>()
    .map((item) => item.map((key, value) => MapEntry('$key', value)))
    .toList();

final qtktRepositoryProvider = Provider<QtktRepository>((ref) {
  return QtktRepository(ref.watch(apiClientProvider));
});
