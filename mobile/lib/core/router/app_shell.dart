import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/requests/presentation/requests_hub_screen.dart';
import '../../features/salary/presentation/salary_screen.dart';
import '../router/route_paths.dart';
import '../router/shell_tab.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/app_ambient_background.dart';

export 'shell_tab.dart';

/// Khung điều hướng chính — bottom nav; tab Lương chỉ hiện khi có quyền xem lương.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(shellTabProvider);
    final canViewSalary =
        ref.watch(authControllerProvider).currentUser?.canViewSalary == true;
    final tabs = _visibleTabs(canViewSalary);

    // Nếu đang chọn Lương nhưng mất quyền → về Trang chủ.
    final effective = tabs.contains(selected) ? selected : AppShellTab.home;
    if (effective != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(shellTabProvider) == selected) {
          ref.read(shellTabProvider.notifier).state = AppShellTab.home;
        }
      });
    }

    final pages = [
      for (final tab in tabs) _pageFor(tab),
    ];
    final index = tabs.indexOf(effective).clamp(0, pages.length - 1);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: effective == AppShellTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ref.read(shellTabProvider.notifier).state = AppShellTab.home;
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              const Positioned.fill(child: AppAmbientBackground()),
              IndexedStack(index: index, children: pages),
            ],
          ),
          bottomNavigationBar: _BottomNavigationDock(
            tabs: tabs,
            selected: effective,
            onDestinationSelected: (tab) =>
                ref.read(shellTabProvider.notifier).state = tab,
          ),
        ),
      ),
    );
  }

  static List<AppShellTab> _visibleTabs(bool canViewSalary) {
    return [
      AppShellTab.home,
      AppShellTab.attendance,
      AppShellTab.requests,
      if (canViewSalary) AppShellTab.salary,
      AppShellTab.profile,
    ];
  }

  static Widget _pageFor(AppShellTab tab) {
    return switch (tab) {
      AppShellTab.home => const DashboardScreen(),
      AppShellTab.attendance => const AttendanceScreen(key: ValueKey('attendance-board')),
      AppShellTab.requests => const RequestsHubScreen(),
      AppShellTab.salary => const SalaryScreen(embedded: true),
      AppShellTab.profile => const ProfileScreen(),
    };
  }
}

class _DockItem {
  const _DockItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final AppShellTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static const catalog = <AppShellTab, _DockItem>{
    AppShellTab.home: _DockItem(
      tab: AppShellTab.home,
      label: 'Trang chủ',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
    ),
    AppShellTab.attendance: _DockItem(
      tab: AppShellTab.attendance,
      label: 'Công',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
    ),
    AppShellTab.requests: _DockItem(
      tab: AppShellTab.requests,
      label: 'Đơn từ',
      icon: Icons.folder_copy_outlined,
      selectedIcon: Icons.folder_copy_rounded,
    ),
    AppShellTab.salary: _DockItem(
      tab: AppShellTab.salary,
      label: 'Lương',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
    ),
    AppShellTab.profile: _DockItem(
      tab: AppShellTab.profile,
      label: 'Cá nhân',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  };
}

class _BottomNavigationDock extends StatelessWidget {
  const _BottomNavigationDock({
    required this.tabs,
    required this.selected,
    required this.onDestinationSelected,
  });

  final List<AppShellTab> tabs;
  final AppShellTab selected;
  final ValueChanged<AppShellTab> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final effectiveScale = textScaler.scale(10) / 10;
    final compact =
        MediaQuery.sizeOf(context).width < 360 || effectiveScale > 1.15;
    final scaleAllowance = ((effectiveScale - 1).clamp(0.0, 1.0) * 8)
        .toDouble();
    final items = [for (final t in tabs) _DockItem.catalog[t]!];

    return RepaintBoundary(
      key: ValueKey(selected),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: const Border(top: BorderSide(color: AppColors.borderSoft)),
          boxShadow: AppShadows.nav,
        ),
        child: TweenAnimationBuilder<double>(
          key: ValueKey('dock-$selected'),
          tween: Tween(begin: 0.015, end: 0),
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
          builder: (context, tint, child) => Opacity(
            opacity: 1 - (tint * 0.66),
            child: ColoredBox(
              color: Color.lerp(AppColors.surface, AppColors.primary, tint)!,
              child: child,
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64 + scaleAllowance,
              child: Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: _DockDestination(
                        item: item,
                        selected: selected == item.tab,
                        compact: compact,
                        onTap: () => onDestinationSelected(item.tab),
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

class _DockDestination extends StatelessWidget {
  const _DockDestination({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _DockItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      hint: selected ? 'Đang hiển thị' : 'Mở ${item.label}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: item.label,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xxs,
                  AppSpacing.xxs,
                  AppSpacing.xxs,
                  compact ? AppSpacing.xxs : 6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 3,
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          curve: Curves.easeOutCubic,
                          width: selected ? 24 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: AppRadius.brPill,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    AnimatedContainer(
                      duration: AppDurations.fast,
                      curve: Curves.easeOutCubic,
                      width: 38,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: AppRadius.brXs,
                      ),
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 22,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 4 : 2,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: AppTypography.style(
                              fontSize: compact ? 9.5 : 10.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: color,
                              height: 1.1,
                            ),
                          ),
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

/// Mở màn thông báo (không còn nằm trên bottom nav).
void openNotifications(BuildContext context) {
  context.push(RoutePaths.notifications);
}
