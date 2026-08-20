import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../application/generic_request_controller.dart';
import '../data/request_type_config.dart';
import 'request_generic_card.dart';

/// Màn loại đơn generic — đồng bộ UX với đơn công / điều động.
///
/// - Nhân viên: một danh sách liên quan + banner hướng dẫn.
/// - Người duyệt / xem quản lý: tab Đơn của tôi · Chờ duyệt (lịch sử nằm trong
///   Chờ duyệt như đơn công).
class RequestTypeScreen extends ConsumerStatefulWidget {
  const RequestTypeScreen({
    super.key,
    required this.typeKey,
    this.highlightRequestId,
    this.initialTab,
  });

  final String typeKey;
  final int? highlightRequestId;
  final String? initialTab;

  @override
  ConsumerState<RequestTypeScreen> createState() => _RequestTypeScreenState();
}

class _RequestTypeScreenState extends ConsumerState<RequestTypeScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  late final bool _useManagerShell;
  late final bool _canReview;

  static String _introFor(String key) {
    return switch (key) {
      'young-child' =>
        'Các đơn chế độ nuôi con nhỏ liên quan đến bạn và trạng thái duyệt hiện tại.',
      'department-transfer' =>
        'Các đơn luân chuyển phòng ban liên quan đến bạn và trạng thái duyệt hiện tại.',
      'probation-conversion' =>
        'Các đơn chuyển chính thức liên quan đến bạn và trạng thái duyệt hiện tại.',
      'main-duty-authorization' =>
        'Các đơn chuyển trực chính liên quan đến bạn và trạng thái duyệt hiện tại.',
      'training-proposal' =>
        'Các đề xuất đào tạo liên quan đến bạn và trạng thái duyệt hiện tại.',
      'seminar-proposal' =>
        'Các đề xuất hội thảo liên quan đến bạn và trạng thái duyệt hiện tại.',
      'shift-config-change' =>
        'Các đơn thay đổi giờ ca của khoa/phòng và trạng thái duyệt hiện tại.',
      _ => 'Các đơn liên quan đến bạn và trạng thái duyệt hiện tại.',
    };
  }

  @override
  void initState() {
    super.initState();
    final role = ref.read(authControllerProvider).role;
    final config = RequestTypeConfig.byKey(widget.typeKey);
    _canReview = config.canReview(role);
    _useManagerShell = config.canUseManagerShell(role);
    if (_useManagerShell) {
      var initial = _canReview ? 1 : 0;
      final tab = widget.initialTab?.toLowerCase();
      if (tab == 'approve') {
        initial = 1;
      } else if (tab == 'mine') {
        initial = 0;
      } else if (widget.highlightRequestId != null && _canReview) {
        initial = 1;
      }
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: initial.clamp(0, 1),
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = RequestTypeConfig.byKey(widget.typeKey);
    final state = ref.watch(genericRequestControllerProvider(widget.typeKey));
    final controller = ref.read(
      genericRequestControllerProvider(widget.typeKey).notifier,
    );
    final role = ref.watch(authControllerProvider).role;
    final canCreate = config.canCreate(role);

    if (!_useManagerShell) {
      return _EmployeeRelatedScaffold(
        config: config,
        state: state,
        onRefresh: controller.refreshAll,
        intro: _introFor(config.key),
        highlightRequestId: widget.highlightRequestId,
        canCreate: canCreate,
      );
    }

    final allListsEmpty =
        state.related.isEmpty && state.pending.isEmpty && state.history.isEmpty;
    final loadingFirstTime = state.loading && allListsEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                RoutePaths.requestCreatePath(widget.typeKey),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo đơn'),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: config.shortLabel,
                icon: config.icon,
                eyebrow: 'Đơn từ',
                subtitle: config.label,
                onBack: () => context.pop(),
                footer: BrandHeaderTabBar(
                  dense: true,
                  controller: _tabController!,
                  items: [
                    BrandHeaderTabItem(
                      label: 'Đơn của tôi',
                      icon: Icons.folder_shared_outlined,
                      count: state.related.length,
                    ),
                    BrandHeaderTabItem(
                      label: 'Chờ duyệt',
                      icon: Icons.pending_actions_rounded,
                      count: state.pending.length,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loadingFirstTime
                    ? const SkeletonList(itemCount: 5)
                    : state.error != null && allListsEmpty
                        ? ErrorState(
                            message: state.error!,
                            onRetry: controller.refreshAll,
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _RequestList(
                                items: [
                                  for (final raw in state.related)
                                    (raw, null),
                                ],
                                error: state.error,
                                onRefresh: controller.refreshAll,
                                typeKey: config.key,
                                accent: config.color,
                                highlightRequestId: widget.highlightRequestId,
                                emptyIcon: Icons.folder_open_outlined,
                                emptyTitle: _canReview
                                    ? 'Bạn chưa có đơn nào'
                                    : 'Chưa có phiếu bạn lập',
                                emptyMessage: _canReview
                                    ? 'Các đơn gắn với hồ sơ của bạn hiện ở đây. Duyệt đơn ở tab Chờ duyệt.'
                                    : 'Các phiếu bạn tạo sẽ xuất hiện ở đây.',
                              ),
                              _PendingWithHistoryList(
                                pending: [
                                  for (final item in state.pending)
                                    (item.raw, item.stage.label),
                                ],
                                history: [
                                  for (final raw in state.history)
                                    (raw, null),
                                ],
                                error: state.error,
                                onRefresh: controller.refreshAll,
                                typeKey: config.key,
                                accent: config.color,
                                highlightRequestId: widget.highlightRequestId,
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

class _EmployeeRelatedScaffold extends StatefulWidget {
  const _EmployeeRelatedScaffold({
    required this.config,
    required this.state,
    required this.onRefresh,
    required this.intro,
    this.highlightRequestId,
    this.canCreate = false,
  });

  final RequestTypeConfig config;
  final GenericRequestState state;
  final Future<void> Function() onRefresh;
  final String intro;
  final int? highlightRequestId;
  final bool canCreate;

  @override
  State<_EmployeeRelatedScaffold> createState() =>
      _EmployeeRelatedScaffoldState();
}

class _EmployeeRelatedScaffoldState extends State<_EmployeeRelatedScaffold> {
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  int? _scrolledForId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final state = widget.state;
    final onRefresh = widget.onRefresh;
    final intro = widget.intro;
    final highlightRequestId = widget.highlightRequestId;
    final canCreate = widget.canCreate;
    final items = [for (final raw in state.related) (raw, null as String?)];
    final empty = items.isEmpty;
    final loadingFirstTime = state.loading && empty;

    if (highlightRequestId != null &&
        _scrolledForId != highlightRequestId &&
        items.any((e) => (e.$1['id'] as num?)?.toInt() == highlightRequestId)) {
      _scrolledForId = highlightRequestId;
      final cardIndex = items.indexWhere(
        (e) => (e.$1['id'] as num?)?.toInt() == highlightRequestId,
      );
      scheduleScrollToHighlight(
        _highlightKey,
        controller: _scroll,
        index: (state.error != null ? 1 : 0) + 3 + cardIndex,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                RoutePaths.requestCreatePath(config.key),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo đơn'),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: config.shortLabel,
                icon: config.icon,
                eyebrow: 'Đơn từ',
                subtitle: config.label,
                onBack: () => context.pop(),
              ),
              Expanded(
                child: loadingFirstTime
                    ? const SkeletonList(itemCount: 5)
                    : state.error != null && empty
                        ? ErrorState(
                            message: state.error!,
                            onRetry: onRefresh,
                          )
                        : RefreshIndicator(
                            color: config.color,
                            onRefresh: onRefresh,
                            child: ListView(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.page,
                                AppSpacing.sm,
                                AppSpacing.page,
                                100,
                              ),
                              children: [
                                if (state.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: NoticeBanner.error(
                                      title: 'Dữ liệu có thể chưa mới nhất',
                                      message: state.error!,
                                      action: TextButton.icon(
                                        onPressed: onRefresh,
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Thử lại'),
                                      ),
                                    ),
                                  ),
                                _InfoBanner(
                                  icon: Icons.info_outline_rounded,
                                  color: AppColors.textSecondary,
                                  text: intro,
                                  soft: true,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                if (empty)
                                  EmptyState(
                                    icon: config.icon,
                                    color: config.color,
                                    title: 'Chưa có đơn nào liên quan đến bạn',
                                    message:
                                        'Khi có đơn được lập cho bạn, danh sách sẽ hiện tại đây.',
                                  )
                                else ...[
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${items.length} đơn',
                                      style: AppTypography.style(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  for (final (raw, stage) in items)
                                    RequestGenericCard(
                                      key: (raw['id'] as num?)?.toInt() ==
                                              highlightRequestId
                                          ? _highlightKey
                                          : null,
                                      raw: raw,
                                      stageLabel: stage,
                                      accentColor: config.color,
                                      highlighted: highlightRequestId != null &&
                                          (raw['id'] as num?)?.toInt() ==
                                              highlightRequestId,
                                      onTap: () => context.push(
                                        RoutePaths.requestDetailPath(
                                          config.key,
                                          (raw['id'] as num).toInt(),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingWithHistoryList extends StatefulWidget {
  const _PendingWithHistoryList({
    required this.pending,
    required this.history,
    required this.error,
    required this.onRefresh,
    required this.typeKey,
    required this.accent,
    this.highlightRequestId,
  });

  final List<(Map<String, dynamic>, String?)> pending;
  final List<(Map<String, dynamic>, String?)> history;
  final String? error;
  final Future<void> Function() onRefresh;
  final String typeKey;
  final Color accent;
  final int? highlightRequestId;

  @override
  State<_PendingWithHistoryList> createState() =>
      _PendingWithHistoryListState();
}

class _PendingWithHistoryListState extends State<_PendingWithHistoryList> {
  bool _showHistory = false;
  bool _autoSwitchedHistory = false;

  @override
  Widget build(BuildContext context) {
    final highlightId = widget.highlightRequestId;
    if (highlightId != null &&
        !_autoSwitchedHistory &&
        !widget.pending.any(
          (e) => (e.$1['id'] as num?)?.toInt() == highlightId,
        ) &&
        widget.history.any(
          (e) => (e.$1['id'] as num?)?.toInt() == highlightId,
        )) {
      _autoSwitchedHistory = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showHistory = true);
      });
    }
    final source = _showHistory ? widget.history : widget.pending;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            8,
            AppSpacing.page,
            4,
          ),
          child: Row(
            children: [
              _ModeSwitch(
                pendingCount: widget.pending.length,
                historyCount: widget.history.length,
                showHistory: _showHistory,
                onPending: () => setState(() => _showHistory = false),
                onHistory: () => setState(() => _showHistory = true),
              ),
              const Spacer(),
              Text(
                '${source.length} đơn',
                style: AppTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _RequestList(
            items: source,
            error: widget.error,
            onRefresh: widget.onRefresh,
            typeKey: widget.typeKey,
            accent: widget.accent,
            highlightRequestId: highlightId,
            emptyIcon: _showHistory
                ? Icons.history_rounded
                : Icons.task_alt_rounded,
            emptyColor: _showHistory ? AppColors.info : AppColors.success,
            emptyTitle: _showHistory
                ? 'Chưa có lịch sử duyệt'
                : 'Không có đơn chờ bạn duyệt',
            emptyMessage: _showHistory
                ? 'Các đơn đã xử lý sẽ được lưu ở đây.'
                : 'Bạn đã xử lý hết đơn thuộc thẩm quyền.',
            padTop: false,
          ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.pendingCount,
    required this.historyCount,
    required this.showHistory,
    required this.onPending,
    required this.onHistory,
  });

  final int pendingCount;
  final int historyCount;
  final bool showHistory;
  final VoidCallback onPending;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniSeg(
            label: pendingCount > 0 ? 'Chờ $pendingCount' : 'Chờ duyệt',
            selected: !showHistory,
            onTap: onPending,
          ),
          _MiniSeg(
            label: historyCount > 0 ? 'Đã xử lý $historyCount' : 'Đã xử lý',
            selected: showHistory,
            onTap: onHistory,
          ),
        ],
      ),
    );
  }
}

class _MiniSeg extends StatelessWidget {
  const _MiniSeg({
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
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.soft = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: soft ? AppColors.surfaceMuted : color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: soft ? AppColors.borderSoft : color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: soft ? AppColors.textSecondary : color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: soft ? FontWeight.w500 : FontWeight.w700,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestList extends StatefulWidget {
  const _RequestList({
    required this.items,
    required this.error,
    required this.onRefresh,
    required this.typeKey,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyMessage,
    this.emptyColor = AppColors.primary,
    this.accent = AppColors.primary,
    this.padTop = true,
    this.highlightRequestId,
  });

  final List<(Map<String, dynamic>, String?)> items;
  final String? error;
  final Future<void> Function() onRefresh;
  final String typeKey;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Color emptyColor;
  final Color accent;
  final bool padTop;
  final int? highlightRequestId;

  @override
  State<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<_RequestList> {
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  int? _scrolledForId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final error = widget.error;
    final accent = widget.accent;
    final highlightId = widget.highlightRequestId;

    if (error != null && items.isEmpty) {
      return ErrorState(message: error, onRetry: widget.onRefresh);
    }

    if (highlightId != null &&
        _scrolledForId != highlightId &&
        items.any((e) => (e.$1['id'] as num?)?.toInt() == highlightId)) {
      _scrolledForId = highlightId;
      final cardIndex = items.indexWhere(
        (e) => (e.$1['id'] as num?)?.toInt() == highlightId,
      );
      scheduleScrollToHighlight(
        _highlightKey,
        controller: _scroll,
        index: (error != null ? 1 : 0) +
            (widget.padTop ? 1 : 0) +
            cardIndex,
      );
    }

    return RefreshIndicator(
      color: accent,
      onRefresh: widget.onRefresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
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
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                widget.padTop ? AppSpacing.sm : 4,
                AppSpacing.page,
                100,
              ),
              children: [
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
                if (widget.padTop)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      '${items.length} đơn',
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                for (final (raw, stageLabel) in items)
                  RequestGenericCard(
                    key: (raw['id'] as num?)?.toInt() == highlightId
                        ? _highlightKey
                        : null,
                    raw: raw,
                    stageLabel: stageLabel,
                    accentColor: accent,
                    highlighted:
                        (raw['id'] as num?)?.toInt() == highlightId,
                    onTap: () => context.push(
                      RoutePaths.requestDetailPath(
                        widget.typeKey,
                        (raw['id'] as num).toInt(),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
