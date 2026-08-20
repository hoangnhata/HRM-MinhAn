import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/sync/live_data_refresh.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../shared/models/employee.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_month_controller.dart';
import 'attendance_employee_picker.dart';
import 'attendance_month_tab.dart';

/// Tab Công — cá nhân hoặc quản lý xem công NV (đồng bộ API web `/work`).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  EmployeeSummary? _selected;
  bool _initialized = false;

  bool get _canPickOthers {
    final role = ref.read(authControllerProvider).role;
    return RoleGroups.workManagers.contains(role);
  }

  int? get _lockDepartmentId {
    final auth = ref.read(authControllerProvider);
    if (auth.role == UserRole.headDepartment) {
      return auth.currentUser?.departmentId;
    }
    return null;
  }

  void _watchEmployee(int? id) {
    if (id == null || id <= 0) return;
    final current = ref.read(watchedAttendanceEmployeeIdsProvider);
    if (current.contains(id)) return;
    ref.read(watchedAttendanceEmployeeIdsProvider.notifier).state = {
      ...current,
      id,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final auth = ref.read(authControllerProvider);
    final id = auth.employeeId;
    if (id != null) {
      _selected = EmployeeSummary(
        id: id,
        fullName: auth.fullName ?? auth.currentUser?.displayName ?? 'Tôi',
        departmentName: auth.currentUser?.departmentName,
        positionTitle: auth.currentUser?.positionTitle,
      );
      _watchEmployee(id);
    }
  }

  Future<void> _pickEmployee() async {
    if (!_canPickOthers) return;
    final picked = await showAttendanceEmployeePicker(
      context,
      title: 'Chọn nhân viên xem công',
      departmentId: _lockDepartmentId,
      highlightId: _selected?.id,
    );
    if (!mounted || picked == null) return;
    setState(() => _selected = picked);
    _watchEmployee(picked.id);
  }

  Future<void> _openDepartmentMatrix() async {
    if (!_canPickOthers) return;
    final employeeId = _selected?.id ?? ref.read(authControllerProvider).employeeId ?? 0;
    int? year;
    int? month;
    if (employeeId > 0) {
      final monthState = ref.read(attendanceMonthControllerProvider(employeeId));
      year = monthState.year;
      month = monthState.month;
    }
    final picked = await context.push<EmployeeSummary>(
      RoutePaths.attendanceDepartmentMatrix,
      extra: {
        if (year != null) 'year': year,
        if (month != null) 'month': month,
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _selected = picked);
    _watchEmployee(picked.id);
  }

  void _viewSelf() {
    final auth = ref.read(authControllerProvider);
    final id = auth.employeeId;
    if (id == null) return;
    setState(() {
      _selected = EmployeeSummary(
        id: id,
        fullName: auth.fullName ?? auth.currentUser?.displayName ?? 'Tôi',
        departmentName: auth.currentUser?.departmentName,
        positionTitle: auth.currentUser?.positionTitle,
      );
    });
    _watchEmployee(id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final selfId = auth.employeeId;
    final viewingSelf = _selected?.id != null && _selected!.id == selfId;
    final employeeId = _selected?.id ?? selfId ?? 0;
    final canManage = _canPickOthers;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppReveal(
            offset: 8,
            child: AppScreenHeader(
              eyebrow: 'Theo dõi thời gian',
              title: 'Bảng công',
              icon: Icons.calendar_month_rounded,
              subtitle: canManage
                  ? 'Công cá nhân hoặc nhân viên đang quản lý'
                  : 'Công tháng và chi tiết từng ngày của bạn',
              trailing: canManage
                  ? _DepartmentMatrixHeaderButton(onTap: _openDepartmentMatrix)
                  : null,
            ),
          ),
          if (canManage)
            AppReveal(
              delay: const Duration(milliseconds: 40),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  8,
                  AppSpacing.page,
                  8,
                ),
                child: _EmployeeSelectorCard(
                  employee: _selected,
                  viewingSelf: viewingSelf,
                  onPick: _pickEmployee,
                  onSelf: selfId == null ? null : _viewSelf,
                ),
              ),
            ),
          Expanded(
            child: AttendanceMonthTab(
              employeeId: employeeId,
              employeeName: _selected?.fullName,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentMatrixHeaderButton extends StatelessWidget {
  const _DepartmentMatrixHeaderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      button: true,
      label: 'Bảng công theo khoa',
      child: Tooltip(
        message: 'Bảng công theo khoa',
        child: Material(
          color: onBrand.withValues(alpha: 0.16),
          borderRadius: AppRadius.brPill,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brPill,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_chart_outlined, size: 16, color: onBrand),
                  const SizedBox(width: 6),
                  Text(
                    'Theo khoa',
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: onBrand,
                      height: 1.1,
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

class _EmployeeSelectorCard extends StatelessWidget {
  const _EmployeeSelectorCard({
    required this.employee,
    required this.viewingSelf,
    required this.onPick,
    this.onSelf,
  });

  final EmployeeSummary? employee;
  final bool viewingSelf;
  final VoidCallback onPick;
  final VoidCallback? onSelf;

  @override
  Widget build(BuildContext context) {
    final name = employee?.fullName ?? 'Chọn nhân viên';
    final meta = [
      if ((employee?.positionTitle ?? '').isNotEmpty) employee!.positionTitle!,
      if ((employee?.departmentName ?? '').isNotEmpty) employee!.departmentName!,
    ].join(' · ');

    return AppCard(
      onTap: onPick,
      accentColor: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          AppAvatar(
            name: name,
            imageUrl: employee?.avatarUrl,
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (viewingSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          'Tôi',
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  meta.isEmpty ? 'Chạm để tìm và chọn nhân viên' : meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (onSelf != null && !viewingSelf)
            IconButton(
              tooltip: 'Công của tôi',
              onPressed: onSelf,
              icon: const Icon(Icons.home_rounded, size: 20),
              color: AppColors.primary,
            ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
