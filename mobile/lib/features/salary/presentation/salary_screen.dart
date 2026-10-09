import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/salary/salary_access_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import '../../../core/widgets/brand_hero.dart';
import '../../../shared/models/salary_models.dart';
import '../../auth/application/auth_controller.dart';
import '../data/salary_repository.dart';
import 'salary_unlock_sheet.dart';

class _SalaryData {
  _SalaryData(this.profile, this.payroll);
  final SalaryProfile profile;
  final List<PayrollRow> payroll;
}

final _salaryDataProvider = FutureProvider.autoDispose.family<_SalaryData, int>(
  (ref, employeeId) async {
    final repo = ref.watch(salaryRepositoryProvider);
    final results = await Future.wait([
      repo.profile(employeeId),
      repo.payroll(employeeId),
    ]);
    return _SalaryData(
      results[0] as SalaryProfile,
      results[1] as List<PayrollRow>,
    );
  },
);

class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key, this.embedded = false});

  /// `true` khi nằm trong bottom nav.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final employeeId = auth.employeeId;
    final canView = auth.currentUser?.canViewSalary == true;
    final isManager = RoleGroups.salaryManagers.contains(auth.role);
    final unlocked = ref.watch(salaryAccessStoreProvider).isUnlocked;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppReveal(
            offset: 8,
            child: AppScreenHeader(
              eyebrow: 'Hồ sơ thu nhập',
              title: isManager ? 'Lương' : 'Lương của tôi',
              icon: Icons.payments_rounded,
              subtitle: isManager
                  ? (unlocked
                        ? 'Đã mở khóa quản lý lương toàn viện'
                        : 'Lương cá nhân · quản lý cần mở khóa')
                  : 'Thông tin lương, thâm niên và bậc lương',
              trailing: canView || isManager
                  ? _HeaderScaleButton(
                      onTap: () => context.push(RoutePaths.salaryScales),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: !canView && !isManager
                ? const EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Chưa có dữ liệu lương',
                    message:
                        'Hồ sơ lương của bạn chưa được tạo hoặc chưa được mở quyền xem. Vui lòng liên hệ HCNS.',
                  )
                : Column(
                    children: [
                      if (isManager)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            8,
                            AppSpacing.page,
                            8,
                          ),
                          child: _AdminHub(
                            unlocked: unlocked,
                            onOpenProfiles: () async {
                              if (!await ensureSalaryUnlocked(context, ref)) {
                                return;
                              }
                              if (!context.mounted) return;
                              context.push(RoutePaths.salaryAdminProfile);
                            },
                            onOpenScales: () async {
                              if (!await ensureSalaryUnlocked(context, ref)) {
                                return;
                              }
                              if (!context.mounted) return;
                              context.push(RoutePaths.salaryAdminScales);
                            },
                            onOpenReviews: () async {
                              if (!await ensureSalaryUnlocked(context, ref)) {
                                return;
                              }
                              if (!context.mounted) return;
                              context.push(RoutePaths.salaryGradeReviews);
                            },
                            onRecalculate: () async {
                              if (!await ensureSalaryUnlocked(context, ref)) {
                                return;
                              }
                              if (!context.mounted) return;
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Tính lại tất cả',
                                message:
                                    'Tính lại lương toàn bộ nhân viên đã có hồ sơ?',
                                confirmLabel: 'Tính lại',
                                icon: Icons.refresh_rounded,
                              );
                              if (ok != true || !context.mounted) return;
                              try {
                                final n = await ref
                                    .read(salaryRepositoryProvider)
                                    .recalculateAll();
                                if (!context.mounted) return;
                                showAppSnackBar(
                                  context,
                                  'Đã tính lại $n hồ sơ lương',
                                  isSuccess: true,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                showAppSnackBar(
                                  context,
                                  e.toString(),
                                  isError: true,
                                );
                              }
                            },
                          ),
                        ),
                      Expanded(
                        child: !canView
                            ? const EmptyState(
                                icon: Icons.lock_outline_rounded,
                                title: 'Chưa có dữ liệu lương cá nhân',
                                message:
                                    'Hồ sơ lương của bạn chưa được mở quyền xem.',
                              )
                            : employeeId == null
                            ? const EmptyState(
                                icon: Icons.link_off_rounded,
                                title: 'Chưa liên kết hồ sơ nhân viên',
                                message:
                                    'Tài khoản chưa gắn hồ sơ nhân viên nên chưa xem được lương cá nhân.',
                              )
                            : _MySalarySection(employeeId: employeeId),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MySalarySection extends ConsumerWidget {
  const _MySalarySection({required this.employeeId});

  final int employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_salaryDataProvider(employeeId));
    return async.when(
      loading: () => const SkeletonList(itemCount: 4, showAvatar: false),
      error: (e, _) => ErrorState(
        message: 'Không tải được thông tin lương',
        onRetry: () => ref.invalidate(_salaryDataProvider(employeeId)),
      ),
      data: (data) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          final _ = await ref.refresh(_salaryDataProvider(employeeId).future);
        },
        child: _Body(data: data),
      ),
    );
  }
}

