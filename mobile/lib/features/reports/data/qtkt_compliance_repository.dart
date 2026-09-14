import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

enum QtktComplianceKind {
  handHygiene('hand-hygiene', 'Vệ sinh tay'),
  technical('technical-procedures', 'Quy trình kỹ thuật'),
  gdsk('gdsk-counseling', 'Tư vấn GDSK');

  const QtktComplianceKind(this.path, this.label);
  final String path;
  final String label;
}

enum ComplianceResultFilter { all, pass, fail }

class ComplianceBucket {
  ComplianceBucket(this.raw);
  final Map<String, dynamic> raw;

  int? get departmentId => (raw['departmentId'] as num?)?.toInt();
  String get departmentName =>
      raw['departmentName'] as String? ??
      raw['procedureName'] as String? ??
      raw['checkContextLabel'] as String? ??
      '—';
  String? get procedureName => raw['procedureName'] as String?;
  String? get procedureCode => raw['procedureCode'] as String?;
  String? get checkContextLabel => raw['checkContextLabel'] as String?;
  String? get checkContextCode => raw['checkContextCode'] as String?;
  int get total => (raw['total'] as num?)?.toInt() ?? 0;
  int get passed => (raw['passed'] as num?)?.toInt() ?? 0;
  int get failed => (raw['failed'] as num?)?.toInt() ?? 0;
  bool get isTotal => raw['isTotal'] == true;
  bool get hasData => raw['hasData'] == true;
  String get rateLabel {
    final labeled = raw['complianceRateLabel'] as String?;
    if (labeled != null && labeled.trim().isNotEmpty) return labeled;
    final rate = raw['complianceRate'];
    if (rate is num) return '${rate.toStringAsFixed(1)}%';
    return '—';
  }

  double get rateFraction {
    final rate = raw['complianceRate'];
    if (rate is num) {
      final v = rate.toDouble();
      // Backend có thể trả 0–1 hoặc 0–100.
      return v > 1 ? (v / 100).clamp(0.0, 1.0) : v.clamp(0.0, 1.0);
    }
    if (total <= 0) return 0;
    return (passed / total).clamp(0.0, 1.0);
  }

  List<ComplianceBucket> get children {
    final list = raw['byProcedure'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) ComplianceBucket(Map<String, dynamic>.from(e)),
    ];
  }
}

class ComplianceTrendPoint {
  ComplianceTrendPoint(this.raw);
  final Map<String, dynamic> raw;

  String get label => raw['label'] as String? ?? '';
  bool get hasData => raw['hasData'] == true;
  double? get rate {
    final v = raw['complianceRate'];
    if (v is! num) return null;
    final n = v.toDouble();
    return n > 1 ? n : n * 100;
  }
}

class ComplianceDetailRow {
  ComplianceDetailRow(this.raw);
  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get employeeName => raw['employeeName'] as String? ?? '—';
  String get employeeCode => raw['employeeCode'] as String? ?? '';
  String get departmentName => raw['departmentName'] as String? ?? '';
  String get procedureName =>
      raw['procedureName'] as String? ?? raw['procedureCode'] as String? ?? '';
  String get evalDateLabel =>
      raw['evalDateLabel'] as String? ?? raw['evalDate'] as String? ?? '';
  String? get checkContextLabel => raw['checkContextLabel'] as String?;
  String? get checkContextCode => raw['checkContextCode'] as String?;
  String get procedureCode => raw['procedureCode'] as String? ?? '';
  String? get patientCode => raw['patientCode'] as String?;
  bool get passed => raw['passed'] == true;
  String get scoreLabel {
    final total = raw['totalScore'];
    final max = raw['maxScore'];
    if (total == null || max == null) return '';
    return '$total/$max';
  }
}

class QtktComplianceReport {
  QtktComplianceReport({required this.raw});
  final Map<String, dynamic> raw;

  String get reportTitle => raw['reportTitle'] as String? ?? 'Tuân thủ QTKT';
  String get departmentName => raw['departmentName'] as String? ?? 'Toàn khối';
  String get yearMonth => raw['yearMonth'] as String? ?? '';
  String get formulaNote => raw['formulaNote'] as String? ?? '';

  Map<String, dynamic> get kpi {
    final k = raw['kpi'];
    if (k is Map) return Map<String, dynamic>.from(k);
    return const {};
  }

  int get total => (kpi['total'] as num?)?.toInt() ?? 0;
  int get passed => (kpi['passed'] as num?)?.toInt() ?? 0;
  int get failed => (kpi['failed'] as num?)?.toInt() ?? 0;
  String get rateLabel =>
      kpi['complianceRateLabel'] as String? ??
      ((kpi['complianceRate'] as num?) != null
          ? '${((kpi['complianceRate'] as num) > 1 ? (kpi['complianceRate'] as num) : (kpi['complianceRate'] as num) * 100).toStringAsFixed(1)}%'
          : '—');

