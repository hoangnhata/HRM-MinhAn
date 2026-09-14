import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_month_picker.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/list_section_title.dart';
import '../../auth/application/auth_controller.dart';
import '../data/qtkt_models.dart';
import '../data/qtkt_repository.dart';
import 'qtkt_evaluation_form_screen.dart';

enum _QtktTab { evaluations, summary }

class QtktEvaluationsScreen extends ConsumerStatefulWidget {
  const QtktEvaluationsScreen({super.key});

  @override
  ConsumerState<QtktEvaluationsScreen> createState() =>
      _QtktEvaluationsScreenState();
}

class _QtktEvaluationsScreenState extends ConsumerState<QtktEvaluationsScreen> {
  late final TextEditingController _searchController;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _QtktTab _tab = _QtktTab.evaluations;
  QtktTemplate? _template;
  List<QtktEmployee> _employees = const [];
  List<QtktDepartment> _departments = const [];
  List<QtktEvaluation> _evaluations = const [];
  QtktSummary? _summary;
  QtktEvaluationStatus? _statusFilter;
  int? _departmentFilter;
  String? _procedureFilter;
  bool _loading = true;
  String? _error;

  String get _yearMonth =>
      '${_month.year.toString().padLeft(4, '0')}-'
      '${_month.month.toString().padLeft(2, '0')}';

  String get _from => '$_yearMonth-01';

  String get _to {
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    return '$_yearMonth-${last.toString().padLeft(2, '0')}';
  }

  bool get _canScore =>
      RoleGroups.canScoreQtkt(ref.read(authControllerProvider).role);

  int get _activeFilterCount =>
      (_statusFilter == null ? 0 : 1) +
      (_departmentFilter == null ? 0 : 1) +
      (_procedureFilter == null ? 0 : 1);

