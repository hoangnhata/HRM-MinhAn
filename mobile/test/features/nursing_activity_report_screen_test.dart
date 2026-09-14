import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_mobile/core/network/api_client.dart';
import 'package:hrm_mobile/core/storage/token_storage.dart';
import 'package:hrm_mobile/features/auth/application/auth_controller.dart';
import 'package:hrm_mobile/features/auth/data/auth_repository.dart';
import 'package:hrm_mobile/features/reports/data/nursing_activity_report_repository.dart';
import 'package:hrm_mobile/features/reports/presentation/nursing_activity_report_screen.dart';

/// Bản đồ chỉ số một khoa, khớp `AggregatedMetrics.toMetricsMap()` của backend.
Map<String, dynamic> _deptRow({
  required int id,
  required String name,
  int falls = 0,
  int ulcers = 0,
  int mixups = 0,
  int medErrors = 0,
  int inpatients = 40,
  int treatmentDays = 120,
  int staff = 18,
  int workingStaff = 12,
  int beds = 30,
  int reportDays = 9,
  bool hasData = true,
}) {
  return {
    'departmentId': id,
    'departmentName': name,
    'falls': falls,
    'newPressureUlcers': ulcers,
    'idMixups': mixups,
    'medicationErrors': medErrors,
    'inpatients': inpatients,
    'inpatientTreatmentDays': treatmentDays,
    'totalStaff': staff,
    'workingStaff': workingStaff,
    'actualBeds': beds,
    'reportDays': reportDays,
    'hasData': hasData,
    'fallRate': hasData ? 1.25 : null,
    'fallRateLabel': hasData ? '1.25%' : 'Chưa đủ dữ liệu',
    'fallFrequency': hasData ? 0.83 : null,
    'fallFrequencyLabel': hasData
        ? '0.83 lượt té ngã/1.000 ngày điều trị'
        : 'Chưa đủ dữ liệu',
    'pressureUlcerRateLabel': hasData ? '0.00%' : 'Chưa đủ dữ liệu',
    'pressureUlcerFrequencyLabel': hasData
        ? '0.00 ca loét mắc mới/1.000 ngày điều trị'
        : 'Chưa đủ dữ liệu',
    'nurseBedRatio': hasData ? 0.41 : null,
    'nurseBedRatioLabel': hasData
        ? '0.41 điều dưỡng/người bệnh'
        : 'Chưa đủ dữ liệu',
    'idMixupFrequencyLabel': hasData
        ? '0.00 sự cố/1.000 ngày điều trị'
        : 'Chưa đủ dữ liệu',
    'medicationErrorRateLabel': hasData ? '0.00%' : 'Chưa đủ dữ liệu',
  };
}

List<Map<String, dynamic>> _trend({required int days, bool withGaps = true}) {
  return [
    for (var i = 1; i <= days; i++)
      {
        'bucketKey': '2026-09-${i.toString().padLeft(2, '0')}',
        'label': '${i.toString().padLeft(2, '0')}/09/2026',
        'hasData': !withGaps || i % 7 != 0,
        'falls': i == 5 ? 2 : 0,
        'newPressureUlcers': i == 11 ? 1 : 0,
        'idMixups': 0,
        'medicationErrors': 0,
        'fallRate': i % 7 == 0 ? null : (i % 5) * 0.35,
        'pressureUlcerRate': i % 7 == 0 ? null : (i % 4) * 0.4,
        'idMixupFrequency': i % 7 == 0 ? null : (i % 3) * 0.5,
        'medicationErrorRate': i % 7 == 0 ? null : (i % 6) * 0.2,
        'nurseBedRatio': i % 7 == 0 ? null : 0.4 + (i % 4) * 0.22,
      },
  ];
}

