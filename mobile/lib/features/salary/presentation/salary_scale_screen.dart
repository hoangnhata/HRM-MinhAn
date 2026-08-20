import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/salary_models.dart';
import '../../auth/application/auth_controller.dart';
import '../data/salary_repository.dart';

final _salaryScalesProvider =
    FutureProvider.autoDispose.family<AllSalaryScales, bool>((ref, admin) async {
  return ref.watch(salaryRepositoryProvider).scales(mine: !admin);
});

final _mySalaryProfileProvider =
    FutureProvider.autoDispose<SalaryProfile?>((ref) async {
  final id = ref.watch(authControllerProvider).employeeId;
  if (id == null) return null;
  return ref.watch(salaryRepositoryProvider).profile(id);
});

class SalaryScaleScreen extends ConsumerStatefulWidget {
  const SalaryScaleScreen({super.key, this.admin = false});

  final bool admin;

  @override
  ConsumerState<SalaryScaleScreen> createState() => _SalaryScaleScreenState();
}

class _SalaryScaleScreenState extends ConsumerState<SalaryScaleScreen> {
  static const _scopeLabels = {
    'DIRECT': 'Nhân viên trực tiếp',
    'INDIRECT': 'Nhân viên gián tiếp',
    'DOCTOR': 'Bác sỹ',
    'ALL': 'Toàn bộ đối tượng',
    'NONE': 'Chưa cấu hình',
  };

  int _scopeTab = 0;
  int _tierIndex = 0;
  int? _expandedGrade;
  bool _userPickedScope = false;
  bool _userPickedTier = false;
  bool _userToggledExpand = false;

  EmployeeScale? _scaleForTab(AllSalaryScales scales, int tab) {
    return switch (tab) {
      1 => scales.employeeIndirect,
      2 => null,
      _ => scales.employeeDirect,
    };
  }

  int _defaultScopeTab(AllSalaryScales scales) {
    return switch (scales.viewerScope) {
      'INDIRECT' => 1,
      'DOCTOR' => 2,
      _ => 0,
    };
  }

  int _defaultTierIndex(EmployeeScale scale, SalaryProfile? profile) {
    final qual = profile?.qualification;
    if (qual == null) return 0;
    final idx = scale.tiers.indexWhere((t) => t.tierLabel == qual);
    return idx >= 0 ? idx : 0;
  }

