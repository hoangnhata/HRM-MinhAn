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
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/list_section_title.dart';
import '../../../core/widgets/metric_strip.dart';
import '../../auth/application/auth_controller.dart';
import '../data/nursing_daily_report_models.dart';
import '../data/nursing_daily_report_repository.dart';
import 'nursing_daily_report_form_screen.dart';

enum _DailyView { day, month }

enum _DayFilter { all, pending, submitted }

/// Số ngày hiển thị trên thanh chọn ngày nhanh (kết thúc ở hôm nay).
const int _kRailDays = 28;

/// Bề rộng + khoảng cách một ô ngày trên thanh chọn nhanh.
const double _kRailItemWidth = 50;
const double _kRailGap = 8;
const double _kRailExtent = _kRailItemWidth + _kRailGap;

/// Danh sách báo cáo ĐD hằng ngày — UI mobile-first, dữ liệu đồng bộ web.
class NursingDailyReportListScreen extends ConsumerStatefulWidget {
  const NursingDailyReportListScreen({super.key});

  @override
  ConsumerState<NursingDailyReportListScreen> createState() =>
      _NursingDailyReportListScreenState();
}

class _NursingDailyReportListScreenState
    extends ConsumerState<NursingDailyReportListScreen> {
  DateTime _date = _dayOnly(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _DailyView _view = _DailyView.day;
  _DayFilter _filter = _DayFilter.all;
  List<NursingDailyReportRow> _dayRows = const [];
  List<NursingDailyReportRow> _monthRows = const [];
  bool _loading = true;
  String? _error;

  final ScrollController _railController = ScrollController();

  String get _iso => _dateIso(_date);
  String get _yearMonth =>
      '${_month.year.toString().padLeft(4, '0')}-'
      '${_month.month.toString().padLeft(2, '0')}';

  /// Ngày cũ nhất trên thanh chọn nhanh — nới ra khi chọn ngày cũ hơn cửa sổ
  /// mặc định để ô đang chọn luôn có mặt trên thanh.
  DateTime get _railStart {
    final base = _dayOnly(
      DateTime.now(),
    ).subtract(const Duration(days: _kRailDays - 1));
    return _date.isBefore(base) ? _date : base;
  }

  int get _railCount =>
      _dayOnly(DateTime.now()).difference(_railStart).inDays + 1;

  List<NursingDailyReportRow> get _filteredDayRows {
    return switch (_filter) {
      _DayFilter.all => _dayRows,
      _DayFilter.pending =>
        _dayRows.where((r) => !r.submitted).toList(growable: false),
      _DayFilter.submitted =>
        _dayRows.where((r) => r.submitted).toList(growable: false),
    };
  }

  /// Khoa đầu tiên người dùng được phép nhập — dùng cho nút hành động nổi.
  NursingDailyReportRow? get _nextEditableRow {
    for (final row in _dayRows) {
      if (!row.submitted && (row.canEdit || row.hasDraft)) return row;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final role = ref.read(authControllerProvider).role;
    _view = RoleGroups.isHeadDepartmentRole(role)
        ? _DailyView.month
        : _DailyView.day;
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _railController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final role = ref.read(authControllerProvider).role;
    if (!RoleGroups.canEnterNursingDailyReports(role)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(nursingDailyReportRepositoryProvider);
      if (_view == _DailyView.day) {
        final rows = await repo.dayRows(_iso);
        rows.sort((a, b) {
          if (a.submitted == b.submitted) {
            return a.departmentName.compareTo(b.departmentName);
          }
          return a.submitted ? 1 : -1;
        });
        if (!mounted) return;
        setState(() => _dayRows = rows);
      } else {
        final rows = await repo.monthRows(_yearMonth);
        if (!mounted) return;
        setState(() => _monthRows = rows);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được dữ liệu báo cáo');
    } finally {
      if (mounted) setState(() => _loading = false);
      _scheduleRailScroll();
    }
  }

  /// Đưa ngày đang chọn vào giữa thanh chọn nhanh.
  void _scheduleRailScroll({bool animate = true}) {
    if (_view != _DailyView.day) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_railController.hasClients) return;
      final index = _date.difference(_railStart).inDays;
      if (index < 0) return;
      final viewport = _railController.position.viewportDimension;
      final target =
          (index * _kRailExtent) - (viewport / 2) + (_kRailItemWidth / 2);
      final clamped = target.clamp(
        _railController.position.minScrollExtent,
        _railController.position.maxScrollExtent,
      );
      if (animate) {
        _railController.animateTo(
          clamped,
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
        );
      } else {
        _railController.jumpTo(clamped);
      }
    });
  }

  Future<void> _selectDate(DateTime value) async {
    final next = _dayOnly(value);
    if (next == _date) return;
    HapticFeedback.selectionClick();
    setState(() => _date = next);
    _scheduleRailScroll();
    await _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    await _selectDate(picked);
  }

  /// Lùi/tiến tháng, chặn vượt quá tháng hiện tại.
  Future<void> _shiftMonth(int delta) async {
    if (delta == 0) return;
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    HapticFeedback.selectionClick();
    setState(() => _month = next);
    await _load();
  }

  Future<void> _openForm(NursingDailyReportRow row) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NursingDailyReportFormScreen(
          departmentId: row.departmentId,
          departmentName: row.departmentName,
          reportDate: row.reportDate,
          existing: row.report,
          canEdit: row.canEdit || row.hasDraft,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openDay(String iso) async {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _date = _dayOnly(parsed);
      _view = _DailyView.day;
      _filter = _DayFilter.all;
    });
    _scheduleRailScroll(animate: false);
    await _load();
  }

  Future<void> _setView(_DailyView view) async {
    if (_view == view) return;
    HapticFeedback.selectionClick();
    setState(() {
      _view = view;
      _filter = _DayFilter.all;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).role;
    if (!RoleGroups.canEnterNursingDailyReports(role)) {
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
                  title: 'Báo cáo ĐD hằng ngày',
                  icon: Icons.edit_note_rounded,
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

    final isHead = RoleGroups.isHeadDepartmentRole(role);
    final isDay = _view == _DailyView.day;
    final rows = isDay ? _dayRows : _monthRows;
    final submitted = rows.where((r) => r.submitted).length;
    final total = rows.length;
    final pending = total - submitted;
    final nextRow = isDay && !_loading ? _nextEditableRow : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: nextRow == null
            ? null
            : _QuickEntryButton(
                label: pending > 1 ? 'Nhập ($pending khoa)' : 'Nhập báo cáo',
                onTap: () => _openForm(nextRow),
              ),
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
                        title: 'Báo cáo ĐD hằng ngày',
                        icon: Icons.monitor_heart_outlined,
                        eyebrow: 'Module Điều dưỡng',
                        subtitle: isHead
                            ? 'Theo dõi và nhập số liệu khoa phụ trách'
                            : 'Theo dõi toàn khối Điều dưỡng',
                        onBack: () => Navigator.of(context).maybePop(),
                        footer: Column(
                          children: [
                            _HeroPanel(
                              title: isDay
                                  ? AppFormat.date(_date)
                                  : AppFormat.monthLabelVi(_month),
                              caption: _heroCaption(
                                isDay: isDay,
                                submitted: submitted,
                                total: total,
                                pending: pending,
                              ),
                              progress: total == 0 ? 0 : submitted / total,
                              loading: _loading,
                              actionIcon: isDay
                                  ? Icons.edit_calendar_outlined
                                  : Icons.restore_rounded,
                              actionTooltip: isDay
                                  ? 'Chọn ngày khác'
                                  : 'Về tháng hiện tại',
                              onAction: isDay
                                  ? _pickDate
                                  : () => _shiftMonth(_monthsFromNow()),
                            ),
                            if (isDay) ...[
                              const SizedBox(height: 12),
                              _DateRail(
                                controller: _railController,
                                start: _railStart,
                                count: _railCount,
                                selected: _date,
                                onSelect: _selectDate,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        14,
                        AppSpacing.page,
                        0,
                      ),
                      child: _ControlTray(
                        view: _view,
                        showFilters:
                            isDay &&
                            !_loading &&
                            _error == null &&
                            _dayRows.isNotEmpty,
                        filter: _filter,
                        total: _dayRows.length,
                        pending: pending,
                        submitted: submitted,
                        onSelectDay: () => _setView(_DailyView.day),
                        onSelectMonth: () => _setView(_DailyView.month),
                        onFilterChanged: (f) {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = f);
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      14,
                      AppSpacing.page,
                      nextRow == null ? AppSpacing.xxl : 96,
                    ),
                    sliver: _buildContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _heroCaption({
    required bool isDay,
    required int submitted,
    required int total,
    required int pending,
  }) {
    if (_loading) return 'Đang tải số liệu…';
    if (total == 0) {
      return isDay ? 'Chưa có khoa cần báo cáo' : 'Chưa có dữ liệu';
    }
    if (isDay) {
      final weekday = AppFormat.weekday(_date);
      return pending == 0
          ? '$weekday · Đủ $total/$total khoa'
          : '$weekday · $submitted/$total khoa · còn $pending';
    }
    return pending == 0
        ? 'Hoàn tất $total/$total lượt báo cáo'
        : '$submitted/$total lượt · còn thiếu $pending';
  }

  /// Số tháng cần bù để quay lại tháng hiện tại.
  int _monthsFromNow() {
    final now = DateTime.now();
    return (now.year - _month.year) * 12 + (now.month - _month.month);
  }

  Widget _buildContent() {
    if (_loading) {
      if (_view == _DailyView.month) {
        return const SliverToBoxAdapter(child: _SkeletonCalendar());
      }
      return SliverList.builder(
        itemCount: 4,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SkeletonCard(delay: i),
        ),
      );
    }
    if (_error != null) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Không tải được báo cáo',
          message: _error!,
          action: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ),
      );
    }
    if (_view == _DailyView.day) return _buildDayList();
    return _buildMonthView();
  }

  Widget _buildDayList() {
    final rows = _filteredDayRows;
    if (_dayRows.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.apartment_outlined,
          title: 'Chưa có khoa khối Điều dưỡng',
          message: 'Không tìm thấy khoa/phòng trong phạm vi phụ trách.',
        ),
      );
    }
    if (rows.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: _filter == _DayFilter.pending
              ? Icons.task_alt_rounded
              : Icons.filter_alt_off_outlined,
          color: _filter == _DayFilter.pending
              ? AppColors.success
              : AppColors.primary,
          title: switch (_filter) {
            _DayFilter.pending => 'Đã nộp đủ',
            _DayFilter.submitted => 'Chưa có báo cáo nào',
            _DayFilter.all => 'Không có dữ liệu',
          },
          message: switch (_filter) {
            _DayFilter.pending => 'Tất cả khoa đã nộp báo cáo ngày này.',
            _DayFilter.submitted => 'Chưa có khoa nào nộp báo cáo.',
            _DayFilter.all => 'Không có dữ liệu.',
          },
        ),
      );
    }

    final items = <Widget>[];
    var animIndex = 0;

    void addCard(NursingDailyReportRow row) {
      items.add(
        AppReveal(
          delay: AppStagger.delayFor(animIndex.clamp(0, 8)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DepartmentReportCard(row: row, onTap: () => _openForm(row)),
          ),
        ),
      );
      animIndex++;
    }

    void addSection(
      String title,
      Color color,
      List<NursingDailyReportRow> list,
    ) {
      if (list.isEmpty) return;
      items.add(
        Padding(
          padding: EdgeInsets.only(bottom: 10, top: items.isEmpty ? 0 : 8),
          child: ListSectionTitle(title: title, count: list.length, color: color),
        ),
      );
      for (final row in list) {
        addCard(row);
      }
    }

    if (_filter == _DayFilter.all) {
      addSection(
        'Cần nhập',
        AppColors.warning,
        rows.where((r) => !r.submitted).toList(growable: false),
      );
      addSection(
        'Đã nộp',
        AppColors.success,
        rows.where((r) => r.submitted).toList(growable: false),
      );
    } else {
      for (final row in rows) {
        addCard(row);
      }
    }

    return SliverList(delegate: SliverChildListDelegate(items));
  }

  Widget _buildMonthView() {
    if (_monthRows.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'Chưa có kỳ theo dõi',
          message: 'Tháng đã chọn chưa có ngày cần báo cáo.',
        ),
      );
    }

    final stats = <String, _DayStats>{};
    for (final row in _monthRows) {
      final current = stats[row.reportDate] ?? const _DayStats(0, 0);
      stats[row.reportDate] = _DayStats(
        current.total + 1,
        current.submitted + (row.submitted ? 1 : 0),
      );
    }

    final incomplete =
        stats.entries.where((e) => e.value.submitted < e.value.total).toList()
          ..sort((a, b) => b.key.compareTo(a.key));

    return SliverList(
      delegate: SliverChildListDelegate([
        AppReveal(
          child: _MonthCalendarCard(
            month: _month,
            stats: stats,
            canGoNext: _monthsFromNow() > 0,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
            onSelectDay: _openDay,
          ),
        ),
        if (incomplete.isNotEmpty) ...[
          const SizedBox(height: 20),
          ListSectionTitle(
            title: 'Ngày chưa hoàn tất',
            count: incomplete.length,
            color: AppColors.warning,
          ),
          const SizedBox(height: 10),
          for (final (index, entry) in incomplete.indexed)
            AppReveal(
              delay: AppStagger.delayFor(index.clamp(0, 8)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MonthDayRow(
                  iso: entry.key,
                  stats: entry.value,
                  onTap: () => _openDay(entry.key),
                ),
              ),
            ),
        ] else ...[
          const SizedBox(height: 16),
          const _AllDoneBanner(),
        ],
      ]),
    );
  }
}

