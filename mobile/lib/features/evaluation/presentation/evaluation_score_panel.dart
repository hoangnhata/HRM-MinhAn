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
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/app_choice_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../data/evaluation_repository.dart';
import 'evaluation_enums.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import '../../../core/widgets/app_card.dart';

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
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
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
                        AppChoiceChip(
                          muted: true,
                          label: 'Tất cả',
                          selected: status.isEmpty,
                          onTap: () => setLocal(() => status = ''),
                        ),
                        for (final opt in EvaluationEnums.rosterStatusFilters)
                          AppChoiceChip(
                            muted: true,
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
                            AppChoiceChip(
                              muted: true,
                              label: 'Tất cả khoa',
                              selected: dept.isEmpty,
                              onTap: () => setLocal(() => dept = ''),
                            ),
                            for (final d in depts)
                              AppChoiceChip(
                                muted: true,
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
                            onPressed: () =>
                                Navigator.pop(ctx, (dept: '', status: 'NONE')),
                            child: const Text('Đặt lại'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, (
                              dept: dept,
                              status: status,
                            )),
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
    final doneRatio = total == 0
        ? 0.0
        : ((total - none) / total).clamp(0.0, 1.0);

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
                AppChoiceChip(
                  label: 'Chưa chấm',
                  count: none,
                  selected: _statusFilter == 'NONE',
                  onTap: () => setState(() {
                    _statusFilter = _statusFilter == 'NONE' ? '' : 'NONE';
                  }),
                ),
                const SizedBox(width: 6),
                AppChoiceChip(
                  label: 'Nháp',
                  count: stats['draft'] ?? 0,
                  selected: _statusFilter == 'DRAFT',
                  onTap: () => setState(() {
                    _statusFilter = _statusFilter == 'DRAFT' ? '' : 'DRAFT';
                  }),
                ),
                const SizedBox(width: 6),
                AppChoiceChip(
                  label: 'Chờ duyệt',
                  count: stats['pending'] ?? 0,
                  selected:
                      _statusFilter == 'NURSING_HEAD' ||
                      _statusFilter == 'HR' ||
                      _statusFilter == 'DIRECTOR',
                  onTap: () => setState(() {
                    _statusFilter = _statusFilter == 'NURSING_HEAD'
                        ? ''
                        : 'NURSING_HEAD';
                  }),
                ),
                const SizedBox(width: 6),
                AppChoiceChip(
                  label: 'Đã duyệt',
                  count: stats['approved'] ?? 0,
                  selected: _statusFilter == 'APPROVED',
                  onTap: () => setState(() {
                    _statusFilter = _statusFilter == 'APPROVED'
                        ? ''
                        : 'APPROVED';
                  }),
                ),
                if (_dept.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  AppChoiceChip(
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

  // Sắc trạng thái trên nền teal đậm — tươi để đọc rõ ở vạch mảnh/chấm.
  static const _approvedTone = AppColors.onBrandRing;
  static const _pendingTone = Color(0xFFFCD34D);
  static const _draftTone = Color(0xFF93C5FD);

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    // Phiếu đã có nhưng không thuộc 3 nhóm trên (vd. bị trả lại).
    final other = (total - none - approved - pending - draft).clamp(0, total);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brXl,
        child: GradientHeader(
          safeAreaTop: false,
          bottomRadius: 0,
          gradient: AppGradients.brandHero,
          ornamentIcon: Icons.fact_check_rounded,
          ornamentScale: 0.85,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PeriodSwitcher(
                label: AppFormat.monthLabelVi(DateTime(year, month)),
                onPrev: onPrev,
                onNext: onNext,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CẦN LẬP PHIẾU',
                          style: AppTypography.uppercase(
                            fontSize: 10,
                            letterSpacing: 0.9,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              AppFormat.number(none),
                              style:
                                  AppTypography.display(
                                    fontSize: 46,
                                    color: Colors.white,
                                  ).copyWith(
                                    shadows: [
                                      Shadow(
                                        color: AppColors.primaryDark.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'nhân viên chưa có phiếu',
                                maxLines: 2,
                                style: AppTypography.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ProgressRing(progress: progress, pct: pct),
                ],
              ),
              const SizedBox(height: 14),
              // Thanh tiến độ chia theo trạng thái — đọc được cả cơ cấu, không chỉ %.
              _StatusBar(
                total: total,
                segments: [
                  (approved, _approvedTone),
                  (pending, _pendingTone),
                  (draft, _draftTone),
                  (other, Colors.white.withValues(alpha: 0.55)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HeroStat(
                      label: 'Nhân viên',
                      value: total,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HeroStat(
                      label: 'Nháp',
                      value: draft,
                      color: _draftTone,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HeroStat(
                      label: 'Chờ duyệt',
                      value: pending,
                      color: _pendingTone,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HeroStat(
                      label: 'Đã duyệt',
                      value: approved,
                      color: _approvedTone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bộ chuyển kỳ: viên kính tối với hai nút tròn hai bên, nhãn kỳ ở giữa.
class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _RoundGlassButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Tháng trước',
            onTap: onPrev,
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondaryLight.withValues(
                              alpha: 0.6,
                            ),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'KỲ ĐÁNH GIÁ',
                      style: AppTypography.uppercase(
                        fontSize: 9.5,
                        letterSpacing: 1.0,
                        color: AppColors.secondaryLight,
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: AppTypography.uppercaseHeight,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          _RoundGlassButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Tháng sau',
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Vòng tiến độ lập phiếu (đã có phiếu / tổng nhân viên).
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.pct});

  final double progress;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 6,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: AppColors.onBrandRing,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: AppTypography.display(fontSize: 17, color: Colors.white),
              ),
              Text(
                'đã lập',
                style: AppTypography.style(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thanh xếp chồng theo trạng thái trong rãnh lõm; mọc dần khi hiện ra.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.total, required this.segments});

  final int total;
  final List<(int, Color)> segments;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.$1 > 0).toList();
    final filled = visible.fold<int>(0, (a, s) => a + s.$1);
    final fraction = total <= 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);

    return Container(
      height: 12,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brPill,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction),
          duration: AppDurations.slow,
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Align(
            alignment: Alignment.centerLeft,
            // Có phiếu mà tỉ lệ quá nhỏ vẫn hiện một vệt ngắn.
            child: FractionallySizedBox(
              widthFactor: t <= 0 ? 0 : t.clamp(0.02, 1.0),
              child: child,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < visible.length; i++)
                Expanded(
                  flex: visible[i].$1,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == visible.length - 1 ? 0 : 2,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: visible[i].$2,
                        borderRadius: AppRadius.brPill,
                      ),
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

/// Ô thống kê kính: chấm sắc trạng thái + nhãn in hoa, số lớn bên dưới.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 8, 6, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: AppRadius.brBase,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.uppercase(
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              AppFormat.number(value),
              maxLines: 1,
              style: AppTypography.display(fontSize: 19, color: Colors.white),
            ),
          ],
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
    final statusColor = EvaluationEnums.statusColor(status);
    // Chưa có phiếu = việc cần làm → sắc teal thương hiệu; còn lại theo trạng thái.
    final accent = isNone ? AppColors.primary : statusColor;
    final label = isNone
        ? 'Chưa có phiếu'
        : EvaluationEnums.statusLabel(status);
    final position = (emp.positionTitle ?? '').trim();
    final code = (emp.employeeCode ?? '').trim();
    final dept = (emp.departmentName ?? '').trim();

    return AppCard(
      onTap: onTap,
      borderRadius: AppRadius.brLg,
      padding: EdgeInsets.zero,
      gradient: TintedCardBackdrop.gradient(accent),
      child: TintedCardBackdrop(
        accent: accent,
        watermarkIcon: Icons.fact_check_rounded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              _RosterAvatar(name: emp.fullName, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (position.isNotEmpty || code.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          children: [
                            if (position.isNotEmpty)
                              TextSpan(
                                text: position,
                                style: AppTypography.style(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            if (position.isNotEmpty && code.isNotEmpty)
                              const TextSpan(text: '   '),
                            if (code.isNotEmpty) ...[
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 3),
                                  child: Icon(
                                    Icons.tag_rounded,
                                    size: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: code,
                                style: AppTypography.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                  tabular: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          height: AppTypography.uppercaseHeight,
                        ),
                      ),
                    if (dept.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dept,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                height: AppTypography.uppercaseHeight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _RosterTag(
                          label: label,
                          color: isNone ? AppColors.textSecondary : statusColor,
                          dot: true,
                        ),
                        if (row.score != null)
                          _RosterTag(
                            label: '${AppFormat.score(row.score)} điểm',
                            color: AppColors.primary,
                            icon: Icons.star_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RosterAction(primary: isNone),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar với viền chuyển sắc theo trạng thái phiếu + chấm trạng thái.
class _RosterAvatar extends StatelessWidget {
  const _RosterAvatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.6),
                  color.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: AppAvatar(name: name, size: 42, showShadow: false),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn gọn: chấm hoặc icon + chữ trên nền pha nhạt, viền mảnh cùng sắc.
class _RosterTag extends StatelessWidget {
  const _RosterTag({
    required this.label,
    required this.color,
    this.dot = false,
    this.icon,
  });

  final String label;
  final Color color;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = Color.lerp(color, AppColors.textPrimary, 0.25)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brChip,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 12, color: ink),
            ),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: AppTypography.uppercaseHeight,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lời gọi hành động bên phải: "Chấm" gradient nổi khi chưa có phiếu,
/// "Xem" tonal nhẹ khi đã có phiếu. Chạm cả thẻ cũng mở như nhau.
class _RosterAction extends StatelessWidget {
  const _RosterAction({required this.primary});

  final bool primary;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          gradient: primary ? AppGradients.brand : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.85),
          borderRadius: AppRadius.brPill,
          border: primary
              ? null
              : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: primary ? AppShadows.button : AppShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              primary ? Icons.edit_rounded : Icons.visibility_outlined,
              size: 15,
              color: primary ? Colors.white : AppColors.primaryDark,
            ),
            const SizedBox(width: 5),
            Text(
              primary ? 'Chấm' : 'Xem',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: AppTypography.uppercaseHeight,
                color: primary ? Colors.white : AppColors.primaryDark,
              ),
            ),
          ],
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