  double get rateFraction {
    final rate = kpi['complianceRate'];
    if (rate is num) {
      final v = rate.toDouble();
      return v > 1 ? (v / 100).clamp(0.0, 1.0) : v.clamp(0.0, 1.0);
    }
    if (total <= 0) return 0;
    return (passed / total).clamp(0.0, 1.0);
  }

  List<ComplianceBucket> _buckets(String key) {
    final list = raw[key];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) ComplianceBucket(Map<String, dynamic>.from(e)),
    ];
  }

  List<ComplianceBucket> get byDepartment =>
      _buckets('byDepartment').where((e) => !e.isTotal).toList();
  List<ComplianceBucket> get byCheckContext => _buckets('byCheckContext');
  List<ComplianceBucket> get byProcedure => _buckets('byProcedure');

  List<ComplianceTrendPoint> get trend {
    final list = raw['trend'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) ComplianceTrendPoint(Map<String, dynamic>.from(e)),
    ];
  }

  List<ComplianceDetailRow> get details {
    final wrap = raw['details'];
    final list = wrap is Map ? wrap['items'] : raw['details'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) ComplianceDetailRow(Map<String, dynamic>.from(e)),
    ];
  }

  int get detailsTotal {
    final wrap = raw['details'];
    if (wrap is Map) return (wrap['total'] as num?)?.toInt() ?? details.length;
    return details.length;
  }

  bool get hasMoreDetails {
    final wrap = raw['details'];
    if (wrap is! Map) return false;
    final page = (wrap['page'] as num?)?.toInt() ?? 0;
    final totalPages = (wrap['totalPages'] as num?)?.toInt() ?? 1;
    return page + 1 < totalPages;
  }

  int get detailsPage {
    final wrap = raw['details'];
    if (wrap is Map) return (wrap['page'] as num?)?.toInt() ?? 0;
    return 0;
  }
}

class QtktComplianceFilterDepartment {
  QtktComplianceFilterDepartment({required this.id, required this.name});
  final int id;
  final String name;

  factory QtktComplianceFilterDepartment.fromJson(Map<String, dynamic> json) {
    return QtktComplianceFilterDepartment(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Khoa/phòng',
    );
  }
}

class QtktComplianceRepository {
  QtktComplianceRepository(this._client);
  final ApiClient _client;

  Future<List<QtktComplianceFilterDepartment>> departments({
    QtktComplianceKind? kind,
  }) async {
    final res = await _client.get<List<dynamic>>(
      '/v1/qtkt-compliance-reports/departments',
      query: {if (kind != null) 'reportKind': kind.name},
    );
    return [
      for (final item in res.data ?? const [])
        if (item is Map)
          QtktComplianceFilterDepartment.fromJson(
            Map<String, dynamic>.from(item),
          ),
    ];
  }

  Future<QtktComplianceReport> fetch(
    QtktComplianceKind kind, {
    required String yearMonth,
    int? departmentId,
    String? procedureCode,
    ComplianceResultFilter resultFilter = ComplianceResultFilter.all,
    int page = 0,
    int size = 30,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/qtkt-compliance-reports/${kind.path}',
      query: {
        'yearMonth': yearMonth,
        if (departmentId != null) 'departmentId': departmentId,
        if (procedureCode != null && procedureCode.isNotEmpty)
          'procedureCode': procedureCode,
        if (resultFilter != ComplianceResultFilter.all)
          'resultFilter': resultFilter == ComplianceResultFilter.pass
              ? 'PASS'
              : 'FAIL',
        'page': page,
        'size': size,
        'sortDir': 'DESC',
      },
    );
    return QtktComplianceReport(raw: res.data ?? const {});
  }

  /// Tải danh sách phiếu để drill-down (khoa / ngữ cảnh / quy trình).
  Future<List<ComplianceDetailRow>> fetchDetailRows(
    QtktComplianceKind kind, {
    required String yearMonth,
    int? departmentId,
    String? procedureCode,
    String? checkContextCode,
    String? checkContextLabel,
    int size = 200,
  }) async {
    final report = await fetch(
      kind,
      yearMonth: yearMonth,
      departmentId: departmentId,
      procedureCode: procedureCode,
      page: 0,
      size: size,
    );
    var rows = report.details;
    if (checkContextCode != null && checkContextCode.isNotEmpty) {
      rows = rows
          .where((r) => r.checkContextCode == checkContextCode)
          .toList(growable: false);
    } else if (checkContextLabel != null && checkContextLabel.isNotEmpty) {
      rows = rows
          .where((r) => r.checkContextLabel == checkContextLabel)
          .toList(growable: false);
    }
    return rows;
  }
}

final qtktComplianceRepositoryProvider = Provider<QtktComplianceRepository>((
  ref,
) {
  return QtktComplianceRepository(ref.watch(apiClientProvider));
});
