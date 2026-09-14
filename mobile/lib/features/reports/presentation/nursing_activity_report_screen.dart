import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_month_picker.dart';
import '../../../core/widgets/app_period_navigator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/list_section_title.dart';
import '../../auth/application/auth_controller.dart';
import '../data/nursing_activity_report_repository.dart';

/// Báo cáo Module A — dữ liệu đồng bộ web, UI tối ưu mobile.
class NursingActivityReportScreen extends ConsumerStatefulWidget {
  const NursingActivityReportScreen({super.key});

  @override
  ConsumerState<NursingActivityReportScreen> createState() =>
      _NursingActivityReportScreenState();
}

class _NursingActivityReportScreenState
    extends ConsumerState<NursingActivityReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  NursingActivityMetric _metric = NursingActivityMetric.overview;
  NursingActivityReport? _report;
  List<NursingActivityFilterDepartment> _departments = const [];
  int? _departmentId;
  String? _departmentName;
  bool _loading = true;
  String? _error;

  String get _yearMonth =>
      '${_month.year.toString().padLeft(4, '0')}-'
      '${_month.month.toString().padLeft(2, '0')}';

  bool get _canPickDept {
    final role = ref.read(authControllerProvider).role;
    return role == UserRole.admin || role == UserRole.headNursing;
  }

  /// Không cho đi tới tương lai: tháng sau chưa thể có báo cáo hằng ngày.
  bool get _atLatestMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (_canPickDept) {
        try {
          _departments = await ref
              .read(nursingActivityReportRepositoryProvider)
              .filterDepartments();
        } catch (_) {}
      }
      await _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await ref
          .read(nursingActivityReportRepositoryProvider)
          .fetch(_metric, yearMonth: _yearMonth, departmentId: _departmentId);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được báo cáo hoạt động điều dưỡng';
      });
    }
  }

  Future<void> _setMetric(NursingActivityMetric m) async {
    if (_metric == m) return;
    setState(() => _metric = m);
    await _load();
  }

  Future<void> _shiftMonth(int delta) async {
    if (delta > 0 && _atLatestMonth) return;
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showAppMonthPicker(
      context,
      year: _month.year,
      month: _month.month,
      title: 'Chọn tháng báo cáo',
    );
    if (picked == null || !mounted) return;
    if (picked.$1 == _month.year && picked.$2 == _month.month) return;
    setState(() => _month = DateTime(picked.$1, picked.$2));
    await _load();
  }

  Future<void> _pickDepartment() async {
    if (!_canPickDept || _departments.isEmpty) return;
    final picked = await showModalBottomSheet<_DeptPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetGrabHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    children: [
                      const AppIconBadge(
                        icon: Icons.filter_list_rounded,
                        size: 34,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phạm vi khoa/phòng',
                              style: AppTypography.style(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_departments.length} khoa trong khối điều dưỡng',
                              style: AppTypography.style(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderSoft),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _departments.length + 1,
                    separatorBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.only(left: 62),
                      child: Divider(height: 1, color: AppColors.borderSoft),
                    ),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _ScopeTile(
                          icon: Icons.account_balance_outlined,
                          color: AppColors.primary,
                          label: 'Toàn viện / toàn khối',
                          selected: _departmentId == null,
                          onTap: () =>
                              Navigator.pop(ctx, const _DeptPick.clear()),
                        );
                      }
                      final d = _departments[i - 1];
                      return _ScopeTile(
                        icon: Icons.apartment_rounded,
                        color: AppColors
                            .chartPalette[i % AppColors.chartPalette.length],
                        label: d.name,
                        selected: d.id == _departmentId,
                        onTap: () => Navigator.pop(ctx, _DeptPick.selected(d)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.cleared) {
        _departmentId = null;
        _departmentName = null;
      } else {
        _departmentId = picked.department?.id;
        _departmentName = picked.department?.name;
      }
    });
    await _load();
  }

  Future<void> _openDeptDetail(NursingActivityDeptMetrics dept) async {
    if (dept.departmentId <= 0) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      builder: (ctx) => _DeptDetailSheet(
        departmentId: dept.departmentId,
        departmentName: dept.departmentName,
        yearMonth: _yearMonth,
        metric: _metric,
      ),
    );
  }

  /// Xếp khoa có sự cố lên đầu và gom khoa chưa có số liệu xuống cuối.
  ///
  /// Toàn viện có 13 khoa mà phần lớn bằng 0; nếu đổ đều thành 13 thẻ giống hệt
  /// nhau thì không thể nhìn ra khoa nào cần chú ý.
  List<Widget> _buildDepartmentList(
    NursingActivityReport report,
    NursingActivityMetricUi ui,
  ) {
    final withData = <NursingActivityDeptMetrics>[];
    final withoutData = <NursingActivityDeptMetrics>[];
    for (final dept in report.byDepartment) {
      (dept.hasData ? withData : withoutData).add(dept);
    }

    withData.sort((a, b) {
      final byIncident = _incidentTotal(b).compareTo(_incidentTotal(a));
      if (byIncident != 0) return byIncident;
      return a.departmentName.compareTo(b.departmentName);
    });
    withoutData.sort((a, b) => a.departmentName.compareTo(b.departmentName));

    final flagged = withData.where((d) => _incidentTotal(d) > 0).length;
    final periodDays = report.trend.length;

    return [
      _DeptSummaryBar(
        total: report.byDepartment.length,
        reported: withData.length,
        flagged: flagged,
        missing: withoutData.length,
      ),
      const SizedBox(height: 10),
      for (final dept in withData)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _DeptMetricCard(
            dept: dept,
            lines: ui.deptLines,
            accent: _metric.color,
            periodDays: periodDays,
            onTap: () => _openDeptDetail(dept),
          ),
        ),
      if (withoutData.isNotEmpty) ...[
        const SizedBox(height: 4),
        _MissingDeptGroup(departments: withoutData, onOpen: _openDeptDetail),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final ui = NursingActivityMetricUi.forMetric(_metric);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppScreenHeader(
            dense: true,
            title: 'Hoạt động điều dưỡng',
            icon: Icons.monitor_heart_outlined,
            eyebrow: 'Khối Điều dưỡng',
            subtitle: 'Sự cố · nhân lực · người bệnh',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Material(
            color: AppColors.surface,
            elevation: 0,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                12,
              ),
              child: Column(
                children: [
                  AppPeriodNavigator(
                    month: _month,
                    scopeLabel: _departmentName ?? 'Toàn khối',
                    canPickScope: _canPickDept && _departments.isNotEmpty,
                    canGoForward: !_atLatestMonth,
                    onPrev: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                    onPickMonth: _pickMonth,
                    onPickScope: _pickDepartment,
                  ),
                  const SizedBox(height: 12),
                  _MetricRail(selected: _metric, onSelect: _setMetric),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _loading
                  ? const LoadingState(label: 'Đang tải báo cáo...')
                  : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Không tải được',
                          message: _error!,
                          action: FilledButton(
                            onPressed: _load,
                            child: const Text('Thử lại'),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.sm,
                        AppSpacing.page,
                        AppSpacing.xxl,
                      ),
                      children: [
                        if (report != null) ...[
                          _PeriodStrip(
                            period: '${report.fromLabel} → ${report.toLabel}',
                            scope: report.departmentName,
                            days: report.trend.length,
                            accent: _metric.color,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MetricBlocks(
                            items: [
                              for (final field in ui.kpiFields)
                                (
                                  field.$1,
                                  field.$2,
                                  report.displayKpi(field.$1),
                                ),
                            ],
                            accent: _metric.color,
                          ),
                          if (_metric == NursingActivityMetric.overview &&
                              report.trend.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            const ListSectionTitle(
                              title: 'Nhật ký theo ngày',
                              trailing: 'Sự cố · báo cáo đã nộp',
                            ),
                            const SizedBox(height: 8),
                            _IncidentCalendarCard(points: report.trend),
                          ] else if (ui.trendPrimaryKey != null &&
                              report.trend.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            const ListSectionTitle(
                              title: 'Xu hướng',
                              trailing: 'Vuốt xem tuần',
                            ),
                            const SizedBox(height: 8),
                            _TrendCard(
                              points: report.trend,
                              valueKey: ui.trendPrimaryKey!,
                              color: _metric.color,
                              unit: ui.trendPrimaryName,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          ListSectionTitle(
                            title: 'Theo khoa/phòng',
                            trailing: report.byDepartment.isEmpty
                                ? null
                                : '${report.byDepartment.length} khoa',
                          ),
                          const SizedBox(height: 8),
                          if (report.byDepartment.isEmpty)
                            const EmptyState(
                              icon: Icons.apartment_outlined,
                              title: 'Chưa có số liệu khoa',
                              message:
                                  'Chưa có báo cáo hằng ngày trong kỳ này.',
                            )
                          else
                            ..._buildDepartmentList(report, ui),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptPick {
  const _DeptPick.clear() : department = null, cleared = true;
  const _DeptPick.selected(this.department) : cleared = false;

  final NursingActivityFilterDepartment? department;
  final bool cleared;
}

// ───────────────────────────── Helpers dùng chung ─────────────────────────────

const Set<String> _incidentKeys = {
  'falls',
  'newPressureUlcers',
  'idMixups',
  'medicationErrors',
};

const Set<String> _contextKeys = {
  'inpatients',
  'outpatients',
  'inpatientTreatmentDays',
  'totalStaff',
  'workingStaff',
  'actualBeds',
};

/// Nhãn đầy đủ cho các khóa chỉ số — bảng khoa dùng nhãn rút gọn ('Ngã', 'Loét')
/// nhưng thẻ KPI và sheet chi tiết có chỗ cho tên đọc được.
const Map<String, String> _fullLabels = {
  'falls': 'Té ngã',
  'newPressureUlcers': 'Loét mới',
  'idMixups': 'Nhầm người bệnh',
  'medicationErrors': 'Sai thuốc',
  'inpatients': 'NB nội trú',
  'outpatients': 'NB ngoại trú',
  'inpatientTreatmentDays': 'Ngày điều trị',
  'totalStaff': 'Tổng nhân viên',
  'workingStaff': 'NV đi làm',
  'actualBeds': 'Giường thực kê',
  'nurseBedRatioLabel': 'ĐD/người bệnh',
  'fallRateLabel': 'Tỉ lệ té ngã',
  'fallFrequencyLabel': 'Tần suất té ngã',
  'pressureUlcerRateLabel': 'Tỉ lệ loét',
  'pressureUlcerFrequencyLabel': 'Tần suất loét',
  'idMixupFrequencyLabel': 'Tần suất nhầm NB',
  'medicationErrorRateLabel': 'Tỉ lệ sai thuốc',
};

/// Phân loại chỉ số để tô màu và xếp khối đúng ý nghĩa.
enum _KpiKind {
  /// Đếm sự cố: 0 là tốt, khác 0 là cần chú ý.
  incident,

  /// Mẫu số / bối cảnh (người bệnh, ngày nằm viện, nhân sự): trung tính.
  context,

  /// Tỉ lệ, tần suất, tỉ số: dùng màu của tab.
  rate,
}

_KpiKind _kpiKindOf(String key) {
  if (_incidentKeys.contains(key)) return _KpiKind.incident;
  if (_contextKeys.contains(key)) return _KpiKind.context;
  return _KpiKind.rate;
}

IconData _iconForKey(String key) {
  return switch (key) {
    'falls' => Icons.personal_injury_outlined,
    'newPressureUlcers' => Icons.healing_outlined,
    'idMixups' => Icons.person_search_outlined,
    'medicationErrors' => Icons.medication_outlined,
    'inpatients' => Icons.airline_seat_flat_outlined,
    'outpatients' => Icons.directions_walk_rounded,
    'inpatientTreatmentDays' => Icons.event_note_outlined,
    'totalStaff' => Icons.groups_2_outlined,
    'workingStaff' => Icons.badge_outlined,
    'actualBeds' => Icons.bed_outlined,
    'nurseBedRatioLabel' => Icons.group_work_outlined,
    'fallRateLabel' || 'pressureUlcerRateLabel' => Icons.percent_rounded,
    'medicationErrorRateLabel' => Icons.percent_rounded,
    'fallFrequencyLabel' ||
    'pressureUlcerFrequencyLabel' ||
    'idMixupFrequencyLabel' => Icons.speed_outlined,
    _ => Icons.insights_outlined,
  };
}

int _incidentTotal(NursingActivityDeptMetrics d) =>
    d.falls + d.newPressureUlcers + d.idMixups + d.medicationErrors;

int _pointIncidents(NursingActivityTrendPoint p) {
  int at(String key) => (p.raw[key] as num?)?.toInt() ?? 0;
  return at('falls') +
      at('newPressureUlcers') +
      at('idMixups') +
      at('medicationErrors');
}

bool _pointHasData(NursingActivityTrendPoint p) => p.raw['hasData'] == true;

/// "01/09/2026" → "01/09" — kỳ báo cáo gói trong một tháng nên bỏ năm.
String _shortDate(String raw) {
  final parts = raw.split('/');
  if (parts.length >= 2) return '${parts[0]}/${parts[1]}';
  return raw.length > 5 ? raw.substring(0, 5) : raw;
}

String _formatValue(double v) {
  if (v.abs() >= 100) return v.toStringAsFixed(0);
  if (v == v.roundToDouble() && v.abs() < 10) return v.toStringAsFixed(2);
  return v.toStringAsFixed(2);
}

String _formatAxis(double v) {
  if (v.abs() >= 10) return v.toStringAsFixed(0);
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

/// Bước chia trục "đẹp" (1 · 2 · 5 × 10ⁿ) để nhãn trục không lệch lẻ.
double _niceStep(double maxValue, int targetLines) {
  if (maxValue <= 0) return 1;
  final raw = maxValue / targetLines;
  final exponent = (math.log(raw) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  final normalized = raw / magnitude;
  final multiplier = normalized <= 1
      ? 1.0
      : normalized <= 2
      ? 2.0
      : normalized <= 5
      ? 5.0
      : 10.0;
  return multiplier * magnitude;
}

// ─────────────────────────────── Header controls ──────────────────────────────

/// Thanh chỉ số trên nền sáng — chip chọn mềm, không pill trắng trên teal.
class _MetricRail extends StatefulWidget {
  const _MetricRail({required this.selected, required this.onSelect});

  final NursingActivityMetric selected;
  final ValueChanged<NursingActivityMetric> onSelect;

  @override
  State<_MetricRail> createState() => _MetricRailState();
}

class _MetricRailState extends State<_MetricRail> {
  final ScrollController _controller = ScrollController();
  late final Map<NursingActivityMetric, GlobalKey> _keys = {
    for (final m in NursingActivityMetric.values) m: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant _MetricRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _keys[widget.selected]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.45,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: AppDurations.normal,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        key: const ValueKey('nursing-activity-metric-rail'),
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final (index, m) in NursingActivityMetric.values.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              _MetricChip(
                key: _keys[m],
                label: m.label,
                icon: m.icon,
                accent: m.color,
                selected: widget.selected == m,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onSelect(m);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : AppColors.surfaceMuted,
          borderRadius: AppRadius.brBase,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.35)
                : AppColors.border.withValues(alpha: 0.45),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brBase,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected ? accent : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? accent : AppColors.textSecondary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────── Khung nội dung ────────────────────────────────

/// Dải kỳ báo cáo — gọn một dòng, không lặp lại tiêu đề đã có ở header.
class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({
    required this.period,
    required this.scope,
    required this.days,
    required this.accent,
  });

  final String period;
  final String scope;
  final int days;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_outlined, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metricMuted(
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (days > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$days ngày trong kỳ',
                    style: AppTypography.style(
                      fontSize: 10.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.brPill,
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.apartment_outlined, size: 12, color: accent),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    scope,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const tone = AppColors.textTertiary;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: tone),
          const SizedBox(width: 5),
        ],
        Text(
          text.toUpperCase(),
          style: AppTypography.style(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: tone,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────── Khối chỉ số KPI ───────────────────────────────

/// Gom KPI thành ba khối có nghĩa thay vì rải đều các ô trắng giống hệt nhau:
/// bảng sự cố (đếm ca), thẻ tỉ lệ (chỉ số chất lượng), dải bối cảnh (mẫu số).
class _MetricBlocks extends StatelessWidget {
  const _MetricBlocks({
    required this.items,
    required this.accent,
    this.dense = false,
  });

  /// (key, label, giá trị đã định dạng)
  final List<(String, String, String)> items;
  final Color accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final incidents = <(String, String, String)>[];
    final rates = <(String, String, String)>[];
    final contexts = <(String, String, String)>[];
    for (final item in items) {
      switch (_kpiKindOf(item.$1)) {
        case _KpiKind.incident:
          incidents.add(item);
        case _KpiKind.rate:
          rates.add(item);
        case _KpiKind.context:
          contexts.add(item);
      }
    }

    final blocks = <Widget>[
      if (incidents.isNotEmpty) _IncidentPanel(items: incidents, dense: dense),
      if (rates.isNotEmpty) _RateRow(items: rates, accent: accent),
      if (contexts.isNotEmpty) _ContextStrip(items: contexts),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, block) in blocks.indexed) ...[
          if (index > 0) SizedBox(height: dense ? 9 : 11),
          block,
        ],
      ],
    );
  }
}

/// Bảng sự cố — một thẻ duy nhất, tiêu đề mang trạng thái chung, thân là lưới ô
/// ngăn bằng hairline. Ô có sự cố được tô nền cảnh báo nên nổi bật ngay.
class _IncidentPanel extends StatelessWidget {
  const _IncidentPanel({required this.items, this.dense = false});

  final List<(String, String, String)> items;
  final bool dense;

  int _count(String raw) => int.tryParse(raw.replaceAll('.', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, e) => sum + _count(e.$3));
    final clean = total == 0;
    final tone = clean ? AppColors.success : AppColors.error;
    final single = items.length == 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: clean ? AppColors.borderSoft : tone.withValues(alpha: 0.28),
        ),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            color: clean
                ? AppColors.surfaceAlt
                : AppColors.errorLight.withValues(alpha: 0.65),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.13),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(
                    clean
                        ? Icons.verified_user_outlined
                        : Icons.warning_amber_rounded,
                    size: 15,
                    color: tone,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Sự cố trong kỳ',
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                _TonePill(
                  label: clean ? 'An toàn' : '$total ca',
                  color: clean ? AppColors.successDark : AppColors.errorText,
                  background: clean
                      ? AppColors.successLight
                      : AppColors.errorLight,
                  icon: clean
                      ? Icons.check_rounded
                      : Icons.priority_high_rounded,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          if (single)
            _IncidentCell(
              item: items.first,
              hero: true,
              count: _count(items.first.$3),
            )
          else
            for (var row = 0; row < (items.length + 1) ~/ 2; row++) ...[
              if (row > 0)
                const Divider(height: 1, color: AppColors.borderSoft),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _IncidentCell(
                        item: items[row * 2],
                        count: _count(items[row * 2].$3),
                      ),
                    ),
                    if (row * 2 + 1 < items.length) ...[
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.borderSoft,
                      ),
                      Expanded(
                        child: _IncidentCell(
                          item: items[row * 2 + 1],
                          count: _count(items[row * 2 + 1].$3),
                        ),
                      ),
                    ] else
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _IncidentCell extends StatelessWidget {
  const _IncidentCell({
    required this.item,
    required this.count,
    this.hero = false,
  });

  final (String, String, String) item;
  final int count;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final alert = count > 0;
    final hasData = item.$3 != '—';
    // Ô bằng 0 giữ màu chữ trung tính: dồn hết sắc đỏ cho ô thật sự có sự cố
    // nên mắt bắt được ngay khoa/chỉ số cần xử lý.
    final valueTone = !hasData
        ? AppColors.textTertiary
        : alert
        ? AppColors.error
        : AppColors.textPrimary;
    final iconTone = alert ? AppColors.error : AppColors.textTertiary;

    return Container(
      padding: EdgeInsets.fromLTRB(12, hero ? 14 : 11, 12, hero ? 14 : 11),
      color: alert ? AppColors.errorLight.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          Container(
            width: hero ? 42 : 30,
            height: hero ? 42 : 30,
            decoration: BoxDecoration(
              color: iconTone.withValues(alpha: alert ? 0.13 : 0.09),
              borderRadius: BorderRadius.circular(hero ? 14 : 10),
            ),
            child: Icon(
              _iconForKey(item.$1),
              size: hero ? 21 : 16,
              color: iconTone,
            ),
          ),
          SizedBox(width: hero ? 13 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullLabels[item.$1] ?? item.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: hero ? 12 : 11,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: hero ? 5 : 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      item.$3,
                      style: AppTypography.metric(
                        fontSize: hero ? 28 : 20,
                        color: valueTone,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasData) ...[
                      const SizedBox(width: 5),
                      Text(
                        'ca',
                        style: AppTypography.style(
                          fontSize: hero ? 11.5 : 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (alert)
            const Icon(
              Icons.arrow_outward_rounded,
              size: 15,
              color: AppColors.error,
            ),
        ],
      ),
    );
  }
}

/// Thẻ tỉ lệ — chỉ số chất lượng của tab, tô theo màu tab và luôn kèm đơn vị.
class _RateRow extends StatelessWidget {
  const _RateRow({required this.items, required this.accent});

  final List<(String, String, String)> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return _RateTile(item: items.first, accent: accent, hero: true);
    }
    return Column(
      children: [
        for (var row = 0; row < (items.length + 1) ~/ 2; row++) ...[
          if (row > 0) const SizedBox(height: 9),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _RateTile(item: items[row * 2], accent: accent),
                ),
                if (row * 2 + 1 < items.length) ...[
                  const SizedBox(width: 9),
                  Expanded(
                    child: _RateTile(item: items[row * 2 + 1], accent: accent),
                  ),
                ] else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.item,
    required this.accent,
    this.hero = false,
  });

  final (String, String, String) item;
  final Color accent;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final parts = MetricLabelParts.parse(item.$3);
    final tone = parts.hasData ? accent : AppColors.textTertiary;
    final label = _fullLabels[item.$1] ?? item.$2;

    final decoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      border: Border.all(
        color: parts.hasData
            ? accent.withValues(alpha: 0.2)
            : AppColors.borderSoft,
      ),
      boxShadow: AppShadows.card,
    );

    if (hero) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: decoration,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: AppRadius.brPaper,
              ),
              child: Icon(_iconForKey(item.$1), size: 22, color: tone),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        parts.value,
                        style: AppTypography.metric(
                          fontSize: parts.hasData ? 28 : 15,
                          color: tone,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (parts.unit != null) ...[
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            parts.unit!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 10.5,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brChip,
                ),
                child: Icon(_iconForKey(item.$1), size: 14, color: tone),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              parts.value,
              maxLines: 1,
              style: AppTypography.metric(
                fontSize: parts.hasData ? 23 : 13,
                color: tone,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (parts.unit != null) ...[
            const SizedBox(height: 3),
            Text(
              parts.unit!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dải bối cảnh — mẫu số của mọi tỉ lệ (người bệnh, ngày điều trị, nhân sự).
/// Trung tính, nhỏ hơn khối trên để không tranh chỗ với chỉ số chính.
class _ContextStrip extends StatelessWidget {
  const _ContextStrip({required this.items});

  final List<(String, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniLabel('Bối cảnh kỳ báo cáo', icon: Icons.layers_outlined),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, item) in items.indexed) ...[
                  if (index > 0)
                    const VerticalDivider(
                      width: 17,
                      thickness: 1,
                      color: AppColors.borderSoft,
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _iconForKey(item.$1),
                              size: 12,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _fullLabels[item.$1] ?? item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.$3,
                            maxLines: 1,
                            style: AppTypography.metric(
                              fontSize: 17,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TonePill extends StatelessWidget {
  const _TonePill({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Biểu đồ ─────────────────────────────────────

DateTime? _parseTrendDate(String raw) {
  final parts = raw.split('/');
  if (parts.length < 2) return null;
  final day = int.tryParse(parts[0].trim());
  final month = int.tryParse(parts[1].trim());
  final year = parts.length >= 3
      ? int.tryParse(parts[2].trim())
      : DateTime.now().year;
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

const _kWeekdayAxis = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

DateTime _mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _formatDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Biểu đồ xu hướng theo tuần lịch (T2→CN) — mặc định tuần này, vuốt xem tuần khác.
///
/// Chạm một điểm để xem chi tiết ngày; thả tay thì ẩn.
class _TrendCard extends StatefulWidget {
  const _TrendCard({
    required this.points,
    required this.valueKey,
    required this.color,
    required this.unit,
  });

  final List<NursingActivityTrendPoint> points;
  final String valueKey;
  final Color color;
  final String? unit;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  late final PageController _pageController;
  late List<_TrendWeek> _weeks;
  late int _weekIndex;
  _TrendDayFocus? _focus;

  @override
  void initState() {
    super.initState();
    _weeks = _TrendWeek.fromPoints(widget.points, widget.valueKey);
    _weekIndex = _defaultWeekIndex(_weeks);
    _pageController = PageController(initialPage: _weekIndex);
  }

  @override
  void didUpdateWidget(covariant _TrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.valueKey != widget.valueKey) {
      _weeks = _TrendWeek.fromPoints(widget.points, widget.valueKey);
      final next = _defaultWeekIndex(_weeks).clamp(0, _weeks.length - 1);
      _weekIndex = next;
      _focus = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_weekIndex);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _defaultWeekIndex(List<_TrendWeek> weeks) {
    if (weeks.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < weeks.length; i++) {
      for (final day in weeks[i].days) {
        final d = day.date;
        if (d != null &&
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day) {
          return i;
        }
      }
    }
    return weeks.length - 1;
  }

  void _goToWeek(int index) {
    if (index < 0 || index >= _weeks.length || index == _weekIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _weekIndex = index;
      _focus = null;
    });
    _pageController.animateToPage(
      index,
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPressDay(int weekIndex, int dayIndex, _TrendDay day) {
    if (_focus?.weekIndex == weekIndex &&
        _focus?.dayIndex == dayIndex &&
        identical(_focus?.day, day)) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _focus = _TrendDayFocus(
        weekIndex: weekIndex,
        dayIndex: dayIndex,
        day: day,
      );
    });
  }

  void _clearFocus() {
    if (_focus == null) return;
    setState(() => _focus = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_weeks.isEmpty || _weeks.every((w) => w.spots.isEmpty)) {
      return const _EmptyHintCard(
        message: 'Chưa đủ điểm dữ liệu để vẽ xu hướng.',
      );
    }

    final week = _weeks[_weekIndex.clamp(0, _weeks.length - 1)];
    final stats = week.stats;
    final latest = stats?.latest;
    final delta = stats?.delta;
    final unit = widget.unit;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        size: 15,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        unit ?? 'Giá trị',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: 8),
                      _DeltaPill(delta: delta),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    latest == null ? '—' : _formatValue(latest),
                    maxLines: 1,
                    style: AppTypography.metric(
                      fontSize: 28,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  week.isCurrentWeek
                      ? 'Giá trị cuối tuần này'
                      : 'Giá trị cuối tuần đang xem',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: _WeekNavigator(
              label: week.title,
              subtitle: week.rangeLabel,
              index: _weekIndex,
              count: _weeks.length,
              onPrev: () => _goToWeek(_weekIndex - 1),
              onNext: () => _goToWeek(_weekIndex + 1),
            ),
          ),
          SizedBox(
            height: 204,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _weeks.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() {
                  _weekIndex = i;
                  _focus = null;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 10, 2),
                  child: _WeekLineChart(
                    week: _weeks[index],
                    weekIndex: index,
                    color: widget.color,
                    focus: _focus?.weekIndex == index ? _focus : null,
                    onPressDay: _onPressDay,
                    onClearFocus: _clearFocus,
                  ),
                );
              },
            ),
          ),
          if (_focus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: _DayFocusPanel(
                focus: _focus!,
                color: widget.color,
                unit: unit,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Chạm ngày để xem · thả tay để ẩn',
                      style: AppTypography.style(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderSoft),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _TrendStat(
                      label: 'Trung bình',
                      value: stats == null ? '—' : _formatValue(stats.average),
                      color: widget.color,
                      dashed: true,
                    ),
                  ),
                  const VerticalDivider(
                    width: 13,
                    thickness: 1,
                    color: AppColors.borderSoft,
                  ),
                  Expanded(
                    child: _TrendStat(
                      label: 'Cao nhất',
                      value: stats == null ? '—' : _formatValue(stats.maxValue),
                      hint: stats?.maxLabel,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const VerticalDivider(
                    width: 13,
                    thickness: 1,
                    color: AppColors.borderSoft,
                  ),
                  Expanded(
                    child: _TrendStat(
                      label: 'Thấp nhất',
                      value: stats == null ? '—' : _formatValue(stats.minValue),
                      hint: stats == null
                          ? null
                          : '${stats.count} ngày có số liệu',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendDay {
  const _TrendDay({
    this.point,
    required this.value,
    required this.date,
    required this.weekdayLabel,
  });

  final NursingActivityTrendPoint? point;
  final double? value;
  final DateTime? date;
  final String weekdayLabel;

  String get label {
    if (point != null) return point!.label;
    if (date != null) {
      return '${_formatDayMonth(date!)}/${date!.year}';
    }
    return weekdayLabel;
  }

  bool get hasValue => value != null;
}

class _TrendWeekStats {
  const _TrendWeekStats({
    required this.average,
    required this.maxValue,
    required this.minValue,
    required this.maxLabel,
    required this.latest,
    required this.delta,
    required this.count,
  });

  final double average;
  final double maxValue;
  final double minValue;
  final String maxLabel;
  final double latest;
  final double? delta;
  final int count;
}

class _TrendWeek {
  const _TrendWeek({
    required this.days,
    required this.spots,
    required this.isCurrentWeek,
  });

  /// Luôn 7 phần tử: T2 → CN.
  final List<_TrendDay> days;
  final List<FlSpot> spots;
  final bool isCurrentWeek;

  static List<_TrendWeek> fromPoints(
    List<NursingActivityTrendPoint> points,
    String valueKey,
  ) {
    if (points.isEmpty) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = <DateTime, NursingActivityTrendPoint>{};
    DateTime? first;
    DateTime? last;

    for (final point in points) {
      final date = _parseTrendDate(point.label);
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      byDate[key] = point;
      if (first == null || key.isBefore(first)) first = key;
      if (last == null || key.isAfter(last)) last = key;
    }

    // Không parse được ngày → vẫn chia 7 ô cố định T2–CN theo thứ tự.
    if (first == null || last == null) {
      return _fallbackSequentialWeeks(points, valueKey, today);
    }

    final weeks = <_TrendWeek>[];
    var monday = _mondayOf(first);
    final endMonday = _mondayOf(last);

    while (!monday.isAfter(endMonday)) {
      final days = <_TrendDay>[];
      final spots = <FlSpot>[];
      var containsToday = false;

      for (var i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final point = byDate[date];
        double? value;
        if (point != null && _pointHasData(point)) {
          final raw = point.primary(valueKey);
          if (raw != null) value = raw.toDouble();
        }
        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          containsToday = true;
        }
        days.add(
          _TrendDay(
            point: point,
            value: value,
            date: date,
            weekdayLabel: _kWeekdayAxis[i],
          ),
        );
        if (value != null) {
          spots.add(FlSpot(i.toDouble(), value));
        }
      }

      weeks.add(
        _TrendWeek(days: days, spots: spots, isCurrentWeek: containsToday),
      );
      monday = monday.add(const Duration(days: 7));
    }
    return weeks;
  }

  static List<_TrendWeek> _fallbackSequentialWeeks(
    List<NursingActivityTrendPoint> points,
    String valueKey,
    DateTime today,
  ) {
    final weeks = <_TrendWeek>[];
    for (var start = 0; start < points.length; start += 7) {
      final end = math.min(start + 7, points.length);
      final slice = points.sublist(start, end);
      final days = <_TrendDay>[];
      final spots = <FlSpot>[];
      var containsToday = false;

      for (var i = 0; i < 7; i++) {
        final point = i < slice.length ? slice[i] : null;
        final date = point == null ? null : _parseTrendDate(point.label);
        double? value;
        if (point != null && _pointHasData(point)) {
          final raw = point.primary(valueKey);
          if (raw != null) value = raw.toDouble();
        }
        if (date != null &&
            date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          containsToday = true;
        }
        days.add(
          _TrendDay(
            point: point,
            value: value,
            date: date,
            weekdayLabel: _kWeekdayAxis[i],
          ),
        );
        if (value != null) {
          spots.add(FlSpot(i.toDouble(), value));
        }
      }

      weeks.add(
        _TrendWeek(days: days, spots: spots, isCurrentWeek: containsToday),
      );
    }
    return weeks;
  }

  String get title {
    if (isCurrentWeek) return 'Tuần này';
    final first = days.first.date;
    if (first == null) return 'Tuần';
    final weekOfMonth = ((first.day - 1) ~/ 7) + 1;
    return 'Tuần $weekOfMonth';
  }

  String get rangeLabel {
    final mon = days.first.date;
    final sun = days.last.date;
    if (mon != null && sun != null) {
      return '${_formatDayMonth(mon)} – ${_formatDayMonth(sun)}';
    }
    final withPoint = days.where((d) => d.point != null).toList();
    if (withPoint.isEmpty) return '';
    final a = _shortDate(withPoint.first.label);
    final b = _shortDate(withPoint.last.label);
    return a == b ? a : '$a – $b';
  }

  _TrendWeekStats? get stats {
    if (spots.isEmpty) return null;
    final values = spots.map((s) => s.y).toList();
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final average = values.reduce((a, b) => a + b) / values.length;
    final maxSpot = spots.firstWhere((s) => s.y == maxValue);
    final maxDay = days[maxSpot.x.round().clamp(0, days.length - 1)];
    final latest = values.last;
    final previous = values.length > 1 ? values[values.length - 2] : null;
    return _TrendWeekStats(
      average: average,
      maxValue: maxValue,
      minValue: minValue,
      maxLabel: _shortDate(maxDay.label),
      latest: latest,
      delta: previous == null ? null : latest - previous,
      count: values.length,
    );
  }
}

class _TrendDayFocus {
  const _TrendDayFocus({
    required this.weekIndex,
    required this.dayIndex,
    required this.day,
  });

  final int weekIndex;
  final int dayIndex;
  final _TrendDay day;
}

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.label,
    required this.subtitle,
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final String subtitle;
  final int index;
  final int count;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canPrev = index > 0;
    final canNext = index < count - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brPaper,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _WeekArrow(
                icon: Icons.chevron_left_rounded,
                enabled: canPrev,
                onTap: onPrev,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.style(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _WeekArrow(
                icon: Icons.chevron_right_rounded,
                enabled: canNext,
                onTap: onNext,
              ),
            ],
          ),
          if (count > 1) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    width: i == index ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.primary : AppColors.border,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekArrow extends StatelessWidget {
  const _WeekArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: Colors.white,
        borderRadius: AppRadius.brBase,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.brBase,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 22, color: AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}

class _WeekLineChart extends StatelessWidget {
  const _WeekLineChart({
    required this.week,
    required this.weekIndex,
    required this.color,
    required this.focus,
    required this.onPressDay,
    required this.onClearFocus,
  });

  final _TrendWeek week;
  final int weekIndex;
  final Color color;
  final _TrendDayFocus? focus;
  final void Function(int weekIndex, int dayIndex, _TrendDay day) onPressDay;
  final VoidCallback onClearFocus;

  @override
  Widget build(BuildContext context) {
    final spots = week.spots;
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'Tuần này chưa có số liệu',
          style: AppTypography.style(
            fontSize: 12.5,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final values = spots.map((s) => s.y).toList();
    final maxValue = values.reduce(math.max);
    final flat = maxValue <= 0;
    final step = _niceStep(flat ? 1 : maxValue, 3);
    final maxY = flat ? 1.0 : (maxValue / step).ceil() * step + step * 0.35;
    final avg = values.reduce((a, b) => a + b) / values.length;
    final focusedDay = focus?.dayIndex;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        // Nới trục X để nhãn T2 / CN không dính mép card.
        minX: -0.45,
        maxX: 6.45,
        clipData: const FlClipData.none(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: step,
          verticalInterval: 1,
          checkToShowVerticalLine: (value) {
            final i = value.round();
            return (value - i).abs() < 0.01 && i >= 0 && i <= 6;
          },
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.borderSoft.withValues(alpha: 0.9),
            strokeWidth: 1,
            dashArray: [3, 5],
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: AppColors.borderSoft.withValues(alpha: 0.45),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: step,
              getTitlesWidget: (value, meta) {
                if (value > maxY - step * 0.45) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    _formatAxis(value),
                    maxLines: 1,
                    style: AppTypography.metricMuted(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 0.01 ||
                    index < 0 ||
                    index >= _kWeekdayAxis.length) {
                  return const SizedBox.shrink();
                }
                final selected = focusedDay == index;
                final hasData =
                    index < week.days.length && week.days[index].hasValue;
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    _kWeekdayAxis[index],
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      color: selected
                          ? color
                          : hasData
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (!flat)
              HorizontalLine(
                y: avg,
                color: color.withValues(alpha: 0.35),
                strokeWidth: 1.2,
                dashArray: [5, 4],
              ),
          ],
          verticalLines: [
            if (focusedDay != null)
              VerticalLine(
                x: focusedDay.toDouble(),
                color: color.withValues(alpha: 0.35),
                strokeWidth: 1.4,
                dashArray: [4, 3],
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchSpotThreshold: 32,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 0,
            getTooltipItems: (touched) =>
                List<LineTooltipItem?>.filled(touched.length, null),
          ),
          touchCallback: (event, response) {
            final spot = response?.lineBarSpots?.firstOrNull;
            final pressing =
                event is FlTapDownEvent ||
                event is FlPanStartEvent ||
                event is FlPanUpdateEvent ||
                event is FlLongPressStart ||
                event is FlLongPressMoveUpdate;
            final released =
                event is FlTapUpEvent ||
                event is FlTapCancelEvent ||
                event is FlPanEndEvent ||
                event is FlLongPressEnd;

            if (pressing && spot != null) {
              final dayIndex = spot.x.round().clamp(0, week.days.length - 1);
              final day = week.days[dayIndex];
              if (!day.hasValue) return;
              onPressDay(weekIndex, dayIndex, day);
              return;
            }
            if (released) {
              onClearFocus();
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            preventCurveOverShooting: true,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [color.withValues(alpha: 0.72), color],
            ),
            barWidth: 3,
            shadow: Shadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                final selected = focusedDay == spot.x.round();
                final isLast = index == spots.length - 1;
                return FlDotCirclePainter(
                  radius: selected ? 6.5 : (isLast ? 4.5 : 3.5),
                  color: selected || isLast ? color : AppColors.surface,
                  strokeWidth: selected ? 0 : 2.2,
                  strokeColor: color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: AppDurations.fast,
    );
  }
}

class _DayFocusPanel extends StatelessWidget {
  const _DayFocusPanel({
    required this.focus,
    required this.color,
    required this.unit,
  });

  final _TrendDayFocus focus;
  final Color color;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final day = focus.day;
    final date = day.date;
    final weekday = day.weekdayLabel;

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: AppRadius.brPaper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.brBase,
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday,
                    style: AppTypography.style(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                  ),
                  Text(
                    date != null
                        ? date.day.toString().padLeft(2, '0')
                        : _shortDate(day.label).split('/').first,
                    style: AppTypography.metric(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.label,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unit ?? 'Giá trị trong ngày',
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              day.value == null ? '—' : _formatValue(day.value!),
              style: AppTypography.metric(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendStat extends StatelessWidget {
  const _TrendStat({
    required this.label,
    required this.value,
    required this.color,
    this.hint,
    this.dashed = false,
  });

  final String label;
  final String value;
  final String? hint;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (dashed) ...[
              SizedBox(
                width: 10,
                height: 8,
                child: CustomPaint(painter: _DashPainter(color: color)),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: AppTypography.metric(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 3, size.width), y),
        paint,
      );
      x += 5;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final flat = delta.abs() < 0.005;
    final color = flat
        ? AppColors.textTertiary
        : delta > 0
        ? AppColors.error
        : AppColors.success;
    final icon = flat
        ? Icons.remove_rounded
        : delta > 0
        ? Icons.north_east_rounded
        : Icons.south_east_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            flat ? 'Không đổi' : _formatValue(delta.abs()),
            style: AppTypography.metric(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lịch sự cố theo ngày cho tab Tổng quan.
///
/// Tab này không có một chỉ số đơn nào để vẽ đường, nên thay vì bỏ trống ta
/// hiển thị dải ô ngày: xanh = không sự cố, đỏ = có sự cố, xám = chưa nộp báo
/// cáo. Nhìn một lần là thấy cả mức tuân thủ báo cáo lẫn ngày cần xem lại.
class _IncidentCalendarCard extends StatefulWidget {
  const _IncidentCalendarCard({required this.points});

  final List<NursingActivityTrendPoint> points;

  @override
  State<_IncidentCalendarCard> createState() => _IncidentCalendarCardState();
}

class _IncidentCalendarCardState extends State<_IncidentCalendarCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final reported = widget.points.where(_pointHasData).length;
    final flaggedDays = widget.points
        .where((p) => _pointIncidents(p) > 0)
        .length;
    final totalIncidents = widget.points.fold<int>(
      0,
      (sum, p) => sum + _pointIncidents(p),
    );
    final selected = _selected != null && _selected! < widget.points.length
        ? widget.points[_selected!]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selected == null
                      ? (flaggedDays == 0
                            ? 'Không ngày nào ghi nhận sự cố'
                            : '$flaggedDays ngày có sự cố · $totalIncidents ca')
                      : '${selected.label} · ${_pointHasData(selected) ? '${_pointIncidents(selected)} sự cố' : 'chưa nộp báo cáo'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TonePill(
                label: '$reported/${widget.points.length} ngày',
                color: AppColors.primaryDark,
                background: AppColors.primaryContainer,
                icon: Icons.fact_check_outlined,
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 3.0;
              final count = widget.points.length;
              final width = count == 0
                  ? 0.0
                  : (c.maxWidth - gap * (count - 1)) / count;
              return Row(
                children: [
                  for (final (index, point) in widget.points.indexed) ...[
                    if (index > 0) const SizedBox(width: gap),
                    _CalendarCell(
                      width: width,
                      point: point,
                      selected: _selected == index,
                      onTap: () => setState(
                        () => _selected = _selected == index ? null : index,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                widget.points.isEmpty
                    ? ''
                    : _shortDate(widget.points.first.label),
                style: AppTypography.metricMuted(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),
              Text(
                widget.points.isEmpty
                    ? ''
                    : _shortDate(widget.points.last.label),
                style: AppTypography.metricMuted(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: 9),
          // Wrap thay Row: ba nhãn chú giải vượt bề ngang máy 360px.
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(color: AppColors.success, label: 'Không sự cố'),
              _LegendDot(color: AppColors.error, label: 'Có sự cố'),
              _LegendDot(
                color: AppColors.surfaceHighest,
                label: 'Chưa nộp',
                outlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.width,
    required this.point,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final NursingActivityTrendPoint point;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = _pointHasData(point);
    final incidents = _pointIncidents(point);
    final Color color;
    if (!hasData) {
      color = AppColors.surfaceHighest;
    } else if (incidents == 0) {
      color = AppColors.success.withValues(alpha: 0.42);
    } else {
      color = AppColors.error.withValues(
        alpha: (0.55 + 0.15 * incidents).clamp(0.55, 1.0),
      );
    }

    return Semantics(
      label:
          '${point.label}: ${hasData ? '$incidents sự cố' : 'chưa nộp báo cáo'}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: math.max(width, 2),
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: selected
                ? Border.all(color: AppColors.textPrimary, width: 1.4)
                : null,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: outlined ? color : color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
            border: outlined ? Border.all(color: AppColors.borderSoft) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _EmptyHintCard extends StatelessWidget {
  const _EmptyHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          const Icon(
            Icons.show_chart_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Danh sách khoa/phòng ───────────────────────────

/// Dòng tóm tắt trước danh sách khoa — trả lời ngay "có gì cần chú ý không".
class _DeptSummaryBar extends StatelessWidget {
  const _DeptSummaryBar({
    required this.total,
    required this.reported,
    required this.flagged,
    required this.missing,
  });

  final int total;
  final int reported;
  final int flagged;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final clean = flagged == 0;
    final tone = clean ? AppColors.successDark : AppColors.errorText;
    final accent = clean ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: clean ? AppColors.successLight : AppColors.errorLight,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: AppRadius.brBase,
            ),
            child: Icon(
              clean ? Icons.verified_rounded : Icons.warning_amber_rounded,
              size: 18,
              color: tone,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clean
                      ? 'Không khoa nào ghi nhận sự cố'
                      : '$flagged/$total khoa có sự cố cần xem',
                  maxLines: 2,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: tone,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$reported/$total khoa đã nộp báo cáo trong kỳ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tone.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (missing > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.85),
                borderRadius: AppRadius.brPill,
              ),
              child: Column(
                children: [
                  Text(
                    '$missing',
                    style: AppTypography.metric(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'chưa nộp',
                    style: AppTypography.style(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeptMetricCard extends StatelessWidget {
  const _DeptMetricCard({
    required this.dept,
    required this.lines,
    required this.accent,
    required this.periodDays,
    required this.onTap,
  });

  final NursingActivityDeptMetrics dept;
  final List<(String, String)> lines;
  final Color accent;
  final int periodDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final counters = <(String label, String value, bool alert)>[];
    final ratios = <(String, MetricLabelParts)>[];

    for (final line in lines) {
      final raw = NursingActivityMetricUi.deptValue(dept, line.$1);
      if (_incidentKeys.contains(line.$1) ||
          (int.tryParse(raw) != null && !line.$1.endsWith('Label'))) {
        final count = int.tryParse(raw) ?? 0;
        counters.add((
          line.$2,
          raw,
          _incidentKeys.contains(line.$1) && count > 0,
        ));
      } else {
        ratios.add((line.$2, MetricLabelParts.parse(raw)));
      }
    }

    final incidentTotal = _incidentTotal(dept);
    final alert = incidentTotal > 0;
    final coverage = periodDays > 0
        ? (dept.reportDays / periodDays).clamp(0.0, 1.0)
        : null;

    return AppCard(
      onTap: onTap,
      accentColor: alert ? AppColors.error : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (alert ? AppColors.error : accent).withValues(
                    alpha: 0.11,
                  ),
                  borderRadius: AppRadius.brBase,
                ),
                child: Icon(
                  alert
                      ? Icons.report_gmailerrorred_rounded
                      : Icons.apartment_rounded,
                  size: 17,
                  color: alert ? AppColors.error : accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dept.departmentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (dept.reportDays > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        periodDays > 0
                            ? '${dept.reportDays}/$periodDays ngày có báo cáo'
                            : '${dept.reportDays} ngày có báo cáo',
                        style: AppTypography.style(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (alert) _IncidentTag(count: incidentTotal),
              const Padding(
                padding: EdgeInsets.only(left: 2, top: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (coverage != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: coverage,
                minHeight: 3,
                backgroundColor: AppColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(
                  (alert ? AppColors.error : accent).withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
          // Từ hai ô đếm trở lên mới xếp thành hàng chia cột; một ô đơn lẻ
          // căn giữa cả bề ngang trông trống, nên gộp vào hàng chip bên dưới.
          if (counters.length > 1) ...[
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, counter) in counters.indexed) ...[
                    if (index > 0)
                      const VerticalDivider(
                        width: 9,
                        thickness: 1,
                        color: AppColors.borderSoft,
                      ),
                    Expanded(
                      child: _CounterCell(
                        label: counter.$1,
                        value: counter.$2,
                        alert: counter.$3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (ratios.isNotEmpty || counters.length == 1) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (counters.length == 1)
                  _CountPill(
                    label: counters.first.$1,
                    value: counters.first.$2,
                    alert: counters.first.$3,
                  ),
                for (final ratio in ratios)
                  _RatioPill(
                    label: ratio.$1,
                    parts: ratio.$2,
                    color: ratio.$2.hasData ? accent : AppColors.textTertiary,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ô đếm trong thẻ khoa — số 0 làm nhạt để chỉ số khác 0 nổi lên trước.
class _CounterCell extends StatelessWidget {
  const _CounterCell({
    required this.label,
    required this.value,
    required this.alert,
  });

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final zero = value == '0';
    final color = alert
        ? AppColors.error
        : zero
        ? AppColors.textTertiary
        : AppColors.textPrimary;

    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: AppTypography.metric(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.style(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: alert ? AppColors.errorText : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Ô đếm dạng chip — dùng khi tab chỉ có một chỉ số đếm duy nhất.
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.value,
    required this.alert,
  });

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.error : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: alert ? AppColors.errorLight : AppColors.surfaceAlt,
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: alert
              ? AppColors.error.withValues(alpha: 0.22)
              : AppColors.borderSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: alert ? AppColors.errorText : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTypography.metric(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioPill extends StatelessWidget {
  const _RatioPill({
    required this.label,
    required this.parts,
    required this.color,
  });

  final String label;
  final MetricLabelParts parts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            parts.value,
            style: AppTypography.metric(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhóm khoa chưa có báo cáo — gộp lại, mặc định thu gọn để không lấp danh sách.
class _MissingDeptGroup extends StatefulWidget {
  const _MissingDeptGroup({required this.departments, required this.onOpen});

  final List<NursingActivityDeptMetrics> departments;
  final ValueChanged<NursingActivityDeptMetrics> onOpen;

  @override
  State<_MissingDeptGroup> createState() => _MissingDeptGroupState();
}

class _MissingDeptGroupState extends State<_MissingDeptGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadius.brBase,
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: const Icon(
                        Icons.inbox_outlined,
                        size: 17,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.departments.length} khoa chưa có số liệu',
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chưa nộp báo cáo hằng ngày trong kỳ',
                            style: AppTypography.style(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: AppDurations.fast,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                for (final dept in widget.departments) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 13),
                    child: Divider(height: 1, color: AppColors.borderSoft),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onOpen(dept),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dept.departmentName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 19,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentTag extends StatelessWidget {
  const _IncidentTag({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: AppColors.errorText,
          ),
          const SizedBox(width: 4),
          Text(
            '$count sự cố',
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.errorText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetGrabHandle extends StatelessWidget {
  const _SheetGrabHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderSoft,
            borderRadius: AppRadius.brPill,
          ),
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.actionSelected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Sheet chi tiết theo khoa ─────────────────────────

/// Một dòng ngày trong sheet chi tiết.
class _DailyRow {
  _DailyRow(this.raw);
  final Map<String, dynamic> raw;

  int _int(String key) => (raw[key] as num?)?.toInt() ?? 0;

  String get dateLabel =>
      raw['reportDateLabel'] as String? ?? raw['reportDate'] as String? ?? '—';
  String get isoDate => raw['reportDate'] as String? ?? '';
  int get falls => _int('falls');
  int get pressureUlcers => _int('newPressureUlcers');
  int get idMixups => _int('idMixups');
  int get medicationErrors => _int('medicationErrors');
  int get inpatients => _int('inpatients');
  int get treatmentDays => _int('inpatientTreatmentDays');
  int get totalStaff => _int('totalStaff');
  int get workingStaff => _int('workingStaff');
  int get actualBeds => _int('actualBeds');
  int get incidents => falls + pressureUlcers + idMixups + medicationErrors;
}

class _DeptDetailSheet extends ConsumerStatefulWidget {
  const _DeptDetailSheet({
    required this.departmentId,
    required this.departmentName,
    required this.yearMonth,
    required this.metric,
  });

  final int departmentId;
  final String departmentName;
  final String yearMonth;
  final NursingActivityMetric metric;

  @override
  ConsumerState<_DeptDetailSheet> createState() => _DeptDetailSheetState();
}

class _DeptDetailSheetState extends ConsumerState<_DeptDetailSheet> {
  NursingActivityDeptDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref
          .read(nursingActivityReportRepositoryProvider)
          .departmentDetail(
            departmentId: widget.departmentId,
            yearMonth: widget.yearMonth,
          );
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được chi tiết khoa';
      });
    }
  }

  /// "01/09/2026" → DateTime. Backend trả nhãn dd/MM/yyyy.
  static DateTime? _parseDmy(String raw) {
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  int _periodDays(NursingActivityDeptDetail detail) {
    final from = _parseDmy(detail.fromLabel);
    final to = _parseDmy(detail.toLabel);
    if (from == null || to == null) return 0;
    return to.difference(from).inDays + 1;
  }

  /// Các chỉ số hiển thị trong khối tóm tắt của sheet: sự cố + tỉ lệ của tab
  /// + bối cảnh, dùng chung component với trang chính.
  List<(String, String, String)> _summaryItems(
    NursingActivityDeptMetrics m,
    NursingActivityMetricUi ui,
  ) {
    final keys = <String>[
      ...ui.deptLines.map((e) => e.$1),
      'inpatients',
      'workingStaff',
      'actualBeds',
    ];
    final seen = <String>{};
    final out = <(String, String, String)>[];
    for (final key in keys) {
      if (!seen.add(key)) continue;
      out.add((
        key,
        _fullLabels[key] ?? key,
        NursingActivityMetricUi.deptValue(m, key),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ui = NursingActivityMetricUi.forMetric(widget.metric);
    final height = MediaQuery.sizeOf(context).height * 0.9;
    final detail = _detail;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          _SheetHeader(
            title: widget.departmentName,
            subtitle: detail == null
                ? 'Chi tiết theo ngày · ${widget.yearMonth}'
                : '${detail.fromLabel} → ${detail.toLabel}',
            color: widget.metric.color,
            icon: widget.metric.icon,
          ),
          Expanded(
            child: _loading
                ? const LoadingState(label: 'Đang tải chi tiết khoa...')
                : _error != null
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Không tải được',
                    message: _error!,
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  )
                : _buildBody(detail!, ui),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    NursingActivityDeptDetail detail,
    NursingActivityMetricUi ui,
  ) {
    final rows = detail.dailyRows.map(_DailyRow.new).toList();
    final periodDays = _periodDays(detail);
    final flagged = rows.where((r) => r.incidents > 0).toList();
    final missingDays = periodDays > rows.length ? periodDays - rows.length : 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _CoverageStrip(
          reported: rows.length,
          periodDays: periodDays,
          missing: missingDays,
          accent: widget.metric.color,
        ),
        const SizedBox(height: 12),
        _MetricBlocks(
          items: _summaryItems(detail.metrics, ui),
          accent: widget.metric.color,
          dense: true,
        ),
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: 18),
          ListSectionTitle(
            title: 'Ngày ghi nhận sự cố',
            trailing: '${flagged.length} ngày',
          ),
          const SizedBox(height: 8),
          for (final row in flagged)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FlaggedDayCard(row: row),
            ),
        ],
        const SizedBox(height: 18),
        ListSectionTitle(
          title: 'Bảng theo ngày',
          trailing: rows.isEmpty ? null : '${rows.length} dòng',
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Chưa có dòng ngày',
            message: 'Khoa chưa có báo cáo hằng ngày trong kỳ.',
          )
        else
          _DailyTable(rows: rows),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.borderSoft)),
        borderRadius: AppRadius.brSheetTop,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            AppColors.surface,
            AppColors.surface,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Column(
        children: [
          const _SheetGrabHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: AppRadius.brPaper,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metricMuted(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mức độ tuân thủ nộp báo cáo của khoa trong kỳ.
class _CoverageStrip extends StatelessWidget {
  const _CoverageStrip({
    required this.reported,
    required this.periodDays,
    required this.missing,
    required this.accent,
  });

  final int reported;
  final int periodDays;
  final int missing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ratio = periodDays > 0
        ? (reported / periodDays).clamp(0.0, 1.0)
        : 0.0;
    final full = missing == 0 && periodDays > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                full ? Icons.task_alt_rounded : Icons.pending_actions_outlined,
                size: 15,
                color: full ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  periodDays > 0
                      ? 'Đã nộp $reported/$periodDays ngày'
                      : 'Đã nộp $reported ngày báo cáo',
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (missing > 0)
                _TonePill(
                  label: 'Thiếu $missing ngày',
                  color: AppColors.warningText,
                  background: AppColors.warningLight,
                ),
            ],
          ),
          if (periodDays > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: AppColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(
                  full ? AppColors.success : accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ nổi cho ngày có sự cố — chỉ liệt kê loại sự cố thật sự xảy ra.
class _FlaggedDayCard extends StatelessWidget {
  const _FlaggedDayCard({required this.row});

  final _DailyRow row;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int)>[
      if (row.falls > 0) ('Té ngã', row.falls),
      if (row.pressureUlcers > 0) ('Loét mới', row.pressureUlcers),
      if (row.idMixups > 0) ('Nhầm NB', row.idMixups),
      if (row.medicationErrors > 0) ('Sai thuốc', row.medicationErrors),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight.withValues(alpha: 0.55),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 15,
                color: AppColors.errorText,
              ),
              const SizedBox(width: 7),
              Text(
                row.dateLabel,
                style: AppTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.errorText,
                ),
              ),
              const Spacer(),
              Text(
                '${row.incidents} ca',
                style: AppTypography.metric(
                  fontSize: 13,
                  color: AppColors.errorText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.brPill,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.$1,
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.$2}',
                        style: AppTypography.metric(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'NB nội trú ${row.inpatients} · Giường ${row.actualBeds} · NV đi làm ${row.workingStaff}',
            style: AppTypography.metricMuted(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bảng theo ngày — thay 30 thẻ giống hệt nhau bằng một bảng đọc theo cột.
///
/// Số 0 vẽ thành dấu gạch mờ để mắt chỉ dừng ở ô có số liệu; chạm vào dòng sẽ
/// mở phần chi tiết còn lại (người bệnh, ngày điều trị, nhân sự, giường).
class _DailyTable extends StatefulWidget {
  const _DailyTable({required this.rows});

  final List<_DailyRow> rows;

  @override
  State<_DailyTable> createState() => _DailyTableState();
}

class _DailyTableState extends State<_DailyTable> {
  final Set<String> _expanded = {};

  static const _columns = ['Ngã', 'Loét', 'Nhầm', 'Thuốc', 'NV'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            child: Row(
              children: [
                Expanded(
                  flex: 28,
                  child: Text(
                    'NGÀY',
                    style: AppTypography.style(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                for (final column in _columns)
                  Expanded(
                    flex: 14,
                    child: Text(
                      column.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: AppTypography.style(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          for (final (index, row) in widget.rows.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: AppColors.borderSoft),
            _DailyTableRow(
              row: row,
              expanded: _expanded.contains(row.isoDate),
              onToggle: () => setState(() {
                if (!_expanded.remove(row.isoDate)) {
                  _expanded.add(row.isoDate);
                }
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyTableRow extends StatelessWidget {
  const _DailyTableRow({
    required this.row,
    required this.expanded,
    required this.onToggle,
  });

  final _DailyRow row;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final alert = row.incidents > 0;

    return Material(
      color: alert
          ? AppColors.errorLight.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 28,
                    child: Row(
                      children: [
                        if (alert)
                          Container(
                            width: 3,
                            height: 15,
                            margin: const EdgeInsets.only(right: 7),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            _shortDate(row.dateLabel),
                            maxLines: 1,
                            style: AppTypography.metric(
                              fontSize: 12.5,
                              color: alert
                                  ? AppColors.errorText
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NumberCell(value: row.falls, incident: true),
                  _NumberCell(value: row.pressureUlcers, incident: true),
                  _NumberCell(value: row.idMixups, incident: true),
                  _NumberCell(value: row.medicationErrors, incident: true),
                  _NumberCell(value: row.workingStaff, incident: false),
                  SizedBox(
                    width: 14,
                    child: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // AnimatedSize + child rỗng khi thu gọn: bảng có thể tới 31 dòng,
            // dựng sẵn panel chi tiết cho mọi dòng là lãng phí.
            AnimatedSize(
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      width: double.infinity,
                      color: AppColors.surfaceAlt,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MiniLabel(
                            row.dateLabel,
                            icon: Icons.event_note_outlined,
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _DetailPill(
                                label: 'NB nội trú',
                                value: '${row.inpatients}',
                              ),
                              _DetailPill(
                                label: 'Ngày điều trị',
                                value: '${row.treatmentDays}',
                              ),
                              _DetailPill(
                                label: 'Giường thực kê',
                                value: '${row.actualBeds}',
                              ),
                              _DetailPill(
                                label: 'Tổng NV',
                                value: '${row.totalStaff}',
                              ),
                              _DetailPill(
                                label: 'NV đi làm',
                                value: '${row.workingStaff}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.value, required this.incident});

  final int value;
  final bool incident;

  @override
  Widget build(BuildContext context) {
    final zero = value == 0;
    return Expanded(
      flex: 14,
      child: Text(
        zero ? '·' : '$value',
        textAlign: TextAlign.center,
        maxLines: 1,
        style: AppTypography.metric(
          fontSize: zero ? 13 : 12.5,
          color: zero
              ? AppColors.textTertiary.withValues(alpha: 0.55)
              : incident
              ? AppColors.error
              : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTypography.metric(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