class _AdminHub extends StatelessWidget {
  const _AdminHub({
    required this.unlocked,
    required this.onOpenProfiles,
    required this.onOpenScales,
    required this.onOpenReviews,
    required this.onRecalculate,
  });

  final bool unlocked;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenScales;
  final VoidCallback onOpenReviews;
  final VoidCallback onRecalculate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _HubTile(
                icon: Icons.badge_outlined,
                title: 'Hồ sơ NV',
                subtitle: 'Cấu hình lương',
                onTap: onOpenProfiles,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HubTile(
                icon: Icons.stairs_outlined,
                title: 'Thang bảng',
                subtitle: 'Toàn viện',
                onTap: onOpenScales,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _HubTile(
                icon: Icons.trending_up_rounded,
                title: 'Nâng bậc',
                subtitle: 'Đến kỳ tháng',
                onTap: onOpenReviews,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HubTile(
                icon: Icons.refresh_rounded,
                title: 'Tính lại',
                subtitle: unlocked ? 'Toàn bộ hồ sơ' : 'Cần mở khóa',
                onTap: onRecalculate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brCard,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: TintedCardBackdrop.gradient(AppColors.primary),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
            child: Row(
              children: [
                TintedIconTile(icon: icon, color: AppColors.primary, size: 34),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 11,
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

class _HeaderScaleButton extends StatelessWidget {
  const _HeaderScaleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return Semantics(
      button: true,
      label: 'Xem thang bảng lương',
      child: Tooltip(
        message: 'Thang bảng lương',
        child: Material(
          color: onBrand.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.stairs_rounded, color: onBrand, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.data});

  final _SalaryData data;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _showAmounts = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final profile = data.profile;

    String money(num? amount) {
      if (!profile.canViewSensitive) return 'Không có quyền xem';
      return _showAmounts ? AppFormat.currency(amount) : '••••••••';
    }

    String semanticMoney(num? amount) {
      if (!profile.canViewSensitive) return 'Không có quyền xem';
      return _showAmounts ? AppFormat.currency(amount) : 'Số tiền đang được ẩn';
    }

    final seniorityLabel = profile.ldg
        ? 'LĐG'
        : '${AppFormat.years(profile.seniorityYears)} năm';
    final startDate = AppFormat.date(
      AppFormat.tryParseDate(profile.salaryScaleStartDate),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        AppReveal(
          offset: 10,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: _SalaryHero(
              totalLabel: money(profile.totalSalary),
              totalSemantic: semanticMoney(profile.totalSalary),
              objectLabel: profile.objectLabel,
              gradeLabel: profile.displayGradeLabel,
              coefficient: profile.coefficient,
              canReveal: profile.canViewSensitive,
              showAmounts: _showAmounts,
              onToggleReveal: () =>
                  setState(() => _showAmounts = !_showAmounts),
            ),
          ),
        ),
        AppReveal(
          delay: const Duration(milliseconds: 35),
          offset: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: _OverviewStrip(
              items: [
                (Icons.calendar_month_rounded, 'Bắt đầu', startDate),
                (Icons.trending_up_rounded, 'Thâm niên', seniorityLabel),
                (Icons.military_tech_rounded, 'Bậc', profile.gradeLabel ?? '—'),
              ],
            ),
          ),
        ),
        AppReveal(
          delay: const Duration(milliseconds: 55),
          offset: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: _ScaleShortcut(
              onTap: () => context.push(RoutePaths.salaryScales),
            ),
          ),
        ),
        AppReveal(
          delay: const Duration(milliseconds: 75),
          offset: 8,
          child: _SalaryDetailsCard(
            profile: profile,
            money: money,
            semanticMoney: semanticMoney,
            seniorityLabel: seniorityLabel,
          ),
        ),
        AppSectionTitle(
          title: 'Lịch sử bảng lương',
          icon: Icons.receipt_long_outlined,
          action: data.payroll.isEmpty
              ? null
              : Text(
                  '${data.payroll.length} kỳ',
                  style: AppTypography.caption(fontWeight: FontWeight.w600),
                ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xs,
          ),
        ),
        if (data.payroll.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Chưa có dữ liệu bảng lương',
            message: 'Bảng lương sẽ xuất hiện sau khi HCNS chốt kỳ lương.',
          )
        else
          for (final (index, row) in data.payroll.indexed)
            AppReveal(
              delay: AppStagger.delayFor(index),
              offset: 9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.xs + 2,
                ),
                child: _PayrollCard(
                  row: row,
                  amountFormatter: money,
                  semanticAmountFormatter: semanticMoney,
                ),
              ),
            ),
      ],
    );
  }
}

class _SalaryHero extends StatelessWidget {
  const _SalaryHero({
    required this.totalLabel,
    required this.totalSemantic,
    required this.objectLabel,
    required this.gradeLabel,
    required this.coefficient,
    required this.canReveal,
    required this.showAmounts,
    required this.onToggleReveal,
  });