  List<QtktEvaluation> get _submittedEvaluations => _evaluations
      .where((item) => item.status == QtktEvaluationStatus.submitted)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()..addListener(_onSearchChanged);
    final role = ref.read(authControllerProvider).role;
    if (role == UserRole.headNursing) {
      _statusFilter = QtktEvaluationStatus.submitted;
    }
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final role = ref.read(authControllerProvider).role;
    if (!RoleGroups.canEnterQtkt(role)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(qtktRepositoryProvider);
      final values = await Future.wait<dynamic>([
        repo.template(),
        repo.employees(),
        repo.departments(),
        repo.evaluations(from: _from, to: _to),
        repo.summary(_yearMonth),
      ]);
      if (!mounted) return;
      setState(() {
        _template = values[0] as QtktTemplate;
        _employees = values[1] as List<QtktEmployee>;
        _departments = values[2] as List<QtktDepartment>;
        _evaluations = values[3] as List<QtktEvaluation>;
        _summary = values[4] as QtktSummary;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được dữ liệu QTKT');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<QtktEvaluation> get _filteredEvaluations {
    final query = _searchController.text.trim().toLowerCase();
    final rows = _evaluations.where((evaluation) {
      if (_statusFilter != null && evaluation.status != _statusFilter) {
        return false;
      }
      if (_departmentFilter != null &&
          evaluation.departmentId != _departmentFilter) {
        return false;
      }
      if ((_procedureFilter ?? '').isNotEmpty &&
          evaluation.procedureCode != _procedureFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        evaluation.employeeName,
        evaluation.employeeCode ?? '',
        evaluation.departmentName,
        evaluation.procedureName,
        evaluation.createdByName ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    rows.sort((a, b) {
      final dateCompare = b.evalDate.compareTo(a.evalDate);
      if (dateCompare != 0) return dateCompare;
      return a.employeeName.compareTo(b.employeeName);
    });
    return rows;
  }

  Future<void> _pickMonth() async {
    final picked = await showAppMonthPicker(
      context,
      year: _month.year,
      month: _month.month,
      title: 'Chọn tháng đánh giá',
    );
    if (picked == null || !mounted) return;
    if (picked.$1 == _month.year && picked.$2 == _month.month) return;
    setState(() {
      _month = DateTime(picked.$1, picked.$2);
      _departmentFilter = null;
      _procedureFilter = null;
    });
    await _load();
  }

  Future<void> _pickStatus() async {
    final selected = await showAppOptionPicker(
      context,
      title: 'Lọc theo trạng thái',
      options: const [
        AppOptionItem(
          value: 'ALL',
          label: 'Tất cả trạng thái',
          icon: Icons.all_inclusive_rounded,
        ),
        AppOptionItem(
          value: 'DRAFT',
          label: 'Phiếu nháp',
          icon: Icons.inventory_2_outlined,
        ),
        AppOptionItem(
          value: 'SUBMITTED',
          label: 'Đã gửi',
          icon: Icons.task_alt_rounded,
        ),
        AppOptionItem(
          value: 'CANCELLED',
          label: 'Đã hủy',
          icon: Icons.cancel_outlined,
        ),
      ],
      selectedValue: _statusFilter?.apiValue ?? 'ALL',
    );
    if (selected == null) return;
    setState(() {
      _statusFilter = selected == 'ALL'
          ? null
          : QtktEvaluationStatusX.fromApi(selected);
    });
  }

  Future<void> _pickDepartment() async {
    final selected = await showAppOptionPicker(
      context,
      title: 'Lọc theo khoa/phòng',
      options: [
        const AppOptionItem(
          value: 'ALL',
          label: 'Tất cả khoa/phòng',
          icon: Icons.apartment_rounded,
        ),
        for (final department in _departments)
          AppOptionItem(
            value: '${department.id}',
            label: department.name,
            subtitle: department.code,
            icon: Icons.local_hospital_outlined,
          ),
      ],
      selectedValue: _departmentFilter?.toString() ?? 'ALL',
    );
    if (selected == null) return;
    setState(
      () =>
          _departmentFilter = selected == 'ALL' ? null : int.tryParse(selected),
    );
  }

  Future<void> _pickProcedure() async {
    final procedures = _template?.procedures ?? const <QtktProcedure>[];
    final selected = await showAppOptionPicker(
      context,
      title: 'Lọc theo quy trình',
      options: [
        const AppOptionItem(
          value: 'ALL',
          label: 'Tất cả quy trình',
          icon: Icons.biotech_outlined,
        ),
        for (final procedure in procedures)
          AppOptionItem(
            value: procedure.code,
            label: procedure.name,
            subtitle: '${procedure.stepCount} bước',
            icon: Icons.fact_check_outlined,
          ),
      ],
      selectedValue: _procedureFilter ?? 'ALL',
    );
    if (selected == null) return;
    setState(() => _procedureFilter = selected == 'ALL' ? null : selected);
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _statusFilter = null;
      _departmentFilter = null;
      _procedureFilter = null;
    });
  }

  Future<void> _openNew() async {
    final template = _template;
    if (template == null || _employees.isEmpty) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QtktEvaluationFormScreen(
          template: template,
          employees: _employees,
          monthEvaluations: _evaluations,
          canEdit: true,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openEvaluation(QtktEvaluation evaluation) async {
    final template = _template;
    if (template == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QtktEvaluationFormScreen(
          template: template,
          employees: _employees,
          monthEvaluations: _evaluations,
          existing: evaluation,
          canEdit: evaluation.canEdit,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _setTab(_QtktTab tab) async {
    if (_tab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).role;
    if (!RoleGroups.canEnterQtkt(role)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppAmbientBackground(intensity: 0.55),
            Column(
              children: [
                AppScreenHeader(
                  dense: true,
                  title: 'Đánh giá QTKT',
                  icon: Icons.fact_check_outlined,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Không có quyền truy cập',
                    message: 'Module dành cho quản lý khối Điều dưỡng.',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final submitted = _submittedEvaluations;
    final draft = _evaluations
        .where((item) => item.status == QtktEvaluationStatus.draft)
        .length;
    final avgScore = submitted.isEmpty
        ? 0.0
        : submitted.fold<double>(0, (sum, item) => sum + item.totalScore) /
              submitted.length;
    final avgPercent = submitted.isEmpty
        ? 0.0
        : submitted.fold<double>(0, (sum, item) => sum + item.percent) /
              submitted.length;

    final showFab =
        _canScore &&
        _tab == _QtktTab.evaluations &&
        !_loading &&
        _error == null &&
        _template != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: showFab
            ? FloatingActionButton.extended(
                onPressed: _openNew,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: Text(
                  'Lập phiếu',
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppAmbientBackground(intensity: 0.7),
            RefreshIndicator(
              color: AppColors.primary,
              edgeOffset: MediaQuery.paddingOf(context).top + 8,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: AppReveal(
                      child: AppScreenHeader(
                        dense: true,
                        title: 'Đánh giá QTKT',
                        icon: Icons.fact_check_outlined,
                        eyebrow: 'Quy trình kỹ thuật',
                        subtitle: _canScore
                            ? 'Chấm checklist · lưu nháp · gửi Trưởng phòng ĐD'
                            : 'Theo dõi và tổng hợp toàn khối Điều dưỡng',
                        onBack: () => Navigator.of(context).maybePop(),
                        footer: Column(
                          children: [
                            _MonthPanel(
                              monthLabel: AppFormat.monthLabelVi(_month),
                              caption: _heroCaption(
                                submitted: submitted.length,
                                draft: draft,
                              ),
                              avgScore: avgScore,
                              avgPercent: avgPercent,
                              hasScore: submitted.isNotEmpty,
                              loading: _loading,
                              onPickMonth: _pickMonth,
                            ),
                            const SizedBox(height: 12),
                            BrandHeaderSegment(
                              dense: true,
                              selectedIndex: _tab == _QtktTab.evaluations
                                  ? 0
                                  : 1,
                              onChanged: (i) => _setTab(
                                i == 0
                                    ? _QtktTab.evaluations
                                    : _QtktTab.summary,
                              ),
                              items: const [
                                BrandSegmentItem(
                                  label: 'Danh sách',
                                  icon: Icons.view_agenda_outlined,
                                ),
                                BrandSegmentItem(
                                  label: 'Tổng hợp',
                                  icon: Icons.insights_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_loading)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.md,
                        AppSpacing.page,
                        AppSpacing.xxl,
                      ),
                      sliver: SliverList.builder(
                        itemCount: 4,
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SkeletonCard(delay: index),
                        ),
                      ),
                    )
                  else if (_error != null)
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      sliver: SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Không tải được dữ liệu',
                          message: _error!,
                          action: FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Thử lại'),
                          ),
                        ),
                      ),
                    )
                  else if (_tab == _QtktTab.evaluations)
                    ..._buildEvaluationSlivers()
                  else
                    ..._buildSummarySlivers(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _heroCaption({required int submitted, required int draft}) {
    if (_loading) return 'Đang tải số liệu…';
    final total = _evaluations.length;
    if (total == 0) return 'Chưa phát sinh phiếu trong tháng';
    return '$total phiếu · $submitted đã gửi · $draft nháp';
  }

  List<Widget> _buildEvaluationSlivers() {
    final rows = _filteredEvaluations;

    final grouped = <int, List<QtktEvaluation>>{};
    for (final evaluation in rows) {
      grouped.putIfAbsent(evaluation.employeeId, () => []).add(evaluation);
    }
    final groups = grouped.values.toList()
      ..sort((a, b) => a.first.employeeName.compareTo(b.first.employeeName));

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          14,
          AppSpacing.page,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _SearchAndFilterBar(
            controller: _searchController,
            activeCount: _activeFilterCount,
            resultCount: rows.length,
            totalCount: _evaluations.length,
            statusLabel: _statusFilter?.label,
            departmentLabel: _departmentFilter == null
                ? null
                : _departmentLabel,
            procedureLabel: _procedureFilter == null ? null : _procedureLabel,
            onPickStatus: _pickStatus,
            onPickDepartment: _pickDepartment,
            onPickProcedure: _pickProcedure,
            onClear: _clearFilters,
          ),
        ),
      ),
      if (groups.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.page),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: _evaluations.isEmpty
                  ? Icons.assignment_outlined
                  : Icons.filter_alt_off_outlined,
              title: _evaluations.isEmpty
                  ? 'Chưa có phiếu trong tháng'
                  : 'Không có phiếu phù hợp',
              message: _evaluations.isEmpty
                  ? 'Chưa phát sinh phiếu đánh giá trong tháng đã chọn.'
                  : 'Thử đổi từ khóa hoặc bỏ bớt bộ lọc.',
              action: _evaluations.isEmpty
                  ? (_canScore
                        ? FilledButton.icon(
                            onPressed: _openNew,
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('Lập phiếu đầu tiên'),
                          )
                        : null)
                  : OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: const Text('Xóa bộ lọc'),
                    ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            14,
            AppSpacing.page,
            104,
          ),
          sliver: SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) => AppReveal(
              delay: AppStagger.delayFor(index.clamp(0, 8)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EmployeeEvaluationGroup(
                  evaluations: groups[index],
                  onOpen: _openEvaluation,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  String get _departmentLabel {
    final id = _departmentFilter;
    if (id == null) return 'Khoa/phòng';
    for (final department in _departments) {
      if (department.id == id) return department.name;
    }
    return 'Khoa/phòng';
  }

  String get _procedureLabel {
    final code = _procedureFilter;
    if (code == null) return 'Quy trình';
    return _template?.procedureByCode(code)?.name ?? 'Quy trình';
  }

  List<Widget> _buildSummarySlivers() {
    final summary = _summary;
    if (summary == null) {
      return const [
        SliverPadding(
          padding: EdgeInsets.all(AppSpacing.page),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: 'Chưa có dữ liệu tổng hợp',
              message: 'Kéo xuống để tải lại.',
            ),
          ),
        ),
      ];
    }

    final procedures = summary.byProcedure
        .where((item) => item.count > 0)
        .toList(growable: false);
    final departments = summary.byDepartment
        .where((item) => item.count > 0)
        .toList(growable: false);

    if (summary.totalSubmitted == 0) {
      return const [
        SliverPadding(
          padding: EdgeInsets.all(AppSpacing.page),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: 'Chưa có phiếu đã gửi',
              message:
                  'Tổng hợp chỉ tính phiếu ở trạng thái Đã gửi. '
                  'Gửi phiếu để thấy số liệu tại đây.',
            ),
          ),
        ),
      ];
    }

    // Xếp hạng cao → thấp để tab tổng hợp trả lời được "ai đang yếu nhất".
    final rankedProcedures = [...procedures]
      ..sort((a, b) => b.avgScore.compareTo(a.avgScore));
    final rankedDepartments = [...departments]
      ..sort((a, b) => b.avgScore.compareTo(a.avgScore));

    final submitted = _submittedEvaluations;
    final scores = submitted.map((e) => e.totalScore).toList()..sort();
    final people = submitted.map((e) => e.employeeId).toSet().length;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          14,
          AppSpacing.page,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: AppReveal(
            child: _SummaryOverview(
              submitted: summary.totalSubmitted,
              people: people,
              lowest: scores.isEmpty ? null : scores.first,
              highest: scores.isEmpty ? null : scores.last,
            ),
          ),
        ),
      ),
      _summarySection(
        title: 'Theo quy trình kỹ thuật',
        icon: Icons.biotech_outlined,
        emptyMessage: 'Chưa có quy trình nào được chấm.',
        rows: [
          for (final (index, item) in rankedProcedures.indexed)
            _SummaryRowCard(
              rank: rankedProcedures.length > 1 ? index + 1 : null,
              icon: Icons.biotech_outlined,
              title: item.procedureName,
              count: item.count,
              score: item.avgScore,
              maxScore: item.maxScore,
            ),
        ],
        topPadding: 20,
      ),
      _summarySection(
        title: 'Theo khoa/phòng',
        icon: Icons.local_hospital_outlined,
        emptyMessage: 'Chưa có khoa/phòng nào được chấm.',
        rows: [
          for (final (index, item) in rankedDepartments.indexed)
            _SummaryRowCard(
              rank: rankedDepartments.length > 1 ? index + 1 : null,
              icon: Icons.local_hospital_outlined,
              title: item.departmentName,
              count: item.count,
              score: item.avgScore,
              maxScore: 10,
            ),
        ],
        topPadding: 22,
      ),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          18,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        sliver: SliverToBoxAdapter(child: _SummaryFootnote()),
      ),
    ];
  }

  Widget _summarySection({
    required String title,
    required IconData icon,
    required String emptyMessage,
    required List<Widget> rows,
    double topPadding = 18,
    double bottomPadding = 0,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        topPadding,
        AppSpacing.page,
        bottomPadding,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          ListSectionTitle(title: title, count: rows.length),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            _EmptyHint(message: emptyMessage)
          else
            for (final (index, row) in rows.indexed)
              AppReveal(
                delay: AppStagger.delayFor(index.clamp(0, 8)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: row,
                ),
              ),
        ]),
      ),
    );
  }
}

/// Khối tháng trên header: vòng điểm trung bình + kỳ + nút đổi tháng.
class _MonthPanel extends StatelessWidget {
  const _MonthPanel({
    required this.monthLabel,
    required this.caption,
    required this.avgScore,
    required this.avgPercent,
    required this.hasScore,
    required this.loading,
    required this.onPickMonth,
  });

  final String monthLabel;
  final String caption;
  final double avgScore;
  final double avgPercent;
  final bool hasScore;
  final bool loading;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onBrand.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          _ScoreRing(
            value: avgPercent,
            label: hasScore ? avgScore.toStringAsFixed(2) : '—',
            caption: 'ĐIỂM TB',
            loading: loading,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metric(
                    fontSize: 19,
                    color: onBrand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.32,
                    color: onBrand.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Đổi tháng',
            child: Material(
              color: onBrand.withValues(alpha: 0.16),
              borderRadius: AppRadius.brMd,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPickMonth,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.edit_calendar_outlined,
                    color: onBrand,
                    size: 20,
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

/// Vòng điểm trung bình trên nền brand.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.value,
    required this.label,
    required this.caption,
    required this.loading,
  });

  final double value;
  final String label;
  final String caption;
  final bool loading;

  static const Color _gold = Color(0xFFF5D77D);
  static const Color _mint = Color(0xFFB8F0D8);

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final safe = value.clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: loading ? 0 : safe),
            duration: AppDurations.slow,
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: loading ? null : animated,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: onBrand.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(
                      safe >= 0.9 ? _mint : _gold,
                    ),
                  ),
                ),
                if (!loading)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        label,
                        maxLines: 1,
                        style: AppTypography.metric(
                          fontSize: 14,
                          color: onBrand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          caption,
          style: AppTypography.style(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: onBrand.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.activeCount,
    required this.resultCount,
    required this.totalCount,
    required this.statusLabel,
    required this.departmentLabel,
    required this.procedureLabel,
    required this.onPickStatus,
    required this.onPickDepartment,
    required this.onPickProcedure,
    required this.onClear,
  });

  final TextEditingController controller;
  final int activeCount;
  final int resultCount;
  final int totalCount;
  final String? statusLabel;
  final String? departmentLabel;
  final String? procedureLabel;
  final VoidCallback onPickStatus;
  final VoidCallback onPickDepartment;
  final VoidCallback onPickProcedure;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final filtering = activeCount > 0 || controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: AppTypography.style(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: 'Tìm nhân viên, mã NV, quy trình…',
                hintStyle: AppTypography.style(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: controller.clear,
                        tooltip: 'Xóa từ khóa',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.textSecondary,
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 1, 4, 5),
            child: Divider(height: 1, color: AppColors.borderSoft),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _FilterPill(
                  label: statusLabel ?? 'Trạng thái',
                  active: statusLabel != null,
                  icon: Icons.flag_outlined,
                  onTap: onPickStatus,
                ),
                const SizedBox(width: 6),
                _FilterPill(
                  label: departmentLabel ?? 'Khoa/phòng',
                  active: departmentLabel != null,
                  icon: Icons.apartment_outlined,
                  onTap: onPickDepartment,
                ),
                const SizedBox(width: 6),
                _FilterPill(
                  label: procedureLabel ?? 'Quy trình',
                  active: procedureLabel != null,
                  icon: Icons.biotech_outlined,
                  onTap: onPickProcedure,
                ),
                if (activeCount > 0) ...[
                  const SizedBox(width: 6),
                  _ClearFilterPill(onTap: onClear),
                ],
              ],
            ),
          ),
          if (filtering) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_alt_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Hiển thị $resultCount / $totalCount phiếu',
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: AppDurations.fast,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final foreground = Color.lerp(
          AppColors.textSecondary,
          AppColors.primary,
          t,
        )!;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.surfaceAlt,
              AppColors.primary.withValues(alpha: 0.1),
              t,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color.lerp(
                Colors.transparent,
                AppColors.primary.withValues(alpha: 0.3),
                t,
              )!,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: foreground),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: t > 0.5
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: foreground,
                            letterSpacing: -0.05,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: foreground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClearFilterPill extends StatelessWidget {
  const _ClearFilterPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.errorLight,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_off_outlined,
                size: 15,
                color: AppColors.errorText,
              ),
              const SizedBox(width: 6),
              Text(
                'Xóa lọc',
                style: AppTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.errorText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeEvaluationGroup extends StatelessWidget {
  const _EmployeeEvaluationGroup({
    required this.evaluations,
    required this.onOpen,
  });

  final List<QtktEvaluation> evaluations;
  final ValueChanged<QtktEvaluation> onOpen;

  @override
  Widget build(BuildContext context) {
    final first = evaluations.first;
    final submitted = evaluations
        .where((item) => item.status == QtktEvaluationStatus.submitted)
        .toList(growable: false);
    final avgPercent = submitted.isEmpty
        ? 0.0
        : submitted.fold<double>(0, (sum, item) => sum + item.percent) /
              submitted.length;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
            decoration: const BoxDecoration(color: AppColors.surfaceAlt),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _initials(first.employeeName),
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.employeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          first.departmentName,
                          if ((first.employeeCode ?? '').isNotEmpty)
                            'Mã ${first.employeeCode}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (submitted.isNotEmpty)
                  _AverageBadge(percent: avgPercent)
                else
                  _CountBadge(count: evaluations.length),
              ],
            ),
          ),
          for (final (index, evaluation) in evaluations.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 62, endIndent: 12),
            _EvaluationRow(
              evaluation: evaluation,
              onTap: () => onOpen(evaluation),
            ),
          ],
        ],
      ),
    );
  }
}

