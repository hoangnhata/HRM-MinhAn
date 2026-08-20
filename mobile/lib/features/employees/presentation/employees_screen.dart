import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/employee.dart';
import '../../auth/application/auth_controller.dart';
import '../application/employee_list_controller.dart';
import 'employee_filter_sheet.dart';

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
    await context.push(
      RoutePaths.employeeCreatePath(trial: choice == 'trial'),
    );
    ref.read(employeeListControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeListControllerProvider);
    final controller = ref.read(employeeListControllerProvider.notifier);
    final role = ref.watch(authControllerProvider).role;
    final canCreate = role == UserRole.admin || role == UserRole.hr;
    final topInset = MediaQuery.paddingOf(context).top;

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
              onOpenFilters: () => showEmployeeFilterSheet(context, ref),
              statusOptions: _statusOptions,
              selectedStatus: state.status,
              onStatusChanged: controller.setStatus,
              extraFilters: _buildActiveFilters(state, controller),
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
        role == UserRole.admin || role == UserRole.headDepartment;
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
              itemCount: state.items.length +
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.appBarMid,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -40,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              topInset + 8,
              AppSpacing.page,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _NavIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nhân viên',
                            style: AppTypography.style(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalElements > 0
                                ? '$totalElements hồ sơ · đồng bộ HRM'
                                : 'Danh sách nhân sự bệnh viện',
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (totalElements > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: AppRadius.brPill,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          '$totalElements',
                          style: AppTypography.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AppSearchField(
                          controller: searchController,
                          hintText: 'Tìm tên, mã NV, CCCD…',
                          onChanged: onQueryChanged,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: hasExtraFilters
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: onOpenFilters,
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: hasExtraFilters
                                    ? AppColors.primaryDark
                                    : Colors.white,
                              ),
                              if (activeFilterCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$activeFilterCount',
                                      style: AppTypography.style(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (index, option)
                          in statusOptions.indexed) ...[
                        if (index > 0) const SizedBox(width: 8),
                        _StatusFilterChip(
                          label: option.$2,
                          icon: option.$3,
                          selected: selectedStatus == option.$1,
                          onTap: () => onStatusChanged(option.$1),
                        ),
                      ],
                    ],
                  ),
                ),
                if (extraFilters.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: extraFilters,
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

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white
          : Colors.white.withValues(alpha: 0.14),
      borderRadius: AppRadius.brPill,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.primaryDark
                    : Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? AppColors.primaryDark
                      : Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
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
    final showMainDutyAction = canProposeHeadRequests &&
        !terminated &&
        !employee.mainDutyAuthorized &&
        !employee.isTrialEmployee;

    return AppCard(
      onTap: () => context.push(RoutePaths.employeeDetailPath(employee.id)),
      accentColor: accent,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            name: employee.fullName,
            imageUrl: employee.avatarUrl,
            size: 48,
            borderColor: accent.withValues(alpha: 0.22),
            borderWidth: 2,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (position.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: AppRadius.brPill,
                          ),
                          child: Text(
                            position,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (unitLine.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final chip in chips)
                        StatusChip(
                          label: chip.$1,
                          color: chip.$2,
                          dense: true,
                        ),
                    ],
                  ),
                ],
                if (showConversionAction || showMainDutyAction) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (showConversionAction)
                        _ProfileActionChip(
                          icon: Icons.badge_outlined,
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
                        _ProfileActionChip(
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
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              color: accent.withValues(alpha: 0.7),
              size: 22,
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
      chips.add(('Quá hạn TV', AppColors.error));
    }

    return chips;
  }
}

class _ProfileActionChip extends StatelessWidget {
  const _ProfileActionChip({
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
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: color.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
