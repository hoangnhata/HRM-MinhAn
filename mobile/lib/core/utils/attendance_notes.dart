/// Parse ghi chú ngày công (nối bằng `;`) để hiển thị gọn trên app.
class ParsedAttendanceNote {
  const ParsedAttendanceNote({
    required this.kind,
    required this.title,
    this.timeRange,
    this.hoursLine,
    this.breakdown,
    this.reason,
    this.ref,
    required this.raw,
  });

  final String kind;
  final String title;
  final String? timeRange;
  final String? hoursLine;
  final String? breakdown;
  final String? reason;
  final String? ref;
  final String raw;
}

final _refRe = RegExp(r'\[(DD(?:TC)?:\d+)\]\s*$', caseSensitive: false);
final _timeRe = RegExp(r'(\d{1,2}:\d{2}\s*[–\-—]\s*\d{1,2}:\d{2})');
final _breakdownRe = RegExp(r'\(([^)]*sáng[^)]*)\)', caseSensitive: false);
final _coeffRe = RegExp(r'×\s*([\d.,]+)');

List<ParsedAttendanceNote> parseAttendanceNotes(String? note) {
  final raw = note?.trim();
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .split(';')
      .map((p) => _parseOne(p.trim()))
      .whereType<ParsedAttendanceNote>()
      .toList();
}

ParsedAttendanceNote? _parseOne(String raw) {
  if (raw.isEmpty) return null;
  final refMatch = _refRe.firstMatch(raw);
  final ref = refMatch?.group(1);
  final body = refMatch == null
      ? raw
      : raw.substring(0, refMatch.start).trim();
  final lower = body.toLowerCase();

  if (lower.startsWith('điều động làm thêm')) {
    return _parseDeployment(body, raw, ref, 'deployment_ot', 'Điều động làm thêm');
  }
  if (lower.startsWith('điều động trong ca')) {
    return _parseDeployment(body, raw, ref, 'deployment_inside', 'Điều động trong ca');
  }
  if (lower.contains('đồng bộ máy chấm')) {
    return ParsedAttendanceNote(
      kind: 'sync',
      title: 'Đồng bộ máy chấm công',
      ref: ref,
      raw: raw,
    );
  }
  return ParsedAttendanceNote(kind: 'other', title: body, ref: ref, raw: raw);
}

ParsedAttendanceNote _parseDeployment(
  String body,
  String raw,
  String? ref,
  String kind,
  String defaultTitle,
) {
  final coeff = _coeffRe.firstMatch(body)?.group(1);
  final title = coeff == null ? defaultTitle : '$defaultTitle ×$coeff';
  final timeRange = _timeRe.firstMatch(body)?.group(1)?.replaceAll(RegExp(r'\s+'), ' ');
  final breakdown = _breakdownRe.firstMatch(body)?.group(1)?.trim();

  String? hoursLine;
  if (timeRange != null) {
    final idx = body.indexOf(timeRange);
    final after = body.substring(idx + timeRange.length);
    final dot = RegExp(r'·\s*([^(]+?)(?=\s*\(|$)').firstMatch(after);
    if (dot != null) {
      hoursLine = dot.group(1)?.trim();
    } else {
      final dash = RegExp(r'[—-]\s*([^(]+?)(?=\s*\(|$)').firstMatch(after);
      hoursLine = dash?.group(1)?.trim();
    }
    if (hoursLine != null && hoursLine.isEmpty) hoursLine = null;
  }

  String? reason;
  if (breakdown != null) {
    final token = '($breakdown)';
    final idx = body.indexOf(token);
    if (idx >= 0) {
      reason = body.substring(idx + token.length).trim().replaceFirst(RegExp(r'^:\s*'), '');
      if (reason.isEmpty) reason = null;
    }
  }

  return ParsedAttendanceNote(
    kind: kind,
    title: title,
    timeRange: timeRange,
    hoursLine: hoursLine,
    breakdown: breakdown,
    reason: reason,
    ref: ref,
    raw: raw,
  );
}
