import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

/// Các tab chỉ số Module A — khớp web `MetricKind`.
enum NursingActivityMetric {
  overview(
    'overview',
    'Tổng quan',
    Icons.dashboard_outlined,
    AppColors.primary,
  ),
  falls('falls', 'Té ngã', Icons.warning_amber_rounded, AppColors.warning),
  pressureUlcers(
    'pressure-ulcers',
    'Loét tì đè',
    Icons.healing_outlined,
    Color(0xFF0369A1),
  ),
  nurseBed('nurse-bed', 'ĐD/NB', Icons.groups_outlined, AppColors.info),
  idMixups(
    'id-mixups',
    'Nhầm NB',
    Icons.person_search_outlined,
    Color(0xFF7C3AED),
  ),
  medicationErrors(
    'medication-errors',
    'Sai thuốc',
    Icons.medication_outlined,
    Color(0xFFB45309),
  );

  const NursingActivityMetric(this.path, this.label, this.icon, this.color);
  final String path;
  final String label;
  final IconData icon;
  final Color color;
}

class NursingActivityDeptMetrics {
  NursingActivityDeptMetrics(this.raw);
  final Map<String, dynamic> raw;

  int get departmentId => (raw['departmentId'] as num?)?.toInt() ?? 0;
  String get departmentName => raw['departmentName'] as String? ?? 'Khoa/phòng';
  int get falls => (raw['falls'] as num?)?.toInt() ?? 0;
  int get newPressureUlcers => (raw['newPressureUlcers'] as num?)?.toInt() ?? 0;
  int get idMixups => (raw['idMixups'] as num?)?.toInt() ?? 0;
  int get medicationErrors => (raw['medicationErrors'] as num?)?.toInt() ?? 0;
  int get inpatients => (raw['inpatients'] as num?)?.toInt() ?? 0;
  int get inpatientTreatmentDays =>
      (raw['inpatientTreatmentDays'] as num?)?.toInt() ?? 0;
  int get totalStaff => (raw['totalStaff'] as num?)?.toInt() ?? 0;
  int get workingStaff => (raw['workingStaff'] as num?)?.toInt() ?? 0;
  int get actualBeds => (raw['actualBeds'] as num?)?.toInt() ?? 0;
  int get reportDays => (raw['reportDays'] as num?)?.toInt() ?? 0;
  bool get hasData => raw['hasData'] == true;

  String _label(String key) {
    final v = raw[key]?.toString().trim();
    if (v == null || v.isEmpty) return '—';
    return v;
  }

  String get fallRateLabel => _label('fallRateLabel');
  String get fallFrequencyLabel => _label('fallFrequencyLabel');
  String get pressureUlcerRateLabel => _label('pressureUlcerRateLabel');
  String get pressureUlcerFrequencyLabel =>
      _label('pressureUlcerFrequencyLabel');
  String get nurseBedRatioLabel => _label('nurseBedRatioLabel');
  String get idMixupFrequencyLabel => _label('idMixupFrequencyLabel');
  String get medicationErrorRateLabel => _label('medicationErrorRateLabel');

  num? _num(String key) {
    final v = raw[key];
    if (v is num) return v;
    return null;
  }

  num? get fallRate => _num('fallRate');
  num? get fallFrequency => _num('fallFrequency');
  num? get pressureUlcerRate => _num('pressureUlcerRate');
  num? get pressureUlcerFrequency => _num('pressureUlcerFrequency');
  num? get nurseBedRatio => _num('nurseBedRatio');
  num? get idMixupFrequency => _num('idMixupFrequency');
  num? get medicationErrorRate => _num('medicationErrorRate');
}

class NursingActivityTrendPoint {
  NursingActivityTrendPoint(this.raw);
  final Map<String, dynamic> raw;

  String get label =>
      raw['label'] as String? ?? raw['bucketKey'] as String? ?? '';
  num? primary(String key) {
    final v = raw[key];
    return v is num ? v : null;
  }
}

class NursingActivityReport {
  NursingActivityReport({required this.raw});
  final Map<String, dynamic> raw;

