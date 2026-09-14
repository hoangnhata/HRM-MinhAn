import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/attendance_models.dart';
import '../application/attendance_requests_controller.dart';
import 'approval_fine_sheet.dart';
import 'attendance_enums.dart';
import 'attendance_request_card.dart';
import 'attendance_request_list_filters.dart';
import 'attendance_request_toolbar.dart';

class AttendancePendingTab extends ConsumerStatefulWidget {
  const AttendancePendingTab({
    super.key,
    required this.scope,
    this.isActive = true,
    this.onSelectModeChanged,
    this.highlightRequestId,
  });

  final AttendanceRequestScope scope;
  /// False khi người dùng đang ở tab khác — tắt chế độ chọn local.
  final bool isActive;
  /// Báo parent (ẩn FAB…) — chỉ gọi sau frame, không gọi trong build/setState.
  final ValueChanged<bool>? onSelectModeChanged;
  final int? highlightRequestId;

  @override
  ConsumerState<AttendancePendingTab> createState() =>
      _AttendancePendingTabState();
}

class _AttendancePendingTabState extends ConsumerState<AttendancePendingTab> {
  bool _showHistory = false;
  bool _selectMode = false;
  bool _bulkBusy = false;
  final Set<int> _selected = {};
  AttendanceRequestListFilters _filters = AttendanceRequestListFilters.empty;
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  int? _scrolledForId;
  bool _autoSwitchedHistory = false;

  List<({String value, String label})> get _typeOptions {
    return switch (widget.scope) {
      AttendanceRequestScope.leave => const [
          (value: 'LEAVE', label: 'Nghỉ phép'),
          (value: 'UNPAID_LEAVE', label: 'Không lương'),
        ],
      AttendanceRequestScope.work => const [
          (value: 'EXPLANATION', label: 'Giải trình'),
          (value: 'UPDATE', label: 'Cập nhật công'),
        ],
      AttendanceRequestScope.deployment => const [
          (value: 'DEPLOYMENT', label: 'Điều động'),
        ],
    };
  }

