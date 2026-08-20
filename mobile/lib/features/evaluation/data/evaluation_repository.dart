import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/nursing_evaluation.dart';

class EvaluationRepository {
  EvaluationRepository(this._client);
  final ApiClient _client;

  Future<NursingEvalTemplate> template({
    String code = kMa2026EvalTemplateCode,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/nursing-evaluations/templates/$code',
    );
    return NursingEvalTemplate.fromJson(response.data ?? const {});
  }

  Future<List<NursingEvaluationRecord>> mine() async {
    final response =
        await _client.get<List<dynamic>>('/v1/nursing-evaluations/mine');
    return (response.data ?? [])
        .map((e) => NursingEvaluationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NursingEvaluationRecord>> pending() async {
    final response =
        await _client.get<List<dynamic>>('/v1/nursing-evaluations/pending');
    return (response.data ?? [])
        .map((e) => NursingEvaluationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NursingEvaluationRecord>> history() async {
    final response =
        await _client.get<List<dynamic>>('/v1/nursing-evaluations/history');
    return (response.data ?? [])
        .map((e) => NursingEvaluationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NursingEvaluationRecord>> forEmployee(int employeeId) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/nursing-evaluations/employees/$employeeId',
    );
    return (response.data ?? [])
        .map((e) => NursingEvaluationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NursingEvaluationRecord> byId(int id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/nursing-evaluations/records/$id',
    );
    return NursingEvaluationRecord.fromJson(response.data!);
  }

  Future<List<NursingPeriodStatus>> periodStatus({
    required int year,
    required int month,
    String templateCode = kMa2026EvalTemplateCode,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/nursing-evaluations/period-status',
      query: {
        'year': year,
        'month': month,
        'templateCode': templateCode,
      },
    );
    return (response.data ?? [])
        .map((e) => NursingPeriodStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NursingEvalSummaryRow>> monthlySummary({
    required int year,
    required int month,
    String templateCode = kMa2026EvalTemplateCode,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/nursing-evaluations/summary',
      query: {
        'year': year,
        'month': month,
        'templateCode': templateCode,
      },
    );
    return (response.data ?? [])
        .map((e) => NursingEvalSummaryRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EmployeeSummary>> evaluationRoster() async {
    final response =
        await _client.get<List<dynamic>>('/v1/employees/evaluation-roster');
    return (response.data ?? [])
        .map((e) => EmployeeSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NursingEvaluationRecord> submit({
    required int employeeId,
    required int periodYear,
    required int periodMonth,
    required Map<String, num> scores,
    Map<String, String>? notes,
    String? comments,
    required bool submitForReview,
    String templateCode = kMa2026EvalTemplateCode,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/nursing-evaluations',
      data: {
        'employeeId': employeeId,
        'periodYear': periodYear,
        'periodMonth': periodMonth,
        'templateCode': templateCode,
        'scores': scores,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (comments != null && comments.trim().isNotEmpty)
          'comments': comments.trim(),
        'submitForReview': submitForReview,
      },
    );
    return NursingEvaluationRecord.fromJson(response.data ?? const {});
  }

  /// [stage]: nursing-head | hr | director
  Future<void> review(
    int id,
    String stage, {
    required bool approved,
    String? comment,
  }) async {
    await _client.post(
      '/v1/nursing-evaluations/$id/$stage-review',
      data: {
        'approved': approved,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  Future<void> cancel(int id) async {
    await _client.post('/v1/nursing-evaluations/$id/cancel');
  }
}

final evaluationRepositoryProvider = Provider<EvaluationRepository>((ref) {
  return EvaluationRepository(ref.watch(apiClientProvider));
});