  String get reportTitle =>
      raw['reportTitle'] as String? ?? 'Báo cáo hoạt động ĐD';
  String get fromLabel =>
      raw['fromLabel'] as String? ?? raw['from'] as String? ?? '';
  String get toLabel => raw['toLabel'] as String? ?? raw['to'] as String? ?? '';
  String get yearMonth => raw['yearMonth'] as String? ?? '';
  String get departmentName => raw['departmentName'] as String? ?? 'Toàn viện';
  String get trendGranularity => raw['trendGranularity'] as String? ?? 'DAY';

  Map<String, dynamic> get kpi {
    final t = raw['kpi'];
    if (t is Map) return Map<String, dynamic>.from(t);
    return const {};
  }

  Map<String, dynamic> get overviewKpi {
    final t = raw['overviewKpi'];
    if (t is Map) return Map<String, dynamic>.from(t);
    return const {};
  }

  List<NursingActivityDeptMetrics> get byDepartment {
    final list = raw['byDepartment'] ?? raw['summaryTable'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) NursingActivityDeptMetrics(Map<String, dynamic>.from(e)),
    ];
  }

  List<NursingActivityTrendPoint> get trend {
    final list = raw['trend'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) NursingActivityTrendPoint(Map<String, dynamic>.from(e)),
    ];
  }

  Object? kpiValue(String key) {
    final direct = kpi[key];
    if (direct != null) return direct;
    final card = overviewKpi[key];
    if (card is Map) {
      return card['value'] ??
          card['rateLabel'] ??
          card['ratioLabel'] ??
          card['frequencyLabel'] ??
          card['count'];
    }
    // Overview cards keyed by metric name.
    if (key == 'fallRateLabel') {
      final c = overviewKpi['falls'];
      if (c is Map) return c['rateLabel'];
    }
    if (key == 'nurseBedRatioLabel') {
      final c = overviewKpi['nurseBed'];
      if (c is Map) return c['ratioLabel'];
    }
    return null;
  }

  String displayKpi(String key) {
    final v = kpiValue(key);
    if (v != null) {
      if (v is num && v == v.roundToDouble()) return '${v.toInt()}';
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    // Overview: cộng từ bảng khoa khi card KPI không có.
    final sumKeys = {
      'falls',
      'newPressureUlcers',
      'idMixups',
      'medicationErrors',
      'inpatients',
      'inpatientTreatmentDays',
      'totalStaff',
      'workingStaff',
      'actualBeds',
    };
    if (sumKeys.contains(key)) {
      var total = 0;
      for (final d in byDepartment) {
        total += int.tryParse(NursingActivityMetricUi.deptValue(d, key)) ?? 0;
      }
      return '$total';
    }
    if (key == 'nurseBedRatioLabel' || key == 'fallRateLabel') {
      final first = byDepartment.where((d) => d.hasData).toList();
      if (first.isNotEmpty) {
        return NursingActivityMetricUi.deptValue(first.first, key);
      }
    }
    return '—';
  }
}

class NursingActivityDeptDetail {
  NursingActivityDeptDetail({required this.raw});
  final Map<String, dynamic> raw;

  String get reportTitle => raw['reportTitle'] as String? ?? 'Chi tiết khoa';
  String get departmentName => raw['departmentName'] as String? ?? 'Khoa/phòng';
  String get fromLabel =>
      raw['fromLabel'] as String? ?? raw['from'] as String? ?? '';
  String get toLabel => raw['toLabel'] as String? ?? raw['to'] as String? ?? '';

  NursingActivityDeptMetrics get metrics {
    final m = raw['metrics'];
    if (m is Map) {
      return NursingActivityDeptMetrics(Map<String, dynamic>.from(m));
    }
    return NursingActivityDeptMetrics(const {});
  }

  List<Map<String, dynamic>> get dailyRows {
    final list = raw['dailyRows'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }
}

class NursingActivityFilterDepartment {
  NursingActivityFilterDepartment({
    required this.id,
    required this.name,
    this.code = '',
  });

  final int id;
  final String name;
  final String code;

  factory NursingActivityFilterDepartment.fromJson(Map<String, dynamic> json) {
    return NursingActivityFilterDepartment(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Khoa/phòng',
      code: json['code'] as String? ?? '',
    );
  }
}

class NursingActivityReportRepository {
  NursingActivityReportRepository(this._client);
  final ApiClient _client;

