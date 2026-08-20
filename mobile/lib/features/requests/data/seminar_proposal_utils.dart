const _blockingSeminarStatuses = {
  'PENDING_HR',
  'PENDING_DIRECTOR',
  'APPROVED',
};

bool seminarDateRangesOverlap(
  String fromA,
  String toA,
  String fromB,
  String toB,
) =>
    fromA.compareTo(toB) <= 0 && toA.compareTo(fromB) >= 0;

Map<String, dynamic>? findSeminarDateOverlap(
  List<Map<String, dynamic>> proposals,
  String startDate,
  String endDate,
) {
  for (final proposal in proposals) {
    final status = proposal['status']?.toString() ?? '';
    if (!_blockingSeminarStatuses.contains(status)) continue;
    final from = proposal['startDate']?.toString();
    final to = proposal['endDate']?.toString();
    if (from == null || to == null) continue;
    if (seminarDateRangesOverlap(startDate, endDate, from, to)) {
      return proposal;
    }
  }
  return null;
}

String? seminarOverlapMessage(
  List<Map<String, dynamic>> proposals,
  String startDate,
  String endDate,
) {
  final hit = findSeminarDateOverlap(proposals, startDate, endDate);
  if (hit == null) return null;
  final name = hit['seminarName']?.toString() ?? 'khác';
  final from = hit['startDate']?.toString() ?? '';
  final to = hit['endDate']?.toString() ?? '';
  return 'Khoảng ngày trùng với phiếu «$name» ($from → $to).';
}