/// Tổng hợp tiến độ một ngày trong tháng.
class _DayStats {
  const _DayStats(this.total, this.submitted);
  final int total;
  final int submitted;

  bool get complete => total > 0 && submitted == total;
  bool get empty => submitted == 0;
  double get progress => total == 0 ? 0 : submitted / total;
  int get pending => total - submitted;
}

/// Khối tóm tắt trên header: vòng tiến độ + kỳ báo cáo + nút đổi kỳ.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.title,
    required this.caption,
    required this.progress,
    required this.loading,
    required this.actionIcon,
    required this.actionTooltip,
    required this.onAction,
  });

  final String title;
  final String caption;
  final double progress;
  final bool loading;
  final IconData actionIcon;
  final String actionTooltip;
  final VoidCallback onAction;

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
          _BrandProgressRing(value: progress, loading: loading),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
            label: actionTooltip,
            child: Material(
              color: onBrand.withValues(alpha: 0.16),
              borderRadius: AppRadius.brMd,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onAction,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(actionIcon, color: onBrand, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vòng tiến độ vàng trên nền brand — số phần trăm ở giữa.
class _BrandProgressRing extends StatelessWidget {
  const _BrandProgressRing({required this.value, required this.loading});

  final double value;
  final bool loading;

  static const Color _gold = Color(0xFFF5D77D);
  static const Color _mint = Color(0xFFB8F0D8);

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final safe = value.clamp(0.0, 1.0);
    final complete = safe >= 1;

    return SizedBox(
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
                valueColor: AlwaysStoppedAnimation(complete ? _mint : _gold),
              ),
            ),
            if (!loading)
              Text(
                '${(safe * 100).round()}%',
                style: AppTypography.metric(
                  fontSize: 14,
                  color: onBrand,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Thanh chọn ngày nhanh — cuộn ngang, chạm để đổi ngày.
class _DateRail extends StatelessWidget {
  const _DateRail({
    required this.controller,
    required this.start,
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  final ScrollController controller;
  final DateTime start;
  final int count;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const List<String> _short = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final today = _dayOnly(DateTime.now());

    return SizedBox(
      height: 60,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: _kRailGap),
        itemBuilder: (context, index) {
          final day = start.add(Duration(days: index));
          return _DateRailChip(
            weekday: _short[day.weekday - 1],
            day: day.day,
            selected: day == selected,
            isToday: day == today,
            onTap: () => onSelect(day),
          );
        },
      ),
    );
  }
}

class _DateRailChip extends StatelessWidget {
  const _DateRailChip({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final fg = selected ? AppColors.primaryDark : onBrand;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Ngày $day, $weekday',
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        width: _kRailItemWidth,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : onBrand.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : onBrand.withValues(alpha: isToday ? 0.42 : 0.14),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekday,
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: selected
                        ? AppColors.textSecondary
                        : onBrand.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$day',
                  style: AppTypography.metric(
                    fontSize: 16,
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday
                        ? (selected ? AppColors.primary : onBrand)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _ControlTray extends StatelessWidget {
  const _ControlTray({
    required this.view,
    required this.showFilters,
    required this.filter,
    required this.total,
    required this.pending,
    required this.submitted,
    required this.onSelectDay,
    required this.onSelectMonth,
    required this.onFilterChanged,
  });

  final _DailyView view;
  final bool showFilters;
  final _DayFilter filter;
  final int total;
  final int pending;
  final int submitted;
  final VoidCallback onSelectDay;
  final VoidCallback onSelectMonth;
  final ValueChanged<_DayFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(5),
      child: AnimatedSize(
        duration: AppDurations.normal,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSegmentedControl(
              selectedIndex: view == _DailyView.day ? 0 : 1,
              onChanged: (i) => i == 0 ? onSelectDay() : onSelectMonth(),
              items: const [
                AppSegmentItem(
                  label: 'Theo ngày',
                  icon: Icons.view_agenda_outlined,
                ),
                AppSegmentItem(
                  label: 'Theo tháng',
                  icon: Icons.calendar_month_outlined,
                ),
              ],
            ),
            if (showFilters) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 5),
                child: Divider(height: 1, color: AppColors.borderSoft),
              ),
              _FilterRow(
                filter: filter,
                total: total,
                pending: pending,
                submitted: submitted,
                onChanged: onFilterChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bộ lọc ngày — ba ô đều nhau, khớp nhịp với segment phía trên.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.total,
    required this.pending,
    required this.submitted,
    required this.onChanged,
  });

  final _DayFilter filter;
  final int total;
  final int pending;
  final int submitted;
  final ValueChanged<_DayFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilterChip(
            label: 'Tất cả',
            count: total,
            selected: filter == _DayFilter.all,
            onTap: () => onChanged(_DayFilter.all),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _FilterChip(
            label: 'Chưa nộp',
            count: pending,
            selected: filter == _DayFilter.pending,
            color: AppColors.warning,
            onTap: () => onChanged(_DayFilter.pending),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _FilterChip(
            label: 'Đã nộp',
            count: submitted,
            selected: filter == _DayFilter.submitted,
            color: AppColors.success,
            onTap: () => onChanged(_DayFilter.submitted),
          ),
        ),
      ],
    );
  }
}

/// Ô lọc — chấm trạng thái + nhãn + số đếm; nền tint nhạt khi được chọn.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count khoa',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: selected ? 1 : 0),
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final labelColor = Color.lerp(AppColors.textSecondary, color, t)!;
          final countColor = Color.lerp(AppColors.textTertiary, color, t)!;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(
                AppColors.surfaceAlt,
                color.withValues(alpha: 0.1),
                t,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color.lerp(
                  Colors.transparent,
                  color.withValues(alpha: 0.3),
                  t,
                )!,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 38,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.34 + (0.66 * t)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            maxLines: 1,
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: t > 0.5
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: labelColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$count',
                            maxLines: 1,
                            style: AppTypography.metric(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: countColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Segment ngày/tháng — con trượt teal đặc, chữ trắng: mốc điều hướng cấp một.
/// Thẻ khoa trong danh sách ngày.
class _DepartmentReportCard extends StatelessWidget {
  const _DepartmentReportCard({required this.row, required this.onTap});

  final NursingDailyReportRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final report = row.report;
    final statusColor = row.submitted
        ? AppColors.success
        : (row.hasDraft ? AppColors.info : AppColors.warning);
    final statusIcon = row.submitted
        ? Icons.check_rounded
        : (row.hasDraft ? Icons.edit_note_rounded : Icons.schedule_rounded);
    final statusLabel = row.submitted
        ? 'Đã nộp'
        : (row.hasDraft ? 'Bản nháp' : 'Chưa nộp');
    final timeLabel = row.submitted
        ? _timeOf(report?.submittedAt ?? report?.updatedAt)
        : null;
    final incidents = report?.safetyIncidents ?? 0;

    return AppCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(statusIcon, size: 21, color: statusColor),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        row.submitted
                            ? Icons.check_rounded
                            : (row.hasDraft
                                ? Icons.edit_rounded
                                : Icons.schedule_rounded),
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.departmentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            timeLabel == null
                                ? statusLabel
                                : '$statusLabel · $timeLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12,
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
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report != null) ...[
            MetricStrip(
              items: [
                MetricItem(
                  label: 'Đi làm',
                  value: '${report.workingStaff}/${report.totalStaff}',
                ),
                MetricItem(
                  label: 'Nội trú',
                  value: '${report.inpatients}',
                  color: AppColors.info,
                ),
                MetricItem(
                  label: 'Giường',
                  value: '${report.actualBeds}/${report.plannedBeds}',
                  color: AppColors.secondaryDark,
                ),
              ],
            ),
            if (incidents > 0) ...[
              const SizedBox(height: 9),
              _IncidentBanner(count: incidents),
            ],
          ] else
            _ActionStrip(
              enabled: row.canEdit || row.hasDraft,
              label: row.hasDraft
                  ? 'Tiếp tục bản nháp'
                  : 'Nhập số liệu cho ngày này',
              lockedLabel: 'Khoa chưa gửi số liệu',
            ),
        ],
      ),
    );
  }
}
class _IncidentBanner extends StatelessWidget {
  const _IncidentBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.errorText,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$count sự cố an toàn người bệnh ngày qua',
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dải gợi ý hành động cho khoa chưa có số liệu.
class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.enabled,
    required this.label,
    required this.lockedLabel,
  });

  final bool enabled;
  final String label;
  final String lockedLabel;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surfaceAlt,
        borderRadius: AppRadius.brSm,
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.borderSoft,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.edit_note_rounded : Icons.lock_outline_rounded,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              enabled ? label : lockedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (enabled)
            const Icon(
              Icons.arrow_forward_rounded,
              size: 15,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}