  Future<List<NursingActivityFilterDepartment>> filterDepartments() async {
    final res = await _client.get<List<dynamic>>(
      '/v1/nursing-activity-reports/departments',
    );
    return [
      for (final item in res.data ?? const [])
        if (item is Map)
          NursingActivityFilterDepartment.fromJson(
            Map<String, dynamic>.from(item),
          ),
    ];
  }

  Future<NursingActivityReport> fetch(
    NursingActivityMetric metric, {
    required String yearMonth,
    int? departmentId,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/nursing-activity-reports/${metric.path}',
      query: {
        'periodType': 'MONTH',
        'yearMonth': yearMonth,
        if (departmentId != null) 'departmentId': departmentId,
      },
    );
    return NursingActivityReport(raw: res.data ?? const {});
  }

  Future<NursingActivityDeptDetail> departmentDetail({
    required int departmentId,
    required String yearMonth,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/nursing-activity-reports/departments/$departmentId/detail',
      query: {'periodType': 'MONTH', 'yearMonth': yearMonth},
    );
    return NursingActivityDeptDetail(raw: res.data ?? const {});
  }
}

/// KPI / cột hiển thị theo từng chỉ số — đồng bộ web METRIC_CONFIGS.
class NursingActivityMetricUi {
  const NursingActivityMetricUi({
    required this.kpiFields,
    required this.deptLines,
    this.trendPrimaryKey,
    this.trendPrimaryName,
  });

  final List<(String key, String label)> kpiFields;
  final List<(String key, String label)> deptLines;
  final String? trendPrimaryKey;
  final String? trendPrimaryName;

  static NursingActivityMetricUi forMetric(NursingActivityMetric m) {
    return switch (m) {
      NursingActivityMetric.overview => const NursingActivityMetricUi(
        kpiFields: [
          ('falls', 'Té ngã'),
          ('newPressureUlcers', 'Loét mới'),
          ('idMixups', 'Nhầm NB'),
          ('medicationErrors', 'Sai thuốc'),
          ('nurseBedRatioLabel', 'ĐD/người bệnh'),
          ('fallRateLabel', 'Tỉ lệ té ngã'),
        ],
        deptLines: [
          ('falls', 'Ngã'),
          ('newPressureUlcers', 'Loét'),
          ('idMixups', 'Nhầm'),
          ('medicationErrors', 'Thuốc'),
          ('nurseBedRatioLabel', 'ĐD/NB'),
        ],
      ),
      NursingActivityMetric.falls => const NursingActivityMetricUi(
        kpiFields: [
          ('falls', 'Tổng ca té ngã'),
          ('inpatients', 'NB nội trú'),
          ('inpatientTreatmentDays', 'Ngày nằm viện'),
          ('fallRateLabel', 'Tỉ lệ té ngã'),
          ('fallFrequencyLabel', 'Tần suất/1.000'),
        ],
        deptLines: [
          ('falls', 'Ca'),
          ('fallRateLabel', 'Tỉ lệ'),
          ('fallFrequencyLabel', 'Tần suất'),
        ],
        trendPrimaryKey: 'fallRate',
        trendPrimaryName: 'Tỉ lệ té ngã (%)',
      ),
      NursingActivityMetric.pressureUlcers => const NursingActivityMetricUi(
        kpiFields: [
          ('newPressureUlcers', 'Ca loét mới'),
          ('inpatients', 'NB nội trú'),
          ('inpatientTreatmentDays', 'Ngày nằm viện'),
          ('pressureUlcerRateLabel', 'Tỉ lệ loét'),
          ('pressureUlcerFrequencyLabel', 'Tần suất/1.000'),
        ],
        deptLines: [
          ('newPressureUlcers', 'Ca'),
          ('pressureUlcerRateLabel', 'Tỉ lệ'),
          ('pressureUlcerFrequencyLabel', 'Tần suất'),
        ],
        trendPrimaryKey: 'pressureUlcerRate',
        trendPrimaryName: 'Tỉ lệ loét (%)',
      ),
      NursingActivityMetric.nurseBed => const NursingActivityMetricUi(
        kpiFields: [
          ('workingStaff', 'NV đi làm'),
          ('totalStaff', 'Tổng NV'),
          ('actualBeds', 'Giường thực kê'),
          ('nurseBedRatioLabel', 'ĐD / người bệnh'),
        ],
        deptLines: [
          ('workingStaff', 'Đi làm'),
          ('actualBeds', 'Giường'),
          ('nurseBedRatioLabel', 'Tỉ lệ'),
        ],
        trendPrimaryKey: 'nurseBedRatio',
        trendPrimaryName: 'ĐD/người bệnh',
      ),
      NursingActivityMetric.idMixups => const NursingActivityMetricUi(
        kpiFields: [
          ('idMixups', 'Ca nhầm NB'),
          ('inpatientTreatmentDays', 'Ngày nằm viện'),
          ('idMixupFrequencyLabel', 'Tần suất/1.000'),
        ],
        deptLines: [('idMixups', 'Ca'), ('idMixupFrequencyLabel', 'Tần suất')],
        trendPrimaryKey: 'idMixupFrequency',
        trendPrimaryName: 'Nhầm NB/1.000',
      ),
      NursingActivityMetric.medicationErrors => const NursingActivityMetricUi(
        kpiFields: [
          ('medicationErrors', 'Ca sai thuốc'),
          ('inpatients', 'NB nội trú'),
          ('medicationErrorRateLabel', 'Tỉ lệ sai thuốc'),
        ],
        deptLines: [
          ('medicationErrors', 'Ca'),
          ('medicationErrorRateLabel', 'Tỉ lệ'),
        ],
        trendPrimaryKey: 'medicationErrorRate',
        trendPrimaryName: 'Sai thuốc (%)',
      ),
    };
  }