  @override
  void didUpdateWidget(covariant AttendancePendingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive && _selectMode) {
      _selectMode = false;
      _selected.clear();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _notifySelectMode(bool value) {
    final cb = widget.onSelectModeChanged;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      cb(value);
    });
  }

  void _setSelectMode(bool value) {
    if (_selectMode == value) return;
    setState(() {
      _selectMode = value;
      if (!value) _selected.clear();
    });
    _notifySelectMode(value);
  }

  void _exitSelectModeQuietly() {
    if (!_selectMode) return;
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
    _notifySelectMode(false);
  }

  void _toggleSelected(AttendanceWorkRequest request, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(request.id);
      } else {
        _selected.remove(request.id);
      }
    });
  }

  Future<void> _runBulk({
    required bool approved,
    required List<AttendanceWorkRequest> targets,
  }) async {
    if (targets.isEmpty) return;

    bool? waiveForgotFine;
    bool? keepOriginalPunchTimes;
    final fineTargets = approved
        ? targets.where(attendanceNeedsFineDecision).toList()
        : const <AttendanceWorkRequest>[];

    if (fineTargets.isNotEmpty) {
      final includeKeep = fineTargets.any(
        (r) =>
            r.requestType == 'EXPLANATION' && r.status == 'PENDING_DIRECTOR',
      );
      final decision = await showBulkFineDecisionSheet(
        context,
        fineTargetCount: fineTargets.length,
        totalCount: targets.length,
        includeKeepOriginal: includeKeep,
      );
      if (decision == null || !mounted) return;
      waiveForgotFine = decision.waiveForgotFine;
      keepOriginalPunchTimes = decision.keepOriginalPunchTimes;
    } else {
      final ok = await showConfirmDialog(
        context,
        title: approved
            ? (targets.length > 1
                ? 'Duyệt ${targets.length} đơn?'
                : 'Duyệt đơn này?')
            : (targets.length > 1
                ? 'Từ chối ${targets.length} đơn?'
                : 'Từ chối đơn này?'),
        message: approved
            ? 'Các đơn đã chọn sẽ được duyệt ở bước hiện tại (đồng bộ với web).'
            : 'Các đơn đã chọn sẽ bị từ chối ở bước hiện tại.',
        confirmLabel: approved ? 'Duyệt' : 'Từ chối',
        danger: !approved,
        icon: approved ? Icons.verified_outlined : Icons.highlight_off_outlined,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _bulkBusy = true);
    final result = await ref
        .read(attendanceRequestsControllerProvider.notifier)
        .bulkReview(
          targets,
          approved: approved,
          waiveForgotFine: waiveForgotFine,
          keepOriginalPunchTimes: keepOriginalPunchTimes,
        );
    if (!mounted) return;
    setState(() => _bulkBusy = false);
    _exitSelectModeQuietly();
    if (result.failed == 0) {
      HapticFeedback.mediumImpact();
    }

    final fineNote = approved && fineTargets.isNotEmpty
        ? (keepOriginalPunchTimes == true
            ? ' (giữ giờ gốc, không trừ tiền)'
            : waiveForgotFine == true
                ? ' (không trừ tiền)'
                : ' (có trừ tiền)')
        : '';

    final messenger = ScaffoldMessenger.of(context);
    if (result.failed == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Đã duyệt ${result.succeeded} đơn$fineNote.'
                : 'Đã từ chối ${result.succeeded} đơn.',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Xử lý ${result.succeeded}/${targets.length} đơn. '
            '${result.failed} đơn lỗi${result.lastError != null ? ': ${result.lastError}' : '.'}',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceRequestsControllerProvider);
    final controller = ref.read(attendanceRequestsControllerProvider.notifier);
    final pending = state.pending
        .where((r) => widget.scope.matches(r.requestType))
        .toList();
    final history = state.history
        .where((r) => widget.scope.matches(r.requestType))
        .toList();
    final highlightId = widget.highlightRequestId;
    if (highlightId != null &&
        !_autoSwitchedHistory &&
        !pending.any((r) => r.id == highlightId) &&
        history.any((r) => r.id == highlightId)) {
      _autoSwitchedHistory = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showHistory = true);
      });
    }
    final source = _showHistory ? history : pending;
    var filtered = _filters.apply(source);
    if (highlightId != null &&
        source.any((r) => r.id == highlightId) &&
        !filtered.any((r) => r.id == highlightId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _filters = AttendanceRequestListFilters.empty;
        });
      });
      filtered = source;
    }
    if (highlightId != null &&
        _scrolledForId != highlightId &&
        filtered.any((r) => r.id == highlightId)) {
      _scrolledForId = highlightId;
      final cardIndex = filtered.indexWhere((r) => r.id == highlightId);
      scheduleScrollToHighlight(
        _highlightKey,
        controller: _scroll,
        index: (state.error != null ? 1 : 0) + cardIndex,
      );
    }
    final emptyNoun = widget.scope == AttendanceRequestScope.leave
        ? 'đơn nghỉ'
        : widget.scope == AttendanceRequestScope.deployment
            ? 'đơn điều động'
            : 'đơn công';

    // Chỉ chọn khi đang ở tab chờ duyệt.
    final canSelect = !_showHistory;
    final selectMode = _selectMode && canSelect;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            8,
            AppSpacing.page,
            4,
          ),
          child: AttendanceRequestToolbar(
            filters: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
            resultCount: filtered.length,
            sourceItems: source,
            typeOptions: _typeOptions,
            selectMode: selectMode,
            selectedCount: _selected.length,
            selectableCount: canSelect ? filtered.length : 0,
            onSelectModeChanged:
                canSelect ? (v) => _setSelectMode(v) : null,
            leading: AppSegmentedControl(
              expand: false,
              style: AppSegmentStyle.soft,
              selectedIndex: _showHistory ? 1 : 0,
              onChanged: (i) {
                if (i == 0) {
                  setState(() {
                    _showHistory = false;
                    _filters = AttendanceRequestListFilters.empty;
                  });
                  return;
                }
                setState(() {
                  _showHistory = true;
                  _filters = AttendanceRequestListFilters.empty;
                  if (_selectMode) {
                    _selectMode = false;
                    _selected.clear();
                  }
                });
                _notifySelectMode(false);
              },
              items: [
                AppSegmentItem(
                  label: pending.isEmpty ? 'Chờ duyệt' : 'Chờ',
                  count: pending.length,
                ),
                AppSegmentItem(label: 'Đã xử lý', count: history.length),
              ],
            ),
          ),
        ),
        if (selectMode && _selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              8,
            ),
            child: _BulkActionBar(
              count: _selected.length,
              busy: _bulkBusy,
              totalSelectable: filtered.length,
              onSelectAll: () => setState(
                () => _selected
                  ..clear()
                  ..addAll(filtered.map((e) => e.id)),
              ),
              onClear: () => setState(_selected.clear),
              onApprove: () {
                final targets =
                    filtered.where((r) => _selected.contains(r.id)).toList();
                _runBulk(approved: true, targets: targets);
              },
              onReject: () {
                final targets =
                    filtered.where((r) => _selected.contains(r.id)).toList();
                _runBulk(approved: false, targets: targets);
              },
            ),
          ),
        Expanded(
          child: state.loading && source.isEmpty
              ? const SkeletonList(itemCount: 4, showAvatar: false)
              : state.error != null && source.isEmpty
                  ? ErrorState(
                      message: state.error!,
                      onRetry: controller.refreshAll,
                    )
                  : RefreshIndicator(
                      onRefresh: controller.refreshAll,
                      child: source.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                EmptyState(
                                  icon: _showHistory
                                      ? Icons.history_rounded
                                      : Icons.task_alt_rounded,
                                  color: _showHistory
                                      ? AppColors.info
                                      : AppColors.success,
                                  title: _showHistory
                                      ? 'Chưa có đơn nào đã xử lý'
                                      : 'Không có đơn chờ bạn duyệt',
                                  message: _showHistory
                                      ? 'Các đơn bạn đã duyệt hoặc từ chối sẽ hiện ở đây.'
                                      : 'Bạn đã xử lý hết $emptyNoun thuộc thẩm quyền.',
                                ),
                              ],
                            )
                          : filtered.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    EmptyState(
                                      icon: Icons.filter_alt_off_outlined,
                                      title: 'Không có đơn phù hợp',
                                      message:
                                          'Thử đổi từ khoá hoặc xoá bớt điều kiện lọc.',
                                    ),
                                  ],
                                )
                              : ListView(
                                  controller: _scroll,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    AppSpacing.page,
                                    AppSpacing.xs,
                                    AppSpacing.page,
                                    selectMode ? 120 : AppSpacing.xxl,
                                  ),
                                  children: [
                                    if (state.error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.sm,
                                        ),
                                        child: NoticeBanner.error(
                                          title:
                                              'Dữ liệu có thể chưa mới nhất',
                                          message: state.error!,
                                          action: TextButton.icon(
                                            onPressed: controller.refreshAll,
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 17,
                                            ),
                                            label: const Text('Thử lại'),
                                          ),
                                        ),
                                      ),
                                    for (final request in filtered)
                                      AttendanceRequestCard(
                                        key: request.id == highlightId
                                            ? _highlightKey
                                            : null,
                                        request: request,
                                        highlighted: request.id == highlightId,
                                        showEmployeeName: true,
                                        selectMode: selectMode,
                                        selected:
                                            _selected.contains(request.id),
                                        onSelectedChanged: (v) =>
                                            _toggleSelected(request, v),
                                        onTap: () => context.push(
                                          RoutePaths
                                              .attendanceRequestDetailPath(
                                            request.id,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                    ),
        ),
      ],
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.count,
    required this.busy,
    required this.totalSelectable,
    required this.onSelectAll,
    required this.onClear,
    required this.onApprove,
    required this.onReject,
  });

  final int count;
  final bool busy;
  final int totalSelectable;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final allSelected = count >= totalSelectable && totalSelectable > 0;

    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count',
                          style: AppTypography.style(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            tabular: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'đã chọn',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _BulkLink(
                  label: allSelected
                      ? 'Đã chọn hết'
                      : 'Tất cả ($totalSelectable)',
                  enabled: !busy && !allSelected,
                  onTap: onSelectAll,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 1,
                  height: 12,
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                _BulkLink(
                  label: 'Bỏ chọn',
                  enabled: !busy,
                  onTap: onClear,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: busy ? null : onReject,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 46,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: busy
                                  ? AppColors.error.withValues(alpha: 0.4)
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Từ chối',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: busy
                                    ? AppColors.error.withValues(alpha: 0.4)
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: busy
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: busy ? null : onApprove,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 46,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (busy)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              busy ? 'Đang xử lý…' : 'Duyệt',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkLink extends StatelessWidget {
  const _BulkLink({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: AppTypography.style(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: enabled
                ? AppColors.primaryDark
                : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
