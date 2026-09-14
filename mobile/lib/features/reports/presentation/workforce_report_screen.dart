import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/workforce_report.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workforce_report_repository.dart';
import 'workforce_department_detail_screen.dart';
import 'workforce_report_widgets.dart';

class WorkforceReportScreen extends ConsumerStatefulWidget {
  const WorkforceReportScreen({super.key, this.initialDaily = false});

  final bool initialDaily;

  @override
  ConsumerState<WorkforceReportScreen> createState() =>
      _WorkforceReportScreenState();
}

class _WorkforceReportScreenState extends ConsumerState<WorkforceReportScreen> {
  late bool _daily = widget.initialDaily;
  DateTime _date = DateTime.now();
  WorkforceReport? _report;
  bool _loading = true;
  String? _error;
  /// dept | role | absent — browse mode (không phải port ma trận web).
  String _browse = 'dept';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(workforceReportRepositoryProvider);
      final report = _daily
          ? await repo.daily(_iso(_date))
          : await repo.hospital();
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
        _report = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được dữ liệu báo cáo';
        _report = null;
      });
    }
  }

  Future<void> _setDaily(bool daily) async {
    if (_daily == daily) return;
    setState(() {
      _daily = daily;
      _browse = 'dept';
    });
    await _load();
  }

  DateTime get _maxDate => DateTime.now().add(const Duration(days: 14));

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _maxDate,
      title: 'Ngày báo cáo',
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _shiftDate(int days) async {
    final next = _date.add(Duration(days: days));
    if (next.isBefore(DateTime(2020)) || next.isAfter(_maxDate)) return;
    setState(() => _date = next);
    await _load();
  }

  Future<void> _goToday() async {
    if (_isToday) return;
    setState(() => _date = DateTime.now());
    await _load();
  }

  List<WorkforceDepartmentRow> get _visibleRows =>
      _report?.rows ?? const <WorkforceDepartmentRow>[];

  List<WorkforceAbsentDepartment> get _visibleAbsent =>
      _report?.absentByDepartment ?? const <WorkforceAbsentDepartment>[];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final allowed = RoleGroups.canViewWorkforceReports(
      auth.role,
      reportViewEnabled: auth.currentUser?.reportViewEnabled ?? false,
    );
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.55)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: _daily ? 'Nhân lực đi làm' : 'Nhân lực toàn viện',
                icon: _daily
                    ? Icons.event_available_rounded
                    : Icons.groups_rounded,
                eyebrow: 'Báo cáo',
                subtitle: _daily
                    ? 'Quân số có mặt theo khoa/phòng'
                    : 'Biên chế theo khoa/phòng và chức vụ',
                onBack: () => context.pop(),
                footer: allowed
                    ? BrandHeaderSegment(
                        dense: true,
                        selectedIndex: _daily ? 1 : 0,
                        onChanged: (index) => _setDaily(index == 1),
                        items: const [
                          BrandSegmentItem(
                            label: 'Toàn viện',
                            icon: Icons.apartment_rounded,
                          ),
                          BrandSegmentItem(
                            label: 'Đi làm',
                            icon: Icons.event_available_rounded,
                          ),
                        ],
                      )
                    : null,
              ),
              if (!allowed)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Không có quyền xem báo cáo',
                    message:
                        'Báo cáo nhân lực dành cho Ban giám đốc, HCNS hoặc tài khoản được cấp quyền xem.',
                  ),
                )
              else ...[
                if (_daily)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      10,
                      AppSpacing.page,
                      14,
                    ),
                    child: _DateBar(
                      date: _date,
                      isToday: _isToday,
                      onTap: _pickDate,
                      onToday: _goToday,
                      onPrev: () => _shiftDate(-1),
                      onNext: _date
                              .add(const Duration(days: 1))
                              .isAfter(_maxDate)
                          ? null
                          : () => _shiftDate(1),
                    ),
                  ),
                Expanded(child: _buildBody(report)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(WorkforceReport? report) {
    if (_loading && report == null) {
      return const _ReportSkeleton();
    }
    if (_error != null && report == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (report == null) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Chưa có dữ liệu',
        message: 'Không có số liệu báo cáo cho kỳ đã chọn.',
      );
    }

    final depts = _visibleRows;
    final absent = _visibleAbsent;
    final roles = report.rankedCategories;
    final reportDateLabel = AppFormat.date(
      AppFormat.tryParseDate(report.reportDate),
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          12,
          AppSpacing.page,
          32,
        ),
        children: [
          AnimatedSize(
            duration: AppDurations.fast,
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: AppRadius.brPill,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: AppColors.primary,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          AppReveal(
            offset: 8,
            child: _SummaryHero(
              report: report,
              daily: _daily,
              isToday: _isToday,
              dateLabel: AppFormat.date(_date),
              onBrowse: (v) => setState(() => _browse = v),
            ),
          ),
          const SizedBox(height: 18),
          _BrowseTabs(
            daily: _daily,
            browse: _browse,
            deptCount: depts.length,
            roleCount: roles.length,
            absentCount: report.absentTotal,
            onChanged: (v) => setState(() => _browse = v),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: AppDurations.normal,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey('$_browse-$_daily'),
              child: _browse == 'role'
                  ? _RoleSection(roles: roles, total: report.grandTotal)
                  : (_browse == 'absent' && _daily)
                      ? _AbsentSection(
                          rows: absent,
                          reportDateLabel: reportDateLabel,
                        )
                      : _DeptSection(
                          depts: depts,
                          report: report,
                          daily: _daily,
                          reportDateLabel: reportDateLabel,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thanh chọn ngày (chế độ Đi làm)
// ---------------------------------------------------------------------------

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.date,
    required this.isToday,
    required this.onTap,
    required this.onToday,
    this.onPrev,
    this.onNext,
  });

  final DateTime date;
  final bool isToday;
  final VoidCallback onTap;
  final VoidCallback onToday;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            _DateStepButton(
              icon: Icons.chevron_left_rounded,
              semanticsLabel: 'Ngày trước',
              onTap: onPrev,
            ),
            const _DateBarDivider(),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Chọn ngày báo cáo, ${AppFormat.date(date)}',
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: AppRadius.brSm,
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 17,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isToday) ...[
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Flexible(
                                      child: Text(
                                        isToday
                                            ? '${AppFormat.weekday(date)} · Hôm nay'
                                            : AppFormat.weekday(date),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.style(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.1,
                                          color: isToday
                                              ? AppColors.primaryDark
                                              : AppColors.textTertiary,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppFormat.date(date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    height: 1.15,
                                    tabular: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Nút về hôm nay chỉ hiện khi đang xem ngày khác — cùng cỡ với hai
            // nút bước ngày nên hàng vẫn cân.
            AnimatedSize(
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              child: isToday
                  ? const SizedBox(height: 56)
                  : Row(
                      children: [
                        const _DateBarDivider(),
                        _DateStepButton(
                          icon: Icons.today_rounded,
                          semanticsLabel: 'Về hôm nay',
                          iconSize: 19,
                          onTap: onToday,
                        ),
                      ],
                    ),
            ),
            const _DateBarDivider(),
            _DateStepButton(
              icon: Icons.chevron_right_rounded,
              semanticsLabel: 'Ngày sau',
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBarDivider extends StatelessWidget {
  const _DateBarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.borderSoft,
    );
  }
}

class _DateStepButton extends StatelessWidget {
  const _DateStepButton({
    required this.icon,
    required this.semanticsLabel,
    this.onTap,
    this.iconSize = 22,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: SizedBox(
          width: 46,
          height: 56,
          child: Icon(
            icon,
            size: iconSize,
            color: enabled
                ? AppColors.primaryDark
                : AppColors.textTertiary.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thẻ tổng quan
// ---------------------------------------------------------------------------

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.report,
    required this.daily,
    required this.isToday,
    required this.dateLabel,
    required this.onBrowse,
  });

  final WorkforceReport report;
  final bool daily;
  final bool isToday;
  final String dateLabel;
  final ValueChanged<String> onBrowse;

  @override
  Widget build(BuildContext context) {
    final present = report.grandTotal;
    final absent = report.absentTotal;
    final headcount = daily ? (present + absent) : present;
    final rate = headcount <= 0 ? 0.0 : (present / headcount).clamp(0.0, 1.0);
    final ratePct = (rate * 100).round();
    final roles = report.rankedCategories;
    final rateColor = rate >= 0.9
        ? AppColors.success
        : (rate >= 0.75 ? AppColors.primary : AppColors.warning);

    final metrics = <_HeroMetricData>[
      _HeroMetricData(
        icon: Icons.apartment_rounded,
        label: 'Khoa/phòng',
        value: '${report.departmentCount}',
        accent: AppColors.primary,
        browse: 'dept',
      ),
      _HeroMetricData(
        icon: Icons.badge_rounded,
        label: 'Chức vụ',
        value: '${roles.length}',
        accent: AppColors.info,
        browse: 'role',
      ),
      if (daily)
        _HeroMetricData(
          icon: Icons.person_off_rounded,
          label: 'Vắng mặt',
          value: '$absent',
          accent: AppColors.warning,
          browse: 'absent',
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: AppGradients.brand,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (daily
                                    ? (isToday
                                        ? 'Có mặt hôm nay'
                                        : 'Có mặt ngày $dateLabel')
                                    : 'Tổng nhân lực')
                                .toUpperCase(),
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.85,
                              color: AppColors.primaryDark,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                AppFormat.number(present),
                                style: AppTypography.metric(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                daily ? 'người' : 'nhân viên',
                                style: AppTypography.style(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            daily
                                ? 'Trên tổng biên chế ${AppFormat.number(headcount)} người'
                                : 'Biên chế hiện hữu · ${report.departmentCount} khoa/phòng',
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (daily)
                      _RateRing(rate: rate, pct: ratePct, color: rateColor)
                    else
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppGradients.brand,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.tinted(AppColors.primary),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (daily)
                  _PresenceBar(
                    color: rateColor,
                    present: present,
                    absent: absent,
                  )
                else if (roles.isNotEmpty)
                  _RoleDistribution(roles: roles, total: present),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var i = 0; i < metrics.length; i++) ...[
                          if (i > 0)
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: AppColors.borderSoft,
                              indent: 10,
                              endIndent: 10,
                            ),
                          Expanded(
                            child: _HeroMetricTile(
                              data: metrics[i],
                              onTap: () => onBrowse(metrics[i].browse),
                            ),
                          ),
                        ],
                      ],
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

class _RateRing extends StatelessWidget {
  const _RateRing({
    required this.rate,
    required this.pct,
    required this.color,
  });

  final double rate;
  final int pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.06),
            ),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 5.5,
              color: color.withValues(alpha: 0.14),
            ),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: rate),
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 5.5,
                strokeCap: StrokeCap.round,
                color: color,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: AppTypography.metric(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                'có mặt',
                style: AppTypography.style(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  height: 1.1,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresenceBar extends StatelessWidget {
  const _PresenceBar({
    required this.color,
    required this.present,
    required this.absent,
  });

  final Color color;
  final int present;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final presentFlex = present > 0 ? present : (absent > 0 ? 0 : 1);
    final absentFlex = absent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.brPill,
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (presentFlex > 0)
                  Expanded(
                    flex: presentFlex,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: color),
                    ),
                  ),
                if (absentFlex > 0) ...[
                  if (presentFlex > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: absentFlex,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PresenceStat(
                color: color,
                label: 'Có mặt',
                value: present,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PresenceStat(
                color: AppColors.textTertiary,
                label: 'Vắng',
                value: absent,
                muted: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PresenceStat extends StatelessWidget {
  const _PresenceStat({
    required this.color,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final Color color;
  final String label;
  final int value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: muted
            ? AppColors.surfaceMuted
            : color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            AppFormat.number(value),
            style: AppTypography.style(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: muted ? AppColors.textSecondary : color,
              tabular: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh phân bổ chức vụ (stacked) — top 5 + nhóm còn lại.
class _RoleDistribution extends StatelessWidget {
  const _RoleDistribution({required this.roles, required this.total});

  final List<(WorkforceCategory, int)> roles;
  final int total;

  @override
  Widget build(BuildContext context) {
    const maxSegments = 5;
    final head = roles.take(maxSegments).toList();
    final restCount = roles.skip(maxSegments).fold<int>(0, (s, e) => s + e.$2);
    final segments = <(String, int, Color)>[
      for (var i = 0; i < head.length; i++)
        (head[i].$1.label, head[i].$2, workforceRoleColor(i)),
      if (restCount > 0) ('Khác', restCount, AppColors.textTertiary),
    ];
    final sum = segments.fold<int>(0, (s, e) => s + e.$2);
    if (sum <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.brPill,
          child: SizedBox(
            height: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < segments.length; i++)
                  Expanded(
                    flex: segments[i].$2,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == segments.length - 1 ? 0 : 2,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: segments[i].$3,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in segments.take(3))
              _LegendDot(
                color: s.$3,
                label: '${s.$1} ${(s.$2 * 100 / sum).round()}%',
              ),
            if (segments.length > 3)
              _LegendDot(
                color: AppColors.textTertiary,
                label: '+${segments.length - 3} nhóm khác',
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            tabular: true,
          ),
        ),
      ],
    );
  }
}

class _HeroMetricData {
  const _HeroMetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.browse,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String browse;
}

class _HeroMetricTile extends StatelessWidget {
  const _HeroMetricTile({required this.data, required this.onTap});

  final _HeroMetricData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${data.label}: ${data.value}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: data.accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brXs,
                      ),
                      child: Icon(data.icon, size: 15, color: data.accent),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textTertiary.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data.value,
                  maxLines: 1,
                  style: AppTypography.metric(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabs duyệt (Khoa / Chức vụ / Vắng)
// ---------------------------------------------------------------------------

class _BrowseTabs extends StatelessWidget {
  const _BrowseTabs({
    required this.daily,
    required this.browse,
    required this.deptCount,
    required this.roleCount,
    required this.absentCount,
    required this.onChanged,
  });

  final bool daily;
  final String browse;
  final int deptCount;
  final int roleCount;
  final int absentCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, String, IconData, int, Color)>[
      (
        'dept',
        'Khoa',
        Icons.apartment_rounded,
        deptCount,
        AppColors.primary,
      ),
      (
        'role',
        'Chức vụ',
        Icons.badge_rounded,
        roleCount,
        AppColors.info,
      ),
      if (daily)
        (
          'absent',
          'Vắng',
          Icons.person_off_rounded,
          absentCount,
          AppColors.warning,
        ),
    ];

    final selectedIndex =
        tabs.indexWhere((t) => t.$1 == browse).clamp(0, tabs.length - 1);
    final slot = tabs.length == 1
        ? 0.0
        : -1 + 2 * selectedIndex / (tabs.length - 1);
    const trackPad = 4.0;
    const tileHeight = 44.0;
    const tileRadius = 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'DUYỆT THEO',
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.7,
              height: 1.2,
            ),
          ),
        ),
        Container(
          height: tileHeight + trackPad * 2,
          padding: const EdgeInsets.all(trackPad),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(tileRadius + trackPad),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadows.soft,
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: AppDurations.normal,
                curve: Curves.easeOutCubic,
                alignment: Alignment(slot, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / tabs.length,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tabs[selectedIndex]
                          .$5
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(tileRadius),
                      border: Border.all(
                        color: tabs[selectedIndex]
                            .$5
                            .withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, t) in tabs.indexed)
                    Expanded(
                      child: _BrowseTab(
                        label: t.$2,
                        icon: t.$3,
                        count: t.$4,
                        selected: i == selectedIndex,
                        accent: t.$5,
                        radius: tileRadius,
                        onTap: () => onChanged(t.$1),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrowseTab extends StatelessWidget {
  const _BrowseTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.accent,
    required this.radius,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final Color accent;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? accent : AppColors.textSecondary;
    final countLabel = count > 999 ? '999+' : '$count';

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(radius),
          splashColor: accent.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: ExcludeSemantics(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: fg),
                    const SizedBox(width: 5),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: AppDurations.normal,
                        curve: Curves.easeOutCubic,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: fg,
                          letterSpacing: -0.1,
                          height: 1.15,
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    AnimatedContainer(
                      duration: AppDurations.normal,
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.16)
                            : AppColors.surfaceMuted,
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        countLabel,
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? accent : AppColors.textTertiary,
                          height: 1.1,
                          tabular: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Các section danh sách
// ---------------------------------------------------------------------------

class _RoleSection extends StatelessWidget {
  const _RoleSection({required this.roles, required this.total});

  final List<(WorkforceCategory, int)> roles;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Chưa có chức vụ',
        message: 'Không có số liệu phân loại trong kỳ này.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkforceSectionTitle(
          title: 'Phân bổ theo chức vụ',
          count: roles.length,
          icon: Icons.badge_rounded,
          trailing: 'Tổng ${AppFormat.number(total)}',
        ),
        const SizedBox(height: 10),
        WorkforceGroupCard(
          dividerIndent: 16,
          children: [
            for (var i = 0; i < roles.length; i++)
              WorkforceRoleTile(
                index: i,
                label: roles[i].$1.label,
                count: roles[i].$2,
                total: total,
              ),
          ],
        ),
      ],
    );
  }
}

class _AbsentSection extends StatelessWidget {
  const _AbsentSection({required this.rows, required this.reportDateLabel});

  final List<WorkforceAbsentDepartment> rows;
  final String reportDateLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        color: AppColors.success,
        title: 'Không có người vắng',
        message: 'Tất cả nhân sự trong phạm vi đều có mặt.',
      );
    }
    final total = rows.fold<int>(0, (s, r) => s + r.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkforceSectionTitle(
          title: 'Khoa/phòng có người vắng',
          count: rows.length,
          icon: Icons.person_off_rounded,
          color: AppColors.warning,
          trailing: '$total người',
        ),
        const SizedBox(height: 10),
        WorkforceGroupCard(
          dividerIndent: 68,
          children: [
            for (final row in rows)
              _AbsentDeptTile(
                row: row,
                onOpen: () => context.push(
                  RoutePaths.workforceAbsentDepartmentDetail,
                  extra: WorkforceAbsentDeptDetailArgs(
                    row: row,
                    reportDateLabel: reportDateLabel,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DeptSection extends StatelessWidget {
  const _DeptSection({
    required this.depts,
    required this.report,
    required this.daily,
    required this.reportDateLabel,
  });

  final List<WorkforceDepartmentRow> depts;
  final WorkforceReport report;
  final bool daily;
  final String reportDateLabel;

  @override
  Widget build(BuildContext context) {
    if (depts.isEmpty) {
      return const EmptyState(
        icon: Icons.apartment_outlined,
        title: 'Chưa có khoa/phòng',
        message: 'Không có đơn vị nào trong kỳ báo cáo này.',
      );
    }
    final maxTotal = depts.fold<int>(0, (m, r) => r.total > m ? r.total : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkforceSectionTitle(
          title: daily ? 'Có mặt theo khoa/phòng' : 'Biên chế theo khoa/phòng',
          count: depts.length,
          icon: Icons.apartment_rounded,
          trailing: 'Tổng ${AppFormat.number(report.grandTotal)}',
        ),
        const SizedBox(height: 10),
        WorkforceGroupCard(
          dividerIndent: 68,
          children: [
            for (final d in depts)
              _DeptTile(
                row: d,
                categories: report.categories,
                grandTotal: report.grandTotal,
                maxTotal: maxTotal,
                onOpen: () => context.push(
                  RoutePaths.workforceDepartmentDetail,
                  extra: WorkforceDeptDetailArgs(
                    row: d,
                    categories: report.categories,
                    people: [
                      for (final p in report.details)
                        if (p.departmentId == d.departmentId) p,
                    ],
                    daily: daily,
                    grandTotal: report.grandTotal,
                    reportDateLabel: reportDateLabel,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DeptTile extends StatelessWidget {
  const _DeptTile({
    required this.row,
    required this.categories,
    required this.grandTotal,
    required this.maxTotal,
    required this.onOpen,
  });

  final WorkforceDepartmentRow row;
  final List<WorkforceCategory> categories;
  final int grandTotal;
  final int maxTotal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final preview = row.breakdownFor(categories).take(2).toList();
    final pct = grandTotal <= 0 ? 0 : (row.total * 100 / grandTotal).round();
    final rel = maxTotal <= 0 ? 0.0 : (row.total / maxTotal).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      label: '${row.departmentName}, ${row.total} người',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onOpen();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              WorkforceInitialsBadge(
                text: workforceDeptInitials(row.departmentName),
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.departmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview.isEmpty
                          ? 'Chưa có phân loại'
                          : preview.map((e) => '${e.$1} ${e.$2}').join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: AppRadius.brPill,
                      child: LinearProgressIndicator(
                        value: rel,
                        minHeight: 3,
                        color: AppColors.primary.withValues(alpha: 0.55),
                        backgroundColor: AppColors.surfaceHigh,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormat.number(row.total),
                    style: AppTypography.metric(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$pct%',
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      tabular: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbsentDeptTile extends StatelessWidget {
  const _AbsentDeptTile({required this.row, required this.onOpen});

  final WorkforceAbsentDepartment row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final names = row.employees.take(2).map((e) => e.fullName).join(', ');
    final more = row.employees.length - 2;
    return Semantics(
      button: true,
      label: '${row.departmentName}, ${row.total} người vắng',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onOpen();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              WorkforceInitialsBadge(
                text: workforceDeptInitials(row.departmentName),
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.departmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      names.isEmpty
                          ? '${row.total} người vắng'
                          : (more > 0 ? '$names +$more' : names),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${row.total}',
                    style: AppTypography.metric(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.warningDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'vắng',
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        12,
        AppSpacing.page,
        32,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton.line(width: 110, height: 10),
                        Skeleton.line(width: 150, height: 34),
                        Skeleton.line(
                          width: 200,
                          height: 10,
                          margin: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Skeleton(width: 48, height: 48, radius: 15),
                ],
              ),
              const SizedBox(height: 18),
              const Skeleton(height: 8, radius: 999),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(child: Skeleton(height: 58, radius: 14)),
                  SizedBox(width: 8),
                  Expanded(child: Skeleton(height: 58, radius: 14)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Skeleton(height: 46, radius: 14),
        const SizedBox(height: 14),
        const Skeleton.line(width: 160, height: 12),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brCard,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 6; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: const [
                      Skeleton(width: 42, height: 42, radius: 13),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Skeleton.line(width: 160, height: 12),
                            Skeleton.line(
                              width: 110,
                              height: 10,
                              margin: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Skeleton(width: 34, height: 20, radius: 6),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