Map<String, dynamic> _report({
  required int deptCount,
  bool anyIncident = true,
}) {
  return {
    'reportTitle': 'Báo cáo hoạt động điều dưỡng — Tổng quan',
    'fromLabel': '01/09/2026',
    'toLabel': '30/09/2026',
    'yearMonth': '2026-09',
    'departmentName': 'Toàn viện',
    'kpi': {
      'nurseBedRatioLabel': '0.54 điều dưỡng/người bệnh',
      'fallRateLabel': '0.00%',
      'fallFrequencyLabel': '0.00 lượt té ngã/1.000 ngày điều trị',
      'inpatients': 320,
      'inpatientTreatmentDays': 1180,
      'workingStaff': 96,
      'totalStaff': 140,
      'actualBeds': 210,
    },
    'byDepartment': [
      _deptRow(
        id: 1,
        name: 'KHOA CHẨN ĐOÁN HÌNH ẢNH VÀ THĂM DÒ CHỨC NĂNG',
        falls: anyIncident ? 2 : 0,
        ulcers: anyIncident ? 1 : 0,
      ),
      for (var i = 2; i <= deptCount - 2; i++)
        _deptRow(id: i, name: 'KHOA SỐ $i'),
      _deptRow(
        id: deptCount - 1,
        name: 'KHOA CHƯA NỘP 1',
        hasData: false,
        reportDays: 0,
      ),
      _deptRow(
        id: deptCount,
        name: 'KHOA CHƯA NỘP 2',
        hasData: false,
        reportDays: 0,
      ),
    ],
    'trend': _trend(days: 30),
    'trendGranularity': 'DAY',
  };
}

class _FakeReportRepository implements NursingActivityReportRepository {
  _FakeReportRepository({this.empty = false});

  /// Kỳ chưa có khoa nào nộp báo cáo — mọi nhãn tỉ lệ là "Chưa đủ dữ liệu".
  final bool empty;

  @override
  Future<List<NursingActivityFilterDepartment>> filterDepartments() async => [
    NursingActivityFilterDepartment(id: 1, name: 'Khoa Nội - Nhi'),
    NursingActivityFilterDepartment(id: 2, name: 'Khoa Ngoại'),
  ];

  @override
  Future<NursingActivityReport> fetch(
    NursingActivityMetric metric, {
    required String yearMonth,
    int? departmentId,
  }) async {
    if (empty) {
      return NursingActivityReport(
        raw: {
          'fromLabel': '01/09/2026',
          'toLabel': '30/09/2026',
          'departmentName': 'Toàn viện',
          'kpi': {
            'nurseBedRatioLabel': 'Chưa đủ dữ liệu',
            'fallRateLabel': 'Chưa đủ dữ liệu',
            'pressureUlcerRateLabel': 'Chưa đủ dữ liệu',
            'pressureUlcerFrequencyLabel': 'Chưa đủ dữ liệu',
            'idMixupFrequencyLabel': 'Chưa đủ dữ liệu',
            'medicationErrorRateLabel': 'Chưa đủ dữ liệu',
            'fallFrequencyLabel': 'Chưa đủ dữ liệu',
          },
          'byDepartment': const [],
          'trend': const [],
        },
      );
    }
    return NursingActivityReport(raw: _report(deptCount: 13));
  }