  final String totalLabel;
  final String totalSemantic;
  final String objectLabel;
  final String gradeLabel;
  final num? coefficient;
  final bool canReveal;
  final bool showAmounts;
  final VoidCallback onToggleReveal;

  @override
  Widget build(BuildContext context) {
    return BrandHeroCard(
      ornamentIcon: Icons.account_balance_wallet_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandGlassIconTile(
                icon: Icons.account_balance_wallet_rounded,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandHeroEyebrow(text: 'Tổng lương hiện tại'),
                    const SizedBox(height: 5),
                    Text(
                      objectLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (canReveal) ...[
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: showAmounts ? 'Ẩn số tiền' : 'Hiện số tiền',
                  child: Material(
                    type: MaterialType.transparency,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      color: Colors.white.withValues(alpha: 0.14),
                      child: InkWell(
                        onTap: onToggleReveal,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            showAmounts
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: 'Tổng lương: $totalSemantic',
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  totalLabel,
                  style: AppTypography.display(
                    fontSize: 32,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _HeroPill(
                icon: Icons.military_tech_rounded,
                label: gradeLabel,
                tone: AppColors.secondaryLight,
              ),
              if (coefficient != null && coefficient! > 0)
                _HeroPill(
                  icon: Icons.functions_rounded,
                  label: 'Hệ số $coefficient',
                  tone: AppColors.onBrandRing,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    this.tone = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: AppTypography.uppercaseHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.items});

  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (i, item) in items.indexed) ...[
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
                    children: [
                      TintedIconTile(
                        icon: item.$1,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.$2.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppTypography.uppercase(
                          fontSize: 9.5,
                          letterSpacing: 0.6,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metric(
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
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

class _ScaleShortcut extends StatelessWidget {
  const _ScaleShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primary;
    return AppCard(
      onTap: onTap,
      gradient: TintedCardBackdrop.gradient(accent),
      borderRadius: AppRadius.brLg,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: TintedCardBackdrop(
        accent: accent,
        watermarkIcon: Icons.stairs_rounded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              const TintedIconTile(
                icon: Icons.stairs_rounded,
                color: accent,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thang bảng lương',
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xem toàn bộ bậc theo trình độ của bạn',
                      style: AppTypography.listSubtitle(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const TintedChevron(accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalaryDetailsCard extends StatelessWidget {
  const _SalaryDetailsCard({
    required this.profile,
    required this.money,
    required this.semanticMoney,
    required this.seniorityLabel,
  });

  final SalaryProfile profile;
  final String Function(num?) money;
  final String Function(num?) semanticMoney;
  final String seniorityLabel;

  @override
  Widget build(BuildContext context) {
    final isEmployee = profile.salaryCategory == 'EMPLOYEE';
    final isDoctor = profile.salaryCategory == 'DOCTOR';
    final grade = profile.computedGrade;
    final hasSplit =
        (profile.insuranceSalary ?? 0) > 0 || (profile.productSalary ?? 0) > 0;
    final conversions = profile.earlyRaiseConversions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
              ),
              child: Row(
                children: [
                  const TintedIconTile(
                    icon: Icons.receipt_rounded,
                    color: AppColors.success,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết lương',
                          style: AppTypography.style(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kết quả tính theo cấu hình hiện tại',
                          style: AppTypography.caption(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: AppRadius.brSm,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đối tượng lương',
                          style: AppTypography.caption(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.objectLabel,
                          style: AppTypography.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DetailLine(
                    label: 'Bắt đầu thang bảng lương',
                    value: AppFormat.date(
                      AppFormat.tryParseDate(profile.salaryScaleStartDate),
                    ),
                  ),
                  _DetailLine(
                    label: 'Thâm niên tính lương',
                    value: seniorityLabel,
                    emphasize: true,
                  ),
                  _DetailLine(
                    label: 'Quy đổi nâng lương sớm',
                    value: '${AppFormat.years(profile.priorRaiseYears)} năm',
                  ),
                  if (conversions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 4),
                        title: Text(
                          'Chi tiết ${conversions.length} lần nâng sớm',
                          style: AppTypography.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.infoDark,
                          ),
                        ),
                        children: [
                          for (final e in conversions)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.raiseDate != null
                                          ? AppFormat.date(
                                              AppFormat.tryParseDate(
                                                e.raiseDate,
                                              ),
                                            )
                                          : 'Không có ngày',
                                      style: AppTypography.listSubtitle(),
                                    ),
                                  ),
                                  Text(
                                    '+${AppFormat.years(e.years)} năm',
                                    style: AppTypography.style(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (isEmployee &&
                      (profile.qualification?.isNotEmpty ?? false))
                    _DetailLine(
                      label: 'Trình độ',
                      value: profile.qualification!,
                    ),
                  _DetailLine(
                    label: 'Bậc lương',
                    value: profile.displayGradeLabel,
                    emphasize: true,
                  ),
                  if (isEmployee &&
                      grade != null &&
                      (profile.coefficient ?? 0) > 0)
                    _DetailLine(
                      label: 'Hệ số',
                      value: '${profile.coefficient}',
                    ),
                  if (isEmployee && hasSplit) ...[
                    _DetailLine(
                      label: 'Lương đóng BH (cơ bản)',
                      value: money(profile.insuranceSalary),
                      semanticValue: semanticMoney(profile.insuranceSalary),
                    ),
                    _DetailLine(
                      label: 'Lương đảm bảo sản phẩm',
                      value: money(profile.productSalary),
                      semanticValue: semanticMoney(profile.productSalary),
                    ),
                  ],
                  if (isDoctor) ...[
                    if (hasSplit) ...[
                      _DetailLine(
                        label: 'Lương cơ bản',
                        value: money(profile.insuranceSalary),
                        semanticValue: semanticMoney(profile.insuranceSalary),
                      ),
                      _DetailLine(
                        label: 'Lương đảm bảo sản phẩm',
                        value: money(profile.productSalary),
                        semanticValue: semanticMoney(profile.productSalary),
                      ),
                    ],
                    if ((profile.scaleSalary ?? 0) > 0)
                      _DetailLine(
                        label: 'Tổng theo thang bảng BS',
                        value: money(profile.scaleSalary),
                        semanticValue: semanticMoney(profile.scaleSalary),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.semanticValue,
  });

  final String label;
  final String value;
  final bool emphasize;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${semanticValue ?? value}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 12.8,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value.isEmpty ? '—' : value,
                  textAlign: TextAlign.end,
                  style: AppTypography.style(
                    fontSize: emphasize ? 13.8 : 13,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                    color: emphasize
                        ? AppColors.primary
                        : AppColors.textPrimary,
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

class _PayrollCard extends StatefulWidget {
  const _PayrollCard({
    required this.row,
    required this.amountFormatter,
    required this.semanticAmountFormatter,
  });

  final PayrollRow row;
  final String Function(num?) amountFormatter;
  final String Function(num?) semanticAmountFormatter;

  @override
  State<_PayrollCard> createState() => _PayrollCardState();
}

class _PayrollCardState extends State<_PayrollCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final color = row.finalized ? AppColors.success : AppColors.warning;
    final spokenDetails = <String>[
      'Kỳ lương ${row.periodMonth}/${row.periodYear}',
      row.finalized ? 'đã chốt' : 'tạm tính',
      'Ngày công ${row.workingDays}',
      'Thực nhận ${widget.semanticAmountFormatter(row.netAmount)}',
      if (_expanded) ...[
        'Tổng thu nhập ${widget.semanticAmountFormatter(row.grossAmount)}',
        'Tổng khấu trừ ${widget.semanticAmountFormatter(row.deductionAmount)}',
        if (row.note?.trim().isNotEmpty == true) 'Ghi chú ${row.note!.trim()}',
      ],
    ];

    return Semantics(
      button: true,
      expanded: _expanded,
      label: spokenDetails.join('. '),
      hint: _expanded
          ? 'Chạm hai lần để thu gọn'
          : 'Chạm hai lần để xem chi tiết',
      child: AppCard(
        onTap: () => setState(() => _expanded = !_expanded),
        gradient: TintedCardBackdrop.gradient(color),
        borderRadius: AppRadius.brCard,
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: ExcludeSemantics(
          child: AnimatedSize(
            duration: AppDurations.normal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TintedIconTile(
                      icon: Icons.calendar_month_rounded,
                      color: color,
                      size: 42,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kỳ lương ${row.periodMonth}/${row.periodYear}',
                            style: AppTypography.listTitle(),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Ngày công: ${AppFormat.score(row.workingDays)}',
                            style: AppTypography.listSubtitle(),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.amountFormatter(row.netAmount),
                          style: AppTypography.display(
                            fontSize: 20,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusChip(
                      label: row.finalized ? 'Đã chốt' : 'Tạm tính',
                      color: color,
                      dense: true,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const Divider(height: AppSpacing.xl),
                  InfoRow(
                    label: 'Tổng thu nhập',
                    value: widget.amountFormatter(row.grossAmount),
                  ),
                  InfoRow(
                    label: 'Tổng khấu trừ',
                    value: widget.amountFormatter(row.deductionAmount),
                    valueColor: AppColors.error,
                  ),
                  InfoRow(
                    label: 'Thực nhận',
                    value: widget.amountFormatter(row.netAmount),
                    valueColor: AppColors.primary,
                  ),
                  if (row.note?.trim().isNotEmpty == true)
                    InfoRow(
                      label: 'Ghi chú',
                      value: row.note!,
                      multiline: true,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
