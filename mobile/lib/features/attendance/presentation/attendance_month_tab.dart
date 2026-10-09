import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_month_picker.dart';
import '../../../core/widgets/app_period_navigator.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import '../../../core/widgets/brand_hero.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_month_controller.dart';
import '../application/attendance_schedule_provider.dart';
import 'attendance_day_detail_sheet.dart';
import 'attendance_schedule_panel.dart';

/// Số công chuẩn một tháng — dưới mức này coi là thiếu công.
const double _standardWorkUnits = 26;

/// Sắc nhận diện các loại công — dùng chung cho chỉ số tháng và thẻ ngày.
const Color _leaveTone = Color(0xFF0F766E);
const Color _dutyTone = Color(0xFF7C3AED);
const Color _mealTone = Color(0xFFE65100);
const Color _youngChildTone = Color(0xFFC2410C);
const Color _quangTrungTone = _leaveTone;

String? _dayKey(AttendanceDay day) {
  final d = day.workDate;
  if (d == null) return null;
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$y-$m-$dd';
}

class AttendanceMonthTab extends ConsumerWidget {
  const AttendanceMonthTab({
    super.key,
    required this.employeeId,
    this.employeeName,
  });

  final int employeeId;
  final String? employeeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceMonthControllerProvider(employeeId));
    final controller = ref.read(
      attendanceMonthControllerProvider(employeeId).notifier,
    );
    final role = ref.watch(authControllerProvider).role;
    final canAssignContinuous =
        role == UserRole.admin || RoleGroups.isHeadDepartmentRole(role);
    final canProposeYoungChild =
        role == UserRole.admin || RoleGroups.isHeadDepartmentRole(role);
    final canManageDutyQuangTrung =
        role == UserRole.admin || RoleGroups.isHeadDepartmentRole(role);

    if (employeeId <= 0) {
      return const EmptyState(
        icon: Icons.person_search_rounded,
        title: 'Chọn nhân viên',
        message: 'Chạm ô nhân viên phía trên để xem bảng công.',
      );
    }

    if (state.loading && state.summary == null) {
      return const SkeletonList(itemCount: 4, showAvatar: false);
    }
    if (state.error != null && state.summary == null) {
      return ErrorState(message: state.error!, onRetry: controller.load);
    }

    final summary = state.summary;
    if (summary == null) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Chưa có dữ liệu chấm công',
      );
    }

    final scheduleKey = AttendanceScheduleKey(
      employeeId: employeeId,
      year: state.year,
      month: state.month,
    );
    final scheduleAsync = ref.watch(attendanceScheduleProvider(scheduleKey));

    Future<void> refreshAll() async {
      await controller.load();
      ref.invalidate(attendanceScheduleProvider(scheduleKey));
    }

    return RefreshIndicator(
      onRefresh: refreshAll,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          AppReveal(
            offset: 8,
            child: _MonthSwitcher(
              year: state.year,
              month: state.month,
              loading: state.loading,
              onPickMonth: controller.setMonth,
            ),
          ),
          AppReveal(
            delay: const Duration(milliseconds: 25),
            offset: 8,
            child: scheduleAsync.when(
              data: (view) => AttendanceSchedulePanel(
                view: view,
                onConfigureContinuous: canAssignContinuous
                    ? () async {
                        final saved = await context.push<bool>(
                          RoutePaths.attendanceContinuousShiftPath(
                            employeeId: employeeId,
                            year: state.year,
                            month: state.month,
                            name: employeeName,
                          ),
                        );
                        if (saved == true) {
                          ref.invalidate(
                            attendanceScheduleProvider(scheduleKey),
                          );
                          await controller.load();
                        }
                      }
                    : null,
                onProposeShiftConfigChange: canAssignContinuous
                    ? () => context.push(
                        RoutePaths.requestCreatePath(
                          'shift-config-change',
                          employeeId: employeeId,
                        ),
                      )
                    : null,
                onProposeYoungChild: canProposeYoungChild
                    ? () => context.push(
                        RoutePaths.requestCreatePath(
                          'young-child',
                          employeeId: employeeId,
                        ),
                      )
                    : null,
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SkeletonList(
                  itemCount: 1,
                  showAvatar: false,
                  embedded: true,
                ),
              ),
              error: (_, _) => Padding(
                padding: AppSpacing.pageH,
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  margin: EdgeInsets.zero,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Không tải được lịch làm việc',
                          style: AppTypography.style(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          attendanceScheduleProvider(scheduleKey),
                        ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppReveal(
            delay: const Duration(milliseconds: 40),
            offset: 10,
            child: _MonthHero(
              summary: summary,
              deploymentDayCount: state.deploymentDayCount,
              employeeId: employeeId,
              year: state.year,
              month: state.month,
              canManageSupplements: canManageDutyQuangTrung,
            ),
          ),
          AppReveal(
            delay: const Duration(milliseconds: 55),
            offset: 8,
            child: _MetricsStrip(
              summary: summary,
              deploymentDayCount: state.deploymentDayCount,
              deploymentOvertimeUnits: state.deploymentOvertimeUnits,
            ),
          ),
          _DayDetailsSection(
            employeeId: employeeId,
            employeeName: employeeName,
            year: state.year,
            month: state.month,
            days: state.days,
            dutyByDate: state.dutyByDate,
            continuousDates:
                scheduleAsync.valueOrNull?.continuousDates ?? const {},
            splitDates: scheduleAsync.valueOrNull?.splitDates ?? const {},
          ),
        ],
      ),
    );
  }
}