  List<_ScopeOption> _visibleScopes(AllSalaryScales scales) {
    final scope = scales.viewerScope;
    if (scope == 'ALL') {
      return const [
        _ScopeOption(0, 'Trực tiếp', 'DIRECT'),
        _ScopeOption(1, 'Gián tiếp', 'INDIRECT'),
        _ScopeOption(2, 'Bác sỹ', 'DOCTOR'),
      ];
    }
    if (scope == 'DIRECT') {
      return const [_ScopeOption(0, 'Trực tiếp', 'DIRECT')];
    }
    if (scope == 'INDIRECT') {
      return const [_ScopeOption(1, 'Gián tiếp', 'INDIRECT')];
    }
    if (scope == 'DOCTOR') {
      return const [_ScopeOption(2, 'Bác sỹ', 'DOCTOR')];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_salaryScalesProvider(widget.admin));
    final profileAsync = ref.watch(_mySalaryProfileProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final scales = async.valueOrNull;
    final scopes =
        scales == null ? const <_ScopeOption>[] : _visibleScopes(scales);
    final computedTab =
        (!_userPickedScope && scales != null) ? _defaultScopeTab(scales) : _scopeTab;
    final headerTab = scopes.any((s) => s.tab == computedTab)
        ? computedTab
        : (scopes.isNotEmpty ? scopes.first.tab : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
          RefreshIndicator(
            edgeOffset: topInset,
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(_salaryScalesProvider(widget.admin));
              ref.invalidate(_mySalaryProfileProvider);
              await Future.wait([
                ref.read(_salaryScalesProvider(widget.admin).future),
                ref.read(_mySalaryProfileProvider.future),
              ]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: AppScreenHeader(
                    dense: true,
                    eyebrow: widget.admin ? 'Quản lý' : 'Thang bảng lương',
                    title: 'Áp dụng từ 4/2025',
                    subtitle: async.maybeWhen(
                      data: (s) {
                        if (widget.admin) {
                          return s.viewerScope == 'ALL'
                              ? 'Đã mở khóa — toàn bộ thang bảng'
                              : 'Thang bảng lương quản trị';
                        }
                        if (s.viewerScope == 'NONE') {
                          return 'Chưa có đối tượng lương trên hồ sơ.';
                        }
                        final label =
                            _scopeLabels[s.viewerScope] ?? s.viewerScope;
                        return 'Đối tượng: $label';
                      },
                      orElse: () => widget.admin
                          ? 'Toàn bộ đối tượng lương'
                          : 'Các bậc lương theo trình độ của bạn',
                    ),
                    icon: Icons.stairs_rounded,
                    onBack: () => context.pop(),
                    footer: scopes.length > 1
                        ? _HeaderScopeSegment(
                            options: scopes,
                            selectedTab: headerTab,
                            onBrand: onBrand,
                            onChanged: (tab) {
                              setState(() {
                                _userPickedScope = true;
                                _scopeTab = tab;
                                _userPickedTier = false;
                                _userToggledExpand = false;
                                _tierIndex = 0;
                                _expandedGrade = null;
                              });
                            },
                          )
                        : null,
                  ),
                ),
                ...async.when(
                  loading: () => [
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: SkeletonList(itemCount: 5, showAvatar: false),
                    ),
                  ],
                  error: (_, _) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorState(
                        message: 'Không tải được thang bảng lương',
                        onRetry: () =>
                            ref.invalidate(_salaryScalesProvider(widget.admin)),
                      ),
                    ),
                  ],
                  data: (scales) {
                    if (scales.viewerScope == 'NONE') {
                      return [
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.info_outline_rounded,
                            title: 'Chưa cấu hình đối tượng lương',
                            message:
                                'Sau khi HCNS gắn Trực tiếp / Gián tiếp / Bác sĩ, bạn sẽ xem đúng thang bảng tương ứng.',
                          ),
                        ),
                      ];
                    }

                    final profile = profileAsync.valueOrNull;
                    final scopes = _visibleScopes(scales);
                    if (scopes.isEmpty) {
                      return [
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.info_outline_rounded,
                            title: 'Chưa cấu hình đối tượng lương',
                            message:
                                'Sau khi HCNS gắn Trực tiếp / Gián tiếp / Bác sĩ, bạn sẽ xem đúng thang bảng tương ứng.',
                          ),
                        ),
                      ];
                    }

                    final activeTab = _userPickedScope
                        ? _scopeTab
                        : _defaultScopeTab(scales);
                    final activeScope = scopes.firstWhere(
                      (s) => s.tab == activeTab,
                      orElse: () => scopes.first,
                    );
                    final isDoctor = activeScope.tab == 2;

                    return [
                      if (!isDoctor)
                        ..._employeeSlivers(
                          scales: scales,
                          scopeTab: activeScope.tab,
                          scopeLabel: _scopeLabels[activeScope.code] ??
                              activeScope.label,
                          profile: profile,
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            14,
                            AppSpacing.page,
                            AppSpacing.xxl,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _DoctorLadder(entries: scales.doctor),
                            ]),
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _employeeSlivers({
    required AllSalaryScales scales,
    required int scopeTab,
    required String scopeLabel,
    required SalaryProfile? profile,
  }) {
    final scale = _scaleForTab(scales, scopeTab);
    if (scale == null || scale.tiers.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Chưa có dữ liệu thang bảng',
            message: 'HCNS chưa import thang bảng cho đối tượng này.',
          ),
        ),
      ];
    }

    final preferredTier = _userPickedTier
        ? _tierIndex
        : _defaultTierIndex(scale, profile);
    final safeTier = preferredTier.clamp(0, scale.tiers.length - 1);
    final tier = scale.tiers[safeTier];
    final myGrade = profile?.gradeLevel;
    final myQual = profile?.qualification;
    final isMyTier = myQual != null && myQual == tier.tierLabel;

    EmployeeScaleGrade? myGradeInTier;
    if (isMyTier && myGrade != null) {
      for (final g in tier.grades) {
        if (g.gradeLevel == myGrade) {
          myGradeInTier = g;
          break;
        }
      }
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppReveal(
                offset: 8,
                child: !widget.admin && myGradeInTier != null
                    ? _CurrentGradeHero(
                        scopeLabel: scopeLabel,
                        qualification: tier.tierLabel,
                        grade: myGradeInTier,
                      )
                    : _ScaleOverviewHero(
                        scopeLabel: scopeLabel,
                        qualification: tier.tierLabel,
                        grades: tier.grades,
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                'TRÌNH ĐỘ',
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              _TierChips(
                tiers: scale.tiers,
                selectedIndex: safeTier,
                onSelected: (i) {
                  setState(() {
                    _userPickedTier = true;
                    _userToggledExpand = false;
                    _tierIndex = i;
                    _expandedGrade = null;
                  });
                },
              ),
              if (widget.admin && scale.baseTotalAtCoef1 > 0) ...[
                const SizedBox(height: 12),
                _AdminBaseEditor(
                  scaleType: scale.scaleType,
                  qualification: tier.tierLabel,
                  currentBase: scale.baseTotalAtCoef1,
                  onUpdated: () =>
                      ref.invalidate(_salaryScalesProvider(true)),
                ),
              ],
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        sliver: SliverToBoxAdapter(
          child: AppReveal(
            delay: const Duration(milliseconds: 50),
            offset: 10,
            child: _GradeLadder(
              tierLabel: tier.tierLabel,
              grades: tier.grades,
              highlightGrade: isMyTier ? myGrade : null,
              expandedGrade: _userToggledExpand
                  ? _expandedGrade
                  : (_expandedGrade ?? (isMyTier ? myGrade : null)),
              onToggle: (level) {
                setState(() {
                  final open = _userToggledExpand
                      ? _expandedGrade
                      : (_expandedGrade ?? (isMyTier ? myGrade : null));
                  _userToggledExpand = true;
                  _expandedGrade = open == level ? null : level;
                });
              },
            ),
          ),
        ),
      ),
    ];
  }
}

