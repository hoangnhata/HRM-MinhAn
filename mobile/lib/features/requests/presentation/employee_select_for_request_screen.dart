import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/employee.dart';
import '../../employees/data/employee_repository.dart';
import '../data/request_type_config.dart';

/// Chọn nhân viên trước khi lập phiếu đề xuất (luân chuyển / đào tạo / hội thảo).
class EmployeeSelectForRequestScreen extends ConsumerStatefulWidget {
  const EmployeeSelectForRequestScreen({
    super.key,
    required this.typeKey,
  });

  final String typeKey;

  @override
  ConsumerState<EmployeeSelectForRequestScreen> createState() =>
      _EmployeeSelectForRequestScreenState();
}

class _EmployeeSelectForRequestScreenState
    extends ConsumerState<EmployeeSelectForRequestScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<EmployeeSummary> _items = const [];
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _query = '';
  late String _status;
  int _loadGen = 0;

  static const _pageSize = 40;
  static const _visibleTarget = 24;
  static const _statusOptions = [
    ('OFFICIAL', 'Chính thức', Icons.verified_rounded),
    ('TRIAL', 'Thử việc / TT', Icons.school_rounded),
  ];

  RequestTypeConfig get _config => RequestTypeConfig.byKey(widget.typeKey);

  bool get _filterMainDuty => widget.typeKey == 'main-duty-authorization';

  List<EmployeeSummary> get _visibleItems {
    if (!_filterMainDuty) return _items;
    return _items.where((e) => !e.mainDutyAuthorized).toList();
  }

  String get _countLabel {
    if (_filterMainDuty) {
      final n = _visibleItems.length;
      return _hasMore ? '$n+ người' : '$n người';
    }
    return '$_total người';
  }

  @override
  void initState() {
    super.initState();
    _status = widget.typeKey == 'probation-conversion' ? 'TRIAL' : 'OFFICIAL';
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    final gen = reset ? ++_loadGen : _loadGen;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
        _hasMore = true;
      });
    }

    try {
      final page = await ref.read(employeeRepositoryProvider).list(
            page: reset ? 0 : _page,
            size: _pageSize,
            query: _query.isEmpty ? null : _query,
            statusGroup: _status,
          );
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _items = reset ? page.content : [..._items, ...page.content];
        _page = page.number;
        _total = page.totalElements;
        _hasMore = !page.last;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      _scheduleFillViewport();
    } on ApiException catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.message;
        if (reset) _items = const [];
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Không tải được danh sách nhân viên';
        if (reset) _items = const [];
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page += 1;
    await _load(reset: false);
  }

  /// Trang API ~40 NV chính thức thường chỉ còn vài người chưa trực chính.
  /// List ngắn thì không cuộn được → không gọi load-more. Tự kéo thêm trang.
  void _scheduleFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _loadingMore || !_hasMore) return;
      final sparse = _filterMainDuty && _visibleItems.length < _visibleTarget;
      final shortViewport = _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent < 120;
      if (sparse || shortViewport) {
        _loadMore();
      }
    });
  }

  void _onQueryChanged(String value) {
    _query = value.trim();
    _load(reset: true);
  }

  void _onStatusChanged(String status) {
    if (_status == status) return;
    HapticFeedback.selectionClick();
    setState(() => _status = status);
    _load(reset: true);
  }

  void _select(EmployeeSummary emp) {
    HapticFeedback.lightImpact();
    context.pushReplacement(
      RoutePaths.requestCreatePath(
        widget.typeKey,
        employeeId: emp.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final accent = config.color;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.8)),
          Column(
            children: [
              AppScreenHeader(
                title: 'Chọn nhân viên',
                icon: Icons.person_search_rounded,
                eyebrow: config.shortLabel,
                subtitle: switch (widget.typeKey) {
                  'probation-conversion' =>
                    'Chọn nhân viên thử việc / thực tập',
                  'main-duty-authorization' =>
                    'Chọn nhân viên chưa được trực chính',
                  'shift-config-change' =>
                    'Chọn nhân viên khoa để lấy giờ ca mẫu',
                  _ => 'Tìm nhanh rồi chạm để lập phiếu',
                },
                onBack: () => context.pop(),
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AppSearchField(
                          controller: _searchController,
                          hintText: 'Tìm tên, mã NV, CCCD…',
                          onChanged: _onQueryChanged,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (i, opt) in _statusOptions.indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _StatusChip(
                                label: opt.$2,
                                icon: opt.$3,
                                selected: _status == opt.$1,
                                onTap: () => _onStatusChanged(opt.$1),
                              ),
                            ],
                            if (_total > 0) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: AppRadius.brPill,
                                ),
                                child: Text(
                                  _countLabel,
                                  style: AppTypography.style(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildBody(accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color accent) {
    if (_loading && _items.isEmpty) {
      return const SkeletonList(itemCount: 8);
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }
    if (_visibleItems.isEmpty) {
      if (_hasMore || _loadingMore) {
        return const SkeletonList(itemCount: 8);
      }
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: widget.typeKey == 'main-duty-authorization'
            ? 'Không còn nhân viên chưa trực chính'
            : 'Không có nhân viên',
        message: _query.isEmpty
            ? 'Thử đổi bộ lọc trạng thái hoặc kiểm tra quyền xem danh sách.'
            : 'Không khớp “$_query”. Thử tên khác hoặc mã nhân viên.',
      );
    }

    return RefreshIndicator(
      color: accent,
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          12,
          AppSpacing.page,
          32,
        ),
        itemCount: _visibleItems.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoticeBanner(
                color: accent,
                icon: Icons.touch_app_rounded,
                message: switch (widget.typeKey) {
                  'probation-conversion' =>
                    'Chạm nhân viên thử việc / thực tập để lập đơn lên chính thức.',
                  'main-duty-authorization' =>
                    'Chạm nhân viên chưa được trực chính để lập đơn.',
                  'shift-config-change' =>
                    'Chạm nhân viên khoa/phòng để lấy giờ ca mẫu rồi đề xuất đổi giờ.',
                  _ =>
                    'Chạm vào nhân viên để điền phiếu ${_config.shortLabel.toLowerCase()}.',
                },
              ),
            );
          }
          if (index == _visibleItems.length + 1) {
            if (!_loadingMore) return const SizedBox(height: 8);
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          }
          final emp = _visibleItems[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EmployeePickCard(
              employee: emp,
              accent: accent,
              onTap: () => _select(emp),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
      borderRadius: AppRadius.brPill,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.primaryDark
                    : Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primaryDark
                      : Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeePickCard extends StatelessWidget {
  const _EmployeePickCard({
    required this.employee,
    required this.accent,
    required this.onTap,
  });

  final EmployeeSummary employee;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code = (employee.employeeCode ?? '').trim();
    final position = (employee.positionTitle ?? '').trim();
    final dept = (employee.departmentName ?? '').trim();
    final unit = (employee.workUnitDetail ?? '').trim();
    final meta = [
      if (dept.isNotEmpty) dept,
      if (unit.isNotEmpty && unit != dept) unit,
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          AppAvatar(
            name: employee.fullName,
            imageUrl: employee.avatarUrl,
            size: 52,
            borderColor: accent.withValues(alpha: 0.22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (code.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          code,
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (position.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    position,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
