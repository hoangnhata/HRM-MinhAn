import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_shell.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/session/session_epoch.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/application/notification_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_charts.dart';

final dashboardAdminStatsProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) {
  ref.watch(sessionEpochProvider);
  return ref.watch(dashboardRepositoryProvider).stats();
});

final dashboardNursingStatsProvider =
    FutureProvider.autoDispose<NursingDashboardStats>((ref) {
      ref.watch(sessionEpochProvider);
      return ref.watch(dashboardRepositoryProvider).nursingStats();
    });

/// Dashboard kiểu mockup chuyên nghiệp: header brand + hero + KPI + charts.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.role;
    final showAdminStats = role == UserRole.admin || role == UserRole.hr;
    final showNursingStats = role == UserRole.headNursing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + 56,
        color: AppColors.primary,
        onRefresh: () async {
          final refreshes = <Future<Object?>>[
            ref.read(authControllerProvider.notifier).refreshCurrentUser(),
            ref
                .read(notificationControllerProvider.notifier)
                .pollQuietly(),
          ];
          if (showAdminStats) {
            refreshes.add(ref.refresh(dashboardAdminStatsProvider.future));
          }
          if (showNursingStats) {
            refreshes.add(ref.refresh(dashboardNursingStatsProvider.future));
          }
          await Future.wait(refreshes);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(child: _DashboardTopBar()),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: _WelcomeHeroCard(),
                ),
              ),
            ),
            if (showAdminStats)
              const SliverToBoxAdapter(child: _AdminDashboardBody())
            else if (showNursingStats)
              const SliverToBoxAdapter(child: _NursingDashboardBody())
            else
              const SliverToBoxAdapter(child: _EmployeeDashboardBody()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

/// Thanh đầu teal: logo BV | tên | chuông + avatar.
class _DashboardTopBar extends ConsumerWidget {
  const _DashboardTopBar();

  static const double _actionSize = 42;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.currentUser;
    final unread = ref.watch(notificationControllerProvider).unreadCount;
    final name = me?.displayName ?? auth.fullName ?? '';
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        topInset + 10,
        AppSpacing.page,
        22,
      ),
      decoration: BoxDecoration(
        gradient: AppGradients.appBar,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: _actionSize,
                height: _actionSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: const BrandMark(size: 42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bệnh viện Minh An',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        'Hệ thống HRM',
                        style: AppTypography.style(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              NotificationBellButton(
                unreadCount: unread,
                size: _DashboardTopBar._actionSize,
                onTap: () => openNotifications(context),
              ),
              const SizedBox(width: 10),
              _HeaderAvatarButton(
                name: name,
                hasAvatar: me?.hasAvatar == true,
                onTap: () => ref.read(shellTabProvider.notifier).state =
                    AppShellTab.profile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatarButton extends StatelessWidget {
  const _HeaderAvatarButton({
    required this.name,
    required this.hasAvatar,
    required this.onTap,
  });

  final String name;
  final bool hasAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mở trang cá nhân của $name',
      child: Tooltip(
        message: 'Trang cá nhân',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: AppAvatar(
              name: name,
              size: _DashboardTopBar._actionSize,
              authImageUrl:
                  hasAvatar ? ProfileRepository.myAvatarUrl : null,
              borderColor: Colors.white.withValues(alpha: 0.92),
              borderWidth: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ chào — hero mobile, đồng bộ nội dung theo vai trò.
class _WelcomeHeroCard extends ConsumerWidget {
  const _WelcomeHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final name = auth.currentUser?.displayName ?? auth.fullName ?? '';
    final role = auth.role;
    final (title, description) = switch (role) {
      UserRole.admin || UserRole.hr => (
        'Tổng quan nhân sự',
        'Theo dõi nguồn lực, phòng ban và các chỉ số vận hành của bệnh viện.',
      ),
      UserRole.headNursing => (
        'Tổng quan khối Điều dưỡng',
        'Nắm nhanh nhân sự trong khối và công việc đang chờ xử lý.',
      ),
      _ => (
        'Ngày làm việc của bạn',
        'Theo dõi công, đơn từ, thông báo và cập nhật cá nhân ở một nơi.',
      ),
    };

    return AppReveal(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppColors.primaryContainer,
              AppColors.primary.withValues(alpha: 0.12),
            ],
            stops: const [0.0, 0.62, 1.0],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.1),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -24,
              child: IgnorePointer(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.14),
                        AppColors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -10,
              child: Opacity(
                opacity: 0.9,
                child: _HospitalDecoration(size: 92),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Xin chào' : 'Xin chào, $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppTypography.style(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: AppRadius.brPill,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppFormat.longDateVi(DateTime.now()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minh họa bệnh viện đơn giản bằng vector — không cần asset ngoài.
class _HospitalDecoration extends StatelessWidget {
  const _HospitalDecoration({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HospitalPainter()),
    );
  }
}

class _HospitalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final building = Paint()..color = AppColors.primary.withValues(alpha: 0.22);
    final accent = Paint()..color = AppColors.primary.withValues(alpha: 0.38);
    final soft = Paint()
      ..color = const Color(0xFF8FCFC6).withValues(alpha: 0.45);

    // Cây trái/phải
    canvas.drawCircle(Offset(w * 0.14, h * 0.72), w * 0.12, soft);
    canvas.drawCircle(Offset(w * 0.86, h * 0.76), w * 0.1, soft);

    // Tòa nhà chính
    final main = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.22, w * 0.44, h * 0.62),
      const Radius.circular(8),
    );
    canvas.drawRRect(main, building);

    // Cánh phụ
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.42, w * 0.2, h * 0.42),
        const Radius.circular(6),
      ),
      soft,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.68, h * 0.42, w * 0.2, h * 0.42),
        const Radius.circular(6),
      ),
      soft,
    );

    // Chữ thập
    final cx = w * 0.5;
    final cy = h * 0.38;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: w * 0.08,
          height: w * 0.22,
        ),
        const Radius.circular(2),
      ),
      accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: w * 0.22,
          height: w * 0.08,
        ),
        const Radius.circular(2),
      ),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppTypography.style(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.25,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(48, 40),
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                actionLabel!,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hero + 2 chỉ số phụ — bố cục mobile, dữ liệu đồng bộ web.
class _SpotlightMetric {
  const _SpotlightMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String? hint;
}

class _AdminPulseBlock extends StatelessWidget {
  const _AdminPulseBlock({
    required this.working,
    required this.totalEmployees,
  });

  final int working;
  final int totalEmployees;

  @override
  Widget build(BuildContext context) {
    final ratio = totalEmployees <= 0
        ? 0.0
        : (working / totalEmployees).clamp(0.0, 1.0);

    return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
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
                right: -18,
                top: -24,
                child: IgnorePointer(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: -28,
                child: IgnorePointer(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: AppRadius.brSm,
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
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
                              'Đang làm việc',
                              style: AppTypography.style(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            Text(
                              'So với tổng hồ sơ nhân sự',
                              style: AppTypography.style(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.68),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          '${(ratio * 100).toStringAsFixed(0)}%',
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppFormat.number(working),
                            style: AppTypography.metric(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '/ ${AppFormat.number(totalEmployees)} hồ sơ',
                          style: AppTypography.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: AppRadius.brPill,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: AppDurations.slow,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 7,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }
}

class _SpotlightSideCard extends StatelessWidget {
  const _SpotlightSideCard({required this.item});

  final _SpotlightMetric item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  item.color.withValues(alpha: 0.2),
                  item.color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(item.icon, size: 20, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppFormat.number(item.value),
                    style: AppTypography.metric(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: item.color,
                    ),
                  ),
                ),
                if (item.hint != null)
                  Text(
                    item.hint!,
                    style: AppTypography.style(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
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

/// Lưới KPI 2 cột — card gradient nhẹ, số lớn, đơn vị rõ.
class SummaryStatGrid extends StatelessWidget {
  const SummaryStatGrid({super.key, required this.items});

  final List<SummaryStatItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        14,
        AppSpacing.page,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 14.0;
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = constraints.maxWidth < 340 || scale > 1.25 ? 1 : 2;
          final tileW = (constraints.maxWidth - (columns - 1) * gap) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: tileW,
                  child: _SummaryStatCard(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class SummaryStatItem {
  const SummaryStatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.accent,
  });

  final String label;
  final int value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? accent;
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({required this.item});
  final SummaryStatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            item.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: IgnorePointer(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: 15, color: item.color),
                    ),
                    const Spacer(),
                    if (item.accent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          item.accent!,
                          style: AppTypography.style(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: item.color,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppFormat.number(item.value),
                    style: AppTypography.metric(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  item.unit,
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    height: 1.2,
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

class _AdminDashboardBody extends ConsumerWidget {
  const _AdminDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardAdminStatsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        child: SkeletonStatGrid(itemCount: 4),
      ),
      error: (_, _) => ErrorState(
        message: 'Không tải được thống kê',
        onRetry: () => ref.invalidate(dashboardAdminStatsProvider),
      ),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppReveal(
            delay: AppStagger.delayFor(0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.assessment_rounded,
                        title: 'Báo cáo nhân lực',
                        subtitle: 'Toàn viện · đi làm',
                        color: AppColors.primary,
                        onTap: () => context.push(RoutePaths.workforceReports),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.groups_rounded,
                        title: 'Danh sách nhân viên',
                        subtitle: 'Tra cứu hồ sơ',
                        color: const Color(0xFF2A7B9B),
                        onTap: () => context.push(RoutePaths.employees),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppReveal(
            delay: AppStagger.delayFor(1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                10,
                AppSpacing.page,
                0,
              ),
              child: _AdminPulseBlock(
                working: stats.status.working,
                totalEmployees: stats.totalEmployees,
              ),
            ),
          ),
          AppReveal(
            delay: AppStagger.delayFor(2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                10,
                AppSpacing.page,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SpotlightSideCard(
                      item: _SpotlightMetric(
                        label: 'Nghỉ thai sản',
                        value: stats.maternityLeave,
                        icon: Icons.pregnant_woman_rounded,
                        color: const Color(0xFFE85D4C),
                        hint: 'nhân viên',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SpotlightSideCard(
                      item: _SpotlightMetric(
                        label: 'Phòng ban',
                        value: stats.departments,
                        icon: Icons.apartment_rounded,
                        color: const Color(0xFF2A9D8F),
                        hint: 'khoa/phòng',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppReveal(
            delay: AppStagger.delayFor(3),
            child: SummaryStatGrid(
              items: [
                SummaryStatItem(
                  label: 'Tổng nhân viên',
                  value: stats.totalEmployees,
                  unit: 'hồ sơ',
                  icon: Icons.groups_rounded,
                  color: AppColors.primary,
                ),
                SummaryStatItem(
                  label: 'Tài khoản NV',
                  value: stats.employeeRoleAccounts,
                  unit: 'tài khoản',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF5C6BC0),
                  accent: stats.totalEmployees <= 0
                      ? null
                      : '${((stats.employeeRoleAccounts / stats.totalEmployees) * 100).round()}%',
                ),
                SummaryStatItem(
                  label: 'Tài liệu PDF',
                  value: stats.totalPdfDocuments,
                  unit: 'tài liệu',
                  icon: Icons.description_rounded,
                  color: const Color(0xFF7C3AED),
                ),
                SummaryStatItem(
                  label: 'Sắp xét lương',
                  value: stats.salaryReviewsDueSoon,
                  unit: 'trong 14 ngày',
                  icon: Icons.payments_rounded,
                  color: AppColors.warning,
                  accent: stats.salaryReviewsDueSoon > 0 ? 'Cần xem' : 'Ổn',
                ),
              ],
            ),
          ),
          const _SectionHeader(
            title: 'Phân tích trực quan',
            icon: Icons.insights_rounded,
          ),
          AppReveal(
            delay: AppStagger.delayFor(3),
            child: Padding(
              padding: AppSpacing.pageH,
              child: StatusDonutChart(status: stats.status),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppReveal(
            delay: AppStagger.delayFor(4),
            child: Padding(
              padding: AppSpacing.pageH,
              child: HiresAreaChart(hires: stats.hiresByMonth),
            ),
          ),
          _SectionHeader(
            title: 'Nhân sự theo phòng ban',
            icon: Icons.people_alt_rounded,
            actionLabel: 'Xem tất cả',
            onAction: () => context.push(RoutePaths.departments),
          ),
          AppReveal(
            delay: AppStagger.delayFor(5),
            child: Padding(
              padding: AppSpacing.pageH,
              child: DepartmentBarChart(
                departments: stats.byDepartment,
                compact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NursingDashboardBody extends ConsumerWidget {
  const _NursingDashboardBody();

  static String _firstPendingRoute(NursingDashboardStats stats) {
    if (stats.pendingDeployments > 0) {
      return RoutePaths.withListFocus(
        RoutePaths.attendanceDeploymentRequests,
        tab: 'approve',
      );
    }
    if (stats.pendingProbation > 0) {
      return RoutePaths.withListFocus(
        RoutePaths.requestTypeListPath('probation-conversion'),
        tab: 'approve',
      );
    }
    if (stats.pendingMainDuty > 0) {
      return RoutePaths.withListFocus(
        RoutePaths.requestTypeListPath('main-duty-authorization'),
        tab: 'approve',
      );
    }
    return RoutePaths.requestsHub;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardNursingStatsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        child: SkeletonStatGrid(itemCount: 4),
      ),
      error: (_, _) => ErrorState(
        message: 'Không tải được thống kê khối Điều dưỡng',
        onRetry: () => ref.invalidate(dashboardNursingStatsProvider),
      ),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppReveal(
            delay: AppStagger.delayFor(0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                0,
              ),
              child: _NursingPulseBlock(stats: stats),
            ),
          ),
          if (stats.pendingTotal > 0)
            AppReveal(
              delay: AppStagger.delayFor(1),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  10,
                  AppSpacing.page,
                  0,
                ),
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(_firstPendingRoute(stats)),
                  icon: const Icon(Icons.task_alt_rounded, size: 20),
                  label: Text('Duyệt đơn (${stats.pendingTotal})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd,
                    ),
                    textStyle: AppTypography.style(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          AppReveal(
            delay: AppStagger.delayFor(1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                14,
                AppSpacing.page,
                0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.groups_rounded,
                        title: 'Nhân sự khối',
                        subtitle: 'ĐD · KTV · Hộ sinh · Thư ký',
                        color: AppColors.primary,
                        onTap: () => context.push(RoutePaths.employees),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.fact_check_rounded,
                        title: 'Đánh giá xếp loại',
                        subtitle: 'Duyệt và tổng hợp tháng',
                        color: const Color(0xFF2A7B9B),
                        onTap: () => context.push(RoutePaths.evaluation),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppReveal(
            delay: AppStagger.delayFor(2),
            child: SummaryStatGrid(
              items: [
                SummaryStatItem(
                  label: 'Chính thức',
                  value: stats.officialCount,
                  unit: 'nhân viên',
                  icon: Icons.badge_rounded,
                  color: AppColors.success,
                ),
                SummaryStatItem(
                  label: 'Thử việc',
                  value: stats.trialCount,
                  unit: 'nhân viên',
                  icon: Icons.school_rounded,
                  color: AppColors.warning,
                ),
                SummaryStatItem(
                  label: 'Trực chính',
                  value: stats.mainDutyAuthorized,
                  unit: 'nhân viên',
                  icon: Icons.verified_user_rounded,
                  color: AppColors.info,
                ),
                SummaryStatItem(
                  label: 'Khoa/phòng',
                  value: stats.departmentsCovered,
                  unit: 'đơn vị',
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFF5C6BC0),
                ),
              ],
            ),
          ),
          if (stats.bySubGroup.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Phân bổ chức danh',
              icon: Icons.pie_chart_outline_rounded,
            ),
            AppReveal(
              delay: AppStagger.delayFor(3),
              child: Padding(
                padding: AppSpacing.pageH,
                child: NursingSubGroupChart(items: stats.bySubGroup),
              ),
            ),
          ],
          _SectionHeader(
            title: 'Công việc chờ xử lý',
            icon: Icons.pending_actions_rounded,
            actionLabel: stats.pendingTotal > 0 ? 'Xem tất cả' : null,
            onAction: stats.pendingTotal > 0
                ? () => context.push(_firstPendingRoute(stats))
                : null,
          ),
          AppReveal(
            delay: AppStagger.delayFor(4),
            child: Padding(
              padding: AppSpacing.pageH,
              child: Column(
                children: [
                  _NursingPendingTile(
                    label: 'Điều động',
                    count: stats.pendingDeployments,
                    icon: Icons.swap_horiz_rounded,
                    color: const Color(0xFF0369A1),
                    onTap: () => context.push(
                      RoutePaths.withListFocus(
                        RoutePaths.attendanceDeploymentRequests,
                        tab: 'approve',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NursingPendingTile(
                    label: 'Lên chính thức',
                    count: stats.pendingProbation,
                    icon: Icons.how_to_reg_outlined,
                    color: const Color(0xFF0F766E),
                    onTap: () => context.push(
                      RoutePaths.withListFocus(
                        RoutePaths.requestTypeListPath('probation-conversion'),
                        tab: 'approve',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NursingPendingTile(
                    label: 'Trực chính',
                    count: stats.pendingMainDuty,
                    icon: Icons.assignment_ind_outlined,
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push(
                      RoutePaths.withListFocus(
                        RoutePaths.requestTypeListPath(
                          'main-duty-authorization',
                        ),
                        tab: 'approve',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _SectionHeader(
            title: 'Theo khoa/phòng',
            icon: Icons.apartment_rounded,
          ),
          AppReveal(
            delay: AppStagger.delayFor(5),
            child: Padding(
              padding: AppSpacing.pageH,
              child: DepartmentBarChart(
                departments: stats.byDepartment,
                title: 'Nhân sự khối theo phòng ban',
                subtitle: 'Số nhân viên khối ĐD–KTV–HS–Thư ký',
                compact: true,
              ),
            ),
          ),
          AppReveal(
            delay: AppStagger.delayFor(6),
            child: const _SectionHeader(
              title: 'Hồ sơ của tôi',
              icon: Icons.badge_outlined,
            ),
          ),
          AppReveal(
            delay: AppStagger.delayFor(6),
            child: const Padding(
              padding: AppSpacing.pageH,
              child: _MyProfileHomeCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NursingPulseBlock extends StatelessWidget {
  const _NursingPulseBlock({required this.stats});

  final NursingDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.totalInBlock;
    final officialRatio =
        total <= 0 ? 0.0 : (stats.officialCount / total).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -30,
            child: IgnorePointer(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: const Icon(
                      Icons.monitor_heart_rounded,
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
                          'NHÂN SỰ KHỐI',
                          style: AppTypography.style(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        Text(
                          'ĐD · KTV · Hộ sinh · Thư ký',
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stats.pendingTotal > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.92),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.pendingTotal} đơn',
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormat.number(total),
                    style: AppTypography.metric(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'nhân viên',
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${(officialRatio * 100).round()}% chính thức',
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: AppRadius.brPill,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: officialRatio),
                  duration: AppDurations.slow,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NursingHeroStat(
                      label: 'Chính thức',
                      value: stats.officialCount,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _NursingHeroStat(
                      label: 'Chờ duyệt',
                      value: stats.pendingTotal,
                      highlight: stats.pendingTotal > 0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _NursingHeroStat(
                      label: 'Khoa/phòng',
                      value: stats.departmentsCovered,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NursingHeroStat extends StatelessWidget {
  const _NursingHeroStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.error.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.brMd,
        border: highlight
            ? Border.all(color: Colors.white.withValues(alpha: 0.28))
            : null,
      ),
      child: Column(
        children: [
          Text(
            AppFormat.number(value),
            style: AppTypography.metric(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _NursingPendingTile extends StatelessWidget {
  const _NursingPendingTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPending = count > 0;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: hasPending
                  ? color.withValues(alpha: 0.28)
                  : AppColors.borderSoft,
            ),
            boxShadow: hasPending ? AppShadows.soft : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        hasPending
                            ? '$count đơn cần duyệt'
                            : 'Không có đơn chờ',
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasPending
                              ? color
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      AppFormat.number(count),
                      style: AppTypography.metric(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: hasPending ? color : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeDashboardBody extends ConsumerWidget {
  const _EmployeeDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.currentUser;
    final tips = [
      (
        Icons.event_available_outlined,
        'Bảng công của bạn',
        'Xem số công, đi muộn / về sớm và số phép còn lại.',
        AppColors.primary,
        () => ref.read(shellTabProvider.notifier).state = AppShellTab.attendance,
      ),
      (
        Icons.post_add_outlined,
        'Gửi đơn trực tuyến',
        'Đơn công, nghỉ con nhỏ, đào tạo, hội thảo… ngay trên máy.',
        AppColors.warning,
        () => ref.read(shellTabProvider.notifier).state = AppShellTab.requests,
      ),
      (
        Icons.fact_check_outlined,
        'Đánh giá & xếp loại',
        'Lập phiếu, duyệt và xem xếp loại khối ĐD–KTV–HS.',
        AppColors.info,
        () => context.push(RoutePaths.evaluation),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppReveal(
          delay: AppStagger.delayFor(0),
          child: const _SectionHeader(
            title: 'Hồ sơ của tôi',
            icon: Icons.badge_outlined,
          ),
        ),
        AppReveal(
          delay: AppStagger.delayFor(1),
          child: const Padding(
            padding: AppSpacing.pageH,
            child: _MyProfileHomeCard(),
          ),
        ),
        if (RoleGroups.canViewWorkforceReports(
          auth.role,
          reportViewEnabled: me?.reportViewEnabled ?? false,
        ))
          AppReveal(
            delay: AppStagger.delayFor(2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: _OrgShortcutCard(
                icon: Icons.assessment_rounded,
                title: 'Báo cáo nhân lực',
                subtitle: 'Toàn viện và quân số đi làm hằng ngày',
                color: AppColors.primary,
                onTap: () => context.push(RoutePaths.workforceReports),
              ),
            ),
          ),
        AppReveal(
          delay: AppStagger.delayFor(2),
          child: const _SectionHeader(
            title: 'Bắt đầu với HRM',
            icon: Icons.tips_and_updates_outlined,
          ),
        ),
        Padding(
          padding: AppSpacing.pageH,
          child: Column(
            children: [
              for (var i = 0; i < tips.length; i++)
                AppReveal(
                  delay: AppStagger.delayFor(i + 3),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _QuickActionTile(
                      icon: tips[i].$1,
                      title: tips[i].$2,
                      body: tips[i].$3,
                      color: tips[i].$4,
                      onTap: tips[i].$5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ hồ sơ nhân viên trên trang chủ — mở trang hồ sơ như web.
class _MyProfileHomeCard extends ConsumerWidget {
  const _MyProfileHomeCard();

  void _openEmployeeProfile(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authControllerProvider);
    final id = auth.employeeId ?? auth.currentUser?.employeeId;
    if (id != null) {
      context.push(RoutePaths.employeeDetailPath(id));
    } else {
      context.push(RoutePaths.employeeMePath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.currentUser;
    final name = me?.displayName ?? auth.fullName ?? 'Nhân viên';
    final position = me?.positionTitle?.trim();
    final department = me?.departmentName?.trim();
    final workUnit = me?.workUnitDetail?.trim();
    final code = me?.employeeCode?.trim();
    final subtitle = [
      if (department != null && department.isNotEmpty) department,
      if (position != null && position.isNotEmpty) position,
    ].join(' · ');
    final hasSignature = me?.hasSignature == true;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                name: name,
                size: 58,
                authImageUrl:
                    me?.hasAvatar == true
                        ? ProfileRepository.myAvatarUrl
                        : null,
                borderColor: Colors.white,
                borderWidth: 2.5,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.listSubtitle(),
                      ),
                    ],
                    if (code != null && code.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          'CCCD: $code',
                          style: AppTypography.caption(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Material(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.brSm,
                child: InkWell(
                  onTap: () => _openEmployeeProfile(context, ref),
                  borderRadius: AppRadius.brSm,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (workUnit != null && workUnit.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.brSm,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      workUnit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _ProfileMetaChip(
            icon: hasSignature
                ? Icons.verified_rounded
                : Icons.draw_outlined,
            label: hasSignature ? 'Đã có chữ ký số' : 'Chưa có chữ ký số',
            color: hasSignature ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openEmployeeProfile(context, ref),
              icon: const Icon(Icons.person_outline_rounded, size: 18),
              label: const Text('Xem hồ sơ của tôi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                textStyle: AppTypography.style(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetaChip extends StatelessWidget {
  const _ProfileMetaChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.brSm,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgShortcutCard extends StatelessWidget {
  const _OrgShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brLg,
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadows.soft,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.brLg,
            child: Stack(
            children: [
              Positioned(
                right: -16,
                top: -18,
                child: IgnorePointer(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.07),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: AppRadius.brSm,
                          ),
                          child: Icon(icon, size: 20, color: color),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.style(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: AppTypography.listSubtitle(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: color,
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
