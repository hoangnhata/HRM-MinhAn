import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/attendance_models.dart';
import '../../../shared/models/employee.dart';
import '../../auth/application/auth_controller.dart';
import '../../employees/data/department_repository.dart';
import '../../employees/presentation/org_unit_picker.dart';
import '../application/department_attendance_controller.dart';

const _morning = Color(0xFFC2410C);
const _afternoon = Color(0xFF15803D);
const _leave = Color(0xFFB45309);
const _duty = Color(0xFFCA8A04);
const _quangTrung = Color(0xFF2563EB);

class DepartmentAttendanceScreen extends ConsumerStatefulWidget {
  const DepartmentAttendanceScreen({super.key, this.initialYear, this.initialMonth});

  final int? initialYear;
  final int? initialMonth;

  @override
  ConsumerState<DepartmentAttendanceScreen> createState() =>
      _DepartmentAttendanceScreenState();
}

class _DepartmentAttendanceScreenState
    extends ConsumerState<DepartmentAttendanceScreen> {
  final _search = TextEditingController();
  bool _appliedInitialMonth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appliedInitialMonth) return;
      final y = widget.initialYear;
      final m = widget.initialMonth;
      if (y != null && m != null) {
        _appliedInitialMonth = true;
        ref.read(departmentAttendanceControllerProvider.notifier).setMonth(y, m);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _deptLocked {
    final auth = ref.read(authControllerProvider);
    return auth.role == UserRole.headDepartment &&
        auth.currentUser?.departmentId != null;
  }

  Future<void> _pickDepartment() async {
    if (_deptLocked) return;
    final depts = await ref.read(departmentListProvider.future);
    if (!mounted) return;
    final current = ref.read(departmentAttendanceControllerProvider).departmentId;
    final picked = await showDepartmentPicker(
      context,
      departments: depts,
      selectedId: current,
      allowClear: true,
      title: 'Khoa / phòng',
    );
    if (picked == null) return;
    await ref.read(departmentAttendanceControllerProvider.notifier).setDepartment(
          picked.cleared ? null : picked.department?.id,
        );
  }

  Future<void> _pickMonth() async {
    final state = ref.read(departmentAttendanceControllerProvider);
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthYearSheet(year: state.year, month: state.month),
    );
    if (picked == null) return;
    await ref
        .read(departmentAttendanceControllerProvider.notifier)
        .setMonth(picked.$1, picked.$2);
  }

  void _openEmployee(AttendanceMatrixRow row) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeeMonthSheet(
        row: row,
        year: ref.read(departmentAttendanceControllerProvider).year,
        month: ref.read(departmentAttendanceControllerProvider).month,
        daysInMonth:
            ref.read(departmentAttendanceControllerProvider).matrix?.daysInMonth ??
                DateTime(
                  ref.read(departmentAttendanceControllerProvider).year,
                  ref.read(departmentAttendanceControllerProvider).month + 1,
                  0,
                ).day,
        onOpenDetail: () {
          Navigator.pop(ctx);
          context.pop(
            EmployeeSummary(
              id: row.employeeId,
              fullName: row.fullName,
              employeeCode: row.employeeCode,
              departmentName: row.department,
              positionTitle: row.position,
              status: row.employeeStatus,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(departmentAttendanceControllerProvider);
    final rows = state.visibleRows;
    final matrix = state.matrix;
    final deptName = matrix?.departmentName ??
        (_deptLocked
            ? (ref.watch(authControllerProvider).currentUser?.departmentName ??
                'Khoa của tôi')
            : 'Toàn bệnh viện');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.75)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: 'Bảng công theo khoa',
                icon: Icons.table_chart_outlined,
                eyebrow: 'Công tháng',
                subtitle: '${AppFormat.monthLabelVi(DateTime(state.year, state.month))} · $deptName',
                onBack: () => context.pop(),
                trailing: IconButton(
                  tooltip: 'Làm mới',
                  onPressed: state.loading
                      ? null
                      : () => ref
                          .read(departmentAttendanceControllerProvider.notifier)
                          .load(),
                  icon: state.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  10,
                  AppSpacing.page,
                  0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _FilterChip(
                          icon: Icons.calendar_month_rounded,
                          label: 'Tháng ${state.month}/${state.year}',
                          onTap: _pickMonth,
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _FilterChip(
                          icon: Icons.apartment_rounded,
                          label: state.departmentId == null && !_deptLocked
                              ? 'Tất cả khoa'
                              : deptName,
                          locked: _deptLocked,
                          onTap: _pickDepartment,
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppSearchField(
                      controller: _search,
                      hintText: 'Tìm tên hoặc mã nhân viên',
                      dense: true,
                      onChanged: (v) => ref
                          .read(departmentAttendanceControllerProvider.notifier)
                          .setQuery(v),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(state, rows)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DepartmentAttendanceState state, List<AttendanceMatrixRow> rows) {
    if (state.loading && state.matrix == null) {
      return const SkeletonList(itemCount: 6);
    }
    if (state.error != null && state.matrix == null) {
      return ErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(departmentAttendanceControllerProvider.notifier).load(),
      );
    }
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Không có nhân viên',
        message: state.query.isEmpty
            ? 'Khoa/phòng này chưa có dữ liệu công tháng đã chọn.'
            : 'Không khớp “${state.query}”. Thử tên hoặc mã khác.',
      );
    }

    final daysInMonth = state.matrix?.daysInMonth ??
        DateTime(state.year, state.month + 1, 0).day;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(departmentAttendanceControllerProvider.notifier).load(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          12,
          AppSpacing.page,
          32,
        ),
        itemCount: rows.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SummaryStrip(
              count: rows.length,
              totalShown: state.matrix?.rows.length ?? rows.length,
              year: state.year,
              month: state.month,
            );
          }
          if (index == 1) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _Legend(),
            );
          }
          final row = rows[index - 2];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EmployeeCard(
              row: row,
              year: state.year,
              month: state.month,
              daysInMonth: daysInMonth,
              onTap: () => _openEmployee(row),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                locked ? Icons.lock_outline_rounded : Icons.expand_more_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.count,
    required this.totalShown,
    required this.year,
    required this.month,
  });

  final int count;
  final int totalShown;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            '$count nhân viên',
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (count != totalShown) ...[
            const SizedBox(width: 6),
            Text(
              '/ $totalShown',
              style: AppTypography.style(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          Text(
            AppFormat.monthLabelVi(DateTime(year, month)),
            style: AppTypography.style(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: const [
        _LegendDot(color: _morning, label: 'Sáng'),
        _LegendDot(color: _afternoon, label: 'Chiều'),
        _LegendDot(color: _leave, label: 'Nghỉ'),
        _LegendDot(color: _duty, label: 'Công trực'),
        _LegendDot(color: _quangTrung, label: 'Quang Trung'),
        _LegendDot(color: AppColors.primary, label: 'Hôm nay', hollow: true),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.hollow = false,
  });

  final Color color;
  final String label;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hollow ? Colors.transparent : color,
            border: Border.all(color: color, width: hollow ? 1.6 : 0),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.row,
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.onTap,
  });

  final AttendanceMatrixRow row;
  final int year;
  final int month;
  final int daysInMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stats = row.stats(daysInMonth);
    final meta = [
      if (row.position.isNotEmpty) row.position,
      if (row.employeeCode.isNotEmpty) row.employeeCode,
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      accentColor: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: row.fullName, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (row.department.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.department,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TotalUnitsBadge(units: stats.totalUnits),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Chấm công',
                  value: AppFormat.workUnits(stats.attendanceUnits),
                  hint: 'Chưa gồm trực',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatBox(
                  label: 'Công trực',
                  value: AppFormat.workUnits(stats.dutyUnits),
                  hint: '${stats.dutyCount} ca',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatBox(
                  label: 'Quang Trung',
                  value: AppFormat.workUnits(stats.quangTrungUnits),
                  hint: '${stats.quangTrungDays} ngày',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WeekStrip(row: row, year: year, month: month),
          if (stats.leaveDays > 0 ||
              stats.lateMinutes > 0 ||
              stats.missingUnits > 0 ||
              row.dutyBonusTotal > 0 ||
              row.dutyPostPayTotal > 0 ||
              row.quangTrungAllowance > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (stats.leaveDays > 0)
                  StatusChip(
                    label: 'Nghỉ ${stats.leaveDays} ngày',
                    color: _leave,
                    dense: true,
                  ),
                if (stats.missingUnits > 0)
                  StatusChip(
                    label: 'Thiếu ${AppFormat.workUnits(stats.missingUnits)} công',
                    color: AppColors.error,
                    dense: true,
                  ),
                if (stats.lateMinutes > 0)
                  StatusChip(
                    label: 'Muộn ${stats.lateCount} lần · ${stats.lateMinutes}’',
                    color: AppColors.warning,
                    dense: true,
                  ),
                if (row.dutyBonusTotal > 0)
                  StatusChip(
                    label: 'Thưởng trực ${AppFormat.currency(row.dutyBonusTotal)}',
                    color: AppColors.primary,
                    dense: true,
                  ),
                if (row.dutyPostPayTotal > 0)
                  StatusChip(
                    label: 'Sau trực ${AppFormat.currency(row.dutyPostPayTotal)}',
                    color: AppColors.primary,
                    dense: true,
                  ),
                if (row.quangTrungAllowance > 0)
                  StatusChip(
                    label: 'PC QT ${AppFormat.currency(row.quangTrungAllowance)}',
                    color: _quangTrung,
                    dense: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalUnitsBadge extends StatelessWidget {
  const _TotalUnitsBadge({required this.units});

  final double units;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.brSm,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppFormat.workUnits(units),
              maxLines: 1,
              softWrap: false,
              style: AppTypography.style(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
                tabular: true,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'công',
              maxLines: 1,
              softWrap: false,
              style: AppTypography.style(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brSm,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              tabular: true,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 1),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 9.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.row,
    required this.year,
    required this.month,
  });

  final AttendanceMatrixRow row;
  final int year;
  final int month;

  static const _wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inMonth = today.year == year && today.month == month
        ? today
        : DateTime(year, month, 1);
    final monday = inMonth.subtract(Duration(days: inMonth.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final byDate = row.dayByDate;
    final duty = row.dutyByDate;

    return Row(
      children: [
        for (final (i, d) in days.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _DayCell(
              date: d,
              weekday: _wd[i],
              inMonth: d.month == month,
              today: d == today,
              day: byDate[_iso(d)],
              duty: duty[_iso(d)],
            ),
          ),
        ],
      ],
    );
  }
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Color _dayColor(AttendanceMatrixDay? day, AttendanceMatrixDutyDay? duty) {
  if (duty != null) return _duty;
  if (day == null) return AppColors.surfaceHigh;
  if (day.quangTrung) return _quangTrung;
  if (day.isLeave) return _leave;
  if (day.morningWorkUnits > 0 && day.afternoonWorkUnits <= 0) return _morning;
  if (day.afternoonWorkUnits > 0 && day.morningWorkUnits <= 0) {
    return _afternoon;
  }
  if (day.totalWorkUnits > 0) return AppColors.primary;
  if ((day.status ?? '').isNotEmpty) return AppColors.info;
  return AppColors.surfaceHigh;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.weekday,
    required this.inMonth,
    required this.today,
    this.day,
    this.duty,
  });

  final DateTime date;
  final String weekday;
  final bool inMonth;
  final bool today;
  final AttendanceMatrixDay? day;
  final AttendanceMatrixDutyDay? duty;

  @override
  Widget build(BuildContext context) {
    final color = _dayColor(day, duty);
    final filled = duty != null || (day != null && (day!.totalWorkUnits > 0 || day!.isLeave));
    return Opacity(
      opacity: inMonth ? 1 : 0.35,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.12) : AppColors.surfaceMuted,
          borderRadius: AppRadius.brSm,
          border: Border.all(
            color: today ? AppColors.primary : Colors.transparent,
            width: today ? 1.4 : 0,
          ),
        ),
        child: Column(
          children: [
            Text(
              weekday,
              style: AppTypography.style(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: filled ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeMonthSheet extends StatefulWidget {
  const _EmployeeMonthSheet({
    required this.row,
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.onOpenDetail,
  });

  final AttendanceMatrixRow row;
  final int year;
  final int month;
  final int daysInMonth;
  final VoidCallback onOpenDetail;

  @override
  State<_EmployeeMonthSheet> createState() => _EmployeeMonthSheetState();
}

class _EmployeeMonthSheetState extends State<_EmployeeMonthSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.year == widget.year && now.month == widget.month) {
      _selected = _iso(now);
    } else {
      _selected = _iso(DateTime(widget.year, widget.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final stats = row.stats(widget.daysInMonth);
    final day = row.dayByDate[_selected];
    final duty = row.dutyByDate[_selected];
    final h = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.brPill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(name: row.fullName, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (row.position.isNotEmpty) row.position,
                          if (row.department.isNotEmpty) row.department,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _TotalUnitsBadge(units: stats.totalUnits),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                _MonthHeatmap(
                  year: widget.year,
                  month: widget.month,
                  daysInMonth: widget.daysInMonth,
                  row: row,
                  selected: _selected,
                  onSelect: (iso) => setState(() => _selected = iso),
                ),
                const SizedBox(height: 14),
                _SelectedDayCard(date: _selected, day: day, duty: duty),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: 'Chấm công',
                        value: AppFormat.workUnits(stats.attendanceUnits),
                        hint: 'Chưa gồm trực',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatBox(
                        label: 'Công trực',
                        value: AppFormat.workUnits(stats.dutyUnits),
                        hint: '${stats.dutyCount} ca',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatBox(
                        label: 'Quang Trung',
                        value: AppFormat.workUnits(stats.quangTrungUnits),
                        hint: '${stats.quangTrungDays} ngày',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.onOpenDetail,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Xem bảng công chi tiết'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
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

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.row,
    required this.selected,
    required this.onSelect,
  });

  final int year;
  final int month;
  final int daysInMonth;
  final AttendanceMatrixRow row;
  final String selected;
  final ValueChanged<String> onSelect;

  static const _wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final lead = first.weekday - 1;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(lead, null),
      ...List.generate(daysInMonth, (i) => DateTime(year, month, i + 1)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final byDate = row.dayByDate;
    final duty = row.dutyByDate;
    final today = _iso(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (final w in _wd)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < cells.length / 7; r++) ...[
          if (r > 0) const SizedBox(height: 4),
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _HeatCell(
                      date: cells[r * 7 + c],
                      selectedIso: selected,
                      todayIso: today,
                      day: cells[r * 7 + c] == null
                          ? null
                          : byDate[_iso(cells[r * 7 + c]!)],
                      duty: cells[r * 7 + c] == null
                          ? null
                          : duty[_iso(cells[r * 7 + c]!)],
                      onTap: cells[r * 7 + c] == null
                          ? null
                          : () => onSelect(_iso(cells[r * 7 + c]!)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.date,
    required this.selectedIso,
    required this.todayIso,
    this.day,
    this.duty,
    this.onTap,
  });

  final DateTime? date;
  final String selectedIso;
  final String todayIso;
  final AttendanceMatrixDay? day;
  final AttendanceMatrixDutyDay? duty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox(height: 36);
    final iso = _iso(date!);
    final color = _dayColor(day, duty);
    final selected = iso == selectedIso;
    final today = iso == todayIso;
    return Material(
      color: color.withValues(alpha: selected ? 0.28 : 0.14),
      borderRadius: AppRadius.brSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.brSm,
            border: Border.all(
              color: selected
                  ? color
                  : today
                      ? AppColors.primary
                      : Colors.transparent,
              width: selected || today ? 1.5 : 0,
            ),
          ),
          child: Text(
            '${date!.day}',
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.date,
    this.day,
    this.duty,
  });

  final String date;
  final AttendanceMatrixDay? day;
  final AttendanceMatrixDutyDay? duty;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final title = parsed == null ? date : AppFormat.longDateVi(parsed);
    return AppCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (day == null && duty == null)
            Text(
              'Chưa có dữ liệu chấm công ngày này.',
              style: AppTypography.style(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            if (day?.morningRange != null)
              _kv('Sáng', day!.morningRange!, _morning),
            if (day?.afternoonRange != null)
              _kv('Chiều', day!.afternoonRange!, _afternoon),
            if (duty != null)
              _kv(
                'Công trực',
                [
                  duty!.displayShort,
                  if (duty!.workUnits > 0)
                    AppFormat.workUnits(duty!.workUnits, suffix: true),
                ].join(' · '),
                _duty,
              ),
            if (day?.quangTrung == true) _kv('Địa điểm', 'Quang Trung', _quangTrung),
            if (day?.isLeave == true)
              _kv('Nghỉ', day!.status == 'UNPAID_LEAVE' ? 'Không lương' : 'Nghỉ phép / vắng', _leave),
            if (day != null && day!.lateMinutes > 0 && !day!.lateMinutesExempt)
              _kv('Đi muộn', '${day!.lateMinutes} phút', AppColors.warning),
            if (day != null && day!.totalWorkUnits > 0)
              _kv('Công ngày', AppFormat.workUnits(day!.totalWorkUnits, suffix: true), AppColors.primary),
            if ((day?.note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                day!.note!.trim(),
                style: AppTypography.style(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            k,
            style: AppTypography.style(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            v,
            style: AppTypography.style(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthYearSheet extends StatefulWidget {
  const _MonthYearSheet({required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<_MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<_MonthYearSheet> {
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [for (var y = now.year - 2; y <= now.year; y++) y];
    if (!years.contains(_year)) {
      _year = now.year;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.brPill,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Chọn tháng',
            style: AppTypography.style(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final y in years) ...[
                if (y != years.first) const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: _MonthPickChip(
                      label: '$y',
                      selected: y == _year,
                      onTap: () => setState(() => _year = y),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              for (var m = 1; m <= 12; m++)
                _MonthPickChip(
                  label: 'Tháng $m',
                  selected: _year == widget.year && m == widget.month,
                  onTap: () => Navigator.pop(context, (_year, m)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthPickChip extends StatelessWidget {
  const _MonthPickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceMuted,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Center(
          child: Text(
            label,
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