class _AdminBaseEditor extends ConsumerStatefulWidget {
  const _AdminBaseEditor({
    required this.scaleType,
    required this.qualification,
    required this.currentBase,
    required this.onUpdated,
  });

  final String scaleType;
  final String qualification;
  final num currentBase;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_AdminBaseEditor> createState() => _AdminBaseEditorState();
}

class _AdminBaseEditorState extends ConsumerState<_AdminBaseEditor> {
  late final _ctrl = TextEditingController(
    text: widget.currentBase.round().toString(),
  );
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _AdminBaseEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentBase != widget.currentBase ||
        oldWidget.qualification != widget.qualification) {
      _ctrl.text = widget.currentBase.round().toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = num.tryParse(_ctrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (value == null || value <= 0 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(salaryRepositoryProvider).updateScaleBase(
            scaleType: widget.scaleType,
            baseTotalIncome: value,
            qualification: widget.qualification,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Đã cập nhật bậc 1', isSuccess: true);
      widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = num.tryParse(_ctrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neo tổng thu nhập bậc 1',
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.qualification,
                      style: AppTypography.style(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppFormat.currency(typed ?? widget.currentBase),
            style: AppTypography.metric(
              fontSize: 22,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Các bậc còn lại = bậc 1 × hệ số',
            style: AppTypography.style(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Số tiền bậc 1',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(108, 48),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.brMd,
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Cập nhật'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScopeOption {
  const _ScopeOption(this.tab, this.label, this.code);
  final int tab;
  final String label;
  final String code;
}

class _HeaderScopeSegment extends StatelessWidget {
  const _HeaderScopeSegment({
    required this.options,
    required this.selectedTab,
    required this.onBrand,
    required this.onChanged,
  });

  final List<_ScopeOption> options;
  final int selectedTab;
  final Color onBrand;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.14),
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Material(
                color: selectedTab == option.tab
                    ? onBrand
                    : Colors.transparent,
                borderRadius: AppRadius.brSm,
                child: InkWell(
                  onTap: () => onChanged(option.tab),
                  borderRadius: AppRadius.brSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: selectedTab == option.tab
                            ? AppColors.primaryDark
                            : onBrand.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TierChips extends StatelessWidget {
  const _TierChips({
    required this.tiers,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<EmployeeScaleTier> tiers;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, tier) in tiers.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: AppRadius.brPill,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: AppRadius.brPill,
                    border: Border.all(
                      color: selectedIndex == i
                          ? AppColors.primary
                          : AppColors.borderSoft,
                    ),
                    boxShadow: selectedIndex == i
                        ? AppShadows.tinted(AppColors.primary)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tier.tierLabel,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: selectedIndex == i
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selectedIndex == i
                              ? Colors.white.withValues(alpha: 0.18)
                              : AppColors.surfaceMuted,
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          '${tier.grades.length}',
                          style: AppTypography.style(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: selectedIndex == i
                                ? Colors.white
                                : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScaleOverviewHero extends StatelessWidget {
  const _ScaleOverviewHero({
    required this.scopeLabel,
    required this.qualification,
    required this.grades,
  });

  final String scopeLabel;
  final String qualification;
  final List<EmployeeScaleGrade> grades;

  @override
  Widget build(BuildContext context) {
    final first = grades.isEmpty ? null : grades.first;
    final last = grades.isEmpty ? null : grades.last;
    final coeffs = grades.map((g) => g.coefficient).toList();
    final minC = coeffs.isEmpty ? 0 : coeffs.reduce((a, b) => a < b ? a : b);
    final maxC = coeffs.isEmpty ? 0 : coeffs.reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 36,
            bottom: -44,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
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
                      Icons.stairs_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scopeLabel.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.65,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          qualification,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'BẬC 1',
                style: AppTypography.style(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppFormat.currency(first?.totalIncome),
                  style: AppTypography.metric(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _HeroPill(
                    icon: Icons.layers_rounded,
                    label: '${grades.length} bậc',
                  ),
                  if (coeffs.isNotEmpty)
                    _HeroPill(
                      icon: Icons.functions_rounded,
                      label: minC == maxC
                          ? 'Hệ số $minC'
                          : 'Hệ số $minC–$maxC',
                    ),
                  if (last != null && last.yearsRange.isNotEmpty)
                    _HeroPill(
                      icon: Icons.timelapse_rounded,
                      label: last.yearsRange,
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentGradeHero extends StatelessWidget {
  const _CurrentGradeHero({
    required this.scopeLabel,
    required this.qualification,
    required this.grade,
  });

  final String scopeLabel;
  final String qualification;
  final EmployeeScaleGrade grade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: -36,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      'BẬC CỦA BẠN',
                      style: AppTypography.style(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.military_tech_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                grade.gradeLabel,
                style: AppTypography.style(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$qualification · ${grade.yearsRange}',
                style: AppTypography.style(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeroChip(label: 'Hệ số', value: '${grade.coefficient}'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroChip(
                      label: 'Tổng thu nhập',
                      value: AppFormat.currency(grade.totalIncome),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                scopeLabel,
                style: AppTypography.style(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.style(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeLadder extends StatelessWidget {
  const _GradeLadder({
    required this.tierLabel,
    required this.grades,
    required this.highlightGrade,
    required this.expandedGrade,
    required this.onToggle,
  });

  final String tierLabel;
  final List<EmployeeScaleGrade> grades;
  final int? highlightGrade;
  final int? expandedGrade;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierLabel,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${grades.length} bậc · chạm một dòng để xem BH / SP',
                      style: AppTypography.caption(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, grade) in grades.indexed)
            _GradeRow(
              grade: grade,
              isLast: i == grades.length - 1,
              highlighted: highlightGrade == grade.gradeLevel,
              expanded: expandedGrade == grade.gradeLevel,
              onTap: () => onToggle(grade.gradeLevel),
            ),
        ],
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.grade,
    required this.isLast,
    required this.highlighted,
    required this.expanded,
    required this.onTap,
  });

  final EmployeeScaleGrade grade;
  final bool isLast;
  final bool highlighted;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = grade.totalIncome.toDouble();
    final bhShare = total <= 0
        ? 0.0
        : (grade.insuranceSalary / total).clamp(0.0, 1.0);
    final short = grade.gradeLabel.replaceFirst(
      RegExp(r'^BẬC\s*', caseSensitive: false),
      '',
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: highlighted ? AppGradients.brand : null,
                    color: highlighted
                        ? null
                        : AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: highlighted
                        ? AppShadows.tinted(AppColors.primary)
                        : null,
                  ),
                  child: Text(
                    short,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: highlighted ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 10),
              child: Material(
                color: highlighted
                    ? AppColors.primary.withValues(alpha: 0.07)
                    : AppColors.surfaceMuted,
                borderRadius: AppRadius.brMd,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: AppRadius.brMd,
                  child: AnimatedSize(
                    duration: AppDurations.normal,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      grade.yearsRange,
                                      style: AppTypography.style(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Hệ số ${grade.coefficient}',
                                      style: AppTypography.style(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppFormat.currency(grade.totalIncome),
                                    style: AppTypography.style(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: highlighted
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      tabular: true,
                                    ),
                                  ),
                                  if (highlighted)
                                    Text(
                                      'Đang áp dụng',
                                      style: AppTypography.style(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 2),
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0,
                                duration: AppDurations.fast,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          if (expanded) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: AppRadius.brPill,
                              child: LinearProgressIndicator(
                                value: bhShare,
                                minHeight: 6,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.16),
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _DetailPair(
                              label: 'Lương đóng BH',
                              value: AppFormat.currency(grade.insuranceSalary),
                            ),
                            const SizedBox(height: 6),
                            _DetailPair(
                              label: 'Đảm bảo SP',
                              value: AppFormat.currency(grade.productSalary),
                            ),
                            const SizedBox(height: 6),
                            _DetailPair(
                              label: 'Tổng thu nhập',
                              value: AppFormat.currency(grade.totalIncome),
                              emphasize: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPair extends StatelessWidget {
  const _DetailPair({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.style(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.style(
            fontSize: emphasize ? 13.5 : 13,
            fontWeight: FontWeight.w800,
            color: emphasize ? AppColors.primary : AppColors.textPrimary,
            tabular: true,
          ),
        ),
      ],
    );
  }
}

class _DoctorLadder extends StatelessWidget {
  const _DoctorLadder({required this.entries});

  final List<DoctorScaleEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.medical_services_outlined,
        title: 'Chưa có thang bảng bác sỹ',
        message: 'HCNS chưa import dữ liệu cho đối tượng này.',
      );
    }

    final amounts = entries.map((e) => e.totalSalary).toList();
    final minA = amounts.reduce((a, b) => a < b ? a : b);
    final maxA = amounts.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppReveal(
          offset: 8,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: AppRadius.brLg,
              boxShadow: AppShadows.tinted(AppColors.primary),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
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
                        Icons.medical_services_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Thang bảng bác sỹ',
                        style: AppTypography.style(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _HeroPill(
                      icon: Icons.layers_rounded,
                      label: '${entries.length} mức',
                    ),
                    _HeroPill(
                      icon: Icons.payments_rounded,
                      label:
                          '${AppFormat.currencyCompact(minA)} – ${AppFormat.currencyCompact(maxA)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final (i, entry) in entries.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          _DoctorEntryCard(entry: entry),
        ],
      ],
    );
  }
}

class _DoctorEntryCard extends StatelessWidget {
  const _DoctorEntryCard({required this.entry});
  final DoctorScaleEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.brSm,
            ),
            child: Text(
              entry.qualificationCode,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.qualificationName,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.timeLabel.isNotEmpty)
                  Text(
                    entry.timeLabel,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            AppFormat.currency(entry.totalSalary),
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              tabular: true,
            ),
          ),
        ],
      ),
    );
  }
}
