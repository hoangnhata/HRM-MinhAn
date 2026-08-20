import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../data/evaluation_repository.dart';
import 'evaluation_enums.dart';

/// Tổng hợp xếp loại theo tháng — đồng bộ GET /summary.
class EvaluationSummaryPanel extends ConsumerStatefulWidget {
  const EvaluationSummaryPanel({super.key});

  @override
  ConsumerState<EvaluationSummaryPanel> createState() =>
      _EvaluationSummaryPanelState();
}

class _EvaluationSummaryPanelState
    extends ConsumerState<EvaluationSummaryPanel> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  final _search = TextEditingController();
  String _query = '';
  String _dept = '';
  /// Lọc nhanh: '', approved, pending, rejected.
  String _bucket = '';
  /// Lọc chi tiết theo nhóm trạng thái web (sheet).
  String _statusFilter = '';

  List<NursingEvalSummaryRow> _rows = const [];
  bool _loading = true;
  String? _error;

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
      final rows = await ref.read(evaluationRepositoryProvider).monthlySummary(
            year: _year,
            month: _month,
          );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được tổng hợp xếp loại';
      });
    }
  }

  Future<void> _shiftMonth(int delta) async {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    if (y < 2020) return;
    setState(() {
      _year = y;
      _month = m;
    });
    await _load();
  }

  bool _matchesBucket(NursingEvalSummaryRow r) {
    if (_bucket.isEmpty) return true;
    final s = r.status;
    return switch (_bucket) {
      'approved' => s == 'APPROVED',
      'pending' => s.startsWith('PENDING_'),
      'rejected' => s.endsWith('_REJECTED'),
      _ => true,
    };
  }

  List<NursingEvalSummaryRow> get _visible {
    final q = _fold(_query);
    return [
      for (final r in _rows)
        if (_dept.isEmpty || r.departmentName == _dept)
          if (_matchesBucket(r))
            if (_bucket.isNotEmpty ||
                _statusFilter.isEmpty ||
                EvaluationEnums.statusFilterGroup(r.status) == _statusFilter)
              if (q.isEmpty ||
                  _fold(r.fullName).contains(q) ||
                  _fold(r.employeeCode).contains(q) ||
                  _fold(r.overallGrade ?? '').contains(q) ||
                  _fold(r.departmentName).contains(q))
                r,
    ];
  }

  Map<String, int> get _stats {
    var approved = 0, pending = 0, rejected = 0;
    for (final r in _rows) {
      if (r.status == 'APPROVED') {
        approved++;
      } else if (r.status.startsWith('PENDING_')) {
        pending++;
      } else if (r.status.endsWith('_REJECTED')) {
        rejected++;
      }
    }
    return {
      'total': _rows.length,
      'approved': approved,
      'pending': pending,
      'rejected': rejected,
    };
  }

  List<String> get _departments {
    final set = <String>{
      for (final r in _rows)
        if (r.departmentName.trim().isNotEmpty) r.departmentName.trim(),
    };
    return set.toList()..sort();
  }

  bool get _hasActiveFilter =>
      _dept.isNotEmpty || _statusFilter.isNotEmpty || _bucket.isNotEmpty;

  void _setBucket(String value) {
    setState(() {
      _bucket = _bucket == value ? '' : value;
      if (_bucket.isNotEmpty) _statusFilter = '';
    });
  }

  Future<void> _openFilters() async {
    final depts = _departments;
    var dept = _dept;
    var status = _statusFilter;
    final result = await showModalBottomSheet<({String dept, String status})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: AppRadius.brPill,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Bộ lọc tổng hợp',
                      style: AppTypography.style(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'TRẠNG THÁI',
                      style: AppTypography.style(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SheetChip(
                          label: 'Tất cả',
                          selected: status.isEmpty,
                          onTap: () => setLocal(() => status = ''),
                        ),
                        for (final g in EvaluationEnums.statusFilterGroups)
                          _SheetChip(
                            label: g.$2,
                            selected: status == g.$1,
                            onTap: () => setLocal(() => status = g.$1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'KHOA / PHÒNG',
                      style: AppTypography.style(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.28,
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _SheetChip(
                              label: 'Tất cả khoa',
                              selected: dept.isEmpty,
                              onTap: () => setLocal(() => dept = ''),
                            ),
                            for (final d in depts)
                              _SheetChip(
                                label: d,
                                selected: dept == d,
                                onTap: () => setLocal(() => dept = d),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                              ctx,
                              (dept: '', status: ''),
                            ),
                            child: const Text('Đặt lại'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(
                              ctx,
                              (dept: dept, status: status),
                            ),
                            child: const Text('Áp dụng'),
                          ),
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
    if (result == null || !mounted) return;
    setState(() {
      _dept = result.dept;
      _statusFilter = result.status;
      if (_statusFilter.isNotEmpty) _bucket = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    final stats = _stats;
    final total = stats['total'] ?? 0;
    final approved = stats['approved'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final rejected = stats['rejected'] ?? 0;
    final approvedRatio = total == 0 ? 0.0 : approved / total;

    if (_loading && _rows.isEmpty) {
      return const SkeletonList(itemCount: 6, showAvatar: false);
    }
    if (_error != null && _rows.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }

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
              padding: const EdgeInsets.only(bottom: 10),
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
            child: _SummaryHero(
              year: _year,
              month: _month,
              total: total,
              approved: approved,
              pending: pending,
              rejected: rejected,
              progress: approvedRatio,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
              onTapApproved: () => _setBucket('approved'),
              onTapPending: () => _setBucket('pending'),
              onTapRejected: () => _setBucket('rejected'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _search,
                  hintText: 'Tìm tên, mã, xếp loại…',
                  dense: true,
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _hasActiveFilter
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: AppRadius.brMd,
                child: InkWell(
                  onTap: _openFilters,
                  borderRadius: AppRadius.brMd,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.brMd,
                      border: Border.all(
                        color: _hasActiveFilter
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : AppColors.borderSoft,
                      ),
                    ),
                    child: Badge(
                      isLabelVisible: _hasActiveFilter,
                      smallSize: 8,
                      child: Icon(
                        Icons.tune_rounded,
                        color: _hasActiveFilter
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickChip(
                  label: 'Tất cả',
                  count: total,
                  selected: _bucket.isEmpty &&
                      _statusFilter.isEmpty &&
                      _dept.isEmpty,
                  onTap: () => setState(() {
                    _bucket = '';
                    _statusFilter = '';
                    _dept = '';
                  }),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  label: 'Đã duyệt',
                  count: approved,
                  selected: _bucket == 'approved',
                  onTap: () => _setBucket('approved'),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  label: 'Chờ duyệt',
                  count: pending,
                  selected: _bucket == 'pending',
                  onTap: () => _setBucket('pending'),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  label: 'Từ chối',
                  count: rejected,
                  selected: _bucket == 'rejected',
                  onTap: () => _setBucket('rejected'),
                ),
                if (_dept.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _QuickChip(
                    label: _dept,
                    selected: true,
                    onTap: () => setState(() => _dept = ''),
                    trailing: Icons.close_rounded,
                  ),
                ],
                if (_statusFilter.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _QuickChip(
                    label: EvaluationEnums.statusFilterGroups
                        .firstWhere(
                          (g) => g.$1 == _statusFilter,
                          orElse: () => (_statusFilter, _statusFilter, const []),
                        )
                        .$2,
                    selected: true,
                    onTap: () => setState(() => _statusFilter = ''),
                    trailing: Icons.close_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'DANH SÁCH',
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              Text(
                '${rows.length}',
                style: AppTypography.metric(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: EmptyState(
                icon: Icons.insights_outlined,
                color: AppColors.primary,
                title: 'Chưa có phiếu trong tháng',
                message:
                    'Đổi kỳ ở phía trên hoặc đợi Trưởng khoa lập và gửi phiếu đánh giá.',
              ),
            )
          else
            for (final (i, row) in rows.indexed)
              AppReveal(
                delay: Duration(milliseconds: (i * 24).clamp(0, 160)),
                offset: 8,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SummaryCard(
                    row: row,
                    onTap: row.evaluationId > 0
                        ? () => context.push(
                              RoutePaths.evaluationDetailPath(row.evaluationId),
                            )
                        : null,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.year,
    required this.month,
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.progress,
    required this.onPrev,
    required this.onNext,
    required this.onTapApproved,
    required this.onTapPending,
    required this.onTapRejected,
  });

  final int year;
  final int month;
  final int total;
  final int approved;
  final int pending;
  final int rejected;
  final double progress;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapApproved;
  final VoidCallback onTapPending;
  final VoidCallback onTapRejected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
            top: -36,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onPrev,
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'TỔNG HỢP XẾP LOẠI',
                          style: AppTypography.style(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        Text(
                          AppFormat.monthLabelVi(DateTime(year, month)),
                          style: AppTypography.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onNext,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: AppTypography.metric(
                      fontSize: 42,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'phiếu trong tháng',
                      style: AppTypography.style(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${(progress * 100).round()}% duyệt',
                      style: AppTypography.style(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: AppRadius.brPill,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HeroStatTap(
                      label: 'Đã duyệt',
                      value: '$approved',
                      onTap: onTapApproved,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HeroStatTap(
                      label: 'Chờ duyệt',
                      value: '$pending',
                      onTap: onTapPending,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HeroStatTap(
                      label: 'Từ chối',
                      value: '$rejected',
                      onTap: onTapRejected,
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

class _HeroStatTap extends StatelessWidget {
  const _HeroStatTap({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            children: [
              Text(
                value,
                style: AppTypography.metric(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.14)
          : AppColors.surface,
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brPill,
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == null ? label : '$label · $count',
                style: AppTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                Icon(trailing, size: 14, color: AppColors.primaryDark),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.14)
          : AppColors.surfaceMuted,
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Text(
            label,
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.row, this.onTap});
  final NursingEvalSummaryRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gradeColor = EvaluationEnums.gradeColor(row.overallGrade);
    final statusColor = EvaluationEnums.statusColor(row.status);
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      row.totalScore == null
                          ? '—'
                          : AppFormat.compactNumber(row.totalScore),
                      style: AppTypography.metric(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: gradeColor,
                      ),
                    ),
                    if (row.overallGrade != null)
                      Text(
                        row.overallGrade!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: gradeColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
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
                      ),
                    ),
                    Text(
                      [
                        if (row.employeeCode.isNotEmpty) row.employeeCode,
                        if (row.departmentName.isNotEmpty) row.departmentName,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            EvaluationEnums.statusLabel(row.status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
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
