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
import '../../../core/widgets/list_section_title.dart';
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
            ref.read(notificationControllerProvider.notifier).pollQuietly(),
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

  static const double _actionSize = 44;

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
              Transform.translate(
                offset: const Offset(0, 2),
                child: Container(
                  width: _actionSize,
                  height: _actionSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.26),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const BrandMark(size: _actionSize),
                ),
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
              authImageUrl: hasAvatar ? ProfileRepository.myAvatarUrl : null,
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
      UserRole.admin || UserRole.hr || UserRole.headHr => (
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
          borderRadius: AppRadius.brXl,
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
    final soft = Paint()..color = AppColors.onBrandSoft.withValues(alpha: 0.45);

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

class _AdminPulseBlock extends StatelessWidget {
  const _AdminPulseBlock({
    required this.working,
    required this.totalEmployees,
    required this.maternityLeave,
    required this.departments,
  });

  final int working;
  final int totalEmployees;
  final int maternityLeave;
  final int departments;

  @override
  Widget build(BuildContext context) {
    final ratio = totalEmployees <= 0
        ? 0.0
        : (working / totalEmployees).clamp(0.0, 1.0);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          'Tổng quan nhân sự toàn viện, $totalEmployees nhân viên, '
          '$working đang làm việc, $maternityLeave nghỉ thai sản, '
          '$departments khoa phòng',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          gradient: AppGradients.brandHero,
          borderRadius: AppRadius.brXl,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.24),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -48,
              top: -54,
              child: IgnorePointer(
                child: Container(
                  width: 172,
                  height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -86,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryLight.withValues(alpha: 0.06),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: AppRadius.brMd,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NHÂN SỰ TOÀN VIỆN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Quản trị nguồn lực bệnh viện',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.onBrandAlert,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$maternityLeave nghỉ thai sản',
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'TỔNG NHÂN SỰ ĐANG QUẢN LÝ',
                  style: AppTypography.style(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.85,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppFormat.number(totalEmployees),
                                style: AppTypography.metric(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'nhân viên',
                              style: AppTypography.style(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DashboardRatioRing(
                      value: ratio,
                      label: 'đang làm',
                      color: AppColors.onBrandRing,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.105),
                    borderRadius: AppRadius.brLg,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DashboardHeroStat(
                          icon: Icons.work_outline_rounded,
                          label: 'Đang làm',
                          value: working,
                        ),
                      ),
                      _DashboardGlassDivider(),
                      Expanded(
                        child: _DashboardHeroStat(
                          icon: Icons.pregnant_woman_rounded,
                          label: 'Nghỉ thai sản',
                          value: maternityLeave,
                          highlight: maternityLeave > 0,
                        ),
                      ),
                      _DashboardGlassDivider(),
                      Expanded(
                        child: _DashboardHeroStat(
                          icon: Icons.apartment_rounded,
                          label: 'Khoa/phòng',
                          value: departments,
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
          const gap = 12.0;
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
                  height: scale > 1.25
                      ? 148
                      : columns == 1
                      ? 112
                      : 124,
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
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${item.label}: ${item.value} ${item.unit}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: item.color.withValues(alpha: 0.15)),
          boxShadow: AppShadows.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -26,
              child: IgnorePointer(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color.withValues(alpha: 0.055),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Icon(item.icon, size: 17, color: item.color),
                      ),
                      const Spacer(),
                      if (item.accent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.09),
                            borderRadius: AppRadius.brPill,
                          ),
                          child: Text(
                            item.accent!,
                            maxLines: 1,
                            style: AppTypography.style(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: item.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppFormat.number(item.value),
                            style: AppTypography.metric(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            item.unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardBody extends ConsumerWidget {
  const _AdminDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardAdminStatsProvider);
    final role = ref.watch(authControllerProvider).role;

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
                        color: AppColors.moduleEmployee,
                        onTap: () => context.push(RoutePaths.employees),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (role == UserRole.admin)
            AppReveal(
              delay: AppStagger.delayFor(1),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  10,
                  AppSpacing.page,
                  0,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _OrgShortcutCard(
                          icon: Icons.monitor_heart_outlined,
                          title: 'Báo cáo ĐD hằng ngày',
                          subtitle: 'Theo dõi toàn khối',
                          color: AppColors.moduleNursingDaily,
                          onTap: () =>
                              context.push(RoutePaths.nursingDailyReports),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OrgShortcutCard(
                          icon: Icons.biotech_outlined,
                          title: 'Đánh giá QTKT',
                          subtitle: 'Lập phiếu · tổng hợp',
                          color: AppColors.moduleQtkt,
                          onTap: () => context.push(RoutePaths.qtktEvaluations),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (role == UserRole.admin)
            AppReveal(
              delay: AppStagger.delayFor(1),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  10,
                  AppSpacing.page,
                  0,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _OrgShortcutCard(
                          icon: Icons.analytics_outlined,
                          title: 'Hoạt động ĐD',
                          subtitle: 'Module A · tỉ lệ sự cố',
                          color: AppColors.moduleNursingActivity,
                          onTap: () =>
                              context.push(RoutePaths.nursingActivityReports),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OrgShortcutCard(
                          icon: Icons.health_and_safety_outlined,
                          title: 'Tuân thủ QTKT',
                          subtitle: 'Vệ sinh tay · GDSK',
                          color: AppColors.moduleQtktCompliance,
                          onTap: () =>
                              context.push(RoutePaths.qtktComplianceReports),
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
                maternityLeave: stats.maternityLeave,
                departments: stats.departments,
              ),
            ),
          ),
          const BlockSectionTitle(
            padding: BlockSectionTitle.pagePadding,
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
          BlockSectionTitle(
            padding: BlockSectionTitle.pagePadding,
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
                  12,
                  AppSpacing.page,
                  0,
                ),
                child: _NursingApprovalAction(
                  count: stats.pendingTotal,
                  onTap: () => context.push(_firstPendingRoute(stats)),
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
                        color: AppColors.moduleEmployee,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                10,
                AppSpacing.page,
                0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Báo cáo ĐD hằng ngày',
                        subtitle: 'Xem · sửa toàn khối',
                        color: AppColors.moduleNursingDaily,
                        onTap: () =>
                            context.push(RoutePaths.nursingDailyReports),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.biotech_outlined,
                        title: 'Đánh giá QTKT',
                        subtitle: 'Xem · tổng hợp tháng',
                        color: AppColors.moduleQtkt,
                        onTap: () => context.push(RoutePaths.qtktEvaluations),
                      ),
                    ),
                  ],
                ),
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
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.analytics_outlined,
                        title: 'Hoạt động ĐD',
                        subtitle: 'Module A · sự cố',
                        color: AppColors.moduleNursingActivity,
                        onTap: () =>
                            context.push(RoutePaths.nursingActivityReports),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.health_and_safety_outlined,
                        title: 'Tuân thủ QTKT',
                        subtitle: 'Vệ sinh tay · GDSK',
                        color: AppColors.moduleQtktCompliance,
                        onTap: () =>
                            context.push(RoutePaths.qtktComplianceReports),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (stats.bySubGroup.isNotEmpty) ...[
            const BlockSectionTitle(
              padding: BlockSectionTitle.pagePadding,
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
          BlockSectionTitle(
            padding: BlockSectionTitle.pagePadding,
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
                    color: AppColors.moduleDeployment,
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
                    color: AppColors.moduleNursingDaily,
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
                    color: AppColors.moduleQtkt,
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
          const BlockSectionTitle(
            padding: BlockSectionTitle.pagePadding,
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
            child: const BlockSectionTitle(
              padding: BlockSectionTitle.pagePadding,
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
    final officialRatio = total <= 0
        ? 0.0
        : (stats.officialCount / total).clamp(0.0, 1.0);

    return Semantics(
      container: true,
      label:
          'Tổng quan khối Điều dưỡng, $total nhân viên, '
          '${stats.pendingTotal} hồ sơ chờ duyệt',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          gradient: AppGradients.brandHero,
          borderRadius: AppRadius.brXl,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.24),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -48,
              top: -54,
              child: IgnorePointer(
                child: Container(
                  width: 172,
                  height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -86,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryLight.withValues(alpha: 0.06),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: AppRadius.brMd,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KHỐI ĐIỀU DƯỠNG',
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.05,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'ĐD · KTV · Hộ sinh · Thư ký',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.94),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stats.pendingTotal > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: AppRadius.brPill,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.onBrandAlert,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${stats.pendingTotal} chờ duyệt',
                              style: AppTypography.style(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TỔNG NHÂN SỰ ĐANG QUẢN LÝ',
                            style: AppTypography.style(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.65,
                              color: Colors.white.withValues(alpha: 0.62),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppFormat.number(total),
                                style: AppTypography.metric(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'nhân viên',
                                  style: AppTypography.style(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Align(
                      alignment: Alignment.center,
                      child: _DashboardRatioRing(
                        value: officialRatio,
                        label: 'chính thức',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.105),
                    borderRadius: AppRadius.brLg,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DashboardHeroStat(
                          icon: Icons.badge_outlined,
                          label: 'Chính thức',
                          value: stats.officialCount,
                        ),
                      ),
                      _DashboardGlassDivider(),
                      Expanded(
                        child: _DashboardHeroStat(
                          icon: Icons.pending_actions_rounded,
                          label: 'Chờ duyệt',
                          value: stats.pendingTotal,
                          highlight: stats.pendingTotal > 0,
                        ),
                      ),
                      _DashboardGlassDivider(),
                      Expanded(
                        child: _DashboardHeroStat(
                          icon: Icons.apartment_rounded,
                          label: 'Khoa/phòng',
                          value: stats.departmentsCovered,
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

class _DashboardRatioRing extends StatelessWidget {
  const _DashboardRatioRing({
    required this.value,
    required this.label,
    this.color = AppColors.secondaryLight,
  });

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    // CircularProgressIndicator bắt đầu từ đỉnh và để phần còn thiếu lệch
    // sang trái. Xoay nửa khoảng trống để khe hở luôn cân giữa ở 12 giờ.
    final centeredGapAngle = (1 - progress) * 3.141592653589793;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return SizedBox.square(
          dimension: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 72,
                child: Transform.rotate(
                  angle: centeredGapAngle,
                  child: CircularProgressIndicator(
                    value: animatedValue,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${(animatedValue * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: AppTypography.metric(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardGlassDivider extends StatelessWidget {
  const _DashboardGlassDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _DashboardHeroStat extends StatelessWidget {
  const _DashboardHeroStat({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? AppColors.onBrandAlertSoft : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: foreground.withValues(alpha: 0.78)),
              const SizedBox(width: 5),
              Text(
                AppFormat.number(value),
                style: AppTypography.metric(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _NursingApprovalAction extends StatelessWidget {
  const _NursingApprovalAction({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Duyệt $count hồ sơ đang chờ xử lý',
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brLg,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.surface,
                  AppColors.primaryContainer.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: AppRadius.brLg,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.13),
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      borderRadius: AppRadius.brMd,
                      boxShadow: AppShadows.tinted(AppColors.primary),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duyệt hồ sơ chờ xử lý',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$count yêu cầu cần kiểm tra và phê duyệt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 10.8,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      AppFormat.number(count),
                      style: AppTypography.metric(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.errorText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: AppColors.primary,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                          color: hasPending ? color : AppColors.textTertiary,
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
        () =>
            ref.read(shellTabProvider.notifier).state = AppShellTab.attendance,
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
          child: const BlockSectionTitle(
            padding: BlockSectionTitle.pagePadding,
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
        if (RoleGroups.canViewEmployeeDirectory(
              auth.role,
              hospitalWideEmployeeViewEnabled:
                  me?.hospitalWideEmployeeViewEnabled ?? false,
            ) &&
            auth.role != UserRole.admin &&
            auth.role != UserRole.hr)
          AppReveal(
            delay: const Duration(milliseconds: 180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: _OrgShortcutCard(
                icon: Icons.groups_rounded,
                title: 'Danh sách nhân viên',
                subtitle:
                    me?.hospitalWideEmployeeViewEnabled == true &&
                        !RoleGroups.isIn(auth.role, RoleGroups.adminHrHeads)
                    ? 'Xem hồ sơ toàn viện'
                    : 'Tra cứu hồ sơ trong phạm vi của bạn',
                color: AppColors.moduleEmployee,
                onTap: () => context.push(RoutePaths.employees),
              ),
            ),
          ),
        if (RoleGroups.canEnterNursingDailyReports(auth.role))
          AppReveal(
            delay: AppStagger.delayFor(3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: _OrgShortcutCard(
                icon: Icons.local_hospital_outlined,
                title: 'Báo cáo ĐD hằng ngày',
                subtitle:
                    'ĐD trưởng khoa nhập · Trưởng phòng ĐD xem/sửa toàn bộ',
                color: AppColors.moduleNursingDaily,
                onTap: () => context.push(RoutePaths.nursingDailyReports),
              ),
            ),
          ),
        if (RoleGroups.canEnterQtkt(auth.role))
          AppReveal(
            delay: AppStagger.delayFor(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: _OrgShortcutCard(
                icon: Icons.biotech_outlined,
                title: 'Đánh giá quy trình kỹ thuật',
                subtitle: 'Lập và chấm phiếu nhân viên khoa phụ trách',
                color: AppColors.moduleQtkt,
                onTap: () => context.push(RoutePaths.qtktEvaluations),
              ),
            ),
          ),
        if (RoleGroups.canViewNursingAnalytics(auth.role))
          AppReveal(
            delay: AppStagger.delayFor(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.analytics_outlined,
                        title: 'Hoạt động ĐD',
                        subtitle: 'Module A',
                        color: AppColors.moduleNursingActivity,
                        onTap: () =>
                            context.push(RoutePaths.nursingActivityReports),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OrgShortcutCard(
                        icon: Icons.health_and_safety_outlined,
                        title: 'Tuân thủ QTKT',
                        subtitle: 'Tỉ lệ đạt',
                        color: AppColors.moduleQtktCompliance,
                        onTap: () =>
                            context.push(RoutePaths.qtktComplianceReports),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        AppReveal(
          delay: AppStagger.delayFor(2),
          child: const BlockSectionTitle(
            padding: BlockSectionTitle.pagePadding,
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
                authImageUrl: me?.hasAvatar == true
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
                          'Mã NV: $code',
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            icon: hasSignature ? Icons.verified_rounded : Icons.draw_outlined,
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
      borderRadius: AppRadius.brLg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brLg,
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
                      Text(body, style: AppTypography.listSubtitle()),
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
