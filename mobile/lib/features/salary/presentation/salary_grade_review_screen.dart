import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
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
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/salary_models.dart';
import '../data/salary_repository.dart';

class SalaryGradeReviewScreen extends ConsumerStatefulWidget {
  const SalaryGradeReviewScreen({super.key});

  @override
  ConsumerState<SalaryGradeReviewScreen> createState() =>
      _SalaryGradeReviewScreenState();
}

class _SalaryGradeReviewScreenState
    extends ConsumerState<SalaryGradeReviewScreen> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  final _search = TextEditingController();
  SalaryGradeReviewReport? _report;
  bool _loading = true;
  String? _error;
  String _query = '';
  String _timing = '';
  String _sort = 'date';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await ref.read(salaryRepositoryProvider).gradeReviews(
            year: _year,
            month: _month,
          );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
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
        _error = 'Không tải được danh sách nâng bậc';
        _report = null;
      });
    }
  }

  List<SalaryGradeReviewRow> get _visible {
    final rows = _report?.rows ?? const <SalaryGradeReviewRow>[];
    final q = _fold(_query);
    final filtered = [
      for (final r in rows)
        if (_matchTiming(r) &&
            (q.isEmpty ||
                _fold(r.fullName).contains(q) ||
                _fold(r.employeeCode).contains(q) ||
                _fold(r.department).contains(q) ||
                _fold(r.position).contains(q)))
          r,
    ];
    filtered.sort((a, b) {
      if (_sort == 'increase') {
        return b.increaseAmount.compareTo(a.increaseAmount);
      }
      if (_sort == 'name') {
        return a.fullName.compareTo(b.fullName);
      }
      final byDate = a.effectiveDate.compareTo(b.effectiveDate);
      if (byDate != 0) return byDate;
      return a.fullName.compareTo(b.fullName);
    });
    return filtered;
  }

  bool _matchTiming(SalaryGradeReviewRow row) {
    if (_timing.isEmpty) return true;
    if (_timing == 'UPCOMING') return row.timingStatus == 'UPCOMING';
    if (_timing == 'DUE') {
      return row.timingStatus == 'PASSED' || row.timingStatus == 'TODAY';
    }
    return row.timingStatus == _timing;
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final years = [for (var y = now.year - 1; y <= now.year + 1; y++) y];
    var year = _year;
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tháng nâng bậc',
                      style: AppTypography.style(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final y in years) ...[
                          if (y != years.first) const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Text('$y'),
                              selected: y == year,
                              onSelected: (_) => setLocal(() => year = y),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var m = 1; m <= 12; m++)
                          ChoiceChip(
                            label: Text('T$m'),
                            selected: year == _year && m == _month,
                            onSelected: (_) => Navigator.pop(ctx, (year, m)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _year = picked.$1;
      _month = picked.$2;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final rows = _visible;
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final dueCount = (report?.today ?? 0) + (report?.passed ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: 'Nâng bậc lương',
                icon: Icons.trending_up_rounded,
                eyebrow: 'Quản lý',
                subtitle: report == null
                    ? 'Nhân viên đến kỳ nâng bậc trong tháng'
                    : '${report.total} người · ${AppFormat.currencyCompact(report.increaseTotal)} chênh lệch',
                onBack: () => context.pop(),
                footer: _HeaderMonthChip(
                  label: 'Tháng $_month/$_year',
                  onBrand: onBrand,
                  onTap: _pickMonth,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  10,
                  AppSpacing.page,
                  0,
                ),
                child: Column(
                  children: [
                    AppSearchField(
                      controller: _search,
                      hintText: 'Tìm tên, mã, khoa…',
                      dense: true,
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _TimingChip(
                            label: 'Tất cả',
                            count: report?.total,
                            selected: _timing.isEmpty,
                            onTap: () => setState(() => _timing = ''),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _TimingChip(
                            label: 'Sắp đến',
                            count: report?.upcoming,
                            selected: _timing == 'UPCOMING',
                            onTap: () => setState(() => _timing = 'UPCOMING'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _TimingChip(
                            label: 'Đến hạn',
                            count: dueCount,
                            selected: _timing == 'DUE',
                            onTap: () => setState(() => _timing = 'DUE'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(report, rows)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    SalaryGradeReviewReport? report,
    List<SalaryGradeReviewRow> rows,
  ) {
    if (_loading && report == null) {
      return const SkeletonList(itemCount: 6);
    }
    if (_error != null && report == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (report == null) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Chưa có dữ liệu',
        message: 'Không có nhân viên đến kỳ nâng bậc tháng này.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          12,
          AppSpacing.page,
          28,
        ),
        itemCount: rows.isEmpty ? 3 : rows.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppReveal(
                offset: 8,
                child: _ReviewHero(report: report),
              ),
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ListHeader(
                count: rows.length,
                sort: _sort,
                onSort: (v) => setState(() => _sort = v),
              ),
            );
          }
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: 'Không có kết quả',
                message: 'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.',
              ),
            );
          }
          final row = rows[index - 2];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReviewCard(
              row: row,
              onOpen: () => context.push(
                RoutePaths.salaryAdminProfile,
                extra: EmployeeSummary(
                  id: row.employeeId,
                  fullName: row.fullName,
                  employeeCode: row.employeeCode,
                  departmentName: row.department,
                  positionTitle: row.position,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderMonthChip extends StatelessWidget {
  const _HeaderMonthChip({
    required this.label,
    required this.onBrand,
    required this.onTap,
  });

  final String label;
  final Color onBrand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onBrand.withValues(alpha: 0.14),
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: onBrand, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: onBrand,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: onBrand, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.report});

  final SalaryGradeReviewReport report;

  @override
  Widget build(BuildContext context) {
    final due = report.passed + report.today;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TỔNG ĐẾN KỲ · THÁNG ${report.month}/${report.year}',
                style: AppTypography.style(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.65,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.total}',
                    style: AppTypography.metric(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'nhân viên',
                      style: AppTypography.style(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
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
                  _HeroStat(
                    label: 'Sắp đến hạn',
                    value: '${report.upcoming}',
                  ),
                  _HeroStat(
                    label: 'Đã đến hạn',
                    value: '$due',
                  ),
                  _HeroStat(
                    label: 'Chênh lệch',
                    value: AppFormat.currencyCompact(report.increaseTotal),
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label $value',
        style: AppTypography.style(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.count,
    required this.sort,
    required this.onSort,
  });

  final int count;
  final String sort;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final sortLabel = switch (sort) {
      'increase' => 'Mức tăng',
      'name' => 'Tên',
      _ => 'Ngày nâng bậc',
    };
    return Row(
      children: [
        Text(
          'DANH SÁCH',
          style: AppTypography.style(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count người',
          style: AppTypography.style(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          tooltip: 'Sắp xếp',
          onSelected: onSort,
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'date', child: Text('Ngày nâng bậc')),
            PopupMenuItem(value: 'increase', child: Text('Mức tăng cao nhất')),
            PopupMenuItem(value: 'name', child: Text('Tên nhân viên')),
          ],
          child: Row(
            children: [
              Icon(Icons.sort_rounded, size: 16, color: AppColors.primaryDark),
              const SizedBox(width: 4),
              Text(
                sortLabel,
                style: AppTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.row, required this.onOpen});

  final SalaryGradeReviewRow row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final timing = switch (row.timingStatus) {
      'TODAY' => ('Đến hạn hôm nay', AppColors.error),
      'PASSED' => ('Đã đến hạn ${row.daysUntil.abs()} ngày', AppColors.warning),
      _ => ('Còn ${row.daysUntil} ngày', AppColors.success),
    };
    final meta = [
      if (row.department.isNotEmpty) row.department,
      if (row.position.isNotEmpty) row.position,
    ].join(' · ');
    final date = AppFormat.date(AppFormat.tryParseDate(row.effectiveDate));
    final source = switch (row.reviewSource) {
      'MANUAL_REVIEW_DATE' => 'Ngày xét lương hồ sơ',
      'SENIORITY_SCALE' => 'Thâm niên / thang lương',
      _ => '',
    };

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadius.brMd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(name: row.fullName, size: 42, showShadow: false),
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          [
                            if (row.employeeCode.isNotEmpty) row.employeeCode,
                            row.objectLabel,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _GradePill(
                    label: row.currentGrade.isEmpty ? '—' : row.currentGrade,
                    filled: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  _GradePill(
                    label: row.nextGrade.isEmpty ? '—' : row.nextGrade,
                    filled: true,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: StatusChip(
                        label: timing.$1,
                        color: timing.$2,
                        dense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppFormat.currency(row.currentSalary),
                            style: AppTypography.style(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              tabular: true,
                            ),
                          ),
                          Text(
                            AppFormat.currency(row.nextSalary),
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${AppFormat.currency(row.increaseAmount)}',
                          style: AppTypography.style(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                            tabular: true,
                          ),
                        ),
                        if (row.increasePercent != 0)
                          Text(
                            '+${AppFormat.compactNumber(row.increasePercent)}%',
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.successDark,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  date,
                  if (row.seniorityYears != 0)
                    'Thâm niên ${AppFormat.years(row.seniorityYears)} năm',
                  if (source.isNotEmpty) source,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradePill extends StatelessWidget {
  const _GradePill({required this.label, required this.filled});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceMuted,
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: filled
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.borderSoft,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: filled ? AppColors.primaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _TimingChip extends StatelessWidget {
  const _TimingChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.88)
                        : AppColors.primaryDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
