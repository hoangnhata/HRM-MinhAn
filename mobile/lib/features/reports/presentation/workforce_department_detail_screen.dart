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
  const WorkforceDepartmentDetailScreen({
    super.key,
    required this.args,
  });

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
                        trailing: _roleFilter == null
                            ? 'Chạm để lọc'
                            : null,
                        action: _roleFilter == null
                            ? null
                            : _ClearFilterButton(
                                onTap: () =>
                                    setState(() => _roleFilter = null),
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
                                  _roleFilter =
                                      _roleFilter == breakdown[i].$1
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
                    AppSearchField(
                      controller: _search,
                      hintText: 'Tìm tên, mã, chức danh trong khoa…',
                      dense: true,
                      borderRadius: BorderRadius.circular(12),
                      onChanged: (v) => setState(() => _query = v.trim()),
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
                        dividerIndent: 68,
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
  const WorkforceAbsentDepartmentDetailScreen({
    super.key,
    required this.args,
  });

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
    final hasDate = widget.args.reportDateLabel != null &&
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
                        dateLabel:
                            hasDate ? widget.args.reportDateLabel : null,
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
                        dividerIndent: 68,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -58,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (daily ? 'Có mặt tại khoa' : 'Biên chế khoa')
                                .toUpperCase(),
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                AppFormat.number(total),
                                style: AppTypography.metric(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'người',
                                style: AppTypography.style(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topRole == null
                                ? 'Chiếm $sharePct% toàn viện'
                                : 'Chiếm $sharePct% toàn viện · nhiều nhất: ${topRole!.$1} ${topRole!.$2}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    WorkforceInitialsBadge(
                      text: workforceDeptInitials(name),
                      color: AppColors.primary,
                      size: 52,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.pie_chart_rounded,
                        label: 'Tỉ lệ viện',
                        value: '$sharePct%',
                        accent: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.badge_rounded,
                        label: 'Chức vụ',
                        value: '$roleCount',
                        accent: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.folder_shared_rounded,
                        label: 'Hồ sơ',
                        value: '$peopleCount',
                        accent: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -58,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.12),
                      AppColors.warning.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NHÂN SỰ KHÔNG ĐI LÀM',
                        style: AppTypography.style(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: AppColors.warningDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$total',
                            style: AppTypography.metric(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'người',
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel == null
                            ? 'Chưa ghi nhận chấm công trong ngày'
                            : 'Chưa ghi nhận chấm công ngày $dateLabel',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                WorkforceInitialsBadge(
                  text: workforceDeptInitials(name),
                  color: AppColors.warning,
                  size: 52,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.brXs,
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            style: AppTypography.metric(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
