import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_shell.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/current_user.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () =>
            ref.read(authControllerProvider.notifier).refreshCurrentUser(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileHeader(
              name: me?.displayName ?? auth.fullName ?? '—',
              roleLabel: auth.role.label,
              subtitle: [
                me?.positionTitle,
                me?.departmentName,
              ].where((e) => e != null && e.isNotEmpty).join(' · '),
              hasAvatar: me?.hasAvatar ?? false,
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Column(
                children: [
                  if (me != null)
                    AppReveal(
                      delay: const Duration(milliseconds: 70),
                      child: _IdentityCard(me: me),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppReveal(
                    delay: const Duration(milliseconds: 120),
                    child: _MenuGroup(
                      title: 'Tài khoản',
                      items: [
                        _MenuItem(
                          icon: Icons.badge_outlined,
                          label: 'Chỉnh sửa hồ sơ',
                          description:
                              'Email, số điện thoại, địa chỉ, ảnh đại diện',
                          onTap: () => context.push(RoutePaths.profileEdit),
                        ),
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Đổi mật khẩu',
                          description: 'Cập nhật mật khẩu đăng nhập',
                          color: AppColors.warning,
                          onTap: () =>
                              context.push(RoutePaths.profileChangePassword),
                        ),
                        _MenuItem(
                          icon: Icons.draw_outlined,
                          label: 'Chữ ký số',
                          description: 'Dùng khi gửi và duyệt đơn từ',
                          color: AppColors.info,
                          trailing: me?.hasSignature == true
                              ? const StatusChip(
                                  label: 'Đã có',
                                  color: AppColors.success,
                                  dense: true,
                                )
                              : const StatusChip(
                                  label: 'Chưa có',
                                  color: AppColors.warning,
                                  dense: true,
                                ),
                          onTap: () =>
                              context.push(RoutePaths.profileSignature),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (RoleGroups.isIn(auth.role, RoleGroups.employeeDirectory))
                    AppReveal(
                      delay: const Duration(milliseconds: 150),
                      child: _MenuGroup(
                        title: 'Tổ chức',
                        items: [
                          _MenuItem(
                            icon: Icons.groups_rounded,
                            label: 'Danh sách nhân viên',
                            description:
                                'Tra cứu hồ sơ, phòng ban và trạng thái làm việc',
                            color: AppColors.primary,
                            onTap: () => context.push(RoutePaths.employees),
                          ),
                          _MenuItem(
                            icon: Icons.apartment_rounded,
                            label: 'Phòng ban',
                            description: 'Cơ cấu khoa/phòng bệnh viện',
                            color: const Color(0xFF2A9D8F),
                            onTap: () => context.push(RoutePaths.departments),
                          ),
                        ],
                      ),
                    ),
                  if (RoleGroups.isIn(auth.role, RoleGroups.employeeDirectory))
                    const SizedBox(height: AppSpacing.sm),
                  if (RoleGroups.canViewWorkforceReports(
                    auth.role,
                    reportViewEnabled:
                        me?.reportViewEnabled ?? false,
                  ))
                    AppReveal(
                      delay: const Duration(milliseconds: 160),
                      child: _MenuGroup(
                        title: 'Báo cáo',
                        items: [
                          _MenuItem(
                            icon: Icons.assessment_rounded,
                            label: 'Nhân lực toàn viện',
                            description:
                                'Biên chế theo khoa/phòng và chức vụ',
                            color: AppColors.primary,
                            onTap: () =>
                                context.push(RoutePaths.workforceReports),
                          ),
                          _MenuItem(
                            icon: Icons.event_available_rounded,
                            label: 'Nhân lực đi làm hằng ngày',
                            description:
                                'Quân số có mặt theo khoa/phòng trong ngày',
                            color: const Color(0xFF0E7490),
                            onTap: () => context.push(
                              RoutePaths.workforceReportsPath(daily: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (RoleGroups.canViewWorkforceReports(
                    auth.role,
                    reportViewEnabled:
                        me?.reportViewEnabled ?? false,
                  ))
                    const SizedBox(height: AppSpacing.sm),
                  AppReveal(
                    delay: const Duration(milliseconds: 170),
                    child: _MenuGroup(
                      title: 'Của tôi',
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Hồ sơ nhân viên',
                          description: 'Thông tin nhân sự đầy đủ của bạn',
                          onTap: () {
                            final id = auth.employeeId ?? me?.employeeId;
                            if (id == null) {
                              context.push(RoutePaths.employeeMePath);
                              return;
                            }
                            context.push(RoutePaths.employeeDetailPath(id));
                          },
                        ),
                        if (me?.canViewSalary == true)
                          _MenuItem(
                            icon: Icons.payments_outlined,
                            label: 'Lương của tôi',
                            description: 'Hồ sơ lương và bảng lương theo kỳ',
                            color: AppColors.secondaryDark,
                            onTap: () =>
                                ref.read(shellTabProvider.notifier).state =
                                    AppShellTab.salary,
                          ),
                        _MenuItem(
                          icon: Icons.fact_check_outlined,
                          label: 'Đánh giá & xếp loại',
                          description: 'Lập phiếu, duyệt và xem kết quả khối ĐD',
                          color: AppColors.success,
                          onTap: () => context.push(RoutePaths.evaluation),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuGroup(
                    title: 'Khác',
                    items: [
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        label: 'Về ứng dụng',
                        description: 'Phiên bản và thông tin bản quyền',
                        color: AppColors.textSecondary,
                        onTap: () => _showAbout(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: AppSpacing.pageH,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                        backgroundColor: AppColors.error.withValues(
                          alpha: 0.04,
                        ),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => _confirmLogout(context, ref),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Đăng xuất'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${AppConfig.appName} · v${AppConfig.appVersion}',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
      confirmLabel: 'Đăng xuất',
      danger: true,
      icon: Icons.logout_rounded,
    );
    if (!context.mounted) return;
    if (confirm) {
      // Đợi dialog đóng xong rồi mới đổi auth — tránh hit-test overlay cũ.
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConfig.appName,
      applicationVersion:
          'Phiên bản ${AppConfig.appVersion} (${AppConfig.appBuildNumber})',
      applicationIcon: const Padding(
        padding: EdgeInsets.all(6),
        child: BrandMark(size: 44),
      ),
      applicationLegalese: 'Bệnh viện Minh An © ${DateTime.now().year}',
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.roleLabel,
    required this.subtitle,
    required this.hasAvatar,
  });

  final String name;
  final String roleLabel;
  final String subtitle;
  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return GradientHeader(
      bottomRadius: 24,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAvatar(
            name: name,
            size: 88,
            authImageUrl: hasAvatar ? ProfileRepository.myAvatarUrl : null,
            borderColor: onBrand.withValues(alpha: 0.92),
            borderWidth: 3,
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            header: true,
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.pageTitle(color: onBrand),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: onBrand.withValues(alpha: 0.16),
              borderRadius: AppRadius.brPill,
            ),
            child: Text(
              roleLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.style(
                color: onBrand,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                fontSize: 12.5,
                color: onBrand.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ thông tin định danh nhanh — mã NV, tên đăng nhập, liên hệ.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.me});

  final CurrentUser me;

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String)>[
      (Icons.pin_outlined, 'Mã nhân viên', me.employeeCode ?? '—'),
      if (me.email != null && me.email!.isNotEmpty)
        (Icons.mail_outline_rounded, 'Email', me.email!),
      if (me.phone != null && me.phone!.isNotEmpty)
        (Icons.phone_outlined, 'Điện thoại', me.phone!),
    ];

    return Padding(
      padding: AppSpacing.pageH,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIconBadge(icon: Icons.contact_page_outlined, size: 36),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Thông tin tài khoản',
                      style: AppTypography.sectionTitle(),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            for (int i = 0; i < entries.length; i++) ...[
              AppKeyValueRow(
                icon: entries[i].$1,
                label: entries[i].$2,
                value: entries[i].$3,
                dense: true,
              ),
              if (i != entries.length - 1) const Divider(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page + 4,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xs,
          ),
          child: Semantics(header: true, child: OverlineLabel(text: title)),
        ),
        Padding(
          padding: AppSpacing.pageH,
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1)
                    const Divider(height: 1, indent: 64, endIndent: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.trailing,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: AppIconBadge(icon: icon, color: color, size: 38),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTypography.listTitle()),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description!,
                            style: AppTypography.style(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  trailing ??
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                          size: 21,
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
