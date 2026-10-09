import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/attendance_notes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_month_picker.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/attendance_models.dart';
import '../../../shared/models/employee.dart';
import '../../auth/application/auth_controller.dart';
import '../../employees/data/department_repository.dart';
import '../../employees/presentation/org_unit_picker.dart';
import '../application/department_attendance_controller.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';

const _morning = Color(0xFFC2410C);
const _afternoon = Color(0xFF15803D);
const _leave = Color(0xFFB45309);
const _duty = Color(0xFFCA8A04);
const _quangTrung = Color(0xFF2563EB);

class DepartmentAttendanceScreen extends ConsumerStatefulWidget {
  const DepartmentAttendanceScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
  });

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
        ref
            .read(departmentAttendanceControllerProvider.notifier)
            .setMonth(y, m);
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
    final current = ref
        .read(departmentAttendanceControllerProvider)
        .departmentId;
    final picked = await showDepartmentPicker(
      context,
      departments: depts,
      selectedId: current,
      allowClear: true,
      title: 'Khoa / phòng',
    );
    if (picked == null) return;
    await ref
        .read(departmentAttendanceControllerProvider.notifier)
        .setDepartment(picked.cleared ? null : picked.department?.id);
  }

  Future<void> _pickMonth() async {
    final state = ref.read(departmentAttendanceControllerProvider);
    final picked = await showAppMonthPicker(
      context,
      year: state.year,
      month: state.month,
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
      showDragHandle: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeeMonthSheet(
        row: row,
        year: ref.read(departmentAttendanceControllerProvider).year,
        month: ref.read(departmentAttendanceControllerProvider).month,
        daysInMonth:
            ref
                .read(departmentAttendanceControllerProvider)
                .matrix
                ?.daysInMonth ??
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
    final deptName =
        matrix?.departmentName ??
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
                subtitle:
                    '${AppFormat.monthLabelVi(DateTime(state.year, state.month))} · $deptName',
                onBack: () => context.pop(),
                trailing: IconButton(
                  tooltip: 'Làm mới',
                  onPressed: state.loading
                      ? null
                      : () => ref
                            .read(
                              departmentAttendanceControllerProvider.notifier,
                            )
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
                        Expanded(
                          child: _FilterChip(
                            icon: Icons.calendar_month_rounded,
                            caption: 'Kỳ công',
                            label: 'Tháng ${state.month}/${state.year}',
                            onTap: _pickMonth,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FilterChip(
                            icon: Icons.apartment_rounded,
                            caption: 'Khoa/Phòng',
                            label: state.departmentId == null && !_deptLocked
                                ? 'Tất cả khoa'
                                : deptName,
                            locked: _deptLocked,
                            onTap: _pickDepartment,
                          ),
                        ),
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

  Widget _buildBody(
    DepartmentAttendanceState state,
    List<AttendanceMatrixRow> rows,
  ) {
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

    final daysInMonth =
        state.matrix?.daysInMonth ??
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
    required this.caption,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String caption;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brCard,
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        color: AppColors.surface,
        child: InkWell(
          onTap: locked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                TintedIconTile(icon: icon, color: AppColors.primary, size: 30),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption.toUpperCase(),
                        style: AppTypography.uppercase(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
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
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: AppTypography.metric(
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (count != totalShown)
                  TextSpan(
                    text: '/$totalShown',
                    style: AppTypography.metric(
                      fontSize: 12.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                TextSpan(
                  text: '  nhân viên',
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  AppFormat.monthLabelVi(DateTime(year, month)),
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: AppTypography.uppercaseHeight,
                    color: AppColors.textSecondary,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: AppRadius.brControl,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: const Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _LegendDot(color: _morning, label: 'Sáng'),
          _LegendDot(color: _afternoon, label: 'Chiều'),
          _LegendDot(color: _leave, label: 'Nghỉ'),
          _LegendDot(color: _duty, label: 'Công trực'),
          _LegendDot(color: _quangTrung, label: 'Quang Trung'),
          _LegendDot(color: AppColors.primary, label: 'Hôm nay', hollow: true),
        ],
      ),
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
          width: 12,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: AppRadius.brPill,
            color: hollow ? Colors.transparent : color,
            border: hollow ? Border.all(color: color, width: 1.4) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: AppTypography.uppercaseHeight,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// "BAN GIÁM ĐỐC" → "Ban Giám Đốc" (tên khoa lưu in hoa).
String _prettyDept(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text != text.toUpperCase()) return text;
  return text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.isEmpty
            ? w
            : '${w.characters.first.toUpperCase()}${w.characters.skip(1)}',
      )
      .join(' ');
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
    final dept = _prettyDept(row.department);

    final flags = <Widget>[
      if (stats.leaveDays > 0)
        _FlagTag(
          icon: Icons.beach_access_rounded,
          label: 'Nghỉ ${stats.leaveDays} ngày',
          color: _leave,
        ),
      if (stats.missingUnits > 0)
        _FlagTag(
          icon: Icons.trending_down_rounded,
          label: 'Thiếu ${AppFormat.workUnits(stats.missingUnits)} công',
          color: AppColors.error,
        ),
      if (stats.lateMinutes > 0)
        _FlagTag(
          icon: Icons.timer_outlined,
          label: 'Muộn ${stats.lateCount} lần · ${stats.lateMinutes}′',
          color: AppColors.warning,
        ),
      if (row.dutyBonusTotal > 0)
        _FlagTag(
          icon: Icons.payments_outlined,
          label: 'Thưởng trực ${AppFormat.currencyCompact(row.dutyBonusTotal)}',
          color: AppColors.primary,
        ),
      if (row.dutyPostPayTotal > 0)
        _FlagTag(
          icon: Icons.bedtime_outlined,
          label: 'Sau trực ${AppFormat.currencyCompact(row.dutyPostPayTotal)}',
          color: AppColors.primary,
        ),
      if (row.quangTrungAllowance > 0)
        _FlagTag(
          icon: Icons.local_hospital_outlined,
          label: 'PC QT ${AppFormat.currencyCompact(row.quangTrungAllowance)}',
          color: _quangTrung,
        ),
    ];

    return AppCard(
      onTap: onTap,
      borderRadius: AppRadius.brCard,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: AppAvatar(
                  name: row.fullName,
                  size: 42,
                  showShadow: false,
                ),
              ),
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
                        letterSpacing: -0.3,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (row.position.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.09),
                              borderRadius: AppRadius.brPill,
                            ),
                            child: Text(
                              row.position,
                              style: AppTypography.style(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                height: AppTypography.uppercaseHeight,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (row.employeeCode.isNotEmpty)
                          Flexible(
                            child: Text(
                              row.employeeCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.metric(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (dept.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        dept,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
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
          const SizedBox(height: 12),
          _StatStrip(
            items: [
              (
                'Chấm công',
                AppFormat.workUnits(stats.attendanceUnits),
                'Chưa gồm trực',
                stats.attendanceUnits > 0,
                AppColors.primary,
              ),
              (
                'Công trực',
                AppFormat.workUnits(stats.dutyUnits),
                '${stats.dutyCount} ca',
                stats.dutyUnits > 0,
                _duty,
              ),
              (
                'Quang Trung',
                AppFormat.workUnits(stats.quangTrungUnits),
                '${stats.quangTrungDays} ngày',
                stats.quangTrungUnits > 0,
                _quangTrung,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WeekStrip(row: row, year: year, month: month),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 5, runSpacing: 5, children: flags),
          ],
        ],
      ),
    );
  }
}

/// Nhãn cảnh báo / phụ cấp nhỏ dưới thẻ nhân viên.
class _FlagTag extends StatelessWidget {
  const _FlagTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
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
  }
}

class _TotalUnitsBadge extends StatelessWidget {
  const _TotalUnitsBadge({required this.units});

  final double units;

  @override
  Widget build(BuildContext context) {
    final has = units > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          AppFormat.workUnits(units),
          maxLines: 1,
          softWrap: false,
          style: AppTypography.metric(
            fontSize: 20,
            color: has ? AppColors.primaryDark : AppColors.textTertiary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'TỔNG CÔNG',
          style: AppTypography.uppercase(
            fontSize: 8.5,
            letterSpacing: 0.6,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Rãnh 3 cột chỉ số: nhãn in hoa + chấm sắc, số giữa, gợi ý dưới.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.items});

  /// (nhãn, giá trị, gợi ý, có phát sinh, sắc).
  final List<(String, String, String, bool, Color)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brControl,
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
                              color: it.$4
                                  ? it.$5
                                  : AppColors.textTertiary.withValues(
                                      alpha: 0.45,
                                    ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              it.$1.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.uppercase(
                                fontSize: 8.5,
                                letterSpacing: 0.4,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        it.$2,
                        maxLines: 1,
                        style: AppTypography.metric(
                          fontSize: 15,
                          color: it.$4
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        it.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
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
              weekend: i >= 5,
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

/// Ô một ngày trong dải tuần: thứ + ngày, vạch màu trạng thái ở đáy.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.weekday,
    required this.inMonth,
    required this.today,
    this.weekend = false,
    this.day,
    this.duty,
  });

  final DateTime date;
  final String weekday;
  final bool inMonth;
  final bool today;
  final bool weekend;
  final AttendanceMatrixDay? day;
  final AttendanceMatrixDutyDay? duty;

  @override
  Widget build(BuildContext context) {
    final color = _dayColor(day, duty);
    final filled =
        duty != null ||
        (day != null && (day!.totalWorkUnits > 0 || day!.isLeave));
    final numberColor = filled
        ? Color.lerp(color, AppColors.textPrimary, 0.25)!
        : AppColors.textSecondary;

    return Opacity(
      opacity: inMonth ? 1 : 0.35,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 5),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.10) : AppColors.surfaceAlt,
          borderRadius: AppRadius.brControl,
          border: Border.all(
            color: today
                ? AppColors.primary
                : filled
                ? color.withValues(alpha: 0.22)
                : AppColors.borderSoft,
            width: today ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              weekday,
              style: AppTypography.uppercase(
                fontSize: 9,
                letterSpacing: 0.2,
                color: weekend
                    ? AppColors.errorDark.withValues(alpha: 0.7)
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: AppTypography.metric(fontSize: 13.5, color: numberColor),
            ),
            const SizedBox(height: 4),
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: filled ? color : Colors.transparent,
                borderRadius: AppRadius.brPill,
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
    final dept = _prettyDept(row.department);

    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.brSheetTop,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                // ── Hồ sơ + tổng công ──────────────────────────────────
                AppCard(
                  gradient: TintedCardBackdrop.gradient(AppColors.primary),
                  borderRadius: AppRadius.brCard,
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  child: TintedCardBackdrop(
                    accent: AppColors.primary,
                    watermarkIcon: Icons.calendar_month_rounded,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: AppAvatar(
                              name: row.fullName,
                              size: 46,
                              showShadow: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppFormat.monthLabelVi(
                                    DateTime(widget.year, widget.month),
                                  ).toUpperCase(),
                                  style: AppTypography.uppercase(
                                    fontSize: 9.5,
                                    letterSpacing: 0.7,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  row.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: AppTypography.uppercaseHeight,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (row.position.isNotEmpty) row.position,
                                    if (dept.isNotEmpty) dept,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
                  ),
                ),
                const SizedBox(height: 12),
                // ── Lịch tháng ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.brCard,
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: AppShadows.soft,
                  ),
                  child: _MonthHeatmap(
                    year: widget.year,
                    month: widget.month,
                    daysInMonth: widget.daysInMonth,
                    row: row,
                    selected: _selected,
                    onSelect: (iso) {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = iso);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _SelectedDayCard(date: _selected, day: day, duty: duty),
                const SizedBox(height: 12),
                _StatStrip(
                  items: [
                    (
                      'Chấm công',
                      AppFormat.workUnits(stats.attendanceUnits),
                      'Chưa gồm trực',
                      stats.attendanceUnits > 0,
                      AppColors.primary,
                    ),
                    (
                      'Công trực',
                      AppFormat.workUnits(stats.dutyUnits),
                      '${stats.dutyCount} ca',
                      stats.dutyUnits > 0,
                      _duty,
                    ),
                    (
                      'Quang Trung',
                      AppFormat.workUnits(stats.quangTrungUnits),
                      '${stats.quangTrungDays} ngày',
                      stats.quangTrungUnits > 0,
                      _quangTrung,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppActionButton(
                  variant: AppActionVariant.primary,
                  icon: Icons.open_in_new_rounded,
                  label: 'Xem bảng công chi tiết',
                  onPressed: widget.onOpenDetail,
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
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final today = _iso(now);

    return Column(
      children: [
        Row(
          children: [
            for (final (i, w) in _wd.indexed)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: AppTypography.uppercase(
                    fontSize: 10,
                    letterSpacing: 0.3,
                    color: i >= 5
                        ? AppColors.errorDark.withValues(alpha: 0.7)
                        : AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var r = 0; r < cells.length / 7; r++) ...[
          if (r > 0) const SizedBox(height: 5),
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
                      future:
                          cells[r * 7 + c] != null &&
                          cells[r * 7 + c]!.isAfter(todayDate),
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

/// Ô ngày trong lịch tháng: có dữ liệu = pha màu trạng thái; đang chọn = đặc
/// màu chữ trắng; hôm nay = viền teal; ngày tương lai = mờ.
class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.date,
    required this.selectedIso,
    required this.todayIso,
    this.future = false,
    this.day,
    this.duty,
    this.onTap,
  });

  final DateTime? date;
  final String selectedIso;
  final String todayIso;
  final bool future;
  final AttendanceMatrixDay? day;
  final AttendanceMatrixDutyDay? duty;
  final VoidCallback? onTap;

  static const double _height = 40;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox(height: _height);
    final iso = _iso(date!);
    final color = _dayColor(day, duty);
    final filled =
        duty != null ||
        (day != null && (day!.totalWorkUnits > 0 || day!.isLeave));
    final tone = filled ? color : AppColors.primary;
    final selected = iso == selectedIso;
    final today = iso == todayIso;

    final Color background = selected
        ? tone
        : filled
        ? color.withValues(alpha: 0.13)
        : AppColors.surfaceAlt;
    final Color numberColor = selected
        ? Colors.white
        : filled
        ? Color.lerp(color, AppColors.textPrimary, 0.25)!
        : AppColors.textSecondary;

    return Opacity(
      opacity: future && !selected ? 0.4 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brControl,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: _height,
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.brControl,
              border: Border.all(
                color: today && !selected
                    ? AppColors.primary
                    : filled && !selected
                    ? color.withValues(alpha: 0.25)
                    : selected
                    ? Colors.transparent
                    : AppColors.borderSoft,
                width: today && !selected ? 1.5 : 1,
              ),
              boxShadow: selected ? AppShadows.tinted(tone) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${date!.day}',
                  style: AppTypography.metric(
                    fontSize: 13.5,
                    color: numberColor,
                  ),
                ),
                if (today)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
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

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({required this.date, this.day, this.duty});

  final String date;
  final AttendanceMatrixDay? day;
  final AttendanceMatrixDutyDay? duty;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final title = parsed == null ? date : AppFormat.longDateVi(parsed);
    final empty = day == null && duty == null;
    final tone = empty ? AppColors.textTertiary : _dayColor(day, duty);

    final rows = <(String, String, Color)>[
      if (day?.morningRange != null) ('Ca sáng', day!.morningRange!, _morning),
      if (day?.afternoonRange != null)
        ('Ca chiều', day!.afternoonRange!, _afternoon),
      if (duty != null)
        (
          'Công trực',
          [
            duty!.displayShort,
            if (duty!.workUnits > 0)
              AppFormat.workUnits(duty!.workUnits, suffix: true),
          ].join(' · '),
          _duty,
        ),
      if (day?.quangTrung == true) ('Địa điểm', 'Quang Trung', _quangTrung),
      if (day?.isLeave == true)
        (
          'Nghỉ',
          day!.status == 'UNPAID_LEAVE'
              ? 'Không lương'
              : day!.status == 'PERSONAL_LEAVE'
              ? 'Nghỉ chế độ'
              : 'Nghỉ phép / vắng',
          _leave,
        ),
      if (day != null && day!.lateMinutes > 0 && !day!.lateMinutesExempt)
        ('Đi muộn', '${day!.lateMinutes} phút', AppColors.warning),
    ];
    final units = day?.totalWorkUnits ?? 0;
    final note = stripAttendanceNoteMarkers(day?.note ?? '');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: tone.withValues(alpha: 0.2)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
            decoration: BoxDecoration(gradient: AppGradients.tint(tone)),
            child: Row(
              children: [
                TintedIconTile(
                  icon: empty
                      ? Icons.event_busy_rounded
                      : Icons.event_available_rounded,
                  color: empty ? AppColors.textSecondary : tone,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.style(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: AppTypography.uppercaseHeight,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (units > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormat.workUnits(units),
                        style: AppTypography.metric(
                          fontSize: 17,
                          color: AppColors.primaryDark,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'CÔNG',
                        style: AppTypography.uppercase(
                          fontSize: 8,
                          letterSpacing: 0.6,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          if (empty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Text(
                'Chưa có dữ liệu chấm công ngày này.',
                style: AppTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, r) in rows.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.divider),
                    _kv(r.$1, r.$2, r.$3),
                  ],
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Không có mốc giờ cho ngày này.',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadius.brControl,
                      ),
                      child: Text(
                        note,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
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

  Widget _kv(String k, String v, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.brPill,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            k,
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: AppTypography.metric(
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