class _DayDetailsSection extends StatefulWidget {
  const _DayDetailsSection({
    required this.employeeId,
    this.employeeName,
    required this.year,
    required this.month,
    required this.days,
    required this.dutyByDate,
    this.continuousDates = const {},
    this.splitDates = const {},
  });

  final int employeeId;
  final String? employeeName;
  final int year;
  final int month;
  final List<AttendanceDay> days;
  final Map<String, DutyShiftEntry> dutyByDate;
  final Set<String> continuousDates;
  final Set<String> splitDates;

  @override
  State<_DayDetailsSection> createState() => _DayDetailsSectionState();
}

class _DayDetailsSectionState extends State<_DayDetailsSection> {
  bool _expanded = false;

  List<AttendanceDay> get _visibleDays {
    if (widget.days.isEmpty) return const [];
    if (!_expanded) {
      final now = DateTime.now();
      final sameMonth = now.year == widget.year && now.month == widget.month;
      if (!sameMonth) return widget.days.take(1).toList();

      final today = DateTime(now.year, now.month, now.day);
      final match = widget.days.where((d) => d.workDate != null).where((d) {
        final wd = d.workDate!;
        return wd.year == today.year &&
            wd.month == today.month &&
            wd.day == today.day;
      }).toList();
      if (match.isNotEmpty) return match.take(1).toList();
      return widget.days.take(1).toList();
    }
    return widget.days;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.days.length;
    final visibleCount = _visibleDays.length;
    final showTodayOnly = !_expanded;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              const TintedIconTile(
                icon: Icons.calendar_view_day_rounded,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chi tiết theo ngày',
                      style: AppTypography.style(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? 'Chưa có ngày nào'
                          : _expanded
                          ? '$total ngày có dữ liệu'
                          : 'Đang hiện $visibleCount/$total ngày',
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (total > 1)
                Material(
                  type: MaterialType.transparency,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.brPill,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    color: _expanded
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : AppColors.surface,
                    child: InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded ? 'Thu gọn' : 'Xem cả tháng',
                              style: AppTypography.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: AppTypography.uppercaseHeight,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 2),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: AppDurations.normal,
                              curve: Curves.easeOutCubic,
                              child: const Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.days.isEmpty)
          const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Chưa có dữ liệu chấm công tháng này',
            message: 'Dữ liệu sẽ hiển thị sau khi máy chấm công đồng bộ.',
          )
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: AppSpacing.pageH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, day) in _visibleDays.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _DayRow(
                      employeeId: widget.employeeId,
                      employeeName: widget.employeeName,
                      day: day,
                      duty: widget.dutyByDate[_dayKey(day)],
                      isContinuousDay: widget.continuousDates.contains(
                        _dayKey(day),
                      ),
                      isSplitDay: widget.splitDates.contains(_dayKey(day)),
                    ),
                  ],
                  if (showTodayOnly) const SizedBox(height: 2),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.year,
    required this.month,
    required this.loading,
    required this.onPickMonth,
  });

  final int year;
  final int month;
  final bool loading;
  final void Function(int year, int month) onPickMonth;

  Future<void> _openPicker(BuildContext context) async {
    if (loading) return;
    final picked = await showAppMonthPicker(
      context,
      year: year,
      month: month,
      title: 'Chọn tháng / năm',
    );
    if (picked == null) return;
    onPickMonth(picked.$1, picked.$2);
  }

  void _shift(int delta) {
    if (loading) return;
    final d = DateTime(year, month + delta);
    onPickMonth(d.year, d.month);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Cho xem trước tháng kế tiếp (lịch ca đã xếp), không đi xa hơn.
    final canGoForward = DateTime(
      year,
      month,
    ).isBefore(DateTime(now.year, now.month + 1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: AppPeriodNavigator(
        month: DateTime(year, month),
        onPrev: () => _shift(-1),
        onNext: () => _shift(1),
        onPickMonth: () => _openPicker(context),
        canGoBack: !loading,
        canGoForward: !loading && canGoForward,
      ),
    );
  }
}

