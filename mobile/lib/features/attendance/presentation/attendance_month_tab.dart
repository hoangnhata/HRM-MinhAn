import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_month_controller.dart';
import '../application/attendance_schedule_provider.dart';
import 'attendance_day_detail_sheet.dart';
import 'attendance_schedule_panel.dart';

/// Số công chuẩn một tháng — dưới mức này coi là thiếu công.
const double _standardWorkUnits = 26;

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
    final controller =
        ref.read(attendanceMonthControllerProvider(employeeId).notifier);
    final role = ref.watch(authControllerProvider).role;
    final canAssignContinuous =
        role == UserRole.admin || role == UserRole.headDepartment;
    final canProposeYoungChild =
        role == UserRole.admin || role == UserRole.headDepartment;
    final canManageDutyQuangTrung =
        role == UserRole.admin || role == UserRole.headDepartment;

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
                child: SkeletonList(itemCount: 1, showAvatar: false),
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
    required this.year,
    required this.month,
    required this.days,
    required this.dutyByDate,
    this.continuousDates = const {},
    this.splitDates = const {},
  });

  final int employeeId;
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
        return wd.year == today.year && wd.month == today.month && wd.day == today.day;
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
        AppSectionTitle(
          title: 'Chi tiết theo ngày',
          icon: Icons.calendar_view_day_rounded,
          action: InkWell(
            borderRadius: AppRadius.brPill,
            onTap: total <= 1
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: AppRadius.brPill,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? 'Thu gọn' : 'Xem tất cả',
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$visibleCount/$total',
                    style: AppTypography.caption(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.xs,
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
                      day: day,
                      duty: widget.dutyByDate[_dayKey(day)],
                      isContinuousDay: widget.continuousDates.contains(
                        _dayKey(day),
                      ),
                      isSplitDay: widget.splitDates.contains(_dayKey(day)),
                    ),
                  ],
                  if (showTodayOnly)
                    const SizedBox(height: 2),
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

  static const _monthNames = [
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  Future<void> _openPicker(BuildContext context) async {
    if (loading) return;
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthYearPickerSheet(year: year, month: month),
    );
    if (picked == null) return;
    onPickMonth(picked.$1, picked.$2);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final label = '${_monthNames[month - 1]} $year';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : () => _openPicker(context),
          borderRadius: AppRadius.brMd,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.style(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          letterSpacing: -0.2,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isCurrentMonth
                            ? 'Tháng hiện tại · chạm để đổi'
                            : 'Chạm để chọn tháng / năm',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  static const _monthShort = [
    'T1',
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'T8',
    'T9',
    'T10',
    'T11',
    'T12',
  ];

  late int _year;
  late int _month;
  final now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
  }

  bool _isFuture(int year, int month) =>
      year > now.year || (year == now.year && month > now.month);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        10,
        AppSpacing.page,
        bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.35),
              borderRadius: AppRadius.brPill,
            ),
          ),
          Text(
            'Chọn tháng / năm',
            style: AppTypography.style(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _YearNavButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => setState(() {
                  _year -= 1;
                }),
              ),
              Expanded(
                child: Text(
                  'Năm $_year',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              _YearNavButton(
                icon: Icons.chevron_right_rounded,
                onPressed: _year >= now.year
                    ? null
                    : () => setState(() {
                          _year += 1;
                          if (_isFuture(_year, _month)) {
                            _month = now.month;
                          }
                        }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final m = index + 1;
              final isSelected = m == _month;
              final disabled = _isFuture(_year, m);
              final isCurrent = _year == now.year && m == now.month;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: disabled
                      ? null
                      : () => setState(() => _month = m),
                  borderRadius: AppRadius.brMd,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : disabled
                              ? AppColors.surfaceMuted
                              : AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: AppRadius.brMd,
                      border: Border.all(
                        color: isCurrent && !isSelected
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _monthShort[index],
                        style: AppTypography.style(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : disabled
                                  ? AppColors.textTertiary
                                  : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd,
                    ),
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: FilledButton(
                  onPressed: _isFuture(_year, _month)
                      ? null
                      : () => Navigator.pop(context, (_year, _month)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd,
                    ),
                  ),
                  child: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YearNavButton extends StatelessWidget {
  const _YearNavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null
          ? AppColors.surfaceMuted
          : AppColors.primary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: onPressed == null
                ? AppColors.textTertiary
                : AppColors.primary,
          ),
        ),
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
    final percent = (ratio * 100).round();

    return Padding(
      padding: AppSpacing.pageH,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          gradient: AppGradients.brand,
          borderRadius: AppRadius.brXl,
          boxShadow: AppShadows.tinted(AppColors.primary),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -28,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 36,
              bottom: -42,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: AppRadius.brMd,
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TỔNG CÔNG THÁNG',
                            style: AppTypography.style(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.65,
                            ),
                          ),
                          Text(
                            'Định mức ${AppFormat.compactNumber(_standardWorkUnits)} công',
                            style: AppTypography.style(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            enough
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            enough ? 'Đủ công' : 'Thiếu công',
                            style: AppTypography.style(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: AppFormat.compactNumber(total),
                                style: AppTypography.metric(
                                  fontSize: 36,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: ' công',
                                style: AppTypography.style(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: AppTypography.style(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: AppRadius.brPill,
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(
                      enough
                          ? Colors.white
                          : AppColors.secondaryLight.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _HeroBreakdownChip(
                      label: '${AppFormat.compactNumber(summary.clockedWorkUnits)} chấm',
                    ),
                    _HeroBreakdownChip(
                      label: '${AppFormat.compactNumber(summary.leaveWorkUnits)} phép',
                    ),
                    _HeroBreakdownChip(
                      label: '${AppFormat.compactNumber(summary.dutyWorkUnitsTotal)} trực',
                    ),
                    _HeroBreakdownChip(
                      label: '$deploymentDayCount đ.động',
                      highlighted: deploymentDayCount > 0,
                    ),
                    if (_supplementCount > 0)
                      _HeroBreakdownChip(
                        label: '$_supplementCount bổ sung',
                        highlighted: true,
                        icon: Icons.add_circle_outline_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  enough
                      ? 'Bạn đã đạt định mức công tháng này.'
                      : 'Còn thiếu ${AppFormat.compactNumber(missing)} công so với định mức tháng.',
                  style: AppTypography.style(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (summary.requiresDiscipline) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.gavel_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Có vi phạm cần xem xét kỷ luật',
                            style: AppTypography.style(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // ── Action buttons: Điều động & Bổ sung công ──
                if (canManageSupplements) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 10),
                  _HeroActionButtons(
                    employeeId: employeeId,
                    year: year,
                    month: month,
                  ),
                ],
              ],
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: AppRadius.brMd,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBreakdownChip extends StatelessWidget {
  const _HeroBreakdownChip({
    required this.label,
    this.highlighted = false,
    this.icon,
  });

  final String label;
  /// Khi true, chip nổi bật hơn (màu trắng đậm hơn).
  final bool highlighted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 7 : 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.95)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
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
    final clocked = AppFormat.compactNumber(s.clockedWorkUnits);
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
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chỉ số tháng',
                        style: AppTypography.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        _expanded
                            ? 'Đầy đủ công · phạt · phụ cấp'
                            : '2 chỉ số chính — mở để xem thêm',
                        style: AppTypography.style(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brPill,
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: AppRadius.brPill,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? 'Thu gọn' : 'Chi tiết',
                            style: AppTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.primaryDark,
                          ),
                        ],
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
                    color: const Color(0xFFE65100),
                    value: meal,
                    label: 'Phụ cấp ăn',
                    sub: s.mealAllowanceSub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _QuickPill(
                  label: 'Phép ${AppFormat.compactNumber(s.leaveWorkUnits)}',
                  color: const Color(0xFF0F766E),
                ),
                _QuickPill(
                  label:
                      'Trực ${AppFormat.compactNumber(s.dutyWorkUnitsTotal)}',
                  color: const Color(0xFF7C3AED),
                ),
                _QuickPill(
                  label: 'Đ.động ${widget.deploymentDayCount} ngày',
                  color: AppColors.info,
                ),
                _QuickPill(
                  label: 'Muộn ${s.lateMinutesTotal}′',
                  color: s.lateMinutesTotal > 0
                      ? AppColors.warning
                      : AppColors.success,
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
                                color: const Color(0xFF0F766E),
                                label: 'Công phép',
                                value: AppFormat.compactNumber(
                                  s.leaveWorkUnits,
                                ),
                                sub: 'Nghỉ có lương',
                              ),
                              _DetailRowData(
                                icon: Icons.nights_stay_rounded,
                                color: const Color(0xFF7C3AED),
                                label: 'Công trực',
                                value: s.dutyWorkUnitsTotal > 0
                                    ? '+${AppFormat.compactNumber(s.dutyWorkUnitsTotal)}'
                                    : AppFormat.compactNumber(
                                        s.dutyWorkUnitsTotal,
                                      ),
                                sub: '${s.dutyShiftCount} ca trực',
                              ),
                              _DetailRowData(
                                icon: Icons.swap_horiz_rounded,
                                color: AppColors.info,
                                label: 'Điều động',
                                value: '${widget.deploymentDayCount} ngày',
                                sub: widget.deploymentOvertimeUnits > 0
                                    ? '+${AppFormat.compactNumber(widget.deploymentOvertimeUnits)} ngoài giờ'
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
                                color: const Color(0xFF7C3AED),
                                label: 'Tiền hỗ trợ',
                                value:
                                    AppFormat.currency(s.seminarSupportTotal),
                                sub: s.seminarSupportCount > 0
                                    ? '${s.seminarSupportCount} hội thảo'
                                    : null,
                              ),
                              _DetailRowData(
                                icon: Icons.local_hospital_outlined,
                                color: const Color(0xFF0F766E),
                                label: 'PC Quang Trung',
                                value:
                                    AppFormat.currency(s.quangTrungAllowance),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (sub ?? '').trim().isEmpty ? ' ' : sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10.5,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
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
              borderRadius: BorderRadius.circular(9),
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
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: data.color,
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
    required this.day,
    this.duty,
    this.isContinuousDay = false,
    this.isSplitDay = false,
  });

  final int employeeId;
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
    final hasLegacyOnly = !hasMorning &&
        !hasAfternoon &&
        (day.checkIn != null || day.checkOut != null);
    final accent = _statusColor(day.status);
    final attUnits = day.totalWorkUnits;
    final dutyUnits = duty?.workUnits ?? 0;
    final displayUnits = attUnits + dutyUnits;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showAttendanceDayDetailSheet(
          context,
          day: day,
          employeeId: employeeId,
        ),
        borderRadius: AppRadius.brLg,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brLg,
            border: Border.all(
              color: accent.withValues(alpha: 0.14),
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: isWeekend
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.14),
                            AppColors.primary.withValues(alpha: 0.06),
                          ],
                        ),
                  color: isWeekend ? AppColors.errorLight : null,
                  borderRadius: AppRadius.brMd,
                ),
                child: Column(
                  children: [
                    Text(
                      date == null
                          ? '--'
                          : date.day.toString().padLeft(2, '0'),
                      style: AppTypography.style(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isWeekend
                            ? AppColors.errorDark
                            : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      date == null ? '' : _weekdayShort[date.weekday - 1],
                      style: AppTypography.style(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isWeekend
                            ? AppColors.error
                            : AppColors.primary.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasMorning || hasAfternoon)
                      _CompactShiftTimes(
                        morningFrom: hasMorning ? day.morningCheckIn : null,
                        morningTo: hasMorning ? day.morningCheckOut : null,
                        afternoonFrom:
                            hasAfternoon ? day.afternoonCheckIn : null,
                        afternoonTo:
                            hasAfternoon ? day.afternoonCheckOut : null,
                      )
                    else if (hasLegacyOnly)
                      _ShiftTimeLine(
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.info,
                        label: 'Ca',
                        from: day.checkIn,
                        to: day.checkOut,
                      )
                    else
                      Text(
                        duty != null
                            ? (duty!.shiftTypeLabel ?? 'Ca trực')
                            : 'Chưa có dữ liệu chấm công',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: day.statusLabel,
                          color: accent,
                          dense: true,
                          showDot: false,
                          icon: day.status == 'PRESENT'
                              ? Icons.check_rounded
                              : day.status == 'ABSENT'
                                  ? Icons.close_rounded
                                  : null,
                        ),
                        _DayTag(
                          label:
                              '${AppFormat.compactNumber(displayUnits)} công',
                          color: AppColors.primary,
                          emphasized: true,
                        ),
                        if (day.isLeaveDay)
                          const _DayTag(
                            label: 'Phép',
                            color: Color(0xFF0F766E),
                            icon: Icons.beach_access_rounded,
                          ),
                        if (isContinuousDay)
                          const _DayTag(
                            label: 'TT',
                            color: AppColors.success,
                            icon: Icons.timeline_rounded,
                          ),
                        if (isSplitDay)
                          const _DayTag(
                            label: 'SC',
                            color: AppColors.primaryDark,
                            icon: Icons.schedule_rounded,
                          ),
                        if (day.isDeploymentDay)
                          const _DayTag(
                            label: 'Đ.động',
                            color: AppColors.info,
                            icon: Icons.swap_horiz_rounded,
                          ),
                        if (duty != null)
                          _DayTag(
                            label: 'Trực',
                            color: const Color(0xFF7C3AED),
                            icon: Icons.nights_stay_rounded,
                            tooltip: duty!.shiftTypeLabel,
                          ),
                        if (day.overtimeWorkUnits > 0)
                          _DayTag(
                            label:
                                'Ngoài giờ ${day.overtimeWorkUnits.toStringAsFixed(2).replaceAll('.', ',')}',
                            color: AppColors.info,
                          ),
                        if (day.youngChild)
                          const _DayTag(
                            label: 'Con nhỏ',
                            color: Color(0xFFC2410C),
                            icon: Icons.child_care_rounded,
                          ),
                        if (day.quangTrung)
                          const _DayTag(
                            label: 'QT',
                            color: Color(0xFF0F766E),
                            icon: Icons.local_hospital_outlined,
                          ),
                        if (day.lateMinutesExempt && late > 0)
                          const _DayTag(
                            label: 'Miễn muộn',
                            color: AppColors.success,
                          ),
                        if (showLate)
                          _DayTag(
                            label: 'Muộn $late phút',
                            color: AppColors.warning,
                            icon: Icons.schedule_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayTag extends StatelessWidget {
  const _DayTag({
    required this.label,
    required this.color,
    this.icon,
    this.emphasized = false,
    this.tooltip,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool emphasized;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.12 : 0.08),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

class _CompactShiftTimes extends StatelessWidget {
  const _CompactShiftTimes({
    this.morningFrom,
    this.morningTo,
    this.afternoonFrom,
    this.afternoonTo,
  });

  final String? morningFrom;
  final String? morningTo;
  final String? afternoonFrom;
  final String? afternoonTo;

  @override
  Widget build(BuildContext context) {
    final morning = morningFrom != null || morningTo != null;
    final afternoon = afternoonFrom != null || afternoonTo != null;

    return Row(
      children: [
        if (morning)
          Expanded(
            child: _MiniShift(
              icon: Icons.wb_sunny_rounded,
              color: AppColors.primary,
              from: morningFrom,
              to: morningTo,
            ),
          ),
        if (morning && afternoon) const SizedBox(width: 8),
        if (afternoon)
          Expanded(
            child: _MiniShift(
              icon: Icons.nightlight_round,
              color: AppColors.secondary,
              from: afternoonFrom,
              to: afternoonTo,
            ),
          ),
      ],
    );
  }
}

class _MiniShift extends StatelessWidget {
  const _MiniShift({
    required this.icon,
    required this.color,
    this.from,
    this.to,
  });

  final IconData icon;
  final Color color;
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${from ?? '—'}→${to ?? '—'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftTimeLine extends StatelessWidget {
  const _ShiftTimeLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.from,
    required this.to,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${from ?? '—'}  →  ${to ?? '—'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}
