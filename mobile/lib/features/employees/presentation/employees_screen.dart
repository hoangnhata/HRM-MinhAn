import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/access_scope_chip.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/employee.dart';
import '../../auth/application/auth_controller.dart';
import '../application/employee_list_controller.dart';
import 'employee_filter_sheet.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';

/// Danh sách nhân viên — UI mobile (nav + thẻ), dữ liệu `/v1/employees` đồng bộ web.
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  static const _statusOptions = [
    ('OFFICIAL', 'Chính thức', Icons.verified_rounded),
    ('TRIAL', 'Thử việc / TT', Icons.school_rounded),
    ('TERMINATED', 'Đã nghỉ', Icons.person_off_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels > position.maxScrollExtent - 300) {
        ref.read(employeeListControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateOptions() async {
    final choice = await showAppBottomSheet<String>(
      context,
      title: 'Thêm nhân viên',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x1A0D7377),
              child: Icon(Icons.verified_rounded, color: AppColors.primary),
            ),
            title: const Text('Nhân viên chính thức'),
            subtitle: const Text('Trạng thái ACTIVE · hồ sơ đầy đủ'),
            onTap: () => Navigator.pop(context, 'official'),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x1AE9A825),
              child: Icon(Icons.school_rounded, color: AppColors.warning),
            ),
            title: const Text('Thử việc / Thực tập'),
            subtitle: const Text('Trạng thái PROBATION hoặc INTERN'),
            onTap: () => Navigator.pop(context, 'trial'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    await context.push(RoutePaths.employeeCreatePath(trial: choice == 'trial'));
    ref.read(employeeListControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeListControllerProvider);
    final controller = ref.read(employeeListControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final role = auth.role;
    final me = auth.currentUser;
    final canCreate = role == UserRole.admin || role == UserRole.hr;
    final topInset = MediaQuery.paddingOf(context).top;
    final workUnitScoped = me?.workUnitScoped == true;
    final workUnit = me?.workUnitDetail?.trim();
    final hospitalWideOnly =
        me?.hospitalWideEmployeeViewEnabled == true &&
        !RoleGroups.isIn(role, RoleGroups.adminHrHeads) &&
        role != UserRole.hr2 &&
        role != UserRole.headHr &&
        role != UserRole.director;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: _showCreateOptions,
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  'Thêm NV',
                  style: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            _EmployeesNav(
              topInset: topInset,
              totalElements: state.totalElements,
              searchController: _searchController,
              onQueryChanged: controller.setQuery,
              hasExtraFilters: state.hasExtraFilters,
              activeFilterCount: state.activeFilterCount,
              onOpenFilters: () => showEmployeeFilterSheet(
                context,
                ref,
                workUnitScoped: workUnitScoped,
                lockedWorkUnit: workUnitScoped ? workUnit : null,
                lockedDepartmentId: workUnitScoped ? me?.departmentId : null,
                lockedDepartmentName: workUnitScoped
                    ? me?.departmentName
                    : null,
              ),
              statusOptions: _statusOptions,
              selectedStatus: state.status,
              onStatusChanged: controller.setStatus,
              extraFilters: _buildActiveFilters(state, controller),
            ),
            if (workUnitScoped && workUnit != null && workUnit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  0,
                ),
                child: AccessScopeChip.workUnit(
                  workUnit: workUnit,
                  departmentName: me?.departmentName,
                ),
              )
            else if (hospitalWideOnly)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  0,
                ),
                child: AccessScopeChip.hospitalWide(),
              ),
            Expanded(child: _buildContent(state, controller)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActiveFilters(
    EmployeeListState state,
    EmployeeListController controller,
  ) {
    if (!state.hasExtraFilters) return const [];
    return [
      if (state.departmentName != null)
        _ActiveFilterChip(
          label: state.departmentName!,
          onClear: () => controller.applyFilters(
            departmentId: null,
            departmentName: null,
            workUnit: null,
            officialWorkFilter: state.officialWorkFilter,
          ),
        ),
      if ((state.workUnit ?? '').isNotEmpty)
        _ActiveFilterChip(
          label: state.workUnit!,
          onClear: () => controller.applyFilters(
            departmentId: state.departmentId,
            departmentName: state.departmentName,
            workUnit: null,
            officialWorkFilter: state.officialWorkFilter,
          ),
        ),
      if ((state.officialWorkFilter ?? '').isNotEmpty)
        _ActiveFilterChip(
          label: switch (state.officialWorkFilter) {
            'WORKING' => 'Đang làm việc',
            'MATERNITY_LEAVE' => 'Nghỉ thai sản',
            'FULL_TIME' => 'TTG',
            'PART_TIME' => 'BTG',
            _ => state.officialWorkFilter!,
          },
          onClear: () => controller.applyFilters(
            departmentId: state.departmentId,
            departmentName: state.departmentName,
            workUnit: state.workUnit,
            officialWorkFilter: null,
          ),
        ),
      TextButton(
        onPressed: controller.clearFilters,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Xóa lọc'),
      ),
    ];
  }

  Widget _buildContent(
    EmployeeListState state,
    EmployeeListController controller,
  ) {
    final role = ref.watch(authControllerProvider).role;
    final canProposeHeadRequests =
        role == UserRole.admin || RoleGroups.isHeadDepartmentRole(role);
    if (state.loading && state.items.isEmpty) {
      return const SkeletonList(itemCount: 8);
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(message: state.error!, onRetry: controller.load);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Không có nhân viên phù hợp',
              message: 'Thử đổi từ khoá tìm kiếm hoặc bộ lọc trạng thái.',
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              0,
            ),
            child: NoticeBanner.error(
              title: 'Dữ liệu có thể chưa mới nhất',
              message: state.error!,
              action: TextButton.icon(
                onPressed: controller.load,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Thử lại'),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.load,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                6,
                AppSpacing.page,
                100,
              ),
              itemCount:
                  state.items.length +
                  ((state.loadingMore || state.loadMoreError != null) ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= state.items.length) {
                  if (state.loadMoreError != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: NoticeBanner.error(
                        title: 'Chưa tải được trang tiếp theo',
                        message: state.loadMoreError!,
                        action: TextButton.icon(
                          onPressed: controller.retryLoadMore,
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Tải lại'),
                        ),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                  );
                }
                return AppReveal(
                  delay: AppStagger.delayFor(i.clamp(0, 8)),
                  offset: 10,
                  child: _EmployeeCard(
                    employee: state.items[i],
                    canProposeHeadRequests: canProposeHeadRequests,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Nav gộp tiêu đề + tìm kiếm + filter — một khối gradient liền mạch.
class _EmployeesNav extends StatelessWidget {
  const _EmployeesNav({
    required this.topInset,
    required this.totalElements,
    required this.searchController,
    required this.onQueryChanged,
    required this.hasExtraFilters,
    required this.activeFilterCount,
    required this.onOpenFilters,
    required this.statusOptions,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.extraFilters,
  });

  final double topInset;
  final int totalElements;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final bool hasExtraFilters;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;
  final List<(String?, String, IconData)> statusOptions;
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final List<Widget> extraFilters;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = statusOptions.indexWhere(
      (o) => o.$1 == selectedStatus,
    );

    return GradientHeader(
      safeAreaTop: false,
      bottomRadius: 28,
      ornamentIcon: Icons.groups_rounded,
      ornamentScale: 0.9,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        topInset + AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NavIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Trở về',
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _NavEyebrow(text: 'Hồ sơ nhân sự'),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      child: Text(
                        'Nhân viên',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTypography.style(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.6,
                              height: AppTypography.uppercaseHeight,
                            ).copyWith(
                              shadows: [
                                Shadow(
                                  color: AppColors.primaryDark.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (totalElements > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                _TotalStat(total: totalElements),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.brCard,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: AppSearchField(
                    controller: searchController,
                    hintText: 'Tìm tên, mã NV, CCCD…',
                    borderRadius: AppRadius.brCard,
                    onChanged: onQueryChanged,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              _FilterButton(
                active: hasExtraFilters,
                count: activeFilterCount,
                onTap: onOpenFilters,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          BrandHeaderSegment(
            dense: true,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onChanged: (i) => onStatusChanged(statusOptions[i].$1),
            items: [
              for (final option in statusOptions)
                BrandSegmentItem(label: option.$2, icon: option.$3),
            ],
          ),
          if (extraFilters.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: 6, runSpacing: 6, children: extraFilters),
          ],
        ],
      ),
    );
  }
}

/// Nhãn nhỏ trên tiêu đề — chấm vàng đồng, cùng ngôn ngữ với header các tab.
class _NavEyebrow extends StatelessWidget {
  const _NavEyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryLight.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.uppercase(
              color: AppColors.secondaryLight,
              fontSize: 10.5,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ô thống kê tổng hồ sơ — số lớn + nhãn nhỏ trong khung kính.
class _TotalStat extends StatelessWidget {
  const _TotalStat({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total hồ sơ nhân sự',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: AppRadius.brBase,
          border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppFormat.number(total),
              style: AppTypography.metric(
                fontSize: 17,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            Text(
              'HỒ SƠ',
              style: AppTypography.uppercase(
                fontSize: 9,
                letterSpacing: 0.9,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút mở bộ lọc nâng cao: kính mờ khi chưa lọc, trắng + badge vàng khi đang lọc.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Bộ lọc, đang áp dụng $count' : 'Bộ lọc',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Bộ lọc',
        child: SizedBox.square(
          dimension: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.brCard,
                    side: BorderSide(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.26),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Icon(
                      Icons.tune_rounded,
                      color: active ? AppColors.primaryDark : Colors.white,
                    ),
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppGradients.gold,
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: AppColors.primaryDark,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$count',
                        textScaler: TextScaler.noScaling,
                        style: AppTypography.style(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                          tabular: true,
                        ),
                      ),
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

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.16),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 42,
              child: Icon(icon, size: 21, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onClear,
      deleteIconColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.18),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      labelStyle: AppTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    this.canProposeHeadRequests = false,
  });

  final EmployeeSummary employee;
  final bool canProposeHeadRequests;

  @override
  Widget build(BuildContext context) {
    final chips = _statusChips(employee);
    final accent = chips.isNotEmpty ? chips.first.$2 : AppColors.primary;
    final dept = (employee.departmentName ?? '').trim();
    final unit = (employee.workUnitDetail ?? '').trim();
    final deptPretty = dept.isEmpty ? '' : _pretty(dept);
    final unitPretty = unit.isEmpty ? '' : _pretty(unit);
    final unitLine = [
      if (deptPretty.isNotEmpty) deptPretty,
      if (unitPretty.isNotEmpty &&
          unitPretty.toLowerCase() != deptPretty.toLowerCase())
        unitPretty,
    ].join(' · ');
    final position = (employee.positionTitle ?? '').trim();
    final terminated = (employee.status ?? '').toUpperCase() == 'TERMINATED';
    final showConversionAction =
        canProposeHeadRequests && !terminated && employee.isTrialEmployee;
    final showMainDutyAction =
        canProposeHeadRequests &&
        !terminated &&
        !employee.mainDutyAuthorized &&
        !employee.isTrialEmployee;

    final actions = <Widget>[
      if (showConversionAction)
        _CardAction(
          icon: Icons.workspace_premium_rounded,
          label: 'Lên chính thức',
          color: AppColors.success,
          onTap: () => context.push(
            RoutePaths.requestCreatePath(
              'probation-conversion',
              employeeId: employee.id,
            ),
          ),
        ),
      if (showMainDutyAction)
        _CardAction(
          icon: Icons.nights_stay_rounded,
          label: 'Chuyển trực chính',
          color: const Color(0xFF5B4BB4),
          onTap: () => context.push(
            RoutePaths.requestCreatePath(
              'main-duty-authorization',
              employeeId: employee.id,
            ),
          ),
        ),
    ];

    return AppCard(
      onTap: () => context.push(RoutePaths.employeeDetailPath(employee.id)),
      borderRadius: AppRadius.brLg,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm - 2),
      padding: EdgeInsets.zero,
      gradient: TintedCardBackdrop.gradient(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TintedCardBackdrop(
            accent: accent,
            watermarkIcon: Icons.badge_rounded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusAvatar(employee: employee, accent: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên là thông tin quan trọng nhất nên chiếm trọn bề ngang;
                        // chức danh xuống dòng phụ thay vì chen cùng hàng và cắt tên.
                        Text(
                          employee.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (position.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            position,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: AppTypography.uppercaseHeight,
                              color: accent,
                            ),
                          ),
                        ],
                        if (unitLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.apartment_rounded,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  unitLine,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs + 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final chip in chips)
                                _MetaTag(label: chip.$1, color: chip.$2),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                      boxShadow: AppShadows.soft,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actions.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                // Dải kính mờ — để lộ nền chuyển sắc thay vì một mảng xám phẳng.
                color: Colors.white.withValues(alpha: 0.55),
                border: Border(
                  top: BorderSide(color: accent.withValues(alpha: 0.12)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  children: [
                    for (final (i, action) in actions.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.xs),
                      Expanded(child: action),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _pretty(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
    if (letters.isEmpty) return trimmed;
    var upper = 0;
    for (final u in letters.runes) {
      final ch = String.fromCharCode(u);
      if (ch == ch.toUpperCase()) upper++;
    }
    if (upper / letters.length < 0.65) return trimmed;
    return trimmed
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          if (w.length <= 3 && RegExp(r'^[a-zà-ỹ]+$').hasMatch(w)) {
            return w.toUpperCase();
          }
          return '${w[0].toUpperCase()}${w.substring(1)}';
        })
        .join(' ');
  }

  static List<(String, Color)> _statusChips(EmployeeSummary e) {
    final status = (e.status ?? '').toUpperCase();
    final employment = (e.employmentType ?? '').toUpperCase();
    final chips = <(String, Color)>[];

    if (status == 'TERMINATED') {
      chips.add(('Đã nghỉ', AppColors.textSecondary));
    } else if (e.maternityLeave) {
      chips.add(('Nghỉ thai sản', const Color(0xFFE85D4C)));
    } else if (status == 'PROBATION') {
      chips.add(('Thử việc', AppColors.warning));
    } else if (status == 'INTERN') {
      chips.add(('Thực tập', const Color(0xFF5B8DEF)));
    } else if (status == 'ON_LEAVE') {
      chips.add(('Nghỉ phép', AppColors.info));
    } else if (status == 'ACTIVE' || status.isEmpty) {
      chips.add(('Chính thức', AppColors.success));
    }

    if (status != 'TERMINATED') {
      chips.add(
        e.mainDutyAuthorized
            ? ('Trực chính', AppColors.primary)
            : ('Trực kèm', AppColors.warning),
      );
    }
    if (employment == 'PART_TIME' || employment == 'BTG') {
      chips.add(('BTG', AppColors.secondaryDark));
    } else if (employment == 'FULL_TIME' || employment == 'TTG') {
      chips.add(('TTG', AppColors.textSecondary));
    }
    if (e.onTraining && status != 'TERMINATED') {
      chips.add(('Đào tạo', const Color(0xFF7C3AED)));
    }
    if (e.probationOverdue) {
      chips.add(('Quá hạn thử việc', AppColors.error));
    }

    return chips;
  }
}

/// Avatar kèm chấm trạng thái (màu theo trạng thái chính) ở góc dưới phải.
class _StatusAvatar extends StatelessWidget {
  const _StatusAvatar({required this.employee, required this.accent});

  final EmployeeSummary employee;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.55),
                  accent.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: AppAvatar(
                name: employee.fullName,
                imageUrl: employee.avatarUrl,
                size: 44,
                showShadow: false,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn thuộc tính gọn: chấm màu + chữ trên nền pha nhạt, viền mảnh.
class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Chữ đậm hơn một bậc để đủ tương phản trên nền pha 8%.
    final text = Color.lerp(color, AppColors.textPrimary, 0.25)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brChip,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: AppTypography.uppercaseHeight,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lối tắt lập phiếu cho nhân viên — nút tonal full-width ở chân thẻ.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brBase,
          side: BorderSide(color: color.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppRadius.brControl,
                      boxShadow: AppShadows.tinted(color),
                    ),
                    child: Icon(icon, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: AppTypography.uppercaseHeight,
                        color: Color.lerp(color, AppColors.textPrimary, 0.2),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: color.withValues(alpha: 0.85),
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
