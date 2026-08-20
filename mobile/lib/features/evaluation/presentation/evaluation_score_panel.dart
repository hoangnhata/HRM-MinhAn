import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../data/evaluation_repository.dart';
import 'evaluation_enums.dart';

/// Danh sách NV khối ĐD để lập / chấm phiếu theo tháng.
class EvaluationScorePanel extends ConsumerStatefulWidget {
  const EvaluationScorePanel({super.key, this.onOpenForm});

  final void Function(EmployeeSummary emp, int year, int month)? onOpenForm;

  @override
  ConsumerState<EvaluationScorePanel> createState() =>
      _EvaluationScorePanelState();
}

class _EvaluationScorePanelState extends ConsumerState<EvaluationScorePanel> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  final _search = TextEditingController();
  String _query = '';
  String _dept = '';
  String _statusFilter = 'NONE';

  List<EmployeeSummary> _roster = const [];
  Map<int, NursingPeriodStatus> _status = const {};
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
      final repo = ref.read(evaluationRepositoryProvider);
      final results = await Future.wait([
        repo.evaluationRoster(),
        repo.periodStatus(year: _year, month: _month),
      ]);
      if (!mounted) return;
      final statusMap = <int, NursingPeriodStatus>{
        for (final s in results[1] as List<NursingPeriodStatus>)
          s.employeeId: s,
      };
      setState(() {
        _roster = results[0] as List<EmployeeSummary>;
        _status = statusMap;
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
        _error = 'Không tải được danh sách chấm đánh giá';
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
    final now = DateTime.now();
    if (y > now.year || (y == now.year && m > now.month + 1)) return;
    if (y < 2020) return;
    setState(() {
      _year = y;
      _month = m;
    });
    await _load();
  }

  List<_RosterRow> get _rows {
    final q = _fold(_query);
    return [
      for (final e in _roster)
        if (_dept.isEmpty || (e.departmentName ?? '') == _dept)
          if (_statusFilter.isEmpty ||
              EvaluationEnums.statusFilterGroup(
                    _status[e.id]?.status ?? 'NONE',
                  ) ==
                  _statusFilter)
            if (q.isEmpty ||
                _fold(e.fullName).contains(q) ||
                _fold(e.employeeCode ?? '').contains(q) ||
                _fold(e.positionTitle ?? '').contains(q) ||
                _fold(e.departmentName ?? '').contains(q))
              _RosterRow(
                employee: e,
                status: _status[e.id]?.status ?? 'NONE',
                score: _status[e.id]?.totalScore,
                evaluationId: _status[e.id]?.evaluationId,
              ),
    ];
  }

  List<String> get _departments {
    final set = <String>{
      for (final e in _roster)
        if ((e.departmentName ?? '').trim().isNotEmpty)
          e.departmentName!.trim(),
    };
    final list = set.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  Map<String, int> get _stats {
    var none = 0, pending = 0, approved = 0, draft = 0;
    for (final e in _roster) {
      final s = _status[e.id]?.status ?? 'NONE';
      if (s == 'NONE' || s.isEmpty) {
        none++;
      } else if (s == 'APPROVED') {
        approved++;
      } else if (s == 'DRAFT') {
        draft++;
      } else if (s.startsWith('PENDING_')) {
        pending++;
      }
    }
    return {
      'total': _roster.length,
      'none': none,
      'pending': pending,
      'approved': approved,
      'draft': draft,
    };
  }

  bool get _hasActiveFilter =>
      _dept.isNotEmpty || (_statusFilter.isNotEmpty && _statusFilter != 'NONE');

  void _open(EmployeeSummary emp) {
    if (widget.onOpenForm != null) {
      widget.onOpenForm!(emp, _year, _month);
      return;
    }
    context.push(
      RoutePaths.evaluationScorePath(
        employeeId: emp.id,
        year: _year,
        month: _month,
        name: emp.fullName,
      ),
    );
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
                      'Bộ lọc danh sách',
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
                        for (final opt
                            in EvaluationEnums.rosterStatusFilters)
                          _SheetChip(
                            label: opt.$2,
                            selected: status == opt.$1,
                            onTap: () => setLocal(() => status = opt.$1),
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
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.32,
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
                              (dept: '', status: 'NONE'),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final stats = _stats;
    final total = stats['total'] ?? 0;
    final none = stats['none'] ?? 0;
    final doneRatio = total == 0 ? 0.0 : ((total - none) / total).clamp(0.0, 1.0);

    if (_loading && _roster.isEmpty) {
      return const SkeletonList(itemCount: 6);
    }
    if (_error != null && _roster.isEmpty) {
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
            child: _ScoreHero(
              year: _year,
              month: _month,
              none: none,
              total: total,
              pending: stats['pending'] ?? 0,
              approved: stats['approved'] ?? 0,
              draft: stats['draft'] ?? 0,
              progress: doneRatio,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _search,
                  hintText: 'Tìm tên, mã, chức danh…',
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
                  label: 'Chưa chấm',
                  count: none,
                  selected: _statusFilter == 'NONE',
                  onTap: () => setState(() {
                    _statusFilter = _statusFilter == 'NONE' ? '' : 'NONE';
                  }),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  label: 'Nháp',
                  count: stats['draft'] ?? 0,
                  selected: _statusFilter == 'DRAFT',
                  onTap: () => setState(() {
                    _statusFilter = _statusFilter == 'DRAFT' ? '' : 'DRAFT';
                  }),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  label: 'Chờ duyệt',
                  count: stats['pending'] ?? 0,
                  selected: _statusFilter == 'NURSING_HEAD' ||
                      _statusFilter == 'HR' ||
                      _statusFilter == 'DIRECTOR',
                  onTap: () => setState(() {
                    _statusFilter =
                        _statusFilter == 'NURSING_HEAD' ? '' : 'NURSING_HEAD';
                  }),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  label: 'Đã duyệt',
                  count: stats['approved'] ?? 0,
                  selected: _statusFilter == 'APPROVED',
                  onTap: () => setState(() {
                    _statusFilter =
                        _statusFilter == 'APPROVED' ? '' : 'APPROVED';
                  }),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'NHÂN VIÊN',
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
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: EmptyState(
                icon: Icons.person_search_rounded,
                title: 'Không có nhân viên',
                message: 'Thử đổi kỳ đánh giá hoặc bộ lọc.',
              ),
            )
          else
            for (final (i, row) in rows.indexed)
              AppReveal(
                delay: Duration(milliseconds: (i * 24).clamp(0, 160)),
                offset: 8,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RosterCard(
                    row: row,
                    onTap: () => _open(row.employee),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _RosterRow {
  const _RosterRow({
    required this.employee,
    required this.status,
    this.score,
    this.evaluationId,
  });
  final EmployeeSummary employee;
  final String status;
  final double? score;
  final int? evaluationId;
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({
    required this.year,
    required this.month,
    required this.none,
    required this.total,
    required this.pending,
    required this.approved,
    required this.draft,
    required this.progress,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final int none;
  final int total;
  final int pending;
  final int approved;
  final int draft;
  final double progress;
  final VoidCallback onPrev;
  final VoidCallback onNext;

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
            right: -30,
            top: -40,
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
                          'KỲ ĐÁNH GIÁ',
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
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$none',
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
                      'chưa có phiếu',
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
                      '${(progress * 100).round()}%',
                      style: AppTypography.style(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _HeroPill(icon: Icons.groups_rounded, label: '$total NV'),
                  _HeroPill(icon: Icons.edit_note_rounded, label: '$draft nháp'),
                  _HeroPill(
                    icon: Icons.hourglass_top_rounded,
                    label: '$pending chờ',
                  ),
                  _HeroPill(
                    icon: Icons.verified_rounded,
                    label: '$approved duyệt',
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
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

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.row, required this.onTap});
  final _RosterRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emp = row.employee;
    final status = row.status;
    final isNone = status == 'NONE' || status.isEmpty;
    final color = EvaluationEnums.statusColor(status);
    final label = isNone
        ? 'Chưa có phiếu'
        : EvaluationEnums.statusLabel(status);
    final meta = [
      if ((emp.employeeCode ?? '').isNotEmpty) emp.employeeCode!,
      if ((emp.departmentName ?? '').isNotEmpty) emp.departmentName!,
      if ((emp.positionTitle ?? '').isNotEmpty) emp.positionTitle!,
    ].join(' · ');

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
            border: Border.all(
              color: isNone
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : AppColors.borderSoft,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              AppAvatar(name: emp.fullName, size: 42, showShadow: false),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        if (row.score != null) ...[
                          Text(
                            '  ·  ${AppFormat.compactNumber(row.score)} điểm',
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isNone
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  isNone ? 'Chấm' : 'Xem',
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isNone ? Colors.white : AppColors.primaryDark,
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
