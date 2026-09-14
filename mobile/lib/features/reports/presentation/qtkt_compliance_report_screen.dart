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
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/list_section_title.dart';
import '../../auth/application/auth_controller.dart';
import '../../qtkt/data/qtkt_models.dart';
import '../../qtkt/data/qtkt_repository.dart';
import '../data/qtkt_compliance_repository.dart';

/// Báo cáo tuân thủ QTKT — dữ liệu đồng bộ web, UI mobile.
class QtktComplianceReportScreen extends ConsumerStatefulWidget {
  const QtktComplianceReportScreen({super.key});

  @override
  ConsumerState<QtktComplianceReportScreen> createState() =>
      _QtktComplianceReportScreenState();
}

class _QtktComplianceReportScreenState
    extends ConsumerState<QtktComplianceReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  QtktComplianceKind _kind = QtktComplianceKind.handHygiene;
  ComplianceResultFilter _resultFilter = ComplianceResultFilter.all;
  QtktComplianceReport? _report;
  List<QtktComplianceFilterDepartment> _departments = const [];
  int? _departmentId;
  String? _departmentName;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  String get _yearMonth =>
      '${_month.year.toString().padLeft(4, '0')}-'
      '${_month.month.toString().padLeft(2, '0')}';

  bool get _canPickDept {
    final role = ref.read(authControllerProvider).role;
    return role == UserRole.admin ||
        role == UserRole.headNursing ||
        RoleGroups.isHeadDepartmentRole(role);
  }

  bool get _atLatestMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadDepartments();
      await _load();
    });
  }

  Future<void> _loadDepartments() async {
    if (!_canPickDept) return;
    try {
      _departments = await ref
          .read(qtktComplianceRepositoryProvider)
          .departments(kind: _kind);
    } catch (_) {}
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = append ? ((_report?.detailsPage ?? 0) + 1) : 0;
      final report = await ref
          .read(qtktComplianceRepositoryProvider)
          .fetch(
            _kind,
            yearMonth: _yearMonth,
            departmentId: _departmentId,
            resultFilter: _resultFilter,
            page: page,
          );
      if (!mounted) return;
      if (append && _report != null) {
        final merged = Map<String, dynamic>.from(report.raw);
        final oldDetails = _report!.raw['details'];
        final newDetails = report.raw['details'];
        if (oldDetails is Map && newDetails is Map) {
          final oldItems = (oldDetails['items'] as List?) ?? const [];
          final newItems = (newDetails['items'] as List?) ?? const [];
          merged['details'] = {
            ...newDetails,
            'items': [...oldItems, ...newItems],
          };
        }
        setState(() {
          _report = QtktComplianceReport(raw: merged);
          _loadingMore = false;
        });
      } else {
        setState(() {
          _report = report;
          _loading = false;
          _loadingMore = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Không tải được báo cáo tuân thủ QTKT';
      });
    }
  }

  Future<void> _setKind(QtktComplianceKind kind) async {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _departmentId = null;
      _departmentName = null;
    });
    await _loadDepartments();
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
    if (!_canPickDept) return;
    final picked = await showModalBottomSheet<_ComplianceDeptPick>(
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
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSoft,
                    borderRadius: AppRadius.brPill,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Lọc theo khoa',
                      style: AppTypography.style(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Toàn khối'),
                  trailing: _departmentId == null
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () =>
                      Navigator.pop(ctx, const _ComplianceDeptPick.clear()),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _departments.length,
                    itemBuilder: (_, i) {
                      final d = _departments[i];
                      return ListTile(
                        title: Text(d.name),
                        trailing: d.id == _departmentId
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () =>
                            Navigator.pop(ctx, _ComplianceDeptPick.selected(d)),
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

  Future<void> _openBucketDetails(
    ComplianceBucket bucket, {
    required _BucketKind kind,
  }) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      builder: (ctx) => _TicketListSheet(
        title: bucket.departmentName,
        subtitle: switch (kind) {
          _BucketKind.department => 'Phiếu theo khoa/phòng',
          _BucketKind.context => 'Phiếu theo ngữ cảnh',
          _BucketKind.procedure => 'Phiếu theo quy trình',
        },
        rateLabel: bucket.rateLabel,
        passed: bucket.passed,
        failed: bucket.failed,
        total: bucket.total,
        kind: _kind,
        yearMonth: _yearMonth,
        departmentId: kind == _BucketKind.department
            ? bucket.departmentId
            : _departmentId,
        procedureCode: kind == _BucketKind.procedure
            ? bucket.procedureCode
            : null,
        checkContextCode: kind == _BucketKind.context
            ? bucket.checkContextCode
            : null,
        checkContextLabel: kind == _BucketKind.context
            ? bucket.checkContextLabel
            : null,
        onOpenTicket: (row) => _openTicketDetail(row),
      ),
    );
  }

  Future<void> _openTicketDetail(ComplianceDetailRow row) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      builder: (ctx) => _TicketDetailSheet(evaluationId: row.id, preview: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppScreenHeader(
            dense: true,
            title: 'Tuân thủ QTKT',
            icon: Icons.health_and_safety_outlined,
            eyebrow: 'Báo cáo chất lượng',
            subtitle: 'Vệ sinh tay · quy trình · GDSK',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Material(
            color: AppColors.surface,
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
                    canPickScope: _canPickDept,
                    canGoForward: !_atLatestMonth,
                    onPrev: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                    onPickMonth: _pickMonth,
                    onPickScope: _pickDepartment,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: QtktComplianceKind.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final k = QtktComplianceKind.values[i];
                        return _KindChip(
                          label: k.label,
                          selected: _kind == k,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _setKind(k);
                          },
                        );
                      },
                    ),
                  ),
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
                          _KpiHero(report: report),
                          if (report.formulaNote.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              report.formulaNote,
                              style: AppTypography.body(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                          if (report.trend.any((t) => t.hasData)) ...[
                            const SizedBox(height: AppSpacing.lg),
                            const ListSectionTitle(
                              title: 'Xu hướng',
                              trailing: 'Vuốt xem tuần',
                            ),
                            const SizedBox(height: 8),
                            _ComplianceTrendCard(points: report.trend),
                          ],
                          if (report.byDepartment.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            ListSectionTitle(
                              title: 'Theo khoa/phòng',
                              trailing: '${report.byDepartment.length}',
                            ),
                            const SizedBox(height: 8),
                            for (final d in report.byDepartment)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BucketCard(
                                  bucket: d,
                                  onTap: () => _openBucketDetails(
                                    d,
                                    kind: _BucketKind.department,
                                  ),
                                ),
                              ),
                          ],
                          if (report.byCheckContext.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            const ListSectionTitle(title: 'Theo ngữ cảnh'),
                            const SizedBox(height: 8),
                            for (final d in report.byCheckContext)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BucketCard(
                                  bucket: d,
                                  onTap: () => _openBucketDetails(
                                    d,
                                    kind: _BucketKind.context,
                                  ),
                                ),
                              ),
                          ],
                          if (report.byProcedure.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            const ListSectionTitle(title: 'Theo quy trình'),
                            const SizedBox(height: 8),
                            for (final d in report.byProcedure)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BucketCard(
                                  bucket: d,
                                  onTap: () => _openBucketDetails(
                                    d,
                                    kind: _BucketKind.procedure,
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Chi tiết đánh giá',
                                  style: AppTypography.style(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '${report.details.length}/${report.detailsTotal}',
                                style: AppTypography.body(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final f in ComplianceResultFilter.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(switch (f) {
                                      ComplianceResultFilter.all => 'Tất cả',
                                      ComplianceResultFilter.pass => 'Đạt',
                                      ComplianceResultFilter.fail => 'Chưa đạt',
                                    }),
                                    selected: _resultFilter == f,
                                    onSelected: (_) async {
                                      if (_resultFilter == f) return;
                                      setState(() => _resultFilter = f);
                                      await _load();
                                    },
                                    selectedColor: AppColors.primaryContainer,
                                    labelStyle: AppTypography.style(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _resultFilter == f
                                          ? AppColors.primaryDark
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (report.details.isEmpty)
                            const EmptyState(
                              icon: Icons.fact_check_outlined,
                              title: 'Chưa có phiếu',
                              message:
                                  'Chưa có đánh giá trong kỳ / bộ lọc hiện tại.',
                            )
                          else ...[
                            for (final item in report.details)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _DetailCard(
                                  row: item,
                                  onTap: () => _openTicketDetail(item),
                                ),
                              ),
                            if (report.hasMoreDetails)
                              Center(
                                child: TextButton.icon(
                                  onPressed: _loadingMore
                                      ? null
                                      : () => _load(append: true),
                                  icon: _loadingMore
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    _loadingMore ? 'Đang tải…' : 'Xem thêm',
                                  ),
                                ),
                              ),
                          ],
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

class _ComplianceDeptPick {
  const _ComplianceDeptPick.clear() : department = null, cleared = true;
  const _ComplianceDeptPick.selected(this.department) : cleared = false;
  final QtktComplianceFilterDepartment? department;
  final bool cleared;
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceMuted,
        borderRadius: AppRadius.brBase,
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.45),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brBase,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              label,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiHero extends StatelessWidget {
  const _KpiHero({required this.report});
  final QtktComplianceReport report;

  @override
  Widget build(BuildContext context) {
    final ratePct = (report.rateFraction * 100).clamp(0.0, 100.0);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brBase,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportTitle,
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.departmentName,
                      style: AppTypography.body(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                report.rateLabel,
                style: AppTypography.metric(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'tỉ lệ tuân thủ',
                style: AppTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: report.rateFraction,
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              color: ratePct >= 80
                  ? AppColors.success
                  : (ratePct >= 50 ? AppColors.warning : AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Tổng',
                  value: '${report.total}',
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Đạt',
                  value: '${report.passed}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Chưa đạt',
                  value: '${report.failed}',
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.style(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.body(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

enum _BucketKind { department, context, procedure }

class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.bucket, required this.onTap});
  final ComplianceBucket bucket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = bucket.total > 0;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  bucket.departmentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bucket.rateLabel,
                style: AppTypography.style(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: hasData
                      ? AppColors.primaryDark
                      : AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: bucket.rateFraction,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${bucket.passed} đạt · ${bucket.failed} chưa · ${bucket.total} phiếu',
                  style: AppTypography.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                'Xem phiếu',
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.row,
    required this.onTap,
    this.hideDepartment = false,
  });
  final ComplianceDetailRow row;
  final VoidCallback onTap;
  final bool hideDepartment;

  @override
  Widget build(BuildContext context) {
    final pass = row.passed;
    final tone = pass ? AppColors.success : AppColors.error;
    final initial = row.employeeName.trim().isNotEmpty
        ? String.fromCharCodes(
            row.employeeName.trim().runes.take(1),
          ).toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tone.withValues(alpha: 0.07),
                AppColors.surface,
                AppColors.surface,
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
            borderRadius: AppRadius.brLg,
            border: Border.all(color: tone.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppRadius.brPaper,
                            border: Border.all(
                              color: tone.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            initial,
                            style: AppTypography.style(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: tone,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: tone,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              pass ? Icons.check_rounded : Icons.close_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (row.employeeCode.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              row.employeeCode,
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusChip(
                      label: pass ? 'Đạt' : 'Chưa đạt',
                      color: tone,
                      dense: true,
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                if (row.procedureName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    row.procedureName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
                if ((!hideDepartment && row.departmentName.isNotEmpty) ||
                    row.evalDateLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (!hideDepartment && row.departmentName.isNotEmpty) ...[
                        Icon(
                          Icons.apartment_rounded,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            row.departmentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      if (!hideDepartment &&
                          row.departmentName.isNotEmpty &&
                          row.evalDateLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: AppTypography.style(
                              fontSize: 11.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      if (row.evalDateLabel.isNotEmpty) ...[
                        Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          row.evalDateLabel,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if ((row.checkContextLabel != null &&
                        row.checkContextLabel!.isNotEmpty) ||
                    (row.patientCode != null &&
                        row.patientCode!.trim().isNotEmpty) ||
                    row.scoreLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (row.checkContextLabel != null &&
                          row.checkContextLabel!.isNotEmpty)
                        _TicketMetaPill(
                          icon: Icons.touch_app_outlined,
                          label: row.checkContextLabel!,
                          color: AppColors.info,
                        ),
                      if (row.patientCode != null &&
                          row.patientCode!.trim().isNotEmpty)
                        _TicketMetaPill(
                          icon: Icons.badge_outlined,
                          label: 'NB ${row.patientCode}',
                          color: AppColors.secondary,
                        ),
                      if (row.scoreLabel.isNotEmpty)
                        _TicketMetaPill(
                          icon: Icons.grade_outlined,
                          label: row.scoreLabel,
                          color: AppColors.primary,
                          emphasize: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketMetaPill extends StatelessWidget {
  const _TicketMetaPill({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasize ? 0.14 : 0.1),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _kQtktWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

DateTime? _parseComplianceDate(String raw) {
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

DateTime _qtktMondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _qtktDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

class _ComplianceTrendCard extends StatefulWidget {
  const _ComplianceTrendCard({required this.points});
  final List<ComplianceTrendPoint> points;

  @override
  State<_ComplianceTrendCard> createState() => _ComplianceTrendCardState();
}

class _ComplianceTrendCardState extends State<_ComplianceTrendCard> {
  late final PageController _pageController;
  late List<_ComplianceWeek> _weeks;
  late int _weekIndex;
  _ComplianceDayFocus? _focus;

  @override
  void initState() {
    super.initState();
    _weeks = _ComplianceWeek.fromPoints(widget.points);
    _weekIndex = _defaultWeekIndex(_weeks);
    _pageController = PageController(initialPage: _weekIndex);
  }

  @override
  void didUpdateWidget(covariant _ComplianceTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _weeks = _ComplianceWeek.fromPoints(widget.points);
      _weekIndex = _defaultWeekIndex(
        _weeks,
      ).clamp(0, math.max(0, _weeks.length - 1));
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

  int _defaultWeekIndex(List<_ComplianceWeek> weeks) {
    if (weeks.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < weeks.length; i++) {
      for (final d in weeks[i].days) {
        if (d.date != null &&
            d.date!.year == today.year &&
            d.date!.month == today.month &&
            d.date!.day == today.day) {
          return i;
        }
      }
    }
    return weeks.length - 1;
  }

  void _goTo(int index) {
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

  @override
  Widget build(BuildContext context) {
    if (_weeks.isEmpty || _weeks.every((w) => w.spots.isEmpty)) {
      return const SizedBox.shrink();
    }
    final week = _weeks[_weekIndex.clamp(0, _weeks.length - 1)];
    final latest = week.spots.isEmpty ? null : week.spots.last.y;

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
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Tỉ lệ tuân thủ (%)',
                    style: AppTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (latest != null)
                  Text(
                    '${latest.toStringAsFixed(1)}%',
                    style: AppTypography.metric(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.brPaper,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AppNavArrow(
                        icon: Icons.chevron_left_rounded,
                        semanticsLabel: 'Tuần trước',
                        onTap: () => _goTo(_weekIndex - 1),
                        enabled: _weekIndex > 0,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              week.isCurrentWeek ? 'Tuần này' : week.title,
                              style: AppTypography.style(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              week.rangeLabel,
                              style: AppTypography.style(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppNavArrow(
                        icon: Icons.chevron_right_rounded,
                        semanticsLabel: 'Tuần sau',
                        onTap: () => _goTo(_weekIndex + 1),
                        enabled: _weekIndex < _weeks.length - 1,
                      ),
                    ],
                  ),
                  if (_weeks.length > 1) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _weeks.length; i++) ...[
                          if (i > 0) const SizedBox(width: 5),
                          AnimatedContainer(
                            duration: AppDurations.fast,
                            width: i == _weekIndex ? 14 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _weekIndex
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: AppRadius.brPill,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            height: 200,
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
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 10, 2),
                child: _ComplianceWeekChart(
                  week: _weeks[index],
                  weekIndex: index,
                  focus: _focus?.weekIndex == index ? _focus : null,
                  onPress: (wi, di, day) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _focus = _ComplianceDayFocus(
                        weekIndex: wi,
                        dayIndex: di,
                        day: day,
                      );
                    });
                  },
                  onClear: () {
                    if (_focus == null) return;
                    setState(() => _focus = null);
                  },
                ),
              ),
            ),
          ),
          if (_focus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.brPaper,
                ),
                child: Row(
                  children: [
                    Text(
                      _focus!.day.weekdayLabel,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _focus!.day.label,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _focus!.day.rate == null
                          ? '—'
                          : '${_focus!.day.rate!.toStringAsFixed(1)}%',
                      style: AppTypography.metric(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Chạm ngày để xem · thả tay để ẩn',
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ComplianceDay {
  const _ComplianceDay({
    required this.label,
    required this.date,
    required this.rate,
    required this.weekdayLabel,
  });

  final String label;
  final DateTime? date;
  final double? rate;
  final String weekdayLabel;

  bool get hasValue => rate != null;
}

class _ComplianceDayFocus {
  const _ComplianceDayFocus({
    required this.weekIndex,
    required this.dayIndex,
    required this.day,
  });

  final int weekIndex;
  final int dayIndex;
  final _ComplianceDay day;
}

class _ComplianceWeek {
  const _ComplianceWeek({
    required this.days,
    required this.spots,
    required this.isCurrentWeek,
  });

  final List<_ComplianceDay> days;
  final List<FlSpot> spots;
  final bool isCurrentWeek;

  String get title {
    final first = days.first.date;
    if (first == null) return 'Tuần';
    return 'Tuần ${((first.day - 1) ~/ 7) + 1}';
  }

  String get rangeLabel {
    final mon = days.first.date;
    final sun = days.last.date;
    if (mon != null && sun != null) {
      return '${_qtktDayMonth(mon)} – ${_qtktDayMonth(sun)}';
    }
    return '';
  }

  static List<_ComplianceWeek> fromPoints(List<ComplianceTrendPoint> points) {
    if (points.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = <DateTime, ComplianceTrendPoint>{};
    DateTime? first;
    DateTime? last;

    for (final p in points) {
      final date = _parseComplianceDate(p.label);
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      byDate[key] = p;
      if (first == null || key.isBefore(first)) first = key;
      if (last == null || key.isAfter(last)) last = key;
    }

    if (first == null || last == null) {
      // Fallback: chunk by 7 in order.
      final weeks = <_ComplianceWeek>[];
      for (var start = 0; start < points.length; start += 7) {
        final end = math.min(start + 7, points.length);
        final slice = points.sublist(start, end);
        final days = <_ComplianceDay>[];
        final spots = <FlSpot>[];
        for (var i = 0; i < 7; i++) {
          final p = i < slice.length ? slice[i] : null;
          final rate = (p != null && p.hasData) ? p.rate : null;
          days.add(
            _ComplianceDay(
              label: p?.label ?? _kQtktWeekdays[i],
              date: p == null ? null : _parseComplianceDate(p.label),
              rate: rate,
              weekdayLabel: _kQtktWeekdays[i],
            ),
          );
          if (rate != null) spots.add(FlSpot(i.toDouble(), rate));
        }
        weeks.add(
          _ComplianceWeek(days: days, spots: spots, isCurrentWeek: false),
        );
      }
      return weeks;
    }

    final weeks = <_ComplianceWeek>[];
    var monday = _qtktMondayOf(first);
    final endMonday = _qtktMondayOf(last);
    while (!monday.isAfter(endMonday)) {
      final days = <_ComplianceDay>[];
      final spots = <FlSpot>[];
      var containsToday = false;
      for (var i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final p = byDate[date];
        final rate = (p != null && p.hasData) ? p.rate : null;
        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          containsToday = true;
        }
        days.add(
          _ComplianceDay(
            label: p?.label ?? '${_qtktDayMonth(date)}/${date.year}',
            date: date,
            rate: rate,
            weekdayLabel: _kQtktWeekdays[i],
          ),
        );
        if (rate != null) spots.add(FlSpot(i.toDouble(), rate));
      }
      weeks.add(
        _ComplianceWeek(days: days, spots: spots, isCurrentWeek: containsToday),
      );
      monday = monday.add(const Duration(days: 7));
    }
    return weeks;
  }
}

class _ComplianceWeekChart extends StatelessWidget {
  const _ComplianceWeekChart({
    required this.week,
    required this.weekIndex,
    required this.focus,
    required this.onPress,
    required this.onClear,
  });

  final _ComplianceWeek week;
  final int weekIndex;
  final _ComplianceDayFocus? focus;
  final void Function(int weekIndex, int dayIndex, _ComplianceDay day) onPress;
  final VoidCallback onClear;

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

    final maxValue = spots.map((s) => s.y).reduce(math.max);
    final maxY = math.max(100.0, maxValue * 1.05);
    final focusedDay = focus?.dayIndex;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: -0.45,
        maxX: 6.45,
        clipData: const FlClipData.none(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 50,
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
              interval: 50,
              getTitlesWidget: (value, meta) {
                if (value > maxY - 10) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    '${value.toInt()}',
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
                    index >= _kQtktWeekdays.length) {
                  return const SizedBox.shrink();
                }
                final selected = focusedDay == index;
                final hasData =
                    index < week.days.length && week.days[index].hasValue;
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    _kQtktWeekdays[index],
                    style: AppTypography.style(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      color: selected
                          ? AppColors.primary
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
          verticalLines: [
            if (focusedDay != null)
              VerticalLine(
                x: focusedDay.toDouble(),
                color: AppColors.primary.withValues(alpha: 0.35),
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
              onPress(weekIndex, dayIndex, day);
              return;
            }
            if (released) onClear();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            preventCurveOverShooting: true,
            color: AppColors.primary,
            barWidth: 3,
            shadow: Shadow(
              color: AppColors.primary.withValues(alpha: 0.22),
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
                  color: selected || isLast
                      ? AppColors.primary
                      : AppColors.surface,
                  strokeWidth: selected ? 0 : 2.2,
                  strokeColor: AppColors.primary,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.primary.withValues(alpha: 0.02),
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

// ───────────────────────────── Drill-down phiếu ───────────────────────────────

class _TicketListSheet extends ConsumerStatefulWidget {
  const _TicketListSheet({
    required this.title,
    required this.subtitle,
    required this.rateLabel,
    required this.passed,
    required this.failed,
    required this.total,
    required this.kind,
    required this.yearMonth,
    required this.onOpenTicket,
    this.departmentId,
    this.procedureCode,
    this.checkContextCode,
    this.checkContextLabel,
  });

  final String title;
  final String subtitle;
  final String rateLabel;
  final int passed;
  final int failed;
  final int total;
  final QtktComplianceKind kind;
  final String yearMonth;
  final int? departmentId;
  final String? procedureCode;
  final String? checkContextCode;
  final String? checkContextLabel;
  final ValueChanged<ComplianceDetailRow> onOpenTicket;

  @override
  ConsumerState<_TicketListSheet> createState() => _TicketListSheetState();
}

class _TicketListSheetState extends ConsumerState<_TicketListSheet> {
  bool _loading = true;
  String? _error;
  List<ComplianceDetailRow> _rows = const [];

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
      final rows = await ref
          .read(qtktComplianceRepositoryProvider)
          .fetchDetailRows(
            widget.kind,
            yearMonth: widget.yearMonth,
            departmentId: widget.departmentId,
            procedureCode: widget.procedureCode,
            checkContextCode: widget.checkContextCode,
            checkContextLabel: widget.checkContextLabel,
          );
      if (!mounted) return;
      setState(() {
        _rows = rows;
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
        _error = 'Không tải được danh sách phiếu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final rate = widget.total <= 0
        ? 0.0
        : (widget.passed / widget.total).clamp(0.0, 1.0);
    final rateTone = rate >= 0.8
        ? AppColors.success
        : rate >= 0.5
        ? AppColors.warning
        : AppColors.error;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSoft,
              borderRadius: AppRadius.brPill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.surface,
                    AppColors.surface,
                  ],
                ),
                borderRadius: AppRadius.brXl,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.brPaper,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.25,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: AppTypography.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 58,
                              height: 58,
                              child: CircularProgressIndicator(
                                value: rate,
                                strokeWidth: 5.5,
                                backgroundColor: AppColors.surfaceHigh,
                                color: rateTone,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              widget.rateLabel,
                              style: AppTypography.metric(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: rateTone,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SheetStat(
                        label: 'Đạt',
                        value: '${widget.passed}',
                        color: AppColors.success,
                        icon: Icons.verified_rounded,
                      ),
                      const SizedBox(width: 8),
                      _SheetStat(
                        label: 'Chưa đạt',
                        value: '${widget.failed}',
                        color: AppColors.error,
                        icon: Icons.cancel_outlined,
                      ),
                      const SizedBox(width: 8),
                      _SheetStat(
                        label: 'Tổng phiếu',
                        value: '${widget.total}',
                        color: AppColors.primary,
                        icon: Icons.description_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  'DANH SÁCH PHIẾU',
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (!_loading && _error == null)
                  Text(
                    '${_rows.length} phiếu',
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
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
                : _rows.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Chưa có phiếu',
                    message: 'Không có đánh giá trong phạm vi này.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final row = _rows[i];
                      return _DetailCard(
                        row: row,
                        hideDepartment: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onOpenTicket(row);
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.brPaper,
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.metric(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.style(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketDetailSheet extends ConsumerStatefulWidget {
  const _TicketDetailSheet({required this.evaluationId, required this.preview});

  final int evaluationId;
  final ComplianceDetailRow preview;

  @override
  ConsumerState<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends ConsumerState<_TicketDetailSheet> {
  bool _loading = true;
  String? _error;
  QtktEvaluation? _eval;
  QtktProcedure? _procedure;

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
      final repo = ref.read(qtktRepositoryProvider);
      final eval = await repo.getById(widget.evaluationId);
      QtktProcedure? procedure;
      try {
        final template = await repo.template();
        for (final p in template.procedures) {
          if (p.code == eval.procedureCode) {
            procedure = p;
            break;
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _eval = eval;
        _procedure = procedure;
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
        _error = 'Không tải được chi tiết phiếu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final eval = _eval;
    final isPass = preview.passed;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSoft,
              borderRadius: AppRadius.brPill,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
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
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      _TicketHeroHeader(
                        name: preview.employeeName,
                        code: preview.employeeCode,
                        passed: isPass,
                        total: eval!.totalScore,
                        max: eval.maxScore,
                        procedureName: eval.procedureName,
                        dateLabel: preview.evalDateLabel.isNotEmpty
                            ? preview.evalDateLabel
                            : eval.evalDate,
                      ),
                      const SizedBox(height: 12),
                      _TicketMetaChips(eval: eval, preview: preview),
                      if (_procedure != null) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CHI TIẾT CHẤM ĐIỂM',
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final section in _procedure!.sections)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ScoreSectionCard(
                              section: section,
                              scores: eval.scores,
                            ),
                          ),
                      ] else if (eval.scores.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        for (final entry in eval.scores.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RawScoreRow(
                              label: entry.key,
                              value: entry.value,
                            ),
                          ),
                      ],
                      if (eval.note != null &&
                          eval.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _NoteCard(note: eval.note!.trim()),
                        const SizedBox(height: 12),
                      ] else
                        const SizedBox(height: 12),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TicketHeroHeader extends StatelessWidget {
  const _TicketHeroHeader({
    required this.name,
    required this.code,
    required this.passed,
    required this.total,
    required this.max,
    required this.procedureName,
    required this.dateLabel,
  });

  final String name;
  final String code;
  final bool passed;
  final double total;
  final double max;
  final String procedureName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final tone = passed ? AppColors.success : AppColors.error;
    final ratio = max <= 0 ? 0.0 : (total / max).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.12),
            AppColors.surface,
            AppColors.surface,
          ],
        ),
        borderRadius: AppRadius.brXl,
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.brPaper,
                  border: Border.all(color: tone.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  passed ? Icons.verified_rounded : Icons.gpp_maybe_outlined,
                  color: tone,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                        height: 1.2,
                      ),
                    ),
                    if (code.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        code,
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: passed ? 'Đạt' : 'Chưa đạt',
                color: tone,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng điểm',
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          total.toStringAsFixed(2),
                          style: AppTypography.metric(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: tone,
                          ),
                        ),
                        Text(
                          ' / ${max.toStringAsFixed(1)}',
                          style: AppTypography.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 6,
                        backgroundColor: AppColors.surfaceHigh,
                        color: tone,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${(ratio * 100).round()}%',
                      style: AppTypography.metric(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              color: tone,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (procedureName.isNotEmpty) procedureName,
              if (dateLabel.isNotEmpty) dateLabel,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketMetaChips extends StatelessWidget {
  const _TicketMetaChips({required this.eval, required this.preview});

  final QtktEvaluation eval;
  final ComplianceDetailRow preview;

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String)>[
      (Icons.apartment_rounded, eval.departmentName),
      if (eval.checkContextLabel != null &&
          eval.checkContextLabel!.trim().isNotEmpty)
        (Icons.touch_app_outlined, eval.checkContextLabel!),
      if (eval.patientCode != null && eval.patientCode!.trim().isNotEmpty)
        (Icons.badge_outlined, 'NB ${eval.patientCode}'),
      (Icons.flag_outlined, eval.status.label),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brBase,
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chip.$1, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    chip.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RawScoreRow extends StatelessWidget {
  const _RawScoreRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: AppTypography.metric(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 18,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghi chú',
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warningDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  note,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: AppColors.textPrimary,
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

enum _StepScoreTone { full, partial, zero }

_StepScoreTone _stepTone(double scored, double max) {
  if (max <= 0) return _StepScoreTone.full;
  if (scored >= max - 0.001) return _StepScoreTone.full;
  if (scored <= 0.001) return _StepScoreTone.zero;
  return _StepScoreTone.partial;
}

bool _shouldShowStepDetail(String title, String? detail) {
  if (detail == null) return false;
  final d = detail.trim();
  if (d.isEmpty) return false;
  final t = title.trim().toLowerCase();
  final dl = d.toLowerCase();
  if (t == dl) return false;
  if (t.contains(dl) || dl.contains(t)) return false;
  return true;
}

class _ScoreSectionCard extends StatelessWidget {
  const _ScoreSectionCard({required this.section, required this.scores});

  final QtktSection section;
  final Map<String, double> scores;

  @override
  Widget build(BuildContext context) {
    var earned = 0.0;
    var max = 0.0;
    for (final step in section.steps) {
      earned += scores[step.id] ?? 0;
      max += step.maxPoints;
    }
    final sectionTone = _stepTone(earned, max);
    final sectionColor = switch (sectionTone) {
      _StepScoreTone.full => AppColors.success,
      _StepScoreTone.partial => AppColors.warning,
      _StepScoreTone.zero => AppColors.error,
    };

    // Không dùng clipBehavior trên container có border + radius:
    // Clip.antiAlias cắt mất góc viền (nhìn như “mất 1 khúc”).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: sectionColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brPill,
                  ),
                  child: Text(
                    '${earned.toStringAsFixed(2)}/${max.toStringAsFixed(1)}',
                    style: AppTypography.metric(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: sectionColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (section.steps.isNotEmpty)
            Container(
              width: double.infinity,
              height: 1,
              color: AppColors.borderSoft,
            ),
          for (final (index, step) in section.steps.indexed) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  height: 1,
                  color: AppColors.borderSoft.withValues(alpha: 0.7),
                ),
              ),
            _ScoreStepRow(step: step, scored: scores[step.id] ?? 0),
          ],
          if (section.steps.isNotEmpty) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ScoreStepRow extends StatelessWidget {
  const _ScoreStepRow({required this.step, required this.scored});

  final QtktStep step;
  final double scored;

  @override
  Widget build(BuildContext context) {
    final tone = _stepTone(scored, step.maxPoints);
    final color = switch (tone) {
      _StepScoreTone.full => AppColors.success,
      _StepScoreTone.partial => AppColors.warning,
      _StepScoreTone.zero => AppColors.error,
    };
    final icon = switch (tone) {
      _StepScoreTone.full => Icons.check_rounded,
      _StepScoreTone.partial => Icons.remove_rounded,
      _StepScoreTone.zero => Icons.close_rounded,
    };
    final showDetail = _shouldShowStepDetail(step.title, step.detail);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.no}. ${step.title}',
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: -0.1,
                  ),
                ),
                if (showDetail) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.detail!.trim(),
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.brSm,
            ),
            child: Text(
              '${scored.toStringAsFixed(2)}/${step.maxPoints.toStringAsFixed(1)}',
              style: AppTypography.metric(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