/// Lịch tháng — mỗi ô là tiến độ nộp của một ngày.
class _MonthCalendarCard extends StatelessWidget {
  const _MonthCalendarCard({
    required this.month,
    required this.stats,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<String, _DayStats> stats;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<String> onSelectDay;

  static const List<String> _heads = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final weeks = ((leading + daysInMonth) / 7).ceil();
    final today = _dayOnly(DateTime.now());

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
              Expanded(
                child: Text(
                  AppFormat.monthLabelVi(month),
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: canGoNext ? onNext : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final head in _heads)
                Expanded(
                  child: Text(
                    head,
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var week = 0; week < weeks; week++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  for (var slot = 0; slot < 7; slot++)
                    Expanded(
                      child: _buildCell(
                        week * 7 + slot - leading + 1,
                        daysInMonth,
                        today,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const _CalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildCell(int dayNumber, int daysInMonth, DateTime today) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 42);
    }
    final date = DateTime(month.year, month.month, dayNumber);
    final iso = _dateIso(date);
    final stat = stats[iso];
    return _CalendarCell(
      day: dayNumber,
      stats: stat,
      isToday: date == today,
      onTap: stat == null ? null : () => onSelectDay(iso),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.stats,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final _DayStats? stats;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stat = stats;
    Color background;
    Color foreground;
    Color? border;

    if (stat == null) {
      background = Colors.transparent;
      foreground = AppColors.textTertiary.withValues(alpha: 0.55);
    } else if (stat.complete) {
      background = AppColors.success;
      foreground = Colors.white;
    } else if (stat.empty) {
      background = AppColors.errorLight;
      foreground = AppColors.errorText;
      border = AppColors.error.withValues(alpha: 0.2);
    } else {
      background = AppColors.warningLight;
      foreground = AppColors.warningText;
      border = AppColors.warning.withValues(alpha: 0.24);
    }

    return Semantics(
      button: onTap != null,
      label: stat == null
          ? 'Ngày $day, không có dữ liệu'
          : 'Ngày $day, ${stat.submitted} trên ${stat.total} khoa đã nộp',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday
                      ? AppColors.primary
                      : (border ?? Colors.transparent),
                  width: isToday ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: AppTypography.metric(
                      fontSize: 13.5,
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (stat != null && !stat.complete) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${stat.submitted}/${stat.total}',
                      style: AppTypography.metricMuted(
                        fontSize: 10,
                        color: foreground.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendDot(color: AppColors.success, label: 'Đủ'),
        _LegendDot(color: AppColors.warning, label: 'Thiếu'),
        _LegendDot(color: AppColors.error, label: 'Chưa nộp'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.surfaceAlt : Colors.transparent,
      borderRadius: AppRadius.brSm,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? AppColors.primaryDark
                : AppColors.textTertiary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Hàng ngày chưa hoàn tất trong tháng.
class _MonthDayRow extends StatelessWidget {
  const _MonthDayRow({
    required this.iso,
    required this.stats,
    required this.onTap,
  });

  final String iso;
  final _DayStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(iso);
    final color = stats.empty ? AppColors.error : AppColors.warning;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      child: Row(
        children: [
          _MiniRing(value: stats.progress, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppFormat.date(parsed),
                  style: AppTypography.metric(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  parsed == null
                      ? '${stats.submitted}/${stats.total} khoa đã nộp'
                      : '${AppFormat.weekday(parsed)} · ${stats.submitted}/${stats.total} khoa đã nộp',
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.brPill,
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Text(
              'Còn ${stats.pending}',
              style: AppTypography.style(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: color.withValues(alpha: 0.13),
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: AppTypography.metric(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.successDark,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Tất cả các ngày trong tháng đã nộp đủ báo cáo.',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: AppColors.successDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút nổi mở nhanh khoa còn thiếu báo cáo.
class _QuickEntryButton extends StatelessWidget {
  const _QuickEntryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      icon: const Icon(Icons.edit_note_rounded, size: 20),
      label: Text(
        label,
        style: AppTypography.style(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
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
                Skeleton(width: 42, height: 42, radius: 13),
                SizedBox(width: 12),
                Expanded(child: Skeleton(height: 16, radius: 8)),
              ],
            ),
            SizedBox(height: 14),
            Skeleton(height: 46, radius: 10),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCalendar extends StatelessWidget {
  const _SkeletonCalendar();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        children: [
          Skeleton(width: 140, height: 16, radius: 8),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Skeleton(height: 42, radius: 12),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Skeleton(height: 42, radius: 12),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Skeleton(height: 42, radius: 12),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Skeleton(height: 42, radius: 12),
          ),
          Skeleton(height: 42, radius: 12),
        ],
      ),
    );
  }
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// "14:20" từ chuỗi ISO trả về từ API; null khi không đọc được.
String? _timeOf(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final parsed = DateTime.tryParse(iso);
  return parsed == null ? null : AppFormat.time(parsed.toLocal());
}
