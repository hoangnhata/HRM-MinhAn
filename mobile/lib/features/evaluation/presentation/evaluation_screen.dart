import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../../auth/application/auth_controller.dart';
import '../application/evaluation_controller.dart';
import 'evaluation_card.dart';
import 'evaluation_score_panel.dart';
import 'evaluation_summary_panel.dart';

enum _EvalMode { mine, score, approve, summary }

class EvaluationScreen extends ConsumerStatefulWidget {
  const EvaluationScreen({
    super.key,
    this.highlightEvaluationId,
    this.initialMode,
  });

  final int? highlightEvaluationId;
  final String? initialMode;

  @override
  ConsumerState<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends ConsumerState<EvaluationScreen> {
  late _EvalMode _mode;
  bool _showHistory = false;
  bool _autoSwitched = false;

  bool get _hasEmployee =>
      (ref.read(authControllerProvider).employeeId ?? 0) > 0;

  bool get _canScore =>
      RoleGroups.canScoreNursingEval(ref.read(authControllerProvider).role);

  bool get _canApprove {
    final auth = ref.read(authControllerProvider);
    return RoleGroups.canApproveNursingEval(
      auth.role,
      directorApprovalEnabled:
          auth.currentUser?.directorApprovalEnabled ?? false,
    );
  }

  bool get _canSummary {
    final auth = ref.read(authControllerProvider);
    return RoleGroups.canViewNursingEvalSummary(
      auth.role,
      directorApprovalEnabled:
          auth.currentUser?.directorApprovalEnabled ?? false,
    );
  }

  List<_EvalMode> get _modes {
    final state = ref.read(evaluationControllerProvider);
    final list = <_EvalMode>[
      if (_hasEmployee && !state.mineUnavailable) _EvalMode.mine,
    ];
    if (_canScore) list.add(_EvalMode.score);
    if (_canApprove) list.add(_EvalMode.approve);
    if (_canSummary) list.add(_EvalMode.summary);
    if (list.isEmpty) {
      if (_canScore) {
        list.add(_EvalMode.score);
      } else if (_canApprove) {
        list.add(_EvalMode.approve);
      } else if (_canSummary) {
        list.add(_EvalMode.summary);
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _mode = _resolveInitialMode();
  }

  _EvalMode _resolveInitialMode() {
    final modes = _modes;
    final raw = (widget.initialMode ?? '').toLowerCase();
    final fromQuery = switch (raw) {
      'score' || 'lap' => _EvalMode.score,
      'approve' || 'duyet' => _EvalMode.approve,
      'summary' || 'tong-hop' => _EvalMode.summary,
      'mine' || 'toi' => _EvalMode.mine,
      _ => null,
    };
    if (fromQuery != null && modes.contains(fromQuery)) return fromQuery;
    if (widget.highlightEvaluationId != null &&
        modes.contains(_EvalMode.approve)) {
      return _EvalMode.approve;
    }
    if (modes.contains(_EvalMode.score)) return _EvalMode.score;
    if (modes.contains(_EvalMode.approve)) return _EvalMode.approve;
    if (modes.contains(_EvalMode.summary)) return _EvalMode.summary;
    return _EvalMode.mine;
  }

  String _modeLabel(_EvalMode mode, EvaluationState state) {
    return switch (mode) {
      _EvalMode.mine => 'Của tôi',
      _EvalMode.score => 'Lập phiếu',
      _EvalMode.approve => state.pending.isEmpty
          ? 'Duyệt'
          : 'Duyệt (${state.pending.length})',
      _EvalMode.summary => 'Tổng hợp',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evaluationControllerProvider);
    final controller = ref.read(evaluationControllerProvider.notifier);
    final highlightId = widget.highlightEvaluationId;
    final modes = _modes;
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final activeMode = modes.contains(_mode) ? _mode : modes.first;

    if (activeMode != _mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _mode = activeMode);
      });
    }

    if (highlightId != null &&
        _canApprove &&
        !_autoSwitched &&
        !state.pending.any((r) => r.id == highlightId) &&
        state.history.any((r) => r.id == highlightId)) {
      _autoSwitched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _mode = _EvalMode.approve;
          _showHistory = true;
        });
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.55)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: 'Đánh giá & xếp loại',
                icon: Icons.fact_check_rounded,
                eyebrow: 'Năng suất & chất lượng',
                subtitle: modes.length == 1
                    ? 'Kết quả sau khi đủ 4 bước duyệt'
                    : 'Chấm · Duyệt · Xếp loại khối ĐD',
                onBack: () => context.pop(),
                footer: modes.length > 1
                    ? _ModeSegment(
                        modes: modes,
                        selected: activeMode,
                        onBrand: onBrand,
                        labelOf: (m) => _modeLabel(m, state),
                        onChanged: (m) => setState(() => _mode = m),
                      )
                    : null,
              ),
              Expanded(
                child: switch (activeMode) {
                  _EvalMode.score => const EvaluationScorePanel(),
                  _EvalMode.summary => const EvaluationSummaryPanel(),
                  _EvalMode.approve => _ApprovePanel(
                      pending: state.pending,
                      history: state.history,
                      loading: state.loading,
                      error: state.queueError,
                      showHistory: _showHistory,
                      highlightId: highlightId,
                      onToggleHistory: (v) => setState(() => _showHistory = v),
                      onRefresh: controller.refreshAll,
                    ),
                  _EvalMode.mine => _EvaluationList(
                      records: state.mine,
                      loading: state.loading,
                      error: state.mineError,
                      onRefresh: controller.refreshAll,
                      highlightEvaluationId: highlightId,
                      emptyIcon: Icons.emoji_events_outlined,
                      emptyColor: AppColors.secondaryDark,
                      emptyTitle: 'Chưa có kết quả xếp loại',
                      emptyMessage:
                          'Sau khi Trưởng khoa chấm và đủ 4 bước duyệt, phiếu của bạn sẽ hiện tại đây.',
                      header: _MineHero(count: state.mine.length),
                    ),
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovePanel extends StatelessWidget {
  const _ApprovePanel({
    required this.pending,
    required this.history,
    required this.loading,
    required this.error,
    required this.showHistory,
    required this.highlightId,
    required this.onToggleHistory,
    required this.onRefresh,
  });

  final List<NursingEvaluationRecord> pending;
  final List<NursingEvaluationRecord> history;
  final bool loading;
  final String? error;
  final bool showHistory;
  final int? highlightId;
  final ValueChanged<bool> onToggleHistory;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final records = showHistory ? history : pending;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            10,
            AppSpacing.page,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: AppRadius.brPill,
              border: Border.all(color: AppColors.borderSoft),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                _Seg(
                  label: pending.isEmpty
                      ? 'Chờ duyệt'
                      : 'Chờ duyệt (${pending.length})',
                  selected: !showHistory,
                  onTap: () => onToggleHistory(false),
                ),
                _Seg(
                  label: 'Đã xử lý',
                  selected: showHistory,
                  onTap: () => onToggleHistory(true),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _EvaluationList(
            records: records,
            loading: loading,
            error: error,
            showEmployeeName: true,
            onRefresh: onRefresh,
            highlightEvaluationId: highlightId,
            emptyIcon:
                showHistory ? Icons.history_rounded : Icons.task_alt_rounded,
            emptyColor: showHistory ? AppColors.info : AppColors.success,
            emptyTitle: showHistory
                ? 'Chưa có phiếu đã xử lý'
                : 'Không có phiếu chờ duyệt',
            emptyMessage: showHistory
                ? 'Các phiếu bạn đã ký duyệt sẽ lưu ở đây.'
                : 'Hiện không có phiếu thuộc bước duyệt của bạn.',
            header: _QueueHero(
              pendingCount: pending.length,
              historyCount: history.length,
              showingHistory: showHistory,
            ),
          ),
        ),
      ],
    );
  }
}

