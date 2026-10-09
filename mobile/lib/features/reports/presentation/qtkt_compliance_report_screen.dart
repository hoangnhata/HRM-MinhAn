import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_month_picker.dart';
import '../../../core/widgets/app_period_navigator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/list_section_title.dart';
import '../../auth/application/auth_controller.dart';
import '../../qtkt/data/qtkt_models.dart';
import '../../qtkt/data/qtkt_repository.dart';
import '../data/qtkt_compliance_repository.dart';
import '../../../core/widgets/department_picker_sheet.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import 'workforce_report_widgets.dart' show foldVi;
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/search_field.dart';

/// Báo cáo tuân thủ QTKT — dữ liệu đồng bộ web, UI mobile.
class QtktComplianceReportScreen extends ConsumerStatefulWidget {
  const QtktComplianceReportScreen({super.key});

  @override
  ConsumerState<QtktComplianceReportScreen> createState() =>
      _QtktComplianceReportScreenState();
}

class _QtktComplianceReportScreenState
    extends ConsumerState<QtktComplianceReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  QtktComplianceKind _kind = QtktComplianceKind.handHygiene;
  ComplianceResultFilter _resultFilter = ComplianceResultFilter.all;
  QtktComplianceReport? _report;
  List<QtktComplianceFilterDepartment> _departments = const [];
  int? _departmentId;
  String? _departmentName;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Tìm kiếm / sắp xếp mục "Chi tiết đánh giá" (lọc phía server).
  final _detailSearch = TextEditingController();
  String _detailQuery = '';
  bool _newestFirst = true;

  /// Chỉ tải lại danh sách phiếu — giữ nguyên màn để ô tìm kiếm không mất focus.
  bool _detailsLoading = false;

  @override
  void dispose() {
    _detailSearch.dispose();
    super.dispose();
  }

  String get _yearMonth =>
      '${_month.year.toString().padLeft(4, '0')}-'
      '${_month.month.toString().padLeft(2, '0')}';

  bool get _canPickDept {
    final role = ref.read(authControllerProvider).role;
    return role == UserRole.admin ||
        role == UserRole.headNursing ||
        RoleGroups.isHeadDepartmentRole(role);
  }

  bool get _atLatestMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadDepartments();
      await _load();
    });
  }

  Future<void> _loadDepartments() async {
    if (!_canPickDept) return;
    try {
      _departments = await ref
          .read(qtktComplianceRepositoryProvider)
          .departments(kind: _kind);
    } catch (_) {}
  }

  Future<void> _load({bool append = false, bool detailsOnly = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else if (detailsOnly && _report != null) {
      setState(() => _detailsLoading = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = append ? ((_report?.detailsPage ?? 0) + 1) : 0;
      final report = await ref
          .read(qtktComplianceRepositoryProvider)
          .fetch(
            _kind,
            yearMonth: _yearMonth,
            departmentId: _departmentId,
            resultFilter: _resultFilter,
            page: page,
            search: _detailQuery,
            newestFirst: _newestFirst,
          );
      if (!mounted) return;
      if (append && _report != null) {
        final merged = Map<String, dynamic>.from(report.raw);
        final oldDetails = _report!.raw['details'];
        final newDetails = report.raw['details'];
        if (oldDetails is Map && newDetails is Map) {
          final oldItems = (oldDetails['items'] as List?) ?? const [];
          final newItems = (newDetails['items'] as List?) ?? const [];
          merged['details'] = {
            ...newDetails,
            'items': [...oldItems, ...newItems],
          };
        }
        setState(() {
          _report = QtktComplianceReport(raw: merged);
          _loadingMore = false;
        });
      } else {
        setState(() {
          _report = report;
          _loading = false;
          _loadingMore = false;
          _detailsLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _detailsLoading = false;
        _loading = false;
        _loadingMore = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _detailsLoading = false;
        _error = 'Không tải được báo cáo tuân thủ QTKT';
      });
    }
  }

  Future<void> _setKind(QtktComplianceKind kind) async {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _departmentId = null;
      _departmentName = null;
    });
    await _loadDepartments();
    await _load();
  }

  Future<void> _shiftMonth(int delta) async {
    if (delta > 0 && _atLatestMonth) return;
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showAppMonthPicker(
      context,
      year: _month.year,
      month: _month.month,
      title: 'Chọn tháng báo cáo',
    );
    if (picked == null || !mounted) return;
    if (picked.$1 == _month.year && picked.$2 == _month.month) return;
    setState(() => _month = DateTime(picked.$1, picked.$2));
    await _load();
  }

  Future<void> _pickDepartment() async {
    if (!_canPickDept) return;
    final picked = await showDepartmentPickerSheet(
      context,
      title: 'Lọc theo khoa',
      subtitle: '${_departments.length} khoa trong khối',
      allLabel: 'Toàn khối',
      items: [for (final d in _departments) (d.id, d.name)],
      selectedId: _departmentId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.cleared) {
        _departmentId = null;
        _departmentName = null;
      } else {
        final d = _departments.firstWhere((e) => e.id == picked.id);
        _departmentId = d.id;
        _departmentName = d.name;
      }
    });
    await _load();
  }

  Future<void> _openBucketDetails(
    ComplianceBucket bucket, {
    required _BucketKind kind,
  }) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      // Sheet tự vẽ thanh kéo — tắt thanh mặc định để không bị trùng.
      showDragHandle: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      builder: (ctx) => _TicketListSheet(
        title: bucket.departmentName,
        subtitle: switch (kind) {
          _BucketKind.department => 'Phiếu theo khoa/phòng',
          _BucketKind.context => 'Phiếu theo ngữ cảnh',
          _BucketKind.procedure => 'Phiếu theo quy trình',
        },
        rateLabel: bucket.rateLabel,
        passed: bucket.passed,
        failed: bucket.failed,
        total: bucket.total,
        kind: _kind,
        yearMonth: _yearMonth,
        departmentId: kind == _BucketKind.department
            ? bucket.departmentId
            : _departmentId,
        procedureCode: kind == _BucketKind.procedure
            ? bucket.procedureCode
            : null,
        checkContextCode: kind == _BucketKind.context
            ? bucket.checkContextCode
            : null,
        checkContextLabel: kind == _BucketKind.context
            ? bucket.checkContextLabel
            : null,
        onOpenTicket: (row) => _openTicketDetail(row),
      ),
    );
  }

  Future<void> _openTicketDetail(ComplianceDetailRow row) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      // Sheet tự vẽ thanh kéo — tắt thanh mặc định để không bị trùng.
      showDragHandle: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      builder: (ctx) => _TicketDetailSheet(evaluationId: row.id, preview: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppScreenHeader(
            dense: true,
            title: 'Tuân thủ QTKT',
            icon: Icons.health_and_safety_outlined,
            eyebrow: 'Báo cáo chất lượng',
            subtitle: 'Vệ sinh tay · quy trình · GDSK',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Material(
            color: AppColors.surface,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                12,
              ),
              child: Column(
                children: [
                  AppPeriodNavigator(
                    month: _month,
                    scopeLabel: _departmentName ?? 'Toàn khối',
                    canPickScope: _canPickDept,
                    canGoForward: !_atLatestMonth,
                    onPrev: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                    onPickMonth: _pickMonth,
                    onPickScope: _pickDepartment,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    // Chừa chỗ cho bóng của chip đang chọn khỏi bị cắt.
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      physics: const BouncingScrollPhysics(),
                      itemCount: QtktComplianceKind.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final k = QtktComplianceKind.values[i];
                        return _KindChip(
                          label: k.label,
                          icon: switch (k) {
                            QtktComplianceKind.handHygiene =>
                              Icons.clean_hands_rounded,
                            QtktComplianceKind.gdsk =>
                              Icons.record_voice_over_rounded,
                            QtktComplianceKind.technical =>
                              Icons.medical_services_rounded,
                          },
                          selected: _kind == k,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _setKind(k);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _loading
                  ? const LoadingState(label: 'Đang tải báo cáo...')
                  : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Không tải được',
                          message: _error!,
                          action: FilledButton(
                            onPressed: _load,
                            child: const Text('Thử lại'),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.sm,
                        AppSpacing.page,
                        AppSpacing.xxl,
                      ),
                      children: [
                        if (report != null) ...[
                          // Công thức tính đã nằm ở chân thẻ hero.
                          _KpiHero(report: report),
                          if (report.trend.any((t) => t.hasData)) ...[
                            const SizedBox(height: AppSpacing.lg),
                            const ListSectionTitle(
                              title: 'Xu hướng',
                              trailing: 'Vuốt xem tuần',
                            ),
                            const SizedBox(height: 8),
                            _ComplianceTrendCard(points: report.trend),
                          ],
                          if (report.byDepartment.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            ListSectionTitle(
                              title: 'Theo khoa/phòng',
                              trailing: '${report.byDepartment.length}',
                            ),
                            const SizedBox(height: 8),
                            for (final d in report.byDepartment)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BucketCard(
                                  bucket: d,
                                  onTap: () => _openBucketDetails(
                                    d,
                                    kind: _BucketKind.department,
                                  ),
                                ),
                              ),
                          ],
                          if (report.byCheckContext.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            const ListSectionTitle(title: 'Theo ngữ cảnh'),
                            const SizedBox(height: 8),
                            for (final d in report.byCheckContext)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BucketCard(
                                  bucket: d,
                                  onTap: () => _openBucketDetails(
                                    d,
                                    kind: _BucketKind.context,
                                  ),
                                ),
                              ),
                          ],
                          if (report.byProcedure.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            const ListSectionTitle(title: 'Theo quy trình'),
                            const SizedBox(height: 8),
                            for (final d in report.byProcedure)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BucketCard(
                                  bucket: d,
                                  onTap: () => _openBucketDetails(
                                    d,
                                    kind: _BucketKind.procedure,
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              const TintedIconTile(
                                icon: Icons.fact_check_rounded,
                                color: AppColors.primary,
                                size: 30,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Chi tiết đánh giá',
                                  style: AppTypography.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: AppTypography.uppercaseHeight,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: AppRadius.brPill,
                                ),
                                child: Text(
                                  report.details.length >= report.detailsTotal
                                      ? '${report.detailsTotal} phiếu'
                                      : '${report.details.length}/${report.detailsTotal} phiếu',
                                  style: AppTypography.style(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    tabular: true,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadius.brMd,
                                    boxShadow: AppShadows.soft,
                                  ),
                                  child: AppSearchField(
                                    controller: _detailSearch,
                                    hintText: 'Tìm tên, mã NV, mã người bệnh…',
                                    dense: true,
                                    borderRadius: AppRadius.brMd,
                                    onChanged: (v) {
                                      final q = v.trim();
                                      if (q == _detailQuery) return;
                                      _detailQuery = q;
                                      _load(detailsOnly: true);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _DateSortButton(
                                newestFirst: _newestFirst,
                                onChanged: (v) {
                                  if (v == _newestFirst) return;
                                  setState(() => _newestFirst = v);
                                  _load(detailsOnly: true);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppSegmentedControl(
                            style: AppSegmentStyle.soft,
                            dense: true,
                            selectedIndex: ComplianceResultFilter.values
                                .indexOf(_resultFilter),
                            onChanged: (i) {
                              final f = ComplianceResultFilter.values[i];
                              if (_resultFilter == f) return;
                              setState(() => _resultFilter = f);
                              _load(detailsOnly: true);
                            },
                            items: [
                              for (final f in ComplianceResultFilter.values)
                                switch (f) {
                                  ComplianceResultFilter.all => AppSegmentItem(
                                    label: 'Tất cả',
                                    count: report.total,
                                  ),
                                  ComplianceResultFilter.pass => AppSegmentItem(
                                    label: 'Đạt',
                                    icon: Icons.check_circle_rounded,
                                    count: report.passed,
                                  ),
                                  ComplianceResultFilter.fail => AppSegmentItem(
                                    label: 'Chưa đạt',
                                    icon: Icons.cancel_rounded,
                                    count: report.failed,
                                  ),
                                },
                            ],
                          ),
                          // Thanh mảnh khi đang lọc/tìm — không che cả màn.
                          AnimatedSwitcher(
                            duration: AppDurations.fast,
                            child: _detailsLoading
                                ? const Padding(
                                    key: ValueKey('loading'),
                                    padding: EdgeInsets.only(top: 8),
                                    child: ClipRRect(
                                      borderRadius: AppRadius.brPill,
                                      child: LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    key: ValueKey('idle'),
                                    height: 10,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          if (report.details.isEmpty)
                            EmptyState(
                              icon: _detailQuery.isEmpty
                                  ? Icons.fact_check_outlined
                                  : Icons.search_off_rounded,
                              title: _detailQuery.isEmpty
                                  ? 'Chưa có phiếu'
                                  : 'Không có phiếu phù hợp',
                              message: _detailQuery.isEmpty
                                  ? 'Chưa có đánh giá trong kỳ / bộ lọc hiện tại.'
                                  : 'Không tìm thấy "$_detailQuery". Thử tên, mã NV hoặc mã người bệnh khác.',
                              action:
                                  _detailQuery.isEmpty &&
                                      _resultFilter ==
                                          ComplianceResultFilter.all
                                  ? null
                                  : TextButton.icon(
                                      onPressed: () {
                                        _detailSearch.clear();
                                        _detailQuery = '';
                                        setState(
                                          () => _resultFilter =
                                              ComplianceResultFilter.all,
                                        );
                                        _load(detailsOnly: true);
                                      },
                                      icon: const Icon(
                                        Icons.filter_alt_off_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Xoá lọc'),
                                    ),
                            )
                          else ...[
                            for (final item in report.details)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _DetailCard(
                                  row: item,
                                  onTap: () => _openTicketDetail(item),
                                ),
                              ),
                            if (report.hasMoreDetails)
                              Center(
                                child: TextButton.icon(
                                  onPressed: _loadingMore
                                      ? null
                                      : () => _load(append: true),
                                  icon: _loadingMore
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    _loadingMore ? 'Đang tải…' : 'Xem thêm',
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút sắp xếp theo ngày đánh giá (server chỉ hỗ trợ ngày mới/cũ).
class _DateSortButton extends StatelessWidget {
  const _DateSortButton({required this.newestFirst, required this.onChanged});

  final bool newestFirst;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: 'Sắp xếp',
      initialValue: newestFirst,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      onSelected: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      itemBuilder: (_) => [
        for (final (v, label, icon) in [
          (true, 'Mới nhất', Icons.south_rounded),
          (false, 'Cũ nhất', Icons.north_rounded),
        ])
          PopupMenuItem(
            value: v,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: v == newestFirst
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: v == newestFirst
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: v == newestFirst
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (v == newestFirst)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              newestFirst ? 'Mới nhất' : 'Cũ nhất',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textSecondary;
    // Loại báo cáo là chế độ xem chính → ô chọn tô gradient brand đặc,
    // ô thường là thẻ trắng viền mảnh.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.brand : null,
          color: selected ? null : AppColors.surface,
          borderRadius: AppRadius.brPill,
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
          boxShadow: selected
              ? AppShadows.tinted(AppColors.primary)
              : AppShadows.soft,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brPill,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: AppTypography.style(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: AppTypography.uppercaseHeight,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiHero extends StatelessWidget {
  const _KpiHero({required this.report});
  final QtktComplianceReport report;

  static const _passTone = AppColors.onBrandRing;
  static const _failTone = Color(0xFFFCA5A5);

  @override
  Widget build(BuildContext context) {
    final rate = report.rateFraction.clamp(0.0, 1.0);
    final pct = rate * 100;
    // Ngưỡng trên nền teal đậm: bạc hà (≥80%) · vàng (≥50%) · hồng (thấp).
    final rateTone = pct >= 80
        ? _passTone
        : (pct >= 50 ? const Color(0xFFFCD34D) : _failTone);
    final verdict = pct >= 80
        ? 'Đạt mục tiêu'
        : (pct >= 50 ? 'Cần cải thiện' : 'Dưới mức yêu cầu');

    return DecoratedBox(
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
          ornamentIcon: Icons.health_and_safety_rounded,
          ornamentScale: 0.85,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _RateRing(
                          rate: rate,
                          label: report.rateLabel,
                          color: rateTone,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryLight,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.secondaryLight
                                              .withValues(alpha: 0.6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'TỈ LỆ TUÂN THỦ',
                                    style: AppTypography.uppercase(
                                      fontSize: 9.5,
                                      letterSpacing: 1.0,
                                      color: AppColors.secondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.reportTitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.35,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _GlassPill(
                                    icon: Icons.apartment_rounded,
                                    label: report.departmentName,
                                  ),
                                  _GlassPill(dot: rateTone, label: verdict),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Thanh chia Đạt / Chưa đạt trên tổng số lượt đánh giá.
                    Container(
                      height: 12,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.16),
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.brPill,
                        child: report.total <= 0
                            ? const SizedBox.expand()
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (report.passed > 0)
                                    Expanded(
                                      flex: report.passed,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _passTone,
                                          borderRadius: AppRadius.brPill,
                                        ),
                                      ),
                                    ),
                                  if (report.passed > 0 && report.failed > 0)
                                    const SizedBox(width: 2),
                                  if (report.failed > 0)
                                    Expanded(
                                      flex: report.failed,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _failTone.withValues(
                                            alpha: 0.85,
                                          ),
                                          borderRadius: AppRadius.brPill,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _GlassStat(
                            label: 'Tổng lượt',
                            value: report.total,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GlassStat(
                            label: 'Đạt',
                            value: report.passed,
                            color: _passTone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GlassStat(
                            label: 'Chưa đạt',
                            value: report.failed,
                            color: _failTone,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (report.formulaNote.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.functions_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report.formulaNote,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vòng tỷ lệ lớn — nhãn % (font hiển thị) nằm giữa vòng.
class _RateRing extends StatelessWidget {
  const _RateRing({
    required this.rate,
    required this.label,
    required this.color,
  });

  final double rate;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.14),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 22),
              ],
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: rate),
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                color: color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTypography.display(fontSize: 22, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label, this.icon, this.dot});

  final String label;
  final IconData? icon;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
          ] else if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: AppTypography.uppercaseHeight,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({
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
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 9),
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
                const SizedBox(width: 5),
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
              style: AppTypography.display(fontSize: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BucketKind { department, context, procedure }

class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.bucket, required this.onTap});
  final ComplianceBucket bucket;
  final VoidCallback onTap;

  /// Tên in hoa toàn bộ → viết hoa đầu chữ ("KHOA SẢN" → "Khoa Sản").
  static String _pretty(String raw) {
    final t = raw.trim();
    final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
    if (letters.isEmpty || letters != letters.toUpperCase()) return t;
    return t
        .toLowerCase()
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? w
              : '${w.characters.first.toUpperCase()}${w.substring(w.characters.first.length)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final hasData = bucket.total > 0;
    final pct = bucket.rateFraction * 100;
    // Ngưỡng giống thẻ KPI: ≥80 đạt · ≥50 cần cải thiện · dưới 50 chưa đạt.
    final (Color tone, String verdict, IconData icon) = !hasData
        ? (AppColors.textTertiary, 'Chưa có phiếu', Icons.remove_circle_outline)
        : pct >= 80
        ? (AppColors.success, 'Đạt mục tiêu', Icons.check_circle_rounded)
        : pct >= 50
        ? (AppColors.warning, 'Cần cải thiện', Icons.error_outline_rounded)
        : (AppColors.error, 'Dưới yêu cầu', Icons.cancel_outlined);
    final ink = Color.lerp(tone, AppColors.textPrimary, 0.25)!;
    final name = _pretty(bucket.departmentName);

    return AppCard(
      onTap: onTap,
      borderRadius: AppRadius.brLg,
      padding: EdgeInsets.zero,
      gradient: TintedCardBackdrop.gradient(
        hasData ? tone : AppColors.textSecondary,
      ),
      child: Semantics(
        label:
            '$name. ${hasData ? '${bucket.rateLabel}, $verdict' : verdict}. '
            '${bucket.passed} đạt, ${bucket.failed} chưa đạt, ${bucket.total} phiếu',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(icon, size: 13, color: tone),
                            const SizedBox(width: 4),
                            Text(
                              verdict,
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: AppTypography.uppercaseHeight,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hasData ? bucket.rateLabel : '—',
                    style: AppTypography.display(
                      fontSize: 22,
                      color: hasData ? ink : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TintedChevron(accent: tone),
                ],
              ),
              const SizedBox(height: 11),
              // Rãnh nhạt + vệt chuyển sắc theo ngưỡng; chưa có phiếu thì để trống.
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: AppRadius.brPill,
                ),
                alignment: Alignment.centerLeft,
                child: !hasData
                    ? null
                    : TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: bucket.rateFraction.clamp(0.0, 1.0),
                        ),
                        duration: AppDurations.slow,
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => FractionallySizedBox(
                          heightFactor: 1,
                          widthFactor: v <= 0 ? 0 : v.clamp(0.03, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.brPill,
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(tone, Colors.white, 0.3)!,
                                  tone,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CountTag(
                    icon: Icons.check_rounded,
                    label: '${bucket.passed} đạt',
                    color: AppColors.success,
                    muted: bucket.passed == 0,
                  ),
                  _CountTag(
                    icon: Icons.close_rounded,
                    label: '${bucket.failed} chưa đạt',
                    color: AppColors.error,
                    muted: bucket.failed == 0,
                  ),
                  _CountTag(
                    icon: Icons.description_outlined,
                    label: '${bucket.total} phiếu',
                    color: AppColors.primary,
                    muted: bucket.total == 0,
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

/// Nhãn đếm: icon + chữ trên nền pha nhạt; [muted] khi giá trị 0.
class _CountTag extends StatelessWidget {
  const _CountTag({
    required this.icon,
    required this.label,
    required this.color,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = muted ? AppColors.textTertiary : color;
    final ink = muted
        ? AppColors.textTertiary
        : Color.lerp(color, AppColors.textPrimary, 0.25)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: muted
            ? Colors.white.withValues(alpha: 0.7)
            : c.withValues(alpha: 0.08),
        borderRadius: AppRadius.brChip,
        border: Border.all(color: c.withValues(alpha: muted ? 0.14 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ink),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: AppTypography.uppercaseHeight,
              tabular: true,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.row,
    required this.onTap,
    this.hideDepartment = false,
  });
  final ComplianceDetailRow row;
  final VoidCallback onTap;
  final bool hideDepartment;

  @override
  Widget build(BuildContext context) {
    final pass = row.passed;
    final tone = pass ? AppColors.success : AppColors.error;
    final ink = Color.lerp(tone, AppColors.textPrimary, 0.25)!;
    final scoreParts = row.scoreLabel.split('/');
    final scoreMain = scoreParts.first.trim();
    final scoreMax = scoreParts.length > 1 ? scoreParts[1].trim() : null;
    final hasContext =
        row.checkContextLabel != null && row.checkContextLabel!.isNotEmpty;
    final hasPatient =
        row.patientCode != null && row.patientCode!.trim().isNotEmpty;
    final showDept = !hideDepartment && row.departmentName.isNotEmpty;

    return AppCard(
      onTap: onTap,
      borderRadius: AppRadius.brLg,
      padding: EdgeInsets.zero,
      gradient: TintedCardBackdrop.gradient(tone),
      child: Semantics(
        label:
            '${row.employeeName}. ${row.procedureName}. '
            '${pass ? 'Đạt' : 'Chưa đạt'}${row.scoreLabel.isEmpty ? '' : ', ${row.scoreLabel} điểm'}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _ResultAvatar(name: row.employeeName, tone: tone, pass: pass),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.employeeName,
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
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
                              decoration: BoxDecoration(
                                color: tone.withValues(alpha: 0.10),
                                borderRadius: AppRadius.brPill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    pass
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    size: 12,
                                    color: tone,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    pass ? 'Đạt' : 'Chưa đạt',
                                    style: AppTypography.style(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      height: AppTypography.uppercaseHeight,
                                      color: ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (row.employeeCode.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.tag_rounded,
                                size: 12,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  row.employeeCode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    tabular: true,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (scoreMain.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ĐIỂM',
                          style: AppTypography.uppercase(
                            fontSize: 8.5,
                            letterSpacing: 0.6,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            text: scoreMain,
                            style: AppTypography.display(
                              fontSize: 22,
                              color: ink,
                            ),
                            children: [
                              if (scoreMax != null)
                                TextSpan(
                                  text: ' /$scoreMax',
                                  style: AppTypography.style(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    tabular: true,
                                    color: AppColors.textTertiary,
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
              const SizedBox(height: 10),
              // Khối quy trình: kính trắng tách nội dung đánh giá khỏi người.
              Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: AppRadius.brBase,
                  border: Border.all(color: tone.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: AppRadius.brControl,
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.procedureName.isEmpty
                                ? 'Phiếu đánh giá'
                                : row.procedureName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (row.evalDateLabel.isNotEmpty || showDept) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (row.evalDateLabel.isNotEmpty)
                                  row.evalDateLabel,
                                if (showDept) row.departmentName,
                              ].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: AppTypography.uppercaseHeight,
                                tabular: true,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TintedChevron(accent: tone),
                  ],
                ),
              ),
              if (hasContext || hasPatient) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (hasContext)
                      _TicketMetaPill(
                        icon: Icons.touch_app_outlined,
                        label: row.checkContextLabel!,
                        color: AppColors.info,
                      ),
                    if (hasPatient)
                      _TicketMetaPill(
                        icon: Icons.badge_outlined,
                        label: 'NB ${row.patientCode}',
                        color: AppColors.secondary,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar chữ cái đầu với viền chuyển sắc theo kết quả + dấu ✓/✕.
class _ResultAvatar extends StatelessWidget {
  const _ResultAvatar({
    required this.name,
    required this.tone,
    required this.pass,
  });

  final String name;
  final Color tone;
  final bool pass;

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    final initial = t.isEmpty ? '?' : t.characters.first.toUpperCase();
    return SizedBox.square(
      dimension: 46,
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
                  tone.withValues(alpha: 0.6),
                  tone.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: Text(
                initial,
                style: AppTypography.display(
                  fontSize: 17,
                  color: Color.lerp(tone, AppColors.textPrimary, 0.2)!,
                ),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: tone,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Icon(
                pass ? Icons.check_rounded : Icons.close_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút sắp xếp danh sách phiếu — viên trắng nổi, mở menu 4 lựa chọn.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final _TicketSort value;
  final ValueChanged<_TicketSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TicketSort>(
      tooltip: 'Sắp xếp',
      initialValue: value,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      onSelected: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      itemBuilder: (_) => [
        for (final o in _TicketSort.values)
          PopupMenuItem(
            value: o,
            child: Row(
              children: [
                Icon(
                  o.icon,
                  size: 18,
                  color: o == value
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    o.label,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: o == value
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: o == value
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (o == value)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              value.label,
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketMetaPill extends StatelessWidget {
  const _TicketMetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: AppTypography.uppercaseHeight,
                color: Color.lerp(color, AppColors.textPrimary, 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _kQtktWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

DateTime? _parseComplianceDate(String raw) {
  final parts = raw.split('/');
  if (parts.length < 2) return null;
  final day = int.tryParse(parts[0].trim());
  final month = int.tryParse(parts[1].trim());
  final year = parts.length >= 3
      ? int.tryParse(parts[2].trim())
      : DateTime.now().year;
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

DateTime _qtktMondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _qtktDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

class _ComplianceTrendCard extends StatefulWidget {
  const _ComplianceTrendCard({required this.points});
  final List<ComplianceTrendPoint> points;

  @override
  State<_ComplianceTrendCard> createState() => _ComplianceTrendCardState();
}

class _ComplianceTrendCardState extends State<_ComplianceTrendCard> {
  late final PageController _pageController;
  late List<_ComplianceWeek> _weeks;
  late int _weekIndex;
  _ComplianceDayFocus? _focus;

  @override
  void initState() {
    super.initState();
    _weeks = _ComplianceWeek.fromPoints(widget.points);
    _weekIndex = _defaultWeekIndex(_weeks);
    _pageController = PageController(initialPage: _weekIndex);
  }

  @override
  void didUpdateWidget(covariant _ComplianceTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _weeks = _ComplianceWeek.fromPoints(widget.points);
      _weekIndex = _defaultWeekIndex(
        _weeks,
      ).clamp(0, math.max(0, _weeks.length - 1));
      _focus = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_weekIndex);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _defaultWeekIndex(List<_ComplianceWeek> weeks) {
    if (weeks.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < weeks.length; i++) {
      for (final d in weeks[i].days) {
        if (d.date != null &&
            d.date!.year == today.year &&
            d.date!.month == today.month &&
            d.date!.day == today.day) {
          return i;
        }
      }
    }
    return weeks.length - 1;
  }

  void _goTo(int index) {
    if (index < 0 || index >= _weeks.length || index == _weekIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _weekIndex = index;
      _focus = null;
    });
    _pageController.animateToPage(
      index,
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_weeks.isEmpty || _weeks.every((w) => w.spots.isEmpty)) {
      return const SizedBox.shrink();
    }
    final week = _weeks[_weekIndex.clamp(0, _weeks.length - 1)];
    final latest = week.spots.isEmpty ? null : week.spots.last.y;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                const TintedIconTile(
                  icon: Icons.show_chart_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tỉ lệ tuân thủ theo ngày',
                        style: AppTypography.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Đơn vị %, vuốt ngang để đổi tuần',
                        style: AppTypography.style(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (latest != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'MỚI NHẤT',
                        style: AppTypography.uppercase(
                          fontSize: 8.5,
                          letterSpacing: 0.6,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        '${latest.toStringAsFixed(1)}%',
                        style: AppTypography.display(
                          fontSize: 20,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDDE8E6), Color(0xFFE9F1F0)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Color(0xCCFFFFFF), offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AppNavArrow(
                        icon: Icons.chevron_left_rounded,
                        semanticsLabel: 'Tuần trước',
                        onTap: () => _goTo(_weekIndex - 1),
                        enabled: _weekIndex > 0,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              week.isCurrentWeek ? 'Tuần này' : week.title,
                              style: AppTypography.style(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              week.rangeLabel,
                              style: AppTypography.style(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppNavArrow(
                        icon: Icons.chevron_right_rounded,
                        semanticsLabel: 'Tuần sau',
                        onTap: () => _goTo(_weekIndex + 1),
                        enabled: _weekIndex < _weeks.length - 1,
                      ),
                    ],
                  ),
                  if (_weeks.length > 1) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _weeks.length; i++) ...[
                          if (i > 0) const SizedBox(width: 5),
                          AnimatedContainer(
                            duration: AppDurations.fast,
                            width: i == _weekIndex ? 14 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _weekIndex
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: AppRadius.brPill,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _weeks.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() {
                  _weekIndex = i;
                  _focus = null;
                });
              },
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 12, 2),
                child: _ComplianceWeekChart(
                  week: _weeks[index],
                  weekIndex: index,
                  focus: _focus?.weekIndex == index ? _focus : null,
                  onPress: (wi, di, day) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _focus = _ComplianceDayFocus(
                        weekIndex: wi,
                        dayIndex: di,
                        day: day,
                      );
                    });
                  },
                  onClear: () {
                    if (_focus == null) return;
                    setState(() => _focus = null);
                  },
                ),
              ),
            ),
          ),
          // Chú thích (luôn hiện) + khung chi tiết ngày đang chạm.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Chạm hoặc kéo trên biểu đồ để xem từng ngày',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const _TargetLegend(),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _focus == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: _FocusDetail(day: _focus!.day),
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Chú thích đường mục tiêu: đoạn nét đứt + nhãn.
class _TargetLegend extends StatelessWidget {
  const _TargetLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Container(width: 4, height: 1.5, color: AppColors.textTertiary),
            ],
          ],
        ),
        const SizedBox(width: 5),
        Text(
          'Mục tiêu 80%',
          style: AppTypography.style(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Chi tiết ngày đang chạm: thứ · ngày, giá trị lớn và chênh lệch so với
/// mục tiêu 80% (kèm icon + chữ, không chỉ dựa vào màu).
class _FocusDetail extends StatelessWidget {
  const _FocusDetail({required this.day});

  final _ComplianceDay day;

  static const double _target = 80;

  @override
  Widget build(BuildContext context) {
    final rate = day.rate;
    final delta = rate == null ? null : rate - _target;
    final ok = delta != null && delta >= 0;
    final tone = delta == null
        ? AppColors.textSecondary
        : (ok ? AppColors.success : AppColors.warning);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: TintedCardBackdrop.gradient(AppColors.primary),
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: AppRadius.brBase,
              boxShadow: AppShadows.tinted(AppColors.primary),
            ),
            child: Text(
              day.weekdayLabel,
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: AppTypography.uppercaseHeight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.label,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: AppTypography.uppercaseHeight,
                    tabular: true,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (delta != null)
                  Row(
                    children: [
                      Icon(
                        ok
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: tone,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          ok
                              ? 'Cao hơn mục tiêu ${delta.toStringAsFixed(1)} điểm'
                              : 'Thấp hơn mục tiêu ${(-delta).toStringAsFixed(1)} điểm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: AppTypography.uppercaseHeight,
                            color: Color.lerp(tone, AppColors.textPrimary, 0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            rate == null ? '—' : '${rate.toStringAsFixed(1)}%',
            style: AppTypography.display(
              fontSize: 22,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplianceDay {
  const _ComplianceDay({
    required this.label,
    required this.date,
    required this.rate,
    required this.weekdayLabel,
  });

  final String label;
  final DateTime? date;
  final double? rate;
  final String weekdayLabel;

  bool get hasValue => rate != null;
}

class _ComplianceDayFocus {
  const _ComplianceDayFocus({
    required this.weekIndex,
    required this.dayIndex,
    required this.day,
  });

  final int weekIndex;
  final int dayIndex;
  final _ComplianceDay day;
}

class _ComplianceWeek {
  const _ComplianceWeek({
    required this.days,
    required this.spots,
    required this.isCurrentWeek,
  });

  final List<_ComplianceDay> days;
  final List<FlSpot> spots;
  final bool isCurrentWeek;

  String get title {
    final first = days.first.date;
    if (first == null) return 'Tuần';
    return 'Tuần ${((first.day - 1) ~/ 7) + 1}';
  }

  String get rangeLabel {
    final mon = days.first.date;
    final sun = days.last.date;
    if (mon != null && sun != null) {
      return '${_qtktDayMonth(mon)} – ${_qtktDayMonth(sun)}';
    }
    return '';
  }

  static List<_ComplianceWeek> fromPoints(List<ComplianceTrendPoint> points) {
    if (points.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = <DateTime, ComplianceTrendPoint>{};
    DateTime? first;
    DateTime? last;

    for (final p in points) {
      final date = _parseComplianceDate(p.label);
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      byDate[key] = p;
      if (first == null || key.isBefore(first)) first = key;
      if (last == null || key.isAfter(last)) last = key;
    }

    if (first == null || last == null) {
      // Fallback: chunk by 7 in order.
      final weeks = <_ComplianceWeek>[];
      for (var start = 0; start < points.length; start += 7) {
        final end = math.min(start + 7, points.length);
        final slice = points.sublist(start, end);
        final days = <_ComplianceDay>[];
        final spots = <FlSpot>[];
        for (var i = 0; i < 7; i++) {
          final p = i < slice.length ? slice[i] : null;
          final rate = (p != null && p.hasData) ? p.rate : null;
          days.add(
            _ComplianceDay(
              label: p?.label ?? _kQtktWeekdays[i],
              date: p == null ? null : _parseComplianceDate(p.label),
              rate: rate,
              weekdayLabel: _kQtktWeekdays[i],
            ),
          );
          if (rate != null) spots.add(FlSpot(i.toDouble(), rate));
        }
        weeks.add(
          _ComplianceWeek(days: days, spots: spots, isCurrentWeek: false),
        );
      }
      return weeks;
    }

    final weeks = <_ComplianceWeek>[];
    var monday = _qtktMondayOf(first);
    final endMonday = _qtktMondayOf(last);
    while (!monday.isAfter(endMonday)) {
      final days = <_ComplianceDay>[];
      final spots = <FlSpot>[];
      var containsToday = false;
      for (var i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final p = byDate[date];
        final rate = (p != null && p.hasData) ? p.rate : null;
        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          containsToday = true;
        }
        days.add(
          _ComplianceDay(
            label: p?.label ?? '${_qtktDayMonth(date)}/${date.year}',
            date: date,
            rate: rate,
            weekdayLabel: _kQtktWeekdays[i],
          ),
        );
        if (rate != null) spots.add(FlSpot(i.toDouble(), rate));
      }
      weeks.add(
        _ComplianceWeek(days: days, spots: spots, isCurrentWeek: containsToday),
      );
      monday = monday.add(const Duration(days: 7));
    }
    return weeks;
  }
}

class _ComplianceWeekChart extends StatelessWidget {
  const _ComplianceWeekChart({
    required this.week,
    required this.weekIndex,
    required this.focus,
    required this.onPress,
    required this.onClear,
  });

  final _ComplianceWeek week;
  final int weekIndex;
  final _ComplianceDayFocus? focus;
  final void Function(int weekIndex, int dayIndex, _ComplianceDay day) onPress;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final spots = week.spots;
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'Tuần này chưa có số liệu',
          style: AppTypography.style(
            fontSize: 12.5,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Tỉ lệ % không vượt 100 → cố định trục 0–100. Bản cũ cộng thêm 5% đầu
    // trục làm thư viện in thêm nhãn "105%" chồng lên "100%".
    final maxValue = spots.map((s) => s.y).reduce(math.max);
    final maxY = maxValue > 100 ? (maxValue / 50).ceil() * 50.0 : 100.0;
    final focusedDay = focus?.dayIndex;

    final bar = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.28,
      preventCurveOverShooting: true,
      color: AppColors.primary,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          final selected = focusedDay == spot.x.round();
          // Đĩa đặc + vòng surface 2px để điểm tách khỏi đường/lưới.
          return FlDotCirclePainter(
            radius: selected ? 6.5 : 4.5,
            color: AppColors.primary,
            strokeWidth: selected ? 3 : 2,
            strokeColor: AppColors.surface,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: -0.45,
        maxX: 6.45,
        clipData: const FlClipData.none(),
        // Lưới chìm: chỉ đường ngang mảnh, không đường dọc chia cắt dữ liệu.
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: value == 0
                ? AppColors.border
                : AppColors.textPrimary.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 50,
              getTitlesWidget: (value, meta) {
                // Chỉ in mốc chẵn 50 — bỏ nhãn min/max thư viện tự chèn.
                if (value % 50 != 0 || value > maxY) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    '${value.toInt()}%',
                    style: AppTypography.metricMuted(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 0.01 ||
                    index < 0 ||
                    index >= _kQtktWeekdays.length) {
                  return const SizedBox.shrink();
                }
                final selected = focusedDay == index;
                final hasData =
                    index < week.days.length && week.days[index].hasValue;
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    _kQtktWeekdays[index],
                    style: AppTypography.style(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      color: selected
                          ? AppColors.primary
                          : hasData
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // Ngưỡng "Đạt mục tiêu" — cùng mốc 80% với thẻ KPI phía trên.
            HorizontalLine(
              y: 80,
              color: AppColors.textTertiary.withValues(alpha: 0.7),
              strokeWidth: 1,
              dashArray: [4, 4],
              // Nhãn nằm ở chú thích dưới biểu đồ — trong vùng vẽ dễ đè điểm.
            ),
          ],
          verticalLines: [
            if (focusedDay != null)
              VerticalLine(
                x: focusedDay.toDouble(),
                color: AppColors.primary.withValues(alpha: 0.08),
                strokeWidth: 30,
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchSpotThreshold: 32,
          // Không hiện bong bóng — chi tiết ngày đã có ở khung bên dưới.
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 0,
            getTooltipItems: (touched) =>
                List<LineTooltipItem?>.filled(touched.length, null),
          ),
          touchCallback: (event, response) {
            final spot = response?.lineBarSpots?.firstOrNull;
            final pressing =
                event is FlTapDownEvent ||
                event is FlPanStartEvent ||
                event is FlPanUpdateEvent ||
                event is FlLongPressStart ||
                event is FlLongPressMoveUpdate;
            final released =
                event is FlTapUpEvent ||
                event is FlTapCancelEvent ||
                event is FlPanEndEvent ||
                event is FlLongPressEnd;
            if (pressing && spot != null) {
              final dayIndex = spot.x.round().clamp(0, week.days.length - 1);
              final day = week.days[dayIndex];
              if (!day.hasValue) return;
              onPress(weekIndex, dayIndex, day);
              return;
            }
            if (released) onClear();
          },
        ),
        lineBarsData: [bar],
      ),
      duration: AppDurations.fast,
    );
  }
}

// ───────────────────────────── Drill-down phiếu ───────────────────────────────

class _TicketListSheet extends ConsumerStatefulWidget {
  const _TicketListSheet({
    required this.title,
    required this.subtitle,
    required this.rateLabel,
    required this.passed,
    required this.failed,
    required this.total,
    required this.kind,
    required this.yearMonth,
    required this.onOpenTicket,
    this.departmentId,
    this.procedureCode,
    this.checkContextCode,
    this.checkContextLabel,
  });

  final String title;
  final String subtitle;
  final String rateLabel;
  final int passed;
  final int failed;
  final int total;
  final QtktComplianceKind kind;
  final String yearMonth;
  final int? departmentId;
  final String? procedureCode;
  final String? checkContextCode;
  final String? checkContextLabel;
  final ValueChanged<ComplianceDetailRow> onOpenTicket;

  @override
  ConsumerState<_TicketListSheet> createState() => _TicketListSheetState();
}

enum _TicketSort { newest, oldest, scoreHigh, scoreLow }

extension on _TicketSort {
  String get label => switch (this) {
    _TicketSort.newest => 'Mới nhất',
    _TicketSort.oldest => 'Cũ nhất',
    _TicketSort.scoreHigh => 'Điểm cao',
    _TicketSort.scoreLow => 'Điểm thấp',
  };

  IconData get icon => switch (this) {
    _TicketSort.newest => Icons.south_rounded,
    _TicketSort.oldest => Icons.north_rounded,
    _TicketSort.scoreHigh => Icons.trending_up_rounded,
    _TicketSort.scoreLow => Icons.trending_down_rounded,
  };
}

class _TicketListSheetState extends ConsumerState<_TicketListSheet> {
  bool _loading = true;
  String? _error;
  List<ComplianceDetailRow> _rows = const [];
  final _searchController = TextEditingController();
  String _query = '';

  /// 0 = tất cả · 1 = đạt · 2 = chưa đạt.
  int _result = 0;
  _TicketSort _sort = _TicketSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static double? _score(ComplianceDetailRow r) {
    final v = r.raw['totalScore'];
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  /// Danh sách sau khi tìm (không dấu: tên, mã NV, quy trình, mã NB) + lọc + sắp.
  List<ComplianceDetailRow> get _visible {
    final q = foldVi(_query);
    final list = [
      for (final r in _rows)
        if ((_result == 0 || (_result == 1) == r.passed) &&
            (q.isEmpty ||
                foldVi(
                  '${r.employeeName} ${r.employeeCode} ${r.procedureName} '
                  '${r.patientCode ?? ''} ${r.checkContextLabel ?? ''}',
                ).contains(q)))
          r,
    ];
    int byDate(ComplianceDetailRow a, ComplianceDetailRow b) {
      final da = _parseComplianceDate(a.evalDateLabel);
      final db = _parseComplianceDate(b.evalDateLabel);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    int byScore(ComplianceDetailRow a, ComplianceDetailRow b) =>
        (_score(a) ?? -1).compareTo(_score(b) ?? -1);

    switch (_sort) {
      case _TicketSort.newest:
        list.sort((a, b) => byDate(b, a));
      case _TicketSort.oldest:
        list.sort(byDate);
      case _TicketSort.scoreHigh:
        list.sort((a, b) => byScore(b, a));
      case _TicketSort.scoreLow:
        list.sort(byScore);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(qtktComplianceRepositoryProvider)
          .fetchDetailRows(
            widget.kind,
            yearMonth: widget.yearMonth,
            departmentId: widget.departmentId,
            procedureCode: widget.procedureCode,
            checkContextCode: widget.checkContextCode,
            checkContextLabel: widget.checkContextLabel,
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
        _error = 'Không tải được danh sách phiếu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final visible = _visible;
    final rate = widget.total <= 0
        ? 0.0
        : (widget.passed / widget.total).clamp(0.0, 1.0);
    // Sắc vòng trên nền teal đậm — cùng ngưỡng với thẻ KPI chính.
    final ringTone = widget.total <= 0
        ? Colors.white.withValues(alpha: 0.5)
        : rate >= 0.8
        ? _KpiHero._passTone
        : rate >= 0.5
        ? const Color(0xFFFCD34D)
        : _KpiHero._failTone;
    final verdict = rate >= 0.8
        ? 'Đạt mục tiêu 80%'
        : rate >= 0.5
        ? 'Cần cải thiện'
        : 'Dưới mức yêu cầu';

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: AppRadius.brPill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.brXl,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
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
                  ornamentScale: 0.75,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _GlassPill(
                                  icon: Icons.folder_open_rounded,
                                  label: widget.subtitle,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _BucketCard._pretty(widget.title),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      AppTypography.style(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        height: AppTypography.uppercaseHeight,
                                        color: Colors.white,
                                      ).copyWith(
                                        shadows: [
                                          Shadow(
                                            color: AppColors.primaryDark
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: ringTone,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.total <= 0
                                          ? 'Chưa có phiếu'
                                          : verdict,
                                      style: AppTypography.style(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        height: AppTypography.uppercaseHeight,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _RateRing(
                            rate: rate,
                            label: widget.total <= 0 ? '—' : widget.rateLabel,
                            color: ringTone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _GlassStat(
                              label: 'Đạt',
                              value: widget.passed,
                              color: _KpiHero._passTone,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GlassStat(
                              label: 'Chưa đạt',
                              value: widget.failed,
                              color: _KpiHero._failTone,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GlassStat(
                              label: 'Tổng phiếu',
                              value: widget.total,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!_loading && _error == null && _rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.brMd,
                            boxShadow: AppShadows.soft,
                          ),
                          child: AppSearchField(
                            controller: _searchController,
                            hintText: 'Tìm tên, mã NV, quy trình, mã NB…',
                            dense: true,
                            borderRadius: AppRadius.brMd,
                            onChanged: (v) => setState(() => _query = v.trim()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SortButton(
                        value: _sort,
                        onChanged: (v) => setState(() => _sort = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppSegmentedControl(
                    style: AppSegmentStyle.soft,
                    dense: true,
                    selectedIndex: _result,
                    onChanged: (i) => setState(() => _result = i),
                    items: [
                      AppSegmentItem(label: 'Tất cả', count: _rows.length),
                      AppSegmentItem(
                        label: 'Đạt',
                        icon: Icons.check_circle_rounded,
                        count: _rows.where((r) => r.passed).length,
                      ),
                      AppSegmentItem(
                        label: 'Chưa đạt',
                        icon: Icons.cancel_rounded,
                        count: _rows.where((r) => !r.passed).length,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Row(
              children: [
                Text(
                  'DANH SÁCH PHIẾU',
                  style: AppTypography.uppercase(
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (!_loading && _error == null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      visible.length == _rows.length
                          ? '${_rows.length} phiếu'
                          : '${visible.length}/${_rows.length} phiếu',
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        tabular: true,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Không tải được',
                    message: _error!,
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  )
                : _rows.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Chưa có phiếu',
                    message: 'Không có đánh giá trong phạm vi này.',
                  )
                : visible.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Không có phiếu phù hợp',
                    message: 'Thử đổi từ khoá hoặc bộ lọc kết quả.',
                    action: TextButton.icon(
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                        _result = 0;
                      }),
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: const Text('Xoá lọc'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final row = visible[i];
                      return _DetailCard(
                        row: row,
                        hideDepartment: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onOpenTicket(row);
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TicketDetailSheet extends ConsumerStatefulWidget {
  const _TicketDetailSheet({required this.evaluationId, required this.preview});

  final int evaluationId;
  final ComplianceDetailRow preview;

  @override
  ConsumerState<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends ConsumerState<_TicketDetailSheet> {
  bool _loading = true;
  String? _error;
  QtktEvaluation? _eval;
  QtktProcedure? _procedure;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(qtktRepositoryProvider);
      final eval = await repo.getById(widget.evaluationId);
      QtktProcedure? procedure;
      try {
        final template = await repo.template();
        for (final p in template.procedures) {
          if (p.code == eval.procedureCode) {
            procedure = p;
            break;
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _eval = eval;
        _procedure = procedure;
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
        _error = 'Không tải được chi tiết phiếu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final eval = _eval;
    final isPass = preview.passed;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSoft,
              borderRadius: AppRadius.brPill,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Không tải được',
                    message: _error!,
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      _TicketHeroHeader(
                        name: preview.employeeName,
                        code: preview.employeeCode,
                        passed: isPass,
                        total: eval!.totalScore,
                        max: eval.maxScore,
                        procedureName: eval.procedureName,
                        dateLabel: preview.evalDateLabel.isNotEmpty
                            ? preview.evalDateLabel
                            : eval.evalDate,
                      ),
                      const SizedBox(height: 12),
                      _TicketMetaChips(eval: eval, preview: preview),
                      if (_procedure != null) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CHI TIẾT CHẤM ĐIỂM',
                              style: AppTypography.uppercase(
                                fontSize: 10.5,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final section in _procedure!.sections)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ScoreSectionCard(
                              section: section,
                              scores: eval.scores,
                            ),
                          ),
                      ] else if (eval.scores.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        for (final entry in eval.scores.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RawScoreRow(
                              label: entry.key,
                              value: entry.value,
                            ),
                          ),
                      ],
                      if (eval.note != null &&
                          eval.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _NoteCard(note: eval.note!.trim()),
                        const SizedBox(height: 12),
                      ] else
                        const SizedBox(height: 12),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TicketHeroHeader extends StatelessWidget {
  const _TicketHeroHeader({
    required this.name,
    required this.code,
    required this.passed,
    required this.total,
    required this.max,
    required this.procedureName,
    required this.dateLabel,
  });

  final String name;
  final String code;
  final bool passed;
  final double total;
  final double max;
  final String procedureName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (total / max).clamp(0.0, 1.0);
    final tone = passed ? _KpiHero._passTone : _KpiHero._failTone;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
          ornamentScale: 0.75,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  initial,
                                  style: AppTypography.display(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.style(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.35,
                                        height: AppTypography.uppercaseHeight,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (code.isNotEmpty)
                                      Text(
                                        '# $code',
                                        style: AppTypography.style(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          tabular: true,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _GlassPill(
                            dot: tone,
                            label: passed ? 'Đạt yêu cầu' : 'Chưa đạt yêu cầu',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Vòng điểm: tổng điểm ở giữa, thang tối đa bên dưới.
                    SizedBox.square(
                      dimension: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _RateRing(rate: ratio, label: '', color: tone),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppFormat.score(total),
                                style: AppTypography.display(
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '/ ${AppFormat.score(max)} điểm',
                                style: AppTypography.style(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (procedureName.isNotEmpty || dateLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: AppRadius.brControl,
                        ),
                        child: const Icon(
                          Icons.medical_services_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (procedureName.isNotEmpty)
                              Text(
                                procedureName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                  color: Colors.white,
                                ),
                              ),
                            if (dateLabel.isNotEmpty)
                              Text(
                                dateLabel,
                                style: AppTypography.style(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  tabular: true,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketMetaChips extends StatelessWidget {
  const _TicketMetaChips({required this.eval, required this.preview});

  final QtktEvaluation eval;
  final ComplianceDetailRow preview;

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String, Color)>[
      (
        Icons.apartment_rounded,
        _BucketCard._pretty(eval.departmentName),
        AppColors.primary,
      ),
      if (eval.checkContextLabel != null &&
          eval.checkContextLabel!.trim().isNotEmpty)
        (Icons.touch_app_outlined, eval.checkContextLabel!, AppColors.info),
      if (eval.patientCode != null && eval.patientCode!.trim().isNotEmpty)
        (Icons.badge_outlined, 'NB ${eval.patientCode}', AppColors.secondary),
      (Icons.flag_rounded, eval.status.label, AppColors.success),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: chip.$3.withValues(alpha: 0.2)),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: chip.$3.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    chip.$1,
                    size: 13,
                    color: Color.lerp(chip.$3, AppColors.textPrimary, 0.2),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    chip.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: AppTypography.uppercaseHeight,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RawScoreRow extends StatelessWidget {
  const _RawScoreRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: AppTypography.metric(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 18,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghi chú',
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warningDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  note,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepScoreTone { full, partial, zero }

_StepScoreTone _stepTone(double scored, double max) {
  if (max <= 0) return _StepScoreTone.full;
  if (scored >= max - 0.001) return _StepScoreTone.full;
  if (scored <= 0.001) return _StepScoreTone.zero;
  return _StepScoreTone.partial;
}

bool _shouldShowStepDetail(String title, String? detail) {
  if (detail == null) return false;
  final d = detail.trim();
  if (d.isEmpty) return false;
  final t = title.trim().toLowerCase();
  final dl = d.toLowerCase();
  if (t == dl) return false;
  if (t.contains(dl) || dl.contains(t)) return false;
  return true;
}

class _ScoreSectionCard extends StatelessWidget {
  const _ScoreSectionCard({required this.section, required this.scores});

  final QtktSection section;
  final Map<String, double> scores;

  @override
  Widget build(BuildContext context) {
    var earned = 0.0;
    var max = 0.0;
    for (final step in section.steps) {
      earned += scores[step.id] ?? 0;
      max += step.maxPoints;
    }
    final sectionColor = switch (_stepTone(earned, max)) {
      _StepScoreTone.full => AppColors.success,
      _StepScoreTone.partial => AppColors.warning,
      _StepScoreTone.zero => AppColors.error,
    };
    final ink = Color.lerp(sectionColor, AppColors.textPrimary, 0.25)!;
    final ratio = max <= 0 ? 0.0 : (earned / max).clamp(0.0, 1.0);

    // Không dùng clipBehavior trên container có border + radius:
    // Clip.antiAlias cắt mất góc viền (nhìn như “mất 1 khúc”).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Đầu phần: nền pha theo kết quả + thanh tỉ lệ của phần.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: TintedCardBackdrop.gradient(sectionColor),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.title,
                        style: AppTypography.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        text: AppFormat.score(earned),
                        style: AppTypography.display(fontSize: 16, color: ink),
                        children: [
                          TextSpan(
                            text: ' / ${AppFormat.score(max)}',
                            style: AppTypography.style(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              tabular: true,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: sectionColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brPill,
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    heightFactor: 1,
                    widthFactor: ratio <= 0 ? 0 : ratio.clamp(0.03, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.brPill,
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(sectionColor, Colors.white, 0.3)!,
                            sectionColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (section.steps.isNotEmpty)
            const Divider(height: 1, thickness: 1, color: AppColors.borderSoft),
          for (final (index, step) in section.steps.indexed) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 49,
                endIndent: 12,
                color: AppColors.divider,
              ),
            _ScoreStepRow(step: step, scored: scores[step.id] ?? 0),
          ],
          if (section.steps.isNotEmpty) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Một bước chấm: số thứ tự, nội dung (mô tả dài thu gọn 2 dòng) và cột điểm
/// gọn bên phải. Bước bị trừ điểm có vạch màu mảnh ở mép trái.
class _ScoreStepRow extends StatefulWidget {
  const _ScoreStepRow({required this.step, required this.scored});

  final QtktStep step;
  final double scored;

  @override
  State<_ScoreStepRow> createState() => _ScoreStepRowState();
}

class _ScoreStepRowState extends State<_ScoreStepRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final scored = widget.scored;
    final tone = _stepTone(scored, step.maxPoints);
    final color = switch (tone) {
      _StepScoreTone.full => AppColors.success,
      _StepScoreTone.partial => AppColors.warning,
      _StepScoreTone.zero => AppColors.error,
    };
    final icon = switch (tone) {
      _StepScoreTone.full => Icons.check_rounded,
      _StepScoreTone.partial => Icons.remove_rounded,
      _StepScoreTone.zero => Icons.close_rounded,
    };
    final ink = Color.lerp(color, AppColors.textPrimary, 0.25)!;
    final showDetail = _shouldShowStepDetail(step.title, step.detail);
    final detail = step.detail?.trim() ?? '';
    final longDetail = detail.length > 90 || '\n'.allMatches(detail).length > 1;
    final flagged = tone != _StepScoreTone.full;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vạch nhấn mép trái cho bước bị trừ điểm (thay nền loang màu).
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: flagged ? color : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(3),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(top: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: AppRadius.brControl,
                    ),
                    child: Text(
                      '${step.no}',
                      style: AppTypography.display(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: AppTypography.style(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            letterSpacing: -0.1,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (showDetail) ...[
                          const SizedBox(height: 4),
                          AnimatedSize(
                            duration: AppDurations.fast,
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: Text(
                              detail,
                              maxLines: _expanded || !longDetail ? null : 2,
                              overflow: _expanded || !longDetail
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (longDetail)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  setState(() => _expanded = !_expanded),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _expanded ? 'Thu gọn' : 'Xem thêm',
                                      style: AppTypography.style(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    AnimatedRotation(
                                      turns: _expanded ? 0.5 : 0,
                                      duration: AppDurations.fast,
                                      child: const Icon(
                                        Icons.expand_more_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Cột điểm gọn: dấu kết quả trên, điểm/tối đa dưới.
                  SizedBox(
                    width: 46,
                    child: Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(icon, size: 14, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppFormat.score(scored),
                          style: AppTypography.display(
                            fontSize: 14,
                            color: ink,
                          ),
                        ),
                        Text(
                          '/ ${AppFormat.score(step.maxPoints)}',
                          style: AppTypography.style(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            tabular: true,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
