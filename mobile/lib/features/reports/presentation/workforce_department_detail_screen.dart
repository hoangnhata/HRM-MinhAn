import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/brand_hero.dart';
import '../../../shared/models/workforce_report.dart';
import 'workforce_report_widgets.dart';

/// Tham số mở chi tiết khoa từ báo cáo nhân lực.
class WorkforceDeptDetailArgs {
  const WorkforceDeptDetailArgs({
    required this.row,
    required this.categories,
    required this.people,
    required this.daily,
    required this.grandTotal,
    this.reportDateLabel,
  });

  final WorkforceDepartmentRow row;
  final List<WorkforceCategory> categories;
  final List<WorkforceDetailRow> people;
  final bool daily;
  final int grandTotal;
  final String? reportDateLabel;
}

/// Tham số mở chi tiết khoa vắng mặt (chế độ đi làm).
class WorkforceAbsentDeptDetailArgs {
  const WorkforceAbsentDeptDetailArgs({
    required this.row,
    this.reportDateLabel,
  });

  final WorkforceAbsentDepartment row;
  final String? reportDateLabel;
}

class WorkforceDepartmentDetailScreen extends StatefulWidget {
  const WorkforceDepartmentDetailScreen({super.key, required this.args});

  final WorkforceDeptDetailArgs args;

  @override
  State<WorkforceDepartmentDetailScreen> createState() =>
      _WorkforceDepartmentDetailScreenState();
}