class _MonthHero extends StatelessWidget {
  const _MonthHero({
    required this.summary,
    this.deploymentDayCount = 0,
    this.employeeId = 0,
    this.year = 0,
    this.month = 0,
    this.canManageSupplements = false,
  });

  final AttendanceMonthSummary summary;
  final int deploymentDayCount;
  final int employeeId;
  final int year;
  final int month;
  final bool canManageSupplements;

  int get _supplementCount => summary.quangTrungAllowanceCount;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalWorkUnits;
    final enough = total >= _standardWorkUnits;
    final missing = (_standardWorkUnits - total).clamp(0, _standardWorkUnits);
    final ratio = (total / _standardWorkUnits).clamp(0.0, 1.0);
    final tone = enough ? AppColors.onBrandRing : AppColors.secondaryLight;
    final period = month > 0 && year > 0
        ? 'Tháng ${month.toString().padLeft(2, '0')}/$year'
        : null;

    return Padding(
      padding: AppSpacing.pageH,
      child: BrandHeroCard(
        ornamentIcon: Icons.event_available_rounded,
        ornamentOnTop: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Đầu thẻ: icon + nhãn + kỳ / định mức ─────────────────────
            Row(
              children: [
                const BrandGlassIconTile(
                  icon: Icons.insights_rounded,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandHeroEyebrow(text: 'Tổng công tháng'),
                      const SizedBox(height: 5),
                      Text(
                        [
                          ?period,
                          'Định mức ${AppFormat.score(_standardWorkUnits)} công',
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // ── Số chính + vòng tiến độ định mức ─────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: AppFormat.workUnits(total),
                                style: AppTypography.display(
                                  fontSize: 42,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '  / ${AppFormat.score(_standardWorkUnits)} công',
                                style: AppTypography.style(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _HeroStatusPill(
                        enough: enough,
                        tone: tone,
                        label: enough
                            ? 'Đã đạt định mức'
                            : 'Còn thiếu ${AppFormat.workUnits(missing)} công',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _HeroRing(ratio: ratio, tone: tone),
              ],
            ),
            const SizedBox(height: 16),
            // ── Cơ cấu công 2×2 ──────────────────────────────────────────
            _HeroBreakdown(
              cells: [
                _BreakdownCell(
                  icon: Icons.fingerprint_rounded,
                  label: 'Chấm công',
                  value: AppFormat.workUnits(summary.clockedWorkUnits),
                  tone: AppColors.onBrandRing,
                  active: summary.clockedWorkUnits > 0,
                ),
                _BreakdownCell(
                  icon: Icons.beach_access_rounded,
                  label: 'Phép',
                  value: AppFormat.workUnits(summary.leaveWorkUnits),
                  tone: AppColors.onBrandSoft,
                  active: summary.leaveWorkUnits > 0,
                ),
                _BreakdownCell(
                  icon: Icons.nights_stay_rounded,
                  label: 'Trực',
                  value: AppFormat.workUnits(summary.dutyWorkUnitsTotal),
                  tone: AppColors.secondaryLight,
                  active: summary.dutyWorkUnitsTotal > 0,
                ),
                _BreakdownCell(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Điều động',
                  value: '$deploymentDayCount',
                  unit: 'ngày',
                  tone: AppColors.secondaryLight,
                  active: deploymentDayCount > 0,
                ),
              ],
            ),
            if (_supplementCount > 0) ...[
              const SizedBox(height: 8),
              _HeroNote(
                icon: Icons.add_circle_outline_rounded,
                text: '$_supplementCount ngày bổ sung công Quang Trung',
                tone: AppColors.secondaryLight,
                expand: true,
              ),
            ],
            if (summary.requiresDiscipline) ...[
              const SizedBox(height: 8),
              _HeroNote(
                icon: Icons.gavel_rounded,
                text: summary.latePenalty > 0
                    ? 'Muộn ≥201′ · phạt ${AppFormat.currency(summary.latePenalty)} · cần xem xét kỷ luật'
                    : 'Muộn ≥201 phút · cần xem xét kỷ luật',
                tone: AppColors.onBrandAlert,
                expand: true,
              ),
            ],
            if (canManageSupplements) ...[
              const SizedBox(height: 14),
              _HeroActionButtons(
                employeeId: employeeId,
                year: year,
                month: month,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vòng tiến độ so với định mức: rãnh tối, cung sáng theo sắc, % ở giữa.
class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.ratio, required this.tone});

  final double ratio;
  final Color tone;

  static const double _size = 78;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đạt ${(ratio * 100).round()}% định mức',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: AppDurations.slow,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => SizedBox.square(
          dimension: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Nền kính tròn sau vòng.
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5),
                child: SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: t,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(tone),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${(t * 100).round()}',
                          style: AppTypography.display(
                            fontSize: 20,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        TextSpan(
                          text: '%',
                          style: AppTypography.display(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ĐỊNH MỨC',
                    style: AppTypography.uppercase(
                      fontSize: 7.5,
                      letterSpacing: 0.6,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Viên trạng thái dưới số chính: icon theo sắc + "Còn thiếu…"/"Đã đạt…".
class _HeroStatusPill extends StatelessWidget {
  const _HeroStatusPill({
    required this.enough,
    required this.tone,
    required this.label,
  });

  final bool enough;
  final Color tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enough ? Icons.check_circle_rounded : Icons.trending_down_rounded,
            size: 14,
            color: tone,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: AppTypography.uppercaseHeight,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCell {
  const _BreakdownCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.unit,
    this.active = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color tone;

  /// Ô có số > 0: số sáng rõ; ô bằng 0 lùi xuống để mắt dừng ở ô có dữ liệu.
  final bool active;
}

/// Lưới 2×2 cơ cấu công: mỗi ô kính có icon sắc riêng, nhãn đầy đủ, số bên phải.
class _HeroBreakdown extends StatelessWidget {
  const _HeroBreakdown({required this.cells});

  final List<_BreakdownCell> cells;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_BreakdownCell>>[
      for (var i = 0; i < cells.length; i += 2)
        cells.sublist(i, (i + 2).clamp(0, cells.length)),
    ];
    return Column(
      children: [
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, c) in row.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _BreakdownTile(cell: c)),
              ],
              if (row.length == 1) ...[
                const SizedBox(width: 8),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({required this.cell});

  final _BreakdownCell cell;

  @override
  Widget build(BuildContext context) {
    final c = cell;
    final valueColor = c.active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: AppRadius.brControl,
        border: Border.all(
          color: c.active
              ? c.tone.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.tone.withValues(alpha: c.active ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              c.icon,
              size: 16,
              color: c.active ? c.tone : c.tone.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.uppercase(
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: c.value,
                          style: AppTypography.metric(
                            fontSize: 16,
                            color: valueColor,
                            height: 1.1,
                          ),
                        ),
                        if (c.unit != null)
                          TextSpan(
                            text: ' ${c.unit}',
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
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

/// Dòng ghi chú trên nền brand (bổ sung công, cảnh báo kỷ luật).
class _HeroNote extends StatelessWidget {
  const _HeroNote({
    required this.icon,
    required this.text,
    required this.tone,
    this.expand = false,
  });

  final IconData icon;
  final String text;
  final Color tone;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: AppTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: Colors.white.withValues(alpha: 0.95),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: AppRadius.brControl,
        border: Border.all(color: tone.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: 6),
          if (expand) Expanded(child: label) else Flexible(child: label),
        ],
      ),
    );
  }
}

/// 2 nút "Điều động" và "Bổ sung công" nằm trong card hero.
class _HeroActionButtons extends StatelessWidget {
  const _HeroActionButtons({
    required this.employeeId,
    required this.year,
    required this.month,
  });

  final int employeeId;
  final int year;
  final int month;

  void _openDeployment(BuildContext context) {
    final today = DateTime.now();
    final workDate = DateTime(year, month, today.day.clamp(1, 28));
    showBulkDeploymentSheet(context, workDate: workDate);
  }

  void _openSupplement(BuildContext context) {
    final today = DateTime.now();
    final workDate = DateTime(year, month, today.day.clamp(1, 28));
    showBulkDutyShiftSheet(context, workDate: workDate);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroActionBtn(
            icon: Icons.swap_horiz_rounded,
            label: 'Điều động',
            onTap: () => _openDeployment(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HeroActionBtn(
            icon: Icons.spa_rounded,
            label: 'Bổ sung công',
            onTap: () => _openSupplement(context),
          ),
        ),
      ],
    );
  }
}

/// Nút kính trắng trên nền brand, có hiệu ứng chạm.
class _HeroActionBtn extends StatelessWidget {
  const _HeroActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brControl,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: AppTypography.uppercaseHeight,
                    color: Colors.white,
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

class _MetricsStrip extends StatefulWidget {
  const _MetricsStrip({
    required this.summary,
    this.deploymentDayCount = 0,
    this.deploymentOvertimeUnits = 0,
  });

  final AttendanceMonthSummary summary;
  final int deploymentDayCount;
  final double deploymentOvertimeUnits;

  @override
  State<_MetricsStrip> createState() => _MetricsStripState();
}

class _MetricsStripState extends State<_MetricsStrip> {
  bool _expanded = false;

  AttendanceMonthSummary get s => widget.summary;

  @override
  Widget build(BuildContext context) {
    final clocked = AppFormat.workUnits(s.clockedWorkUnits);
    final meal = AppFormat.currency(s.mealAllowance);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        0,
      ),
      child: AppCard(
        elevated: true,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const TintedIconTile(
                  icon: Icons.analytics_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chỉ số tháng',
                        style: AppTypography.style(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _expanded
                            ? 'Cơ cấu công · muộn & phạt · phụ cấp'
                            : 'Công chấm · phụ cấp · vi phạm',
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.brPill,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    color: _expanded
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : AppColors.surface,
                    child: InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded ? 'Thu gọn' : 'Chi tiết',
                              style: AppTypography.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: AppTypography.uppercaseHeight,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 2),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: AppDurations.normal,
                              curve: Curves.easeOutCubic,
                              child: const Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _HighlightTile(
                    icon: Icons.fingerprint_rounded,
                    color: AppColors.info,
                    value: clocked,
                    label: 'Công chấm',
                    sub: 'Đi làm thực tế',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HighlightTile(
                    icon: Icons.restaurant_rounded,
                    color: _mealTone,
                    value: meal,
                    label: 'Phụ cấp ăn',
                    sub: s.mealAllowanceSub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _QuickStatsStrip(
              items: [
                _QuickStat(
                  label: 'Phút muộn',
                  value: '${s.lateMinutesTotal}′',
                  tone: AppColors.warning,
                  active: s.lateMinutesTotal > 0,
                ),
                _QuickStat(
                  label: 'Quên chấm',
                  value: '${s.forgotFineCount} lần',
                  tone: AppColors.error,
                  active: s.forgotFineCount > 0,
                ),
                _QuickStat(
                  label: 'Bị trừ',
                  value: AppFormat.currencyCompact(
                    s.latePenalty + s.forgotPenalty,
                  ),
                  tone: AppColors.error,
                  active: s.latePenalty + s.forgotPenalty > 0,
                ),
                _QuickStat(
                  label: 'Tiền trực',
                  value: AppFormat.currencyCompact(s.dutyBonusTotal),
                  tone: _dutyTone,
                  active: s.dutyBonusTotal > 0,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        children: [
                          _DetailGroup(
                            title: 'Cơ cấu công',
                            rows: [
                              _DetailRowData(
                                icon: Icons.beach_access_rounded,
                                color: _leaveTone,
                                label: 'Công phép',
                                value: AppFormat.workUnits(s.leaveWorkUnits),
                                sub: 'Nghỉ có lương',
                              ),
                              _DetailRowData(
                                icon: Icons.nights_stay_rounded,
                                color: _dutyTone,
                                label: 'Công trực',
                                value: s.dutyWorkUnitsTotal > 0
                                    ? '+${AppFormat.workUnits(s.dutyWorkUnitsTotal)}'
                                    : AppFormat.workUnits(s.dutyWorkUnitsTotal),
                                sub: '${s.dutyShiftCount} ca trực',
                              ),
                              _DetailRowData(
                                icon: Icons.swap_horiz_rounded,
                                color: AppColors.info,
                                label: 'Điều động',
                                value: '${widget.deploymentDayCount} ngày',
                                sub: widget.deploymentOvertimeUnits > 0
                                    ? '+${AppFormat.workUnits(widget.deploymentOvertimeUnits)} ngoài giờ'
                                    : 'Ngày gắn Đ.động',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _DetailGroup(
                            title: 'Muộn & phạt',
                            rows: [
                              _DetailRowData(
                                icon: Icons.timer_outlined,
                                color: s.lateMinutesTotal > 0
                                    ? AppColors.warning
                                    : AppColors.success,
                                label: 'Phút muộn',
                                value: '${s.lateMinutesTotal}',
                              ),
                              _DetailRowData(
                                icon: Icons.gavel_rounded,
                                color: AppColors.warning,
                                label: 'Trừ muộn',
                                value: AppFormat.currency(s.latePenalty),
                                sub: (s.latePenaltyTier ?? '').trim().isEmpty
                                    ? null
                                    : s.latePenaltyTier,
                              ),
                              _DetailRowData(
                                icon: Icons.touch_app_outlined,
                                color: s.forgotFineCount > 0
                                    ? AppColors.error
                                    : AppColors.success,
                                label: 'Quên chấm',
                                value: '${s.forgotFineCount} lần',
                              ),
                              _DetailRowData(
                                icon: Icons.money_off_rounded,
                                color: AppColors.error,
                                label: 'Trừ quên chấm',
                                value: AppFormat.currency(s.forgotPenalty),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _DetailGroup(
                            title: 'Phụ cấp & hỗ trợ',
                            rows: [
                              _DetailRowData(
                                icon: Icons.medical_services_outlined,
                                color: AppColors.info,
                                label: 'Tiền trực',
                                value: AppFormat.currency(s.dutyBonusTotal),
                                sub: '${s.dutyShiftCount} ca',
                              ),
                              _DetailRowData(
                                icon: Icons.payments_outlined,
                                color: _dutyTone,
                                label: 'Tiền hỗ trợ',
                                value: AppFormat.currency(
                                  s.seminarSupportTotal,
                                ),
                                sub: s.seminarSupportCount > 0
                                    ? '${s.seminarSupportCount} hội thảo'
                                    : null,
                              ),
                              _DetailRowData(
                                icon: Icons.local_hospital_outlined,
                                color: _leaveTone,
                                label: 'PC Quang Trung',
                                value: AppFormat.currency(
                                  s.quangTrungAllowance,
                                ),
                                sub:
                                    '${s.quangTrungAllowanceCount} ngày × ${AppFormat.currency(s.quangTrungAllowanceRate)}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.sub,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final subText = (sub ?? '').trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        gradient: TintedCardBackdrop.gradient(color),
        borderRadius: AppRadius.brCard,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TintedIconTile(icon: icon, color: color, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.uppercase(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.metric(
                fontSize: 21,
                color: Color.lerp(color, AppColors.textPrimary, 0.25)!,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subText.isEmpty ? ' ' : subText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat {
  const _QuickStat({
    required this.label,
    required this.value,
    required this.tone,
    this.active = true,
  });

  final String label;
  final String value;
  final Color tone;

  /// Có phát sinh: chấm sắc + số đậm; bằng 0: lùi xuống màu trung tính.
  final bool active;
}

/// Dải 4 cột trong rãnh nhạt: chấm sắc + nhãn in hoa, số bên dưới.
class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip({required this.items});

  final List<_QuickStat> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (i, it) in items.indexed) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.divider,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: it.active
                                  ? it.tone
                                  : AppColors.textTertiary.withValues(
                                      alpha: 0.5,
                                    ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              it.label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.uppercase(
                                fontSize: 9,
                                letterSpacing: 0.4,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          it.value,
                          maxLines: 1,
                          style: AppTypography.metric(
                            fontSize: 14.5,
                            color: it.active
                                ? Color.lerp(
                                    it.tone,
                                    AppColors.textPrimary,
                                    0.25,
                                  )!
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.sub,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? sub;
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.title, required this.rows});

  final String title;
  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border.withValues(alpha: 0.55),
                  ),
                _DetailRow(data: rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.data});

  final _DetailRowData data;

  @override
  Widget build(BuildContext context) {
    final sub = (data.sub ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brControl,
              border: Border.all(color: data.color.withValues(alpha: 0.18)),
            ),
            child: Icon(data.icon, size: 16, color: data.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            data.value,
            style: AppTypography.metric(
              fontSize: 15,
              color: Color.lerp(data.color, AppColors.textPrimary, 0.2)!,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.employeeId,
    this.employeeName,
    required this.day,
    this.duty,
    this.isContinuousDay = false,
    this.isSplitDay = false,
  });

  final int employeeId;
  final String? employeeName;
  final AttendanceDay day;
  final DutyShiftEntry? duty;
  final bool isContinuousDay;
  final bool isSplitDay;

  static const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  Color _statusColor(String? status) {
    return switch (status) {
      'PRESENT' => AppColors.success,
      'PARTIAL' => AppColors.warning,
      'ABSENT' => AppColors.error,
      'LEAVE' || 'SEMINAR' || 'DEPLOYMENT' => AppColors.info,
      'BUSINESS_TRIP' => AppColors.warning,
      _ => AppColors.textTertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = day.workDate;
    final isWeekend = date != null && date.weekday >= 6;
    final late = day.lateMinutes;
    final showLate = late > 0 && !day.lateMinutesExempt;
    final hasMorning =
        day.morningCheckIn != null || day.morningCheckOut != null;
    final hasAfternoon =
        day.afternoonCheckIn != null || day.afternoonCheckOut != null;
    final hasLegacyOnly =
        !hasMorning &&
        !hasAfternoon &&
        (day.checkIn != null || day.checkOut != null);
    final accent = _statusColor(day.status);
    final now = DateTime.now();
    final isToday =
        date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final displayUnits = day.totalWorkUnits + (duty?.workUnits ?? 0);

    final tags = <Widget>[
      if (day.isLeaveDay)
        const _DayTag(
          label: 'Phép',
          color: _leaveTone,
          icon: Icons.beach_access_rounded,
        ),
      if (isContinuousDay)
        const _DayTag(
          label: 'Thông tầm',
          color: AppColors.success,
          icon: Icons.timeline_rounded,
        ),
      if (isSplitDay)
        const _DayTag(
          label: 'Sáng–chiều',
          color: AppColors.primaryDark,
          icon: Icons.call_split_rounded,
        ),
      if (day.isDeploymentDay)
        const _DayTag(
          label: 'Điều động',
          color: AppColors.info,
          icon: Icons.swap_horiz_rounded,
        ),
      if (duty != null)
        _DayTag(
          label: 'Trực',
          color: _dutyTone,
          icon: Icons.nights_stay_rounded,
          tooltip: duty!.shiftTypeLabel,
        ),
      if (day.overtimeWorkUnits > 0)
        _DayTag(
          label: 'Ngoài giờ ${AppFormat.workUnits(day.overtimeWorkUnits)}',
          color: AppColors.info,
          icon: Icons.more_time_rounded,
        ),
      if (day.youngChild)
        const _DayTag(
          label: 'Con nhỏ',
          color: _youngChildTone,
          icon: Icons.child_care_rounded,
        ),
      if (day.quangTrung)
        const _DayTag(
          label: 'Quang Trung',
          color: _quangTrungTone,
          icon: Icons.local_hospital_outlined,
        ),
      if (day.lateMinutesExempt && late > 0)
        const _DayTag(
          label: 'Miễn muộn',
          color: AppColors.success,
          icon: Icons.verified_rounded,
        ),
      if (showLate)
        _DayTag(
          label: 'Muộn $late′',
          color: AppColors.warning,
          icon: Icons.timer_outlined,
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showAttendanceDayDetailSheet(
          context,
          day: day,
          employeeId: employeeId,
          employeeName: employeeName,
        ),
        borderRadius: AppRadius.brLg,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: TintedCardBackdrop.gradient(accent),
            borderRadius: AppRadius.brLg,
            border: Border.all(
              color: isToday
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : accent.withValues(alpha: 0.16),
              width: isToday ? 1.4 : 1,
            ),
            boxShadow: isToday
                ? AppShadows.tinted(AppColors.primary)
                : AppShadows.soft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBadge(
                day: date == null ? '--' : date.day.toString().padLeft(2, '0'),
                weekday: date == null ? '' : _weekdayShort[date.weekday - 1],
                isToday: isToday,
                isWeekend: isWeekend,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(
                      label: day.statusLabel,
                      color: accent,
                      icon: switch (day.status) {
                        'PRESENT' => Icons.check_circle_rounded,
                        'ABSENT' => Icons.cancel_rounded,
                        'PARTIAL' => Icons.timelapse_rounded,
                        _ => Icons.circle,
                      },
                    ),
                    const SizedBox(height: 8),
                    if (hasMorning || hasAfternoon) ...[
                      _ShiftLine(
                        icon: Icons.wb_sunny_rounded,
                        color: _morningShiftTone,
                        label: 'Sáng',
                        from: day.morningCheckIn,
                        to: day.morningCheckOut,
                      ),
                      const SizedBox(height: 4),
                      _ShiftLine(
                        icon: Icons.nightlight_round,
                        color: _afternoonShiftTone,
                        label: 'Chiều',
                        from: day.afternoonCheckIn,
                        to: day.afternoonCheckOut,
                      ),
                    ] else if (hasLegacyOnly)
                      _ShiftLine(
                        icon: Icons.schedule_rounded,
                        color: AppColors.info,
                        label: 'Ca',
                        from: day.checkIn,
                        to: day.checkOut,
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            duty != null
                                ? Icons.nights_stay_rounded
                                : Icons.fingerprint_rounded,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              duty != null
                                  ? (duty!.shiftTypeLabel ?? 'Ca trực')
                                  : 'Chưa có dữ liệu chấm công',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Wrap(spacing: 5, runSpacing: 5, children: tags),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _UnitsColumn(units: displayUnits),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sắc riêng cho mốc giờ ca sáng / chiều trên thẻ ngày.
const Color _morningShiftTone = Color(0xFFD97706);
const Color _afternoonShiftTone = Color(0xFF7C3AED);

/// Viên trạng thái ngày (Có mặt / Vắng / Thiếu ca…).
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 8 : 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              height: AppTypography.uppercaseHeight,
              color: Color.lerp(color, AppColors.textPrimary, 0.2)!,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng mốc giờ: icon ca + nhãn ca + giờ vào → ra (mốc thiếu hiện "—" nhạt).
class _ShiftLine extends StatelessWidget {
  const _ShiftLine({
    required this.icon,
    required this.color,
    required this.label,
    this.from,
    this.to,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    final none = from == null && to == null;
    Widget time(String? v) => Text(
      v ?? '—',
      style: AppTypography.metric(
        fontSize: 13.5,
        color: v == null ? AppColors.textTertiary : AppColors.textPrimary,
      ),
    );

    return Opacity(
      opacity: none ? 0.6 : 1,
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          time(from),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 12,
              color: AppColors.textTertiary,
            ),
          ),
          time(to),
        ],
      ),
    );
  }
}

/// Cột phải thẻ ngày: số công cỡ lớn + nhãn "CÔNG" + mũi tên mở chi tiết.
class _UnitsColumn extends StatelessWidget {
  const _UnitsColumn({required this.units});

  final double units;

  @override
  Widget build(BuildContext context) {
    final has = units > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          AppFormat.workUnits(units),
          style: AppTypography.metric(
            fontSize: 19,
            color: has ? AppColors.primaryDark : AppColors.textTertiary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'CÔNG',
          style: AppTypography.uppercase(
            fontSize: 8.5,
            letterSpacing: 0.8,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.textTertiary,
        ),
      ],
    );
  }
}

/// Ô ngày bên trái thẻ: số ngày + thứ. Hôm nay đặc màu brand, cuối tuần sắc đỏ.
class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.day,
    required this.weekday,
    required this.isToday,
    required this.isWeekend,
  });

  final String day;
  final String weekday;
  final bool isToday;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    final tone = isWeekend ? AppColors.error : AppColors.primary;
    final Color numColor = isToday
        ? Colors.white
        : (isWeekend ? AppColors.errorDark : AppColors.primaryDark);
    final Color subColor = isToday
        ? Colors.white.withValues(alpha: 0.85)
        : tone.withValues(alpha: 0.8);

    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: isToday
            ? AppGradients.brand
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tone.withValues(alpha: 0.14),
                  tone.withValues(alpha: 0.05),
                ],
              ),
        borderRadius: AppRadius.brMd,
        border: isToday
            ? null
            : Border.all(color: tone.withValues(alpha: 0.14)),
        boxShadow: isToday ? AppShadows.tinted(AppColors.primary) : null,
      ),
      child: Column(
        children: [
          Text(day, style: AppTypography.metric(fontSize: 19, color: numColor)),
          const SizedBox(height: 2),
          Text(
            isToday ? 'HÔM NAY' : weekday,
            maxLines: 1,
            style: AppTypography.uppercase(
              fontSize: isToday ? 8 : 10.5,
              letterSpacing: isToday ? 0.4 : 0.3,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTag extends StatelessWidget {
  const _DayTag({
    required this.label,
    required this.color,
    this.icon,
    this.tooltip,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: AppTypography.uppercaseHeight,
              color: Color.lerp(color, AppColors.textPrimary, 0.2)!,
            ),
          ),
        ],
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