class _MineHero extends StatelessWidget {
  const _MineHero({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KẾT QUẢ CỦA TÔI',
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Chưa có phiếu đã duyệt'
                      : '$count phiếu đã duyệt',
                  style: AppTypography.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chỉ hiện phiếu sau bước Giám đốc',
                  style: AppTypography.style(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: AppRadius.brMd,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueHero extends StatelessWidget {
  const _QueueHero({
    required this.pendingCount,
    required this.historyCount,
    required this.showingHistory,
  });

  final int pendingCount;
  final int historyCount;
  final bool showingHistory;

  @override
  Widget build(BuildContext context) {
    final title = showingHistory ? 'ĐÃ XỬ LÝ' : 'CHỜ BẠN DUYỆT';
    final subtitle = showingHistory
        ? (historyCount == 0
            ? 'Chưa có phiếu bạn đã ký'
            : '$historyCount phiếu đã xử lý ở bước của bạn')
        : (pendingCount == 0
            ? 'Không còn phiếu ở bước hiện tại'
            : '$pendingCount phiếu cần ký duyệt');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -28,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.style(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showingHistory ? '$historyCount' : '$pendingCount',
                      style: AppTypography.metric(
                        fontSize: 34,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(
                  showingHistory
                      ? Icons.history_rounded
                      : Icons.draw_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.modes,
    required this.selected,
    required this.onBrand,
    required this.labelOf,
    required this.onChanged,
  });

  final List<_EvalMode> modes;
  final _EvalMode selected;
  final Color onBrand;
  final String Function(_EvalMode) labelOf;
  final ValueChanged<_EvalMode> onChanged;

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
          for (final m in modes)
            Expanded(
              child: Material(
                color: selected == m ? onBrand : Colors.transparent,
                borderRadius: AppRadius.brPill,
                child: InkWell(
                  onTap: () => onChanged(m),
                  borderRadius: AppRadius.brPill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      labelOf(m),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected == m
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

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
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
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EvaluationList extends StatefulWidget {
  const _EvaluationList({
    required this.records,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyMessage,
    this.emptyColor = AppColors.primary,
    this.showEmployeeName = false,
    this.highlightEvaluationId,
    this.header,
  });

  final List<NursingEvaluationRecord> records;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Color emptyColor;
  final bool showEmployeeName;
  final int? highlightEvaluationId;
  final Widget? header;

  @override
  State<_EvaluationList> createState() => _EvaluationListState();
}

class _EvaluationListState extends State<_EvaluationList> {
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  int? _scrolledForId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _isUnlinkedEmployeeError {
    final e = (widget.error ?? '').toLowerCase();
    return e.contains('chưa liên kết') ||
        e.contains('lien ket') ||
        e.contains('liên kết hồ sơ');
  }

  /// Lỗi gắn hồ sơ NV không áp dụng cho hàng chờ duyệt — bỏ qua.
  String? get _displayError =>
      _isUnlinkedEmployeeError ? null : widget.error;

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    final loading = widget.loading;
    final error = _displayError;
    final highlightId = widget.highlightEvaluationId;

    if (loading && records.isEmpty) {
      return const SkeletonList(itemCount: 4, showAvatar: false);
    }

    if (highlightId != null &&
        _scrolledForId != highlightId &&
        records.any((r) => r.id == highlightId)) {
      _scrolledForId = highlightId;
      final cardIndex = records.indexWhere((r) => r.id == highlightId);
      scheduleScrollToHighlight(
        _highlightKey,
        controller: _scroll,
        index: (widget.header != null ? 1 : 0) +
            (error != null ? 1 : 0) +
            cardIndex,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.onRefresh,
      child: records.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                28,
              ),
              children: [
                if (widget.header != null) widget.header!,
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NoticeBanner.error(
                      title: 'Không tải được danh sách',
                      message: error,
                      action: TextButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Thử lại'),
                      ),
                    ),
                  )
                else
                  EmptyState(
                    icon: widget.emptyIcon,
                    color: widget.emptyColor,
                    title: widget.emptyTitle,
                    message: widget.emptyMessage,
                  ),
              ],
            )
          : ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                if (widget.header != null) widget.header!,
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: NoticeBanner.error(
                      title: 'Dữ liệu có thể chưa mới nhất',
                      message: error,
                      action: TextButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Thử lại'),
                      ),
                    ),
                  ),
                for (final (index, record) in records.indexed)
                  AppReveal(
                    delay: AppStagger.delayFor(index),
                    offset: 9,
                    child: EvaluationCard(
                      key: record.id == highlightId ? _highlightKey : null,
                      record: record,
                      showEmployeeName: widget.showEmployeeName,
                      highlighted: record.id == highlightId,
                      onTap: () => context.push(
                        RoutePaths.evaluationDetailPath(record.id),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
