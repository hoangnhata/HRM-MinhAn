import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/bulk_selection_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../../auth/application/auth_controller.dart';
import '../application/evaluation_controller.dart';
import 'evaluation_card.dart';
import 'evaluation_score_panel.dart';
import 'evaluation_summary_panel.dart';
import '../../../core/utils/formatters.dart';

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
      _EvalMode.approve =>
        state.pending.isEmpty ? 'Duyệt' : 'Duyệt (${state.pending.length})',
      _EvalMode.summary => 'Tổng hợp',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evaluationControllerProvider);
    final controller = ref.read(evaluationControllerProvider.notifier);
    final highlightId = widget.highlightEvaluationId;
    final modes = _modes;
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
                    : 'Chấm · Duyệt · Xếp loại khối ĐD (+ NV YHCT/Khám bệnh)',
                onBack: () => context.pop(),
                footer: modes.length > 1
                    ? BrandHeaderSegment(
                        dense: true,
                        selectedIndex: modes.indexOf(activeMode),
                        onChanged: (i) => setState(() => _mode = modes[i]),
                        items: [
                          for (final m in modes)
                            BrandSegmentItem(label: _modeLabel(m, state)),
                        ],
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

class _ApprovePanel extends ConsumerStatefulWidget {
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
  ConsumerState<_ApprovePanel> createState() => _ApprovePanelState();
}

class _ApprovePanelState extends ConsumerState<_ApprovePanel> {
  bool _selectMode = false;
  bool _bulkBusy = false;
  final Set<int> _selected = {};

  @override
  void didUpdateWidget(covariant _ApprovePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sang tab "Đã xử lý" thì thoát chế độ chọn.
    if (widget.showHistory && _selectMode) {
      _selectMode = false;
      _selected.clear();
    }
    // Phiếu đã rời hàng chờ (duyệt ở máy khác / tải lại) — bỏ khỏi lựa chọn.
    final ids = widget.pending.map((r) => r.id).toSet();
    _selected.removeWhere((id) => !ids.contains(id));
  }

  void _setSelectMode(bool value) {
    setState(() {
      _selectMode = value;
      if (!value) _selected.clear();
    });
  }

  void _toggle(NursingEvaluationRecord record, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(record.id);
      } else {
        _selected.remove(record.id);
      }
    });
  }

  Future<void> _runBulk({required bool approved}) async {
    final targets = widget.pending
        .where((r) => _selected.contains(r.id))
        .toList();
    if (targets.isEmpty) return;
    final n = targets.length;

    String? comment;
    if (approved) {
      final ok = await showConfirmDialog(
        context,
        title: n > 1 ? 'Duyệt & ký $n phiếu?' : 'Duyệt & ký phiếu này?',
        message:
            'Chữ ký của bạn sẽ được chèn vào từng phiếu đã chọn và các phiếu '
            'chuyển sang bước tiếp theo.',
        confirmLabel: 'Duyệt & ký',
        icon: Icons.draw_outlined,
      );
      if (!ok || !mounted) return;
    } else {
      comment = await showNoteInputDialog(
        context,
        title: n > 1 ? 'Từ chối $n phiếu' : 'Từ chối phiếu',
        label: 'Lý do từ chối',
        hint: 'Lý do áp dụng cho tất cả phiếu đã chọn…',
        required: true,
        confirmLabel: 'Từ chối',
        confirmColor: AppColors.error,
      );
      if (comment == null || !mounted) return;
    }

    setState(() => _bulkBusy = true);
    final result = await ref
        .read(evaluationControllerProvider.notifier)
        .bulkReview(targets, approved: approved, comment: comment);
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectMode = false;
      _selected.clear();
    });

    if (result.failed == 0) {
      HapticFeedback.mediumImpact();
      showAppSnackBar(
        context,
        approved
            ? 'Đã duyệt và ký ${result.succeeded} phiếu'
            : 'Đã từ chối ${result.succeeded} phiếu',
        isSuccess: true,
      );
    } else {
      showAppSnackBar(
        context,
        'Xử lý ${result.succeeded}/$n phiếu. ${result.failed} phiếu lỗi'
        '${result.lastError != null ? ': ${result.lastError}' : '.'}',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showHistory = widget.showHistory;
    final pending = widget.pending;
    final records = showHistory ? widget.history : pending;
    final canSelect = !showHistory && pending.isNotEmpty;
    final selectMode = _selectMode && canSelect;

    return Column(
      children: [
        Padding(
          // Đệm dưới tách thanh chọn khỏi danh sách — thẻ không còn bị cắt sát
          // ngay mép thanh khi cuộn.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            12,
            AppSpacing.page,
            10,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppSegmentedControl(
                  style: AppSegmentStyle.soft,
                  selectedIndex: showHistory ? 1 : 0,
                  onChanged: (i) => widget.onToggleHistory(i == 1),
                  items: [
                    AppSegmentItem(label: 'Chờ duyệt', count: pending.length),
                    const AppSegmentItem(label: 'Đã xử lý'),
                  ],
                ),
              ),
              if (!showHistory) ...[
                const SizedBox(width: 8),
                _SelectToggleButton(
                  active: selectMode,
                  onTap: canSelect || selectMode
                      ? () => _setSelectMode(!selectMode)
                      : null,
                ),
              ],
            ],
          ),
        ),
        if (selectMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page + 2,
              8,
              AppSpacing.page,
              0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 5),
                Text(
                  _selected.isEmpty
                      ? 'Chạm vào phiếu để chọn · ${pending.length} phiếu'
                      : 'Đã chọn ${_selected.length}/${pending.length} phiếu',
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        if (selectMode && _selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              8,
              AppSpacing.page,
              0,
            ),
            child: BulkSelectionBar(
              count: _selected.length,
              busy: _bulkBusy,
              totalSelectable: pending.length,
              approveLabel: 'Duyệt & ký',
              approveIcon: Icons.draw_outlined,
              onSelectAll: () => setState(
                () => _selected
                  ..clear()
                  ..addAll(pending.map((r) => r.id)),
              ),
              onClear: () => setState(_selected.clear),
              onApprove: () => _runBulk(approved: true),
              onReject: () => _runBulk(approved: false),
            ),
          ),
        Expanded(
          child: _TopFade(
            child: _EvaluationList(
              records: records,
              loading: widget.loading,
              error: widget.error,
              showEmployeeName: true,
              onRefresh: widget.onRefresh,
              highlightEvaluationId: widget.highlightId,
              selectMode: selectMode,
              selectedIds: _selected,
              onSelectedChanged: _toggle,
              emptyIcon: showHistory
                  ? Icons.history_rounded
                  : Icons.task_alt_rounded,
              emptyColor: showHistory ? AppColors.info : AppColors.success,
              emptyTitle: showHistory
                  ? 'Chưa có phiếu đã xử lý'
                  : 'Không có phiếu chờ duyệt',
              emptyMessage: showHistory
                  ? 'Các phiếu bạn đã ký duyệt sẽ lưu ở đây.'
                  : 'Hiện không có phiếu thuộc bước duyệt của bạn.',
              // Đang chọn: bỏ thẻ tổng để danh sách phiếu lên sát thanh thao tác.
              header: selectMode
                  ? null
                  : _QueueHero(
                      pendingCount: pending.length,
                      historyCount: widget.history.length,
                      showingHistory: showHistory,
                      records: records,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dải mờ dần ở đầu danh sách: nội dung cuộn lên "chìm" mượt dưới thanh chọn
/// thay vì bị cắt cứng ngang chữ.
class _TopFade extends StatelessWidget {
  const _TopFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.transparent, Colors.black],
        stops: [0, (16 / bounds.height).clamp(0.0, 1.0)],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Nút tròn bật/tắt chế độ chọn nhiều — cùng kiểu nút trên toolbar đơn công.
class _SelectToggleButton extends StatelessWidget {
  const _SelectToggleButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: active ? 'Huỷ chọn' : 'Chọn phiếu',
      child: Material(
        color: active ? AppColors.primary : AppColors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Icon(
              active ? Icons.close_rounded : Icons.checklist_rtl_rounded,
              size: 20,
              color: !enabled
                  ? AppColors.textTertiary
                  : active
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vỏ thẻ hero của màn đánh giá — gradient thương hiệu, vòng sáng, icon chìm,
/// bo đủ bốn góc và bóng teal; cùng ngôn ngữ với header phía trên.
class _EvalHeroCard extends StatelessWidget {
  const _EvalHeroCard({required this.ornamentIcon, required this.child});

  final IconData ornamentIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.brXl,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.26),
              blurRadius: 24,
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
            ornamentIcon: ornamentIcon,
            ornamentScale: 0.8,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Phần đầu thẻ hero: nhãn vàng đồng, số lớn + đơn vị, dòng mô tả và ô kính.
class _EvalHeroHead extends StatelessWidget {
  const _EvalHeroHead({
    required this.eyebrow,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.icon,
  });

  final String eyebrow;
  final int value;
  final String unit;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.14),
                  borderRadius: AppRadius.brPill,
                  border: Border.all(
                    color: AppColors.secondaryLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondaryLight.withValues(
                              alpha: 0.6,
                            ),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      eyebrow.toUpperCase(),
                      style: AppTypography.uppercase(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: AppColors.secondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value.toDouble()),
                    duration: AppDurations.slow,
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      AppFormat.number(v.round()),
                      style:
                          AppTypography.display(
                            fontSize: 44,
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
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
          child: Icon(icon, size: 24, color: Colors.white),
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
    return _EvalHeroCard(
      ornamentIcon: Icons.emoji_events_rounded,
      child: _EvalHeroHead(
        eyebrow: 'Kết quả của tôi',
        value: count,
        unit: 'phiếu đã duyệt',
        subtitle: 'Chỉ hiện phiếu sau bước Giám đốc',
        icon: Icons.emoji_events_rounded,
      ),
    );
  }
}

class _QueueHero extends StatelessWidget {
  const _QueueHero({
    required this.pendingCount,
    required this.historyCount,
    required this.showingHistory,
    required this.records,
  });

  final int pendingCount;
  final int historyCount;
  final bool showingHistory;

  /// Phiếu đang hiển thị — dùng tính phân bổ xếp loại.
  final List<NursingEvaluationRecord> records;

  /// Sắc xếp loại trên nền teal đậm (vạch/chấm nhỏ nên cần tươi).
  static Color _gradeTone(String grade) {
    final g = grade.toUpperCase();
    if (g.contains('XUẤT SẮC') || g == 'A') return const Color(0xFFFCD34D);
    if (g.contains('TỐT')) return AppColors.onBrandRing;
    if (g.contains('KHÁ') || g == 'B') return const Color(0xFF93C5FD);
    if (g.contains('TRUNG BÌNH') || g == 'C') return const Color(0xFFFDBA74);
    return const Color(0xFFFCA5A5);
  }

  @override
  Widget build(BuildContext context) {
    final count = showingHistory ? historyCount : pendingCount;
    final subtitle = showingHistory
        ? (historyCount == 0
              ? 'Chưa có phiếu bạn đã ký'
              : 'Đã xử lý ở bước duyệt của bạn')
        : (pendingCount == 0
              ? 'Không còn phiếu ở bước hiện tại'
              : 'Cần bạn ký duyệt ở bước hiện tại');

    // Phân bổ xếp loại, nhiều nhất đứng trước.
    final grades = <String, int>{};
    for (final r in records) {
      final g = r.overallGrade?.trim();
      if (g == null || g.isEmpty) continue;
      grades[g] = (grades[g] ?? 0) + 1;
    }
    final ranked = grades.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final graded = ranked.fold<int>(0, (s, e) => s + e.value);

    return _EvalHeroCard(
      ornamentIcon: showingHistory ? Icons.history_rounded : Icons.draw_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EvalHeroHead(
            eyebrow: showingHistory ? 'Đã xử lý' : 'Chờ bạn duyệt',
            value: count,
            unit: 'phiếu',
            subtitle: subtitle,
            icon: showingHistory ? Icons.history_rounded : Icons.draw_outlined,
          ),
          if (graded > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Xếp loại',
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${ranked.length} mức',
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Container(
              height: 10,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.16),
                borderRadius: AppRadius.brPill,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.brPill,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < ranked.length; i++)
                      Expanded(
                        flex: ranked[i].value,
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == ranked.length - 1 ? 0 : 2,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _gradeTone(ranked[i].key),
                              borderRadius: AppRadius.brPill,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in ranked.take(4))
                  Container(
                    padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: AppRadius.brPill,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _gradeTone(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          e.key,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: AppTypography.uppercaseHeight,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          AppFormat.number(e.value),
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            tabular: true,
                            height: AppTypography.uppercaseHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
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
    this.selectMode = false,
    this.selectedIds = const {},
    this.onSelectedChanged,
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
  final bool selectMode;
  final Set<int> selectedIds;
  final void Function(NursingEvaluationRecord record, bool selected)?
  onSelectedChanged;

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
  String? get _displayError => _isUnlinkedEmployeeError ? null : widget.error;

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
        index:
            (widget.header != null ? 1 : 0) +
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
                      selectMode: widget.selectMode,
                      selected: widget.selectedIds.contains(record.id),
                      onSelectedChanged: widget.onSelectedChanged == null
                          ? null
                          : (v) => widget.onSelectedChanged!(record, v),
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
