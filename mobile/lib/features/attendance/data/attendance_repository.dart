import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/attendance_models.dart';

class AttendanceRepository {
  AttendanceRepository(this._client);
  final ApiClient _client;

  Future<AttendanceMonthMatrix> monthMatrix({
    required int year,
    required int month,
    int? departmentId,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/attendance/report/matrix',
      query: {
        'year': year,
        'month': month,
        ?'departmentId': departmentId,
      },
    );
    return AttendanceMonthMatrix.fromJson(response.data ?? const {});
  }

  Future<AttendanceMonthSummary> monthSummary(
    int employeeId,
    int year,
    int month,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/attendance/employees/$employeeId/summary',
      query: {'year': year, 'month': month},
    );
    return AttendanceMonthSummary.fromJson(response.data!);
  }

  /// Chi tiết tháng (summary + days kèm youngChild/deployment) — đồng bộ web.
  Future<({AttendanceMonthSummary summary, List<AttendanceDay> days})> monthDetail(
    int employeeId,
    int year,
    int month,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/attendance/employees/$employeeId/detail',
      query: {'year': year, 'month': month},
    );
    final data = response.data ?? const <String, dynamic>{};
    final daysRaw = data['days'];
    final days = daysRaw is List
        ? daysRaw
            .whereType<Map>()
            .map((e) => AttendanceDay.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AttendanceDay>[];
    return (
      summary: AttendanceMonthSummary.fromJson(data),
      days: days,
    );
  }

  Future<List<DutyShiftEntry>> dutyShifts({
    required int employeeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/attendance/employees/$employeeId/duty-shifts',
      query: {'from': _fmt(from), 'to': _fmt(to)},
    );
    return (response.data ?? [])
        .map((e) => DutyShiftEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DutyShiftTypeOption>> dutyShiftTypes({int? employeeId}) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/attendance/duty-shifts/types',
      query: employeeId != null && employeeId > 0 ? {'employeeId': employeeId} : null,
    );
    return (response.data ?? [])
        .map((e) => DutyShiftTypeOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertDutyShift({
    required int employeeId,
    required DateTime workDate,
    required String shiftTypeCode,
    String? roleTierCode,
    String? note,
  }) async {
    await _client.put(
      '/v1/attendance/employees/$employeeId/duty-shifts',
      data: {
        'workDate': _fmt(workDate),
        'shiftTypeCode': shiftTypeCode,
        if (roleTierCode != null && roleTierCode.trim().isNotEmpty)
          'roleTierCode': roleTierCode.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> bulkUpsertDutyShifts({
    required DateTime workDate,
    String? note,
    required List<({int employeeId, String shiftTypeCode, String? roleTierCode})> items,
  }) async {
    await _client.post(
      '/v1/attendance/duty-shifts/bulk',
      data: {
        'workDate': _fmt(workDate),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'items': [
          for (final item in items)
            {
              'employeeId': item.employeeId,
              'shiftTypeCode': item.shiftTypeCode,
              if (item.roleTierCode != null && item.roleTierCode!.trim().isNotEmpty)
                'roleTierCode': item.roleTierCode!.trim(),
            }
        ],
      },
    );
  }

  /// Điều động hàng loạt: mỗi nhân viên gửi 1 request riêng.
  Future<({int successCount, List<String> errors})> bulkDeployment({
    required DateTime workDate,
    required String reason,
    required List<({
      int employeeId,
      String shiftScope,
      String requestedStart,
      String requestedEnd,
      String? requestedAfternoonStart,
      String? requestedAfternoonEnd,
    })> items,
  }) async {
    int successCount = 0;
    final errors = <String>[];
    for (final item in items) {
      try {
        await _client.post(
          '/v1/attendance/requests',
          data: {
            'requestType': 'DEPLOYMENT',
            'employeeId': item.employeeId,
            'workDate': _fmt(workDate),
            'shiftScope': item.shiftScope,
            'reason': reason,
            'requestedStart': item.requestedStart,
            'requestedEnd': item.requestedEnd,
            if (item.requestedAfternoonStart != null)
              'requestedAfternoonStart': item.requestedAfternoonStart,
            if (item.requestedAfternoonEnd != null)
              'requestedAfternoonEnd': item.requestedAfternoonEnd,
          },
        );
        successCount++;
      } catch (e) {
        errors.add(e.toString());
      }
    }
    return (successCount: successCount, errors: errors);
  }

  Future<QuangTrungSupplementView> quangTrungSupplement({
    required int employeeId,
    required DateTime workDate,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/attendance/employees/$employeeId/quang-trung-supplement',
      query: {'workDate': _fmt(workDate)},
    );
    return QuangTrungSupplementView(
      raw: response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> applyQuangTrungSupplement({
    required int employeeId,
    required DateTime workDate,
    required String updateKind,
    required String requestedStart,
    required String requestedEnd,
    String? reason,
    String? requestedAfternoonStart,
    String? requestedAfternoonEnd,
  }) async {
    await _client.put(
      '/v1/attendance/employees/$employeeId/quang-trung-supplement',
      data: {
        'workDate': _fmt(workDate),
        'updateKind': updateKind,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        'requestedStart': requestedStart,
        'requestedEnd': requestedEnd,
        if (requestedAfternoonStart != null)
          'requestedAfternoonStart': requestedAfternoonStart,
        if (requestedAfternoonEnd != null)
          'requestedAfternoonEnd': requestedAfternoonEnd,
      },
    );
  }

  Future<void> bulkApplyQuangTrungSupplement({
    required DateTime workDate,
    required String updateKind,
    String? reason,
    required String requestedStart,
    required String requestedEnd,
    String? requestedAfternoonStart,
    String? requestedAfternoonEnd,
    required List<int> employeeIds,
  }) async {
    await _client.post(
      '/v1/attendance/quang-trung-supplement/bulk',
      data: {
        'employeeIds': employeeIds,
        'workDate': _fmt(workDate),
        'updateKind': updateKind,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        'requestedStart': requestedStart,
        'requestedEnd': requestedEnd,
        if (requestedAfternoonStart != null)
          'requestedAfternoonStart': requestedAfternoonStart,
        if (requestedAfternoonEnd != null)
          'requestedAfternoonEnd': requestedAfternoonEnd,
      },
    );
  }

  Future<void> deleteQuangTrungSupplement({
    required int employeeId,
    required DateTime workDate,
  }) async {
    await _client.delete(
      '/v1/attendance/employees/$employeeId/quang-trung-supplement/${_fmt(workDate)}',
    );
  }

  Future<List<AttendanceDay>> dayRange(int employeeId, DateTime from, DateTime to) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/attendance/employees/$employeeId',
      query: {'from': _fmt(from), 'to': _fmt(to)},
    );
    return (response.data ?? []).map((e) => AttendanceDay.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LeaveBalance> leaveBalance({int? year}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/attendance/leave-balance',
      query: year != null ? {'year': year} : null,
    );
    return LeaveBalance.fromJson(response.data!);
  }

  Future<List<AttendanceWorkRequest>> myRequests() async {
    final response = await _client.get<List<dynamic>>('/v1/attendance/requests/mine');
    return (response.data ?? []).map((e) => AttendanceWorkRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AttendanceWorkRequest>> pendingRequests() async {
    final response = await _client.get<List<dynamic>>('/v1/attendance/requests/pending');
    return (response.data ?? []).map((e) => AttendanceWorkRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AttendanceWorkRequest>> reviewHistory() async {
    final response = await _client.get<List<dynamic>>('/v1/attendance/requests/review-history');
    return (response.data ?? []).map((e) => AttendanceWorkRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lịch ca của một ngày (tự nhận mùa hè/đông, ca thông tầm, nuôi con nhỏ).
  /// Dùng để gợi ý sẵn khung giờ khi lập đơn bổ sung công.
  Future<DayShiftSchedule> daySchedule({
    required DateTime date,
    int? employeeId,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/attendance/schedule',
      query: {'date': _fmt(date), 'employeeId': ?employeeId},
    );
    return DayShiftSchedule.fromJson(response.data ?? const {});
  }

  Future<List<ContinuousShiftType>> continuousShiftTypes({
    bool activeOnly = true,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/attendance/continuous-shift-types',
      query: {'activeOnly': activeOnly},
    );
    return (response.data ?? [])
        .map((e) => ContinuousShiftType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ContinuousShiftMonth> continuousShiftDays({
    required int employeeId,
    required int year,
    required int month,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/attendance/employees/$employeeId/continuous-shift',
      query: {'year': year, 'month': month},
    );
    return ContinuousShiftMonth.fromJson(response.data ?? const {});
  }

  Future<ContinuousShiftMonth> setContinuousShiftDays({
    required int employeeId,
    required int year,
    required int month,
    required List<ContinuousShiftDayInfo> days,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/v1/attendance/employees/$employeeId/continuous-shift',
      data: {
        'year': year,
        'month': month,
        'days': [for (final d in days) d.toPayload()],
      },
    );
    return ContinuousShiftMonth.fromJson(response.data ?? const {});
  }

  Future<Map<String, dynamic>?> pendingYoungChildForEmployee({
    required int employeeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/young-child-requests/employee/$employeeId/pending',
      query: {'fromDate': _fmt(from), 'toDate': _fmt(to)},
    );
    return response.data;
  }

  Future<void> createRequest(Map<String, dynamic> payload) async {
    await _client.post('/v1/attendance/requests', data: payload);
  }

  Future<void> updateRequest(int id, Map<String, dynamic> payload) async {
    await _client.put('/v1/attendance/requests/$id', data: payload);
  }

  Future<void> withdraw(int id) async {
    await _client.post('/v1/attendance/requests/$id/withdraw');
  }

  /// [endpointSlug]: head-review | nursing-head-review | hr-review | director-review
  Future<void> review(
    int id,
    String endpointSlug, {
    required bool approved,
    String? comment,
    bool? waiveForgotFine,
  }) async {
    await _client.post(
      '/v1/attendance/requests/$id/$endpointSlug',
      data: {
        'approved': approved,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        'waiveForgotFine': ?waiveForgotFine,
      },
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(apiClientProvider));
});