class _WorkforceDepartmentDetailScreenState
    extends State<WorkforceDepartmentDetailScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _roleFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(String, int)> get _breakdown =>
      widget.args.row.breakdownFor(widget.args.categories);

  List<WorkforceDetailRow> get _visiblePeople {
    final q = foldVi(_query);
    return [
      for (final p in widget.args.people)
        if ((_roleFilter == null || p.categoryLabel == _roleFilter) &&
            (q.isEmpty ||
                foldVi(p.fullName).contains(q) ||
                foldVi(p.employeeCode).contains(q) ||
                foldVi(p.positionTitle).contains(q) ||
                foldVi(p.categoryLabel).contains(q)))
          p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final share = args.grandTotal <= 0
        ? 0.0
        : (args.row.total / args.grandTotal).clamp(0.0, 1.0);
    final pct = (share * 100).round();
    final people = _visiblePeople;
    final breakdown = _breakdown;
    final hasDate =
        args.reportDateLabel != null && args.reportDateLabel!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.5)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: args.row.departmentName,
                icon: Icons.apartment_rounded,
                eyebrow: args.daily ? 'Nhân lực đi làm' : 'Nhân lực toàn viện',
                subtitle: hasDate
                    ? '${args.reportDateLabel} · ${args.row.total} người'
                    : '${args.row.total} người · $pct% toàn viện',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    14,
                    AppSpacing.page,
                    32,
                  ),
                  children: [
                    AppReveal(
                      offset: 8,
                      child: _DeptSummaryCard(
                        name: args.row.departmentName,
                        total: args.row.total,
                        share: share,
                        sharePct: pct,
                        daily: args.daily,
                        roleCount: breakdown.length,
                        peopleCount: args.people.length,
                        topRole: breakdown.isEmpty ? null : breakdown.first,
                      ),
                    ),
                    if (breakdown.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      WorkforceSectionTitle(
                        title: 'Phân bổ chức vụ',
                        count: breakdown.length,
                        icon: Icons.badge_rounded,
                        trailing: _roleFilter == null ? 'Chạm để lọc' : null,
                        action: _roleFilter == null
                            ? null
                            : _ClearFilterButton(
                                onTap: () => setState(() => _roleFilter = null),
                              ),
                      ),
                      const SizedBox(height: 10),
                      WorkforceGroupCard(
                        children: [
                          for (var i = 0; i < breakdown.length; i++)
                            WorkforceRoleTile(
                              index: i,
                              label: breakdown[i].$1,
                              count: breakdown[i].$2,
                              total: args.row.total,
                              selected: _roleFilter == breakdown[i].$1,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _roleFilter = _roleFilter == breakdown[i].$1
                                      ? null
                                      : breakdown[i].$1;
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    WorkforceSectionTitle(
                      title: 'Danh sách nhân sự',
                      count: people.length,
                      icon: Icons.people_alt_rounded,
                      trailing: _roleFilter == null
                          ? null
                          : 'Lọc: $_roleFilter',
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.brMd,
                        boxShadow: AppShadows.soft,
                      ),
                      child: AppSearchField(
                        controller: _search,
                        hintText: 'Tìm tên, mã, chức danh trong khoa…',
                        borderRadius: AppRadius.brMd,
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (people.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'Không có nhân sự',
                          message: _roleFilter == null
                              ? 'Thử đổi từ khóa tìm kiếm.'
                              : 'Thử đổi từ khóa hoặc bỏ lọc chức vụ.',
                          action: _roleFilter == null
                              ? null
                              : OutlinedButton.icon(
                                  onPressed: () =>
                                      setState(() => _roleFilter = null),
                                  icon: const Icon(
                                    Icons.filter_alt_off_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Bỏ lọc chức vụ'),
                                ),
                        ),
                      )
                    else
                      WorkforceGroupCard(
                        dividerIndent: 76,
                        children: [
                          for (final p in people)
                            WorkforcePersonTile(
                              row: p,
                              daily: args.daily,
                              showDepartment: false,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WorkforceAbsentDepartmentDetailScreen extends StatefulWidget {
  const WorkforceAbsentDepartmentDetailScreen({super.key, required this.args});

  final WorkforceAbsentDeptDetailArgs args;

  @override
  State<WorkforceAbsentDepartmentDetailScreen> createState() =>
      _WorkforceAbsentDepartmentDetailScreenState();
}

class _WorkforceAbsentDepartmentDetailScreenState
    extends State<WorkforceAbsentDepartmentDetailScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<WorkforceAbsentEmployee> get _visible {
    final q = foldVi(_query);
    final list = widget.args.row.employees;
    if (q.isEmpty) return list;
    return [
      for (final e in list)
        if (foldVi(e.fullName).contains(q) ||
            foldVi(e.employeeCode).contains(q) ||
            foldVi(e.positionTitle).contains(q))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.args.row;
    final people = _visible;
    final hasDate =
        widget.args.reportDateLabel != null &&
        widget.args.reportDateLabel!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.5)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: row.departmentName,
                icon: Icons.person_off_rounded,
                eyebrow: 'Không đi làm',
                subtitle: hasDate
                    ? '${widget.args.reportDateLabel} · ${row.total} người vắng'
                    : '${row.total} người vắng',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    14,
                    AppSpacing.page,
                    32,
                  ),
                  children: [
                    AppReveal(
                      offset: 8,
                      child: _AbsentSummaryCard(
                        name: row.departmentName,
                        total: row.total,
                        dateLabel: hasDate ? widget.args.reportDateLabel : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    WorkforceSectionTitle(
                      title: 'Nhân sự vắng mặt',
                      count: people.length,
                      icon: Icons.person_off_rounded,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 10),
                    AppSearchField(
                      controller: _search,
                      hintText: 'Tìm tên, mã, chức danh…',
                      dense: true,
                      borderRadius: BorderRadius.circular(12),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 12),
                    if (people.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: EmptyState(
                          icon: Icons.filter_alt_off_rounded,
                          title: 'Không có kết quả',
                          message: 'Thử từ khóa khác.',
                        ),
                      )
                    else
                      WorkforceGroupCard(
                        dividerIndent: 76,
                        children: [
                          for (final e in people) _AbsentPersonTile(row: e),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClearFilterButton extends StatelessWidget {
  const _ClearFilterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 4),
              Text(
                'Bỏ lọc',
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeptSummaryCard extends StatelessWidget {
  const _DeptSummaryCard({
    required this.name,
    required this.total,
    required this.share,
    required this.sharePct,
    required this.daily,
    required this.roleCount,
    required this.peopleCount,
    required this.topRole,
  });

  final String name;
  final int total;
  final double share;
  final int sharePct;
  final bool daily;
  final int roleCount;
  final int peopleCount;
  final (String, int)? topRole;

  @override
  Widget build(BuildContext context) {
    return BrandHeroCard(
      ornamentIcon: Icons.apartment_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandHeroEyebrow(
                      text: daily ? 'Có mặt tại khoa' : 'Biên chế khoa',
                    ),
                    const SizedBox(height: 10),
                    _HeroNumber(value: total, unit: 'người'),
                    if (topRole != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 14,
                            color: AppColors.secondaryLight.withValues(
                              alpha: 0.9,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'Đông nhất: ',
                                children: [
                                  TextSpan(
                                    text: '${topRole!.$1} · ${topRole!.$2}',
                                    style: AppTypography.style(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.75),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _GlassInitials(text: workforceDeptInitials(name)),
            ],
          ),
          const SizedBox(height: 16),
          // Tỷ trọng khoa trong toàn viện — trực quan hơn một con số % đứng riêng.
          Row(
            children: [
              Text(
                'Tỷ trọng toàn viện',
                style: AppTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(),
              Text(
                '$sharePct%',
                style: AppTypography.display(fontSize: 15, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BrandGlassTrack(
            child: FractionallySizedBox(
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              // Khoa nhỏ vẫn thấy một vệt để biết thanh có dữ liệu.
              widthFactor: share <= 0 ? 0 : share.clamp(0.02, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.onBrandRing, AppColors.onBrandSoft],
                  ),
                  borderRadius: AppRadius.brPill,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BrandHeroStat(
                  icon: Icons.badge_rounded,
                  label: 'Chức vụ',
                  value: '$roleCount',
                  accent: const Color(0xFF93C5FD),
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: BrandHeroStat(
                  icon: Icons.folder_shared_rounded,
                  label: 'Hồ sơ',
                  value: '$peopleCount',
                  accent: const Color(0xFFFCD34D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbsentSummaryCard extends StatelessWidget {
  const _AbsentSummaryCard({
    required this.name,
    required this.total,
    required this.dateLabel,
  });

  final String name;
  final int total;
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    return BrandHeroCard(
      ornamentIcon: Icons.person_off_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandHeroEyebrow(text: 'Nhân sự không đi làm'),
                const SizedBox(height: 10),
                _HeroNumber(value: total, unit: 'người'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        dateLabel == null
                            ? 'Chưa ghi nhận chấm công trong ngày'
                            : 'Chưa ghi nhận chấm công ngày $dateLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _GlassInitials(text: workforceDeptInitials(name)),
        ],
      ),
    );
  }
}

/// Số hero trắng (font hiển thị) + đơn vị, canh theo baseline.
class _HeroNumber extends StatelessWidget {
  const _HeroNumber({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: AppDurations.slow,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            AppFormat.number(v.round()),
            style: AppTypography.display(fontSize: 48, color: Colors.white)
                .copyWith(
                  shadows: [
                    Shadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          unit,
          style: AppTypography.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

/// Viết tắt tên khoa trong ô kính trắng mờ.
class _GlassInitials extends StatelessWidget {
  const _GlassInitials({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        style: AppTypography.display(fontSize: 18, color: Colors.white),
      ),
    );
  }
}

class _AbsentPersonTile extends StatelessWidget {
  const _AbsentPersonTile({required this.row});
  final WorkforceAbsentEmployee row;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (row.employeeCode.isNotEmpty) row.employeeCode,
      if (row.positionTitle.isNotEmpty) row.positionTitle,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          AppAvatar(name: row.fullName, size: 42, showShadow: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    height: 1.25,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusChip(
            label: row.employeeStatusLabel,
            color: AppColors.statusColor(row.employeeStatus),
            dense: true,
          ),
        ],
      ),
    );
  }
}