  static String deptValue(NursingActivityDeptMetrics d, String key) {
    return switch (key) {
      'falls' => '${d.falls}',
      'newPressureUlcers' => '${d.newPressureUlcers}',
      'idMixups' => '${d.idMixups}',
      'medicationErrors' => '${d.medicationErrors}',
      'inpatients' => '${d.inpatients}',
      'inpatientTreatmentDays' => '${d.inpatientTreatmentDays}',
      'totalStaff' => '${d.totalStaff}',
      'workingStaff' => '${d.workingStaff}',
      'actualBeds' => '${d.actualBeds}',
      'fallRateLabel' => d.fallRateLabel,
      'fallFrequencyLabel' => d.fallFrequencyLabel,
      'pressureUlcerRateLabel' => d.pressureUlcerRateLabel,
      'pressureUlcerFrequencyLabel' => d.pressureUlcerFrequencyLabel,
      'nurseBedRatioLabel' => d.nurseBedRatioLabel,
      'idMixupFrequencyLabel' => d.idMixupFrequencyLabel,
      'medicationErrorRateLabel' => d.medicationErrorRateLabel,
      _ => '—',
    };
  }
}

final nursingActivityReportRepositoryProvider =
    Provider<NursingActivityReportRepository>((ref) {
      return NursingActivityReportRepository(ref.watch(apiClientProvider));
    });

/// Nhãn chỉ số tách thành phần số và phần đơn vị để hiển thị trên thẻ hẹp.
///
/// Backend trả chuỗi dài như `0.54 điều dưỡng/người bệnh` hay
/// `0.00 lượt té ngã/1.000 ngày điều trị`; để nguyên thì thẻ KPI trên phone bị
/// xuống dòng gãy khúc. [hasData] là false với `Chưa đủ dữ liệu`/`Không xác định`.
class MetricLabelParts {
  const MetricLabelParts({
    required this.value,
    required this.unit,
    required this.hasData,
  });

  final String value;
  final String? unit;
  final bool hasData;

  static final RegExp _leadingNumber = RegExp(r'^(-?[\d.,]+\s*%?)\s*(.*)$');

  factory MetricLabelParts.parse(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty || text == '—') {
      return const MetricLabelParts(value: '—', unit: null, hasData: false);
    }
    final match = _leadingNumber.firstMatch(text);
    if (match == null) {
      // "Chưa đủ dữ liệu", "Không xác định"…
      return MetricLabelParts(value: text, unit: null, hasData: false);
    }
    final unit = match.group(2)?.trim();
    return MetricLabelParts(
      value: match.group(1)!.trim(),
      unit: unit == null || unit.isEmpty ? null : unit,
      hasData: true,
    );
  }
}