  @override
  Future<NursingActivityDeptDetail> departmentDetail({
    required int departmentId,
    required String yearMonth,
  }) async {
    return NursingActivityDeptDetail(
      raw: {
        'reportTitle': 'Báo cáo hoạt động điều dưỡng — Tổng quan',
        'departmentName': 'KHOA CHẨN ĐOÁN HÌNH ẢNH VÀ THĂM DÒ CHỨC NĂNG',
        'fromLabel': '01/09/2026',
        'toLabel': '09/09/2026',
        'metrics': _deptRow(id: 1, name: 'KHOA CHẨN ĐOÁN HÌNH ẢNH', falls: 2),
        'dailyRows': [
          for (var i = 1; i <= 6; i++)
            {
              'reportDate': '2026-09-${i.toString().padLeft(2, '0')}',
              'reportDateLabel': '${i.toString().padLeft(2, '0')}/09/2026',
              'inpatients': 30 + i,
              'inpatientTreatmentDays': 90 + i,
              'falls': i == 3 ? 2 : 0,
              'newPressureUlcers': i == 3 ? 1 : 0,
              'idMixups': 0,
              'medicationErrors': i == 5 ? 1 : 0,
              'totalStaff': 27,
              'workingStaff': 6 + i,
              'actualBeds': 34,
            },
        ],
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<String?> readToken() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeApiClient implements ApiClient {
  @override
  UnauthorizedCallback? onUnauthorized;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _host({bool empty = false}) {
  return ProviderScope(
    overrides: [
      nursingActivityReportRepositoryProvider.overrideWithValue(
        _FakeReportRepository(empty: empty),
      ),
      authControllerProvider.overrideWith(
        (ref) => AuthController(
          ref,
          _FakeAuthRepository(),
          _FakeTokenStorage(),
          _FakeApiClient(),
        ),
      ),
    ],
    child: const MaterialApp(home: NursingActivityReportScreen()),
  );
}

/// Vùng cuộn của nội dung trang (thanh chip chỉ số cũng là một Scrollable).
Finder _pageScrollable() => find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

/// Thanh chip chỉ số cuộn ngang.
Finder _metricRail() =>
    find.byKey(const ValueKey('nursing-activity-metric-rail'));

Finder _metricRailScrollable() =>
    find.descendant(of: _metricRail(), matching: find.byType(Scrollable)).first;

Finder _metricChip(String label) =>
    find.descendant(of: _metricRail(), matching: find.text(label));

void main() {
  testWidgets('renders overview blocks on a narrow phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sự cố trong kỳ'), findsOneWidget);
    expect(find.text('Té ngã'), findsWidgets);
    expect(find.text('Nhật ký theo ngày'.toUpperCase()), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('THEO KHOA/PHÒNG'),
      250,
      scrollable: _pageScrollable(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('khoa đã nộp báo cáo'), findsOneWidget);
  });

  testWidgets('renders the trend chart on a metric tab', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      _metricChip('Loét tì đè'),
      80,
      scrollable: _metricRailScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(_metricChip('Loét tì đè'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trung bình'),
      250,
      scrollable: _pageScrollable(),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Trung bình'), findsOneWidget);
    expect(find.text('Cao nhất'), findsOneWidget);
  });

  testWidgets('opens the department detail sheet with the daily table', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final deptCard = find.text('KHOA CHẨN ĐOÁN HÌNH ẢNH VÀ THĂM DÒ CHỨC NĂNG');
    await tester.scrollUntilVisible(
      deptCard,
      250,
      scrollable: _pageScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(deptCard);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Đã nộp'), findsOneWidget);

    final sheetScrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .last;
    await tester.scrollUntilVisible(
      find.text('BẢNG THEO NGÀY'),
      250,
      scrollable: sheetScrollable,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('NGÀY GHI NHẬN SỰ CỐ'), findsOneWidget);
    expect(find.text('NGÀY'), findsOneWidget);
    expect(find.text('01/09'), findsOneWidget);

    // Chạm một dòng để mở phần chi tiết còn lại của ngày đó.
    await tester.tap(find.text('01/09'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ngày điều trị'), findsOneWidget);
  });

  // 320px là bề ngang máy Android nhỏ nhất còn dùng ở bệnh viện.
  testWidgets('renders every metric tab without layout errors', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    const tabs = [
      'Té ngã',
      'Loét tì đè',
      'ĐD/NB',
      'Nhầm NB',
      'Sai thuốc',
      'Tổng quan',
    ];
    for (final tab in tabs) {
      final chip = _metricChip(tab);
      await tester.scrollUntilVisible(
        chip,
        80,
        scrollable: _metricRailScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }
  });

  testWidgets('renders a period with no submitted report', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(empty: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chưa có số liệu khoa'), findsOneWidget);
  });

  testWidgets('opens the shared year/month grid picker', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final label = 'Tháng ${now.month.toString().padLeft(2, '0')}/${now.year}';
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chọn tháng báo cáo'), findsOneWidget);
    expect(find.text('${now.year}'), findsOneWidget);
    expect(find.text('Tháng 12'), findsOneWidget);

    // Chọn tháng 1 của năm đang xem: sheet đóng và header đổi theo.
    await tester.tap(find.text('Tháng 1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tháng 01/${now.year}'), findsOneWidget);
  });
}
