import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/workforce_report.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workforce_report_repository.dart';

class WorkforceReportScreen extends ConsumerStatefulWidget {
  const WorkforceReportScreen({super.key, this.initialDaily = false});

  final bool initialDaily;

  @override
  ConsumerState<WorkforceReportScreen> createState() =>
      _WorkforceReportScreenState();
}

class _WorkforceReportScreenState extends ConsumerState<WorkforceReportScreen> {
  late bool _daily = widget.initialDaily;
  DateTime _date = DateTime.now();
  final _search = TextEditingController();
  WorkforceReport? _report;
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _expandedDeptId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(workforceReportRepositoryProvider);
      final report = _daily
          ? await repo.daily(_iso(_date))
          : await repo.hospital();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
        _expandedDeptId = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _report = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được dữ liệu báo cáo';
        _report = null;
      });
    }
  }

  Future<void> _setDaily(bool daily) async {
    if (_daily == daily) return;
    setState(() {
      _daily = daily;
      _query = '';
      _search.clear();
    });
    await _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _shiftDate(int days) async {
    final next = _date.add(Duration(days: days));
    final max = DateTime.now().add(const Duration(days: 14));
    if (next.isBefore(DateTime(2020)) || next.isAfter(max)) return;
    setState(() => _date = next);
    await _load();
  }

  List<WorkforceDepartmentRow> get _visibleRows {
    final rows = _report?.rows ?? const <WorkforceDepartmentRow>[];
    final q = _fold(_query);
    if (q.isEmpty) return rows;
    return [
      for (final r in rows)
        if (_fold(r.departmentName).contains(q)) r,
    ];
  }

  List<WorkforceDetailRow> get _visiblePeople {
    final details = _report?.details ?? const <WorkforceDetailRow>[];
    final q = _fold(_query);
    if (q.isEmpty) return details;
    return [
      for (final r in details)
        if (_fold(r.fullName).contains(q) ||
            _fold(r.employeeCode).contains(q) ||
            _fold(r.departmentName).contains(q) ||
            _fold(r.positionTitle).contains(q) ||
            _fold(r.categoryLabel).contains(q))
          r,
    ];
  }

  bool get _searching => _query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final allowed = RoleGroups.canViewWorkforceReports(
      auth.role,
      reportViewEnabled: auth.currentUser?.reportViewEnabled ?? false,
    );
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: _daily
                    ? 'Nhân lực đi làm'
                    : 'Nhân lực toàn viện',
                icon: _daily
                    ? Icons.event_available_rounded
                    : Icons.groups_rounded,
                eyebrow: 'Báo cáo',
                subtitle: _daily
                    ? 'Quân số có mặt theo khoa/phòng trong ngày'
                    : 'Biên chế theo khoa/phòng và chức vụ trên hồ sơ',
                onBack: () => context.pop(),
                footer: Column(
                  children: [
                    _HeaderModeSegment(
                      daily: _daily,
                      onBrand: onBrand,
                      onChanged: allowed ? _setDaily : null,
                    ),
                    if (_daily) ...[
                      const SizedBox(height: 8),
                      _HeaderDateChip(
                        label: AppFormat.date(_date),
                        weekday: AppFormat.weekday(_date),
                        onBrand: onBrand,
                        onTap: allowed ? _pickDate : () {},
                        onPrev: allowed ? () => _shiftDate(-1) : null,
                        onNext: allowed ? () => _shiftDate(1) : null,
                      ),
                    ],
                  ],
                ),
              ),
              if (!allowed)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Không có quyền xem báo cáo',
                    message:
                        'Báo cáo nhân lực dành cho Ban giám đốc, HCNS hoặc tài khoản được cấp quyền xem.',
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    10,
                    AppSpacing.page,
                    0,
                  ),
                  child: AppSearchField(
                    controller: _search,
                    hintText: 'Tìm khoa, tên, mã, chức vụ…',
                    dense: true,
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                Expanded(child: _buildBody(report)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(WorkforceReport? report) {
    if (_loading && report == null) {
      return const SkeletonList(itemCount: 6, showAvatar: false);
    }
    if (_error != null && report == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (report == null) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Chưa có dữ liệu',
        message: 'Không có số liệu báo cáo cho kỳ đã chọn.',
      );
    }

    final depts = _visibleRows;
    final people = _visiblePeople;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          12,
          AppSpacing.page,
          28,
        ),
        children: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: AppRadius.brPill,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
          AppReveal(
            offset: 8,
            child: _ReportHero(report: report, daily: _daily),
          ),
          if (!_searching && report.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TopRolesStrip(report: report),
          ],
          const SizedBox(height: 16),
          _SectionTitle(
            text: _searching ? 'Kết quả tìm kiếm' : 'Theo khoa / phòng',
            count: _searching ? people.length : depts.length,
          ),
          const SizedBox(height: 8),
          if (_searching) ...[
            if (people.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'Không có kết quả',
                  message: 'Thử từ khóa khác.',
                ),
              )
            else
              for (final p in people)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PersonCard(row: p, daily: _daily),
                ),
          ] else ...[
            if (depts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.apartment_outlined,
                  title: 'Chưa có khoa/phòng',
                  message: 'Không có đơn vị nào trong kỳ báo cáo này.',
                ),
              )
          else
            _DeptRoster(
              children: [
                for (final row in depts)
                  _DeptCard(
                    row: row,
                    grandTotal: report.grandTotal,
                    categories: report.categories,
                    people: [
                      for (final p in report.details)
                        if (p.departmentId == row.departmentId) p,
                    ],
                    daily: _daily,
                    expanded: _expandedDeptId == row.departmentId,
                    onToggle: () => setState(() {
                      _expandedDeptId = _expandedDeptId == row.departmentId
                          ? null
                          : row.departmentId;
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderModeSegment extends StatelessWidget {
  const _HeaderModeSegment({
    required this.daily,
    required this.onBrand,
    required this.onChanged,
  });

  final bool daily;
  final Color onBrand;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        children: [
          _seg('Toàn viện', !daily, () => onChanged?.call(false)),
          _seg('Đi làm', daily, () => onChanged?.call(true)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: selected ? onBrand : Colors.transparent,
        borderRadius: AppRadius.brPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brPill,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected
                    ? AppColors.primaryDark
                    : onBrand.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderDateChip extends StatelessWidget {
  const _HeaderDateChip({
    required this.label,
    required this.weekday,
    required this.onBrand,
    required this.onTap,
    this.onPrev,
    this.onNext,
  });

  final String label;
  final String weekday;
  final Color onBrand;
  final VoidCallback onTap;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPrev,
            icon: Icon(Icons.chevron_left_rounded, color: onBrand),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.brSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: onBrand.withValues(alpha: 0.82),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            weekday,
                            style: AppTypography.style(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: onBrand.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: onBrand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onNext,
            icon: Icon(Icons.chevron_right_rounded, color: onBrand),
          ),
        ],
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.report, required this.daily});
  final WorkforceReport report;
  final bool daily;

  @override
  Widget build(BuildContext context) {
    final top = report.topCategory;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -42,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                daily ? 'CÓ MẶT' : 'TỔNG NHÂN LỰC',
                style: AppTypography.style(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.grandTotal}',
                    style: AppTypography.metric(
                      fontSize: 44,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      daily ? 'người đi làm' : 'nhân viên',
                      style: AppTypography.style(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (!daily) ...[
                const SizedBox(height: 4),
                Text(
                  'Biên chế hiện có · không gồm nghỉ việc',
                  style: AppTypography.style(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _HeroChip(
                    icon: Icons.apartment_rounded,
                    label: '${report.departmentCount} khoa/phòng',
                  ),
                  if (top != null)
                    _HeroChip(
                      icon: Icons.medical_services_outlined,
                      label: '${top.label} ${report.topCategoryCount}',
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRolesStrip extends StatelessWidget {
  const _TopRolesStrip({required this.report});
  final WorkforceReport report;

  @override
  Widget build(BuildContext context) {
    final ranked = [
      for (final c in report.categories)
        if ((report.totals[c.key] ?? 0) > 0) (c.label, report.totals[c.key]!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (ranked.isEmpty) return const SizedBox.shrink();
    final shown = ranked.take(6).toList();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = shown[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              '${item.$1} ${item.$2}',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.count});
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: AppTypography.style(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: AppColors.primaryDark,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: AppTypography.style(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DeptRoster extends StatelessWidget {
  const _DeptRoster({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

class _DeptCard extends StatelessWidget {
  const _DeptCard({
    required this.row,
    required this.grandTotal,
    required this.categories,
    required this.people,
    required this.daily,
    required this.expanded,
    required this.onToggle,
  });

  final WorkforceDepartmentRow row;
  final int grandTotal;
  final List<WorkforceCategory> categories;
  final List<WorkforceDetailRow> people;
  final bool daily;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final breakdown = [
      for (final c in categories)
        if ((row.counts[c.key] ?? 0) > 0) (c.label, row.counts[c.key]!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final preview = breakdown.take(2).toList();
    final share = grandTotal <= 0
        ? 0.0
        : (row.total / grandTotal).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: expanded
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.borderSoft,
        ),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
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
                            row.departmentName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (preview.isNotEmpty)
                            Text(
                              preview
                                  .map((e) => '${e.$1} ${e.$2}')
                                  .join(' · '),
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
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(minWidth: 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        '${row.total}',
                        textAlign: TextAlign.center,
                        style: AppTypography.metric(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, expanded ? 8 : 12),
            child: ClipRRect(
              borderRadius: AppRadius.brPill,
              child: LinearProgressIndicator(
                value: share,
                minHeight: 4,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (breakdown.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in breakdown)
                          _CountChip(label: item.$1, count: item.$2),
                      ],
                    ),
                  if (people.isNotEmpty) ...[
                    if (breakdown.isNotEmpty) const SizedBox(height: 12),
                    for (final p in people)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _PersonCard(row: p, daily: daily, compact: true),
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        '$label · $count',
        style: AppTypography.style(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.row,
    required this.daily,
    this.compact = false,
  });

  final WorkforceDetailRow row;
  final bool daily;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusColor = daily
        ? (row.attendanceStatus == 'PRESENT'
            ? AppColors.success
            : AppColors.warning)
        : (row.employeeStatus == 'ACTIVE'
            ? AppColors.success
            : AppColors.warning);
    final meta = [
      if (row.employeeCode.isNotEmpty) row.employeeCode,
      if (row.positionTitle.isNotEmpty) row.positionTitle,
      if (!compact && row.departmentName.isNotEmpty) row.departmentName,
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 12, 10, 12, 10),
      decoration: BoxDecoration(
        color: compact ? AppColors.surfaceMuted : AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: compact ? null : Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(
                name: row.fullName,
                size: compact ? 34 : 40,
                showShadow: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusChip(
                          label: daily
                              ? row.attendanceStatusLabel
                              : row.employeeStatusLabel,
                          color: statusColor,
                          dense: true,
                        ),
                        if (!daily && row.categoryLabel.isNotEmpty)
                          StatusChip(
                            label: row.categoryLabel,
                            color: AppColors.primary,
                            dense: true,
                            showDot: false,
                          ),
                        if (daily && row.lateMinutes > 0)
                          StatusChip(
                            label: 'Muộn ${row.lateMinutes}’',
                            color: AppColors.warning,
                            dense: true,
                            showDot: false,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (daily && compact) ...[
                const SizedBox(width: 8),
                _PunchTimes(row: row),
              ],
            ],
          ),
          if (daily && !compact) ...[
            const SizedBox(height: 10),
            _PunchBar(row: row),
          ],
        ],
      ),
    );
  }
}

class _PunchTimes extends StatelessWidget {
  const _PunchTimes({required this.row});
  final WorkforceDetailRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          row.displayCheckIn,
          style: AppTypography.metric(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        Text(
          row.displayCheckOut,
          style: AppTypography.metric(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '${AppFormat.workUnits(row.workUnits)} công',
          style: AppTypography.caption(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PunchBar extends StatelessWidget {
  const _PunchBar({required this.row});
  final WorkforceDetailRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: _PunchCol(label: 'Vào', value: row.displayCheckIn),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
          Expanded(
            child: _PunchCol(
              label: 'Ra',
              value: row.displayCheckOut,
              alignEnd: true,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${AppFormat.workUnits(row.workUnits)} công',
            style: AppTypography.style(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchCol extends StatelessWidget {
  const _PunchCol({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.style(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.metric(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

String _fold(String raw) {
  const map = {
    'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
    'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
    'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
    'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
    'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
    'đ': 'd',
  };
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}
