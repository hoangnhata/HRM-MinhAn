import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_month_picker.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/app_segmented_control.dart';
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
      final report = await ref
          .read(salaryRepositoryProvider)
          .gradeReviews(year: _year, month: _month);
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
    // Nâng bậc nhìn về phía trước nên cho chọn cả tháng tương lai.
    final picked = await showAppMonthPicker(
      context,
      year: _year,
      month: _month,
      title: 'Tháng nâng bậc',
      yearsBack: 1,
      yearsForward: 1,
      allowFuture: true,
    );
    if (picked == null || !mounted) return;
    if (picked.$1 == _year && picked.$2 == _month) return;
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
    final dueCount = (report?.today ?? 0) + (report?.passed ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.55)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: 'Nâng bậc lương',
                icon: Icons.trending_up_rounded,
                eyebrow: 'Quản lý',
                subtitle: 'Nhân viên đến kỳ nâng bậc trong tháng',
                onBack: () => context.pop(),
              ),
              Material(
                color: AppColors.surface,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderSoft),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    10,
                    AppSpacing.page,
                    10,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _MonthChip(
                            label: AppFormat.monthLabelVi(
                              DateTime(_year, _month),
                            ),
                            onTap: _pickMonth,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppSearchField(
                              controller: _search,
                              hintText: 'Tìm tên, mã, khoa…',
                              dense: true,
                              onChanged: (v) =>
                                  setState(() => _query = v.trim()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppSegmentedControl(
                        style: AppSegmentStyle.soft,
                        dense: true,
                        selectedIndex: switch (_timing) {
                          'UPCOMING' => 1,
                          'DUE' => 2,
                          _ => 0,
                        },
                        onChanged: (i) => setState(
                          () => _timing = switch (i) {
                            1 => 'UPCOMING',
                            2 => 'DUE',
                            _ => '',
                          },
                        ),
                        items: [
                          AppSegmentItem(label: 'Tất cả', count: report?.total),
                          AppSegmentItem(
                            label: 'Sắp đến',
                            count: report?.upcoming,
                          ),
                          AppSegmentItem(label: 'Đến hạn', count: dueCount),
                        ],
                      ),
                    ],
                  ),
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
              child: AppReveal(offset: 8, child: _ReviewHero(report: report)),
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

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Chọn tháng, $label',
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brBase,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: AppRadius.brBase,
          child: Container(
            height: 40,
            padding: const EdgeInsets.only(left: 11, right: 7),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brBase,
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
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
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng đến kỳ',
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppFormat.monthLabelVi(
                        DateTime(report.year, report.month),
                      ),
                      style: AppTypography.body(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${report.total}',
                style: AppTypography.metric(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'nhân viên',
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Sắp đến',
                  value: '${report.upcoming}',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Đến hạn',
                  value: '$due',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Chênh lệch',
                  value: AppFormat.currencyCompact(report.increaseTotal),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
              tabular: true,
            ),
          ),
        ],
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

  static const _options = <AppOptionItem>[
    AppOptionItem(
      value: 'date',
      label: 'Ngày nâng bậc',
      subtitle: 'Sớm đến hạn trước',
      icon: Icons.event_available_rounded,
    ),
    AppOptionItem(
      value: 'increase',
      label: 'Mức tăng cao nhất',
      subtitle: 'Chênh lệch lương giảm dần',
      icon: Icons.trending_up_rounded,
    ),
    AppOptionItem(
      value: 'name',
      label: 'Tên nhân viên',
      subtitle: 'Theo thứ tự A → Z',
      icon: Icons.sort_by_alpha_rounded,
    ),
  ];

  Future<void> _openSort(BuildContext context) async {
    HapticFeedback.selectionClick();
    final selected = await showAppOptionPicker(
      context,
      title: 'Sắp xếp danh sách',
      subtitle: 'Chọn cách xếp nhân viên đến kỳ nâng bậc',
      selectedValue: sort,
      options: _options,
    );
    if (selected == null || selected == sort) return;
    onSort(selected);
  }

  @override
  Widget build(BuildContext context) {
    final sortLabel = switch (sort) {
      'increase' => 'Mức tăng',
      'name' => 'Tên A–Z',
      _ => 'Ngày nâng bậc',
    };
    final sortIcon = switch (sort) {
      'increase' => Icons.trending_up_rounded,
      'name' => Icons.sort_by_alpha_rounded,
      _ => Icons.event_available_rounded,
    };

    return Row(
      children: [
        Text(
          'Danh sách',
          style: AppTypography.style(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: AppRadius.brPill,
          ),
          child: Text(
            '$count',
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              tabular: true,
            ),
          ),
        ),
        const Spacer(),
        Material(
          color: AppColors.surfaceMuted,
          shape: StadiumBorder(
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
          ),
          child: InkWell(
            onTap: () => _openSort(context),
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sortIcon, size: 14, color: AppColors.primaryDark),
                  const SizedBox(width: 5),
                  Text(
                    sortLabel,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
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
    // Quá hạn là khẩn nhất nên tô đỏ; đến hạn hôm nay tô cam; sắp đến xanh.
    final accent = switch (row.timingStatus) {
      'TODAY' => AppColors.warning,
      'PASSED' => AppColors.error,
      _ => AppColors.success,
    };
    final timingLabel = switch (row.timingStatus) {
      'TODAY' => 'Đến hạn hôm nay',
      'PASSED' => 'Quá hạn ${row.daysUntil.abs()} ngày',
      _ => 'Còn ${row.daysUntil} ngày',
    };
    final date = AppFormat.date(AppFormat.tryParseDate(row.effectiveDate));
    final source = switch (row.reviewSource) {
      'MANUAL_REVIEW_DATE' => 'Xét lương hồ sơ',
      'SENIORITY_SCALE' => 'Thâm niên',
      _ => '',
    };
    final currentGrade = row.currentGrade.isEmpty ? '—' : row.currentGrade;
    final nextGrade = row.nextGrade.isEmpty ? '—' : row.nextGrade;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(name: row.fullName, size: 38, showShadow: false),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (row.employeeCode.isNotEmpty) row.employeeCode,
                            if (row.objectLabel.isNotEmpty) row.objectLabel,
                            if (row.position.isNotEmpty) row.position,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (row.department.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            row.department,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Chip thời hạn nằm cùng hàng bậc lương để tên và khoa có trọn
              // bề ngang, không bị cắt cụt bởi chip.
              Row(
                children: [
                  Flexible(
                    child: Text(
                      currentGrade,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      nextGrade,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  StatusChip(label: timingLabel, color: accent, dense: true),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: AppFormat.currency(row.currentSalary),
                              style: AppTypography.style(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                                tabular: true,
                              ),
                            ),
                            TextSpan(
                              text: '  →  ',
                              style: AppTypography.style(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            TextSpan(
                              text: AppFormat.currency(row.nextSalary),
                              style: AppTypography.style(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                tabular: true,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${AppFormat.currencyCompact(row.increaseAmount)}'
                      '${row.increasePercent != 0 ? ' · ${AppFormat.compactNumber(row.increasePercent)}%' : ''}',
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
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
                  fontSize: 11,
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

String _fold(String raw) {
  const map = {
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
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