/// Điểm trung bình của nhân viên trong tháng.
class _AverageBadge extends StatelessWidget {
  const _AverageBadge({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(percent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_graph_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '${(percent * 100).round()}%',
            style: AppTypography.metric(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.24)),
      ),
      child: Text(
        '$count nháp',
        style: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

class _EvaluationRow extends StatelessWidget {
  const _EvaluationRow({required this.evaluation, required this.onTap});

  final QtktEvaluation evaluation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(evaluation.status);
    final scoreColor = _scoreColor(evaluation.percent);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  evaluation.status == QtktEvaluationStatus.submitted
                      ? Icons.task_alt_rounded
                      : (evaluation.status == QtktEvaluationStatus.draft
                            ? Icons.edit_note_rounded
                            : Icons.cancel_outlined),
                  size: 19,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evaluation.procedureName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          AppFormat.date(
                            DateTime.tryParse(evaluation.evalDate),
                          ),
                          style: AppTypography.metricMuted(fontSize: 11.5),
                        ),
                        const SizedBox(width: 7),
                        StatusChip(
                          label: evaluation.status.label,
                          color: statusColor,
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ScorePill(
                score: evaluation.totalScore,
                maxScore: evaluation.maxScore,
                color: scoreColor,
              ),
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

/// Điểm phiếu — số lớn trên, thang điểm nhỏ dưới.
class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.score,
    required this.maxScore,
    required this.color,
  });

  final double score;
  final double maxScore;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          score.toStringAsFixed(2),
          style: AppTypography.metric(
            fontSize: 17,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '/ ${maxScore.toStringAsFixed(0)}',
          style: AppTypography.metricMuted(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _SummaryOverview extends StatelessWidget {
  const _SummaryOverview({
    required this.submitted,
    required this.people,
    required this.lowest,
    required this.highest,
  });

  final int submitted;
  final int people;
  final double? lowest;
  final double? highest;

  @override
  Widget build(BuildContext context) {
    final spread = lowest != null && highest != null && highest! > lowest!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
      child: Column(
        children: [
          Row(
            children: [
              _OverviewCell(
                value: '$submitted',
                label: 'Phiếu đã gửi',
                color: AppColors.primary,
              ),
              const _OverviewDivider(),
              _OverviewCell(
                value: '$people',
                label: 'Nhân viên',
                color: AppColors.info,
              ),
              const _OverviewDivider(),
              _OverviewCell(
                value: highest == null ? '—' : highest!.toStringAsFixed(2),
                label: 'Điểm cao nhất',
                color: AppColors.success,
              ),
            ],
          ),
          if (spread) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 11, 10, 9),
              child: Divider(height: 1, color: AppColors.borderSoft),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_down_rounded,
                    size: 15,
                    color: _scoreColor(lowest! / 10),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Thấp nhất ',
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    lowest!.toStringAsFixed(2),
                    style: AppTypography.metric(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor(lowest! / 10),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Chênh ${(highest! - lowest!).toStringAsFixed(2)} điểm',
                    style: AppTypography.metricMuted(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewCell extends StatelessWidget {
  const _OverviewCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.metric(
                fontSize: 19,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewDivider extends StatelessWidget {
  const _OverviewDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.borderSoft);
  }
}

/// Ghi chú phạm vi tính toán — khép lại trang thay vì bỏ lửng khoảng trống.
class _SummaryFootnote extends StatelessWidget {
  const _SummaryFootnote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Tổng hợp chỉ tính phiếu ở trạng thái Đã gửi trong tháng đang '
              'chọn. Phiếu nháp chưa được tính vào điểm trung bình.',
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRowCard extends StatelessWidget {
  const _SummaryRowCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.score,
    required this.maxScore,
    this.rank,
  });

  /// Thứ hạng theo điểm (null khi chỉ có một mục — xếp hạng không có nghĩa).
  final int? rank;
  final IconData icon;
  final String title;
  final int count;
  final double score;
  final double maxScore;

  @override
  Widget build(BuildContext context) {
    final progress = maxScore <= 0
        ? 0.0
        : (score / maxScore).clamp(0, 1).toDouble();
    final color = count == 0 ? AppColors.textTertiary : _scoreColor(progress);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Center(
              child: rank == null
                  ? Icon(icon, size: 19, color: color)
                  : Text(
                      '$rank',
                      style: AppTypography.metric(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.brPill,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: AppDurations.slow,
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor: color.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count phiếu',
                      style: AppTypography.metricMuted(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == 0 ? '—' : score.toStringAsFixed(2),
                style: AppTypography.metric(
                  fontSize: 17,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '/ ${maxScore.toStringAsFixed(0)}',
                style: AppTypography.metricMuted(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.delay});

  final int delay;

  @override
  Widget build(BuildContext context) {
    return AppReveal(
      delay: AppStagger.delayFor(delay),
      child: const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton(width: 40, height: 40, radius: 13),
                SizedBox(width: 11),
                Expanded(child: Skeleton(height: 16, radius: 8)),
              ],
            ),
            SizedBox(height: 14),
            Skeleton(height: 44, radius: 10),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(QtktEvaluationStatus status) => switch (status) {
  QtktEvaluationStatus.draft => AppColors.warning,
  QtktEvaluationStatus.submitted => AppColors.success,
  QtktEvaluationStatus.cancelled => AppColors.textTertiary,
};

Color _scoreColor(double progress) {
  if (progress >= 0.9) return AppColors.success;
  if (progress >= 0.7) return AppColors.primary;
  if (progress >= 0.5) return AppColors.warning;
  return AppColors.error;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'NV';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
