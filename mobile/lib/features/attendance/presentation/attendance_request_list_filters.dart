import '../../../shared/models/attendance_models.dart';
import 'attendance_enums.dart';

/// Bộ lọc danh sách đơn công / nghỉ — đồng bộ logic web `applyRequestListFilters`.
class AttendanceRequestListFilters {
  const AttendanceRequestListFilters({
    this.query = '',
    this.department = '',
    this.status = '',
    this.requestType = '',
    this.dateFrom,
    this.dateTo,
  });

  final String query;
  final String department;
  final String status;
  final String requestType;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  static const empty = AttendanceRequestListFilters();

  bool get isActive =>
      query.trim().isNotEmpty ||
      department.trim().isNotEmpty ||
      status.isNotEmpty ||
      requestType.isNotEmpty ||
      dateFrom != null ||
      dateTo != null;

  /// Bộ lọc từ sheet (không tính ô tìm kiếm).
  bool get hasAdvancedFilters =>
      department.trim().isNotEmpty ||
      status.isNotEmpty ||
      requestType.isNotEmpty ||
      dateFrom != null ||
      dateTo != null;

  int get advancedFilterCount {
    var n = 0;
    if (department.trim().isNotEmpty) n++;
    if (status.isNotEmpty) n++;
    if (requestType.isNotEmpty) n++;
    if (dateFrom != null) n++;
    if (dateTo != null) n++;
    return n;
  }

  AttendanceRequestListFilters copyWith({
    String? query,
    String? department,
    String? status,
    String? requestType,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return AttendanceRequestListFilters(
      query: query ?? this.query,
      department: department ?? this.department,
      status: status ?? this.status,
      requestType: requestType ?? this.requestType,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }

  List<AttendanceWorkRequest> apply(List<AttendanceWorkRequest> items) {
    final q = query.trim().toLowerCase();
    final dept = department.trim().toLowerCase();
    final from = dateFrom == null ? null : _ymd(dateFrom!);
    final to = dateTo == null ? null : _ymd(dateTo!);

    final filtered = items.where((r) {
      if (requestType.isNotEmpty && r.requestType != requestType) return false;
      if (status.isNotEmpty && r.status != status) return false;
      if (dept.isNotEmpty) {
        final d = (r.department ?? '').trim().toLowerCase();
        if (d != dept && !d.contains(dept)) return false;
      }
      if (q.isNotEmpty) {
        final hay = [
          r.employeeName,
          r.department,
          r.positionTitle,
          r.reason,
          AttendanceEnums.requestTypeLabel(r.requestType),
          AttendanceEnums.statusLabel(r.status),
        ].whereType<String>().join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      final created = r.createdAt == null ? '' : _ymd(r.createdAt!);
      if (from != null && (created.isEmpty || created.compareTo(from) < 0)) {
        return false;
      }
      if (to != null && (created.isEmpty || created.compareTo(to) > 0)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = a.createdAt?.toIso8601String() ?? '';
      final bDate = b.createdAt?.toIso8601String() ?? '';
      return bDate.compareTo(aDate);
    });
    return filtered;
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Tùy chọn trạng thái xuất hiện trong danh sách (+ nhãn chuẩn).
List<({String value, String label})> attendanceStatusFilterOptions(
  Iterable<AttendanceWorkRequest> items,
) {
  final seen = <String>{};
  final out = <({String value, String label})>[];
  for (final r in items) {
    if (seen.add(r.status)) {
      out.add((
        value: r.status,
        label: AttendanceEnums.statusLabel(r.status),
      ));
    }
  }
  out.sort((a, b) => a.label.compareTo(b.label));
  return out;
}

List<String> attendanceDepartmentOptions(
  Iterable<AttendanceWorkRequest> items,
) {
  final names = <String>{};
  for (final r in items) {
    final d = r.department?.trim();
    if (d != null && d.isNotEmpty) names.add(d);
  }
  final list = names.toList()..sort((a, b) => a.compareTo(b));
  return list;
}
