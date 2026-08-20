import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_time_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/search_field.dart';
import '../../../shared/models/attendance_models.dart';
import '../../../shared/models/employee.dart';
import '../../employees/data/employee_repository.dart';
import '../data/attendance_repository.dart';

/// Mở sheet điều động hàng loạt — API đồng bộ web, UI tối ưu mobile.
Future<bool?> showBulkDeploymentSheet(
  BuildContext context, {
  required DateTime workDate,
  DayShiftSchedule? schedule,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BulkDeploymentSheet(
      workDate: workDate,
      schedule: schedule,
    ),
  );
}

typedef _EmpDeployConfig = ({
  String timeMode, // OUTSIDE | INSIDE
  String insideScope, // MORNING | AFTERNOON | FULL_DAY
  TimeOfDay? outsideStart,
  TimeOfDay? outsideEnd,
  TimeOfDay? morningStart,
  TimeOfDay? morningEnd,
  TimeOfDay? afternoonStart,
  TimeOfDay? afternoonEnd,
});

_EmpDeployConfig _defaultDeployConfig(DayShiftSchedule? schedule) {
  return (
    timeMode: 'OUTSIDE',
    insideScope: 'MORNING',
    outsideStart: const TimeOfDay(hour: 18, minute: 0),
    outsideEnd: const TimeOfDay(hour: 21, minute: 0),
    morningStart: _parseHm(schedule?.morningStart),
    morningEnd: _parseHm(schedule?.morningEnd),
    afternoonStart: _parseHm(schedule?.afternoonStart),
    afternoonEnd: _parseHm(schedule?.afternoonEnd),
  );
}

TimeOfDay? _parseHm(String? s) {
  if (s == null) return null;
  final parts = s.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

_EmpDeployConfig _withInsideTimes(
  _EmpDeployConfig cfg,
  DayShiftSchedule? schedule, {
  bool overwriteEmptyOnly = true,
}) {
  TimeOfDay? pick(TimeOfDay? current, String? fromSch) {
    if (overwriteEmptyOnly && current != null) return current;
    return _parseHm(fromSch) ?? current;
  }

  return (
    timeMode: cfg.timeMode,
    insideScope: cfg.insideScope,
    outsideStart: cfg.outsideStart,
    outsideEnd: cfg.outsideEnd,
    morningStart: pick(cfg.morningStart, schedule?.morningStart),
    morningEnd: pick(cfg.morningEnd, schedule?.morningEnd),
    afternoonStart: pick(cfg.afternoonStart, schedule?.afternoonStart),
    afternoonEnd: pick(cfg.afternoonEnd, schedule?.afternoonEnd),
  );
}

String _fmtHm(TimeOfDay? t) => t != null
    ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
    : '—';

String _fmtSubmit(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

String _configSummary(_EmpDeployConfig cfg) {
  if (cfg.timeMode == 'OUTSIDE') {
    return 'Ngoài ca ${_fmtHm(cfg.outsideStart)}–${_fmtHm(cfg.outsideEnd)}';
  }
  if (cfg.insideScope == 'MORNING') {
    return 'Sáng ${_fmtHm(cfg.morningStart)}–${_fmtHm(cfg.morningEnd)}';
  }
  if (cfg.insideScope == 'AFTERNOON') {
    return 'Chiều ${_fmtHm(cfg.afternoonStart)}–${_fmtHm(cfg.afternoonEnd)}';
  }
  return 'Cả ngày ${_fmtHm(cfg.morningStart)}–${_fmtHm(cfg.morningEnd)} · ${_fmtHm(cfg.afternoonStart)}–${_fmtHm(cfg.afternoonEnd)}';
}

class _BulkDeploymentSheet extends ConsumerStatefulWidget {
  const _BulkDeploymentSheet({
    required this.workDate,
    this.schedule,
  });

  final DateTime workDate;
  final DayShiftSchedule? schedule;

  @override
  ConsumerState<_BulkDeploymentSheet> createState() =>
      _BulkDeploymentSheetState();
}

class _BulkDeploymentSheetState extends ConsumerState<_BulkDeploymentSheet> {
  static const _accent = AppColors.primary;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();

  List<EmployeeSummary> _employees = const [];
  final Set<int> _selectedIds = {};
  final Map<int, _EmpDeployConfig> _configByEmp = {};
  final Map<int, DayShiftSchedule> _scheduleByEmp = {};

  DayShiftSchedule? _schedule;

  String _quickMode = 'OUTSIDE';
  String _quickScope = 'MORNING';
  TimeOfDay _quickOutStart = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _quickOutEnd = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay? _quickMorStart;
  TimeOfDay? _quickMorEnd;
  TimeOfDay? _quickAftStart;
  TimeOfDay? _quickAftEnd;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    _applyScheduleToQuick(_schedule);
    _bootstrap();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyScheduleToQuick(DayShiftSchedule? sch) {
    _quickMorStart = _parseHm(sch?.morningStart) ?? _quickMorStart;
    _quickMorEnd = _parseHm(sch?.morningEnd) ?? _quickMorEnd;
    _quickAftStart = _parseHm(sch?.afternoonStart) ?? _quickAftStart;
    _quickAftEnd = _parseHm(sch?.afternoonEnd) ?? _quickAftEnd;
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final employees = await _fetchEmployees('');
      DayShiftSchedule? schedule = _schedule;
      schedule ??= await ref
          .read(attendanceRepositoryProvider)
          .daySchedule(date: widget.workDate);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _schedule = schedule;
        _applyScheduleToQuick(schedule);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<EmployeeSummary>> _fetchEmployees(String query) async {
    final page = await ref.read(employeeRepositoryProvider).list(
          page: 0,
          size: 200,
          query: query.trim().isEmpty ? null : query.trim(),
          statusGroup: 'OFFICIAL',
        );
    return page.content;
  }

  Future<void> _loadEmployeesList(String query) async {
    try {
      final employees = await _fetchEmployees(query);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<DayShiftSchedule?> _scheduleForEmployee(int employeeId) async {
    final cached = _scheduleByEmp[employeeId];
    if (cached != null) return cached;
    try {
      final sch = await ref.read(attendanceRepositoryProvider).daySchedule(
            date: widget.workDate,
            employeeId: employeeId,
          );
      _scheduleByEmp[employeeId] = sch;
      return sch;
    } catch (_) {
      return _schedule;
    }
  }

  void _setQuickMode(String mode) {
    setState(() {
      _quickMode = mode;
      if (mode == 'INSIDE') {
        _applyScheduleToQuick(_schedule);
      }
    });
  }

  Future<void> _toggleEmp(int id) async {
    HapticFeedback.selectionClick();
    if (_selectedIds.contains(id)) {
      setState(() {
        _selectedIds.remove(id);
        _configByEmp.remove(id);
      });
      return;
    }

    var cfg = _withInsideTimes(_buildQuickConfig(), _schedule);
    setState(() {
      _selectedIds.add(id);
      _configByEmp[id] = cfg;
    });

    final sch = await _scheduleForEmployee(id);
    if (!mounted || !_selectedIds.contains(id)) return;
    setState(() {
      final current = _configByEmp[id] ?? cfg;
      _configByEmp[id] = _withInsideTimes(current, sch, overwriteEmptyOnly: false);
    });
  }

  void _selectAllVisible() {
    HapticFeedback.lightImpact();
    final base = _withInsideTimes(_buildQuickConfig(), _schedule);
    setState(() {
      for (final emp in _employees) {
        if (_selectedIds.add(emp.id)) {
          _configByEmp[emp.id] = base;
        }
      }
    });
    for (final emp in _employees) {
      _hydrateEmpSchedule(emp.id);
    }
  }

  Future<void> _hydrateEmpSchedule(int id) async {
    final sch = await _scheduleForEmployee(id);
    if (!mounted || !_selectedIds.contains(id)) return;
    setState(() {
      final current = _configByEmp[id];
      if (current == null) return;
      _configByEmp[id] = _withInsideTimes(current, sch, overwriteEmptyOnly: false);
    });
  }

  void _clearSelection() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIds.clear();
      _configByEmp.clear();
    });
  }

  void _applyQuickToSelected() {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.mediumImpact();
    final base = _withInsideTimes(_buildQuickConfig(), _schedule);
    setState(() {
      for (final id in _selectedIds) {
        _configByEmp[id] = base;
      }
    });
  }

  _EmpDeployConfig _buildQuickConfig() => (
        timeMode: _quickMode,
        insideScope: _quickScope,
        outsideStart: _quickOutStart,
        outsideEnd: _quickOutEnd,
        morningStart: _quickMorStart,
        morningEnd: _quickMorEnd,
        afternoonStart: _quickAftStart,
        afternoonEnd: _quickAftEnd,
      );

  void _patchEmp(int id, _EmpDeployConfig patch) {
    final sch = _scheduleByEmp[id] ?? _schedule;
    final filled = patch.timeMode == 'INSIDE'
        ? _withInsideTimes(patch, sch)
        : patch;
    setState(() => _configByEmp[id] = filled);
  }

  Future<TimeOfDay?> _pickTime(
    TimeOfDay? initial,
    String label, {
    TimeOfDay? suggested,
  }) {
    return showAppTimePicker(
      context,
      initialTime: initial ?? suggested ?? TimeOfDay.now(),
      title: label,
      suggestedTime: suggested ?? initial,
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
  }

  String? _validateItems() {
    if (_selectedIds.isEmpty) return 'Chọn ít nhất 1 nhân viên.';
    if (_reasonController.text.trim().isEmpty) {
      return 'Nhập nội dung điều động.';
    }
    for (final id in _selectedIds) {
      final cfg = _configByEmp[id] ?? _defaultDeployConfig(_schedule);
      var name = 'NV #$id';
      for (final e in _employees) {
        if (e.id == id) {
          name = e.fullName;
          break;
        }
      }
      if (cfg.timeMode == 'OUTSIDE') {
        if (cfg.outsideStart == null || cfg.outsideEnd == null) {
          return '$name: chưa nhập giờ ngoài ca.';
        }
      } else {
        final scope = cfg.insideScope;
        if ((scope == 'MORNING' || scope == 'FULL_DAY') &&
            (cfg.morningStart == null || cfg.morningEnd == null)) {
          return '$name: chưa nhập giờ ca sáng.';
        }
        if ((scope == 'AFTERNOON' || scope == 'FULL_DAY') &&
            (cfg.afternoonStart == null || cfg.afternoonEnd == null)) {
          return '$name: chưa nhập giờ ca chiều.';
        }
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validateItems();
    if (err != null) {
      showAppSnackBar(context, err, isError: true);
      return;
    }

    setState(() => _saving = true);
    final reason = _reasonController.text.trim();
    final items = _selectedIds.map((id) {
      final cfg = _configByEmp[id] ?? _defaultDeployConfig(_schedule);
      if (cfg.timeMode == 'OUTSIDE') {
        return (
          employeeId: id,
          shiftScope: 'FULL_DAY',
          requestedStart: _fmtSubmit(cfg.outsideStart!),
          requestedEnd: _fmtSubmit(cfg.outsideEnd!),
          requestedAfternoonStart: null as String?,
          requestedAfternoonEnd: null as String?,
        );
      }
      if (cfg.insideScope == 'MORNING') {
        return (
          employeeId: id,
          shiftScope: 'MORNING',
          requestedStart: _fmtSubmit(cfg.morningStart!),
          requestedEnd: _fmtSubmit(cfg.morningEnd!),
          requestedAfternoonStart: null as String?,
          requestedAfternoonEnd: null as String?,
        );
      }
      if (cfg.insideScope == 'AFTERNOON') {
        return (
          employeeId: id,
          shiftScope: 'AFTERNOON',
          requestedStart: _fmtSubmit(cfg.afternoonStart!),
          requestedEnd: _fmtSubmit(cfg.afternoonEnd!),
          requestedAfternoonStart: null as String?,
          requestedAfternoonEnd: null as String?,
        );
      }
      return (
        employeeId: id,
        shiftScope: 'FULL_DAY',
        requestedStart: _fmtSubmit(cfg.morningStart!),
        requestedEnd: _fmtSubmit(cfg.morningEnd!),
        requestedAfternoonStart: _fmtSubmit(cfg.afternoonStart!),
        requestedAfternoonEnd: _fmtSubmit(cfg.afternoonEnd!),
      );
    }).toList();

    try {
      final result = await ref.read(attendanceRepositoryProvider).bulkDeployment(
            workDate: widget.workDate,
            reason: reason,
            items: items,
          );
      if (!mounted) return;
      if (result.errors.isNotEmpty) {
        showAppSnackBar(
          context,
          'Thành công ${result.successCount}/${items.length}. Lỗi: ${result.errors.first}',
          isError: result.successCount == 0,
        );
      } else {
        showAppSnackBar(
          context,
          'Đã điều động ${result.successCount} nhân viên',
          isSuccess: true,
        );
      }
      if (result.successCount > 0) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _saving = false);
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final canSubmit = !_saving && _selectedIds.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _Header(
              workDate: widget.workDate,
              onBrand: onBrand,
              onClose: _saving ? null : () => Navigator.pop(context),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    _QuickPanel(
                      timeMode: _quickMode,
                      insideScope: _quickScope,
                      outsideStart: _quickOutStart,
                      outsideEnd: _quickOutEnd,
                      morningStart: _quickMorStart,
                      morningEnd: _quickMorEnd,
                      afternoonStart: _quickAftStart,
                      afternoonEnd: _quickAftEnd,
                      selectedCount: _selectedIds.length,
                      onTimeModeChanged: _setQuickMode,
                      onScopeChanged: (v) => setState(() => _quickScope = v),
                      onPickOutStart: () async {
                        final t = await _pickTime(
                            _quickOutStart, 'Ngoài ca – bắt đầu');
                        if (t != null) setState(() => _quickOutStart = t);
                      },
                      onPickOutEnd: () async {
                        final t = await _pickTime(
                            _quickOutEnd, 'Ngoài ca – kết thúc');
                        if (t != null) setState(() => _quickOutEnd = t);
                      },
                      onPickMorStart: () async {
                        final t = await _pickTime(
                          _quickMorStart,
                          'Ca sáng – bắt đầu',
                          suggested: _parseHm(_schedule?.morningStart),
                        );
                        if (t != null) setState(() => _quickMorStart = t);
                      },
                      onPickMorEnd: () async {
                        final t = await _pickTime(
                          _quickMorEnd,
                          'Ca sáng – kết thúc',
                          suggested: _parseHm(_schedule?.morningEnd),
                        );
                        if (t != null) setState(() => _quickMorEnd = t);
                      },
                      onPickAftStart: () async {
                        final t = await _pickTime(
                          _quickAftStart,
                          'Ca chiều – bắt đầu',
                          suggested: _parseHm(_schedule?.afternoonStart),
                        );
                        if (t != null) setState(() => _quickAftStart = t);
                      },
                      onPickAftEnd: () async {
                        final t = await _pickTime(
                          _quickAftEnd,
                          'Ca chiều – kết thúc',
                          suggested: _parseHm(_schedule?.afternoonEnd),
                        );
                        if (t != null) setState(() => _quickAftEnd = t);
                      },
                      onApply:
                          _selectedIds.isEmpty ? null : _applyQuickToSelected,
                    ),
                    const SizedBox(height: 10),
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Tìm nhân viên…',
                      dense: true,
                      onChanged: _loadEmployeesList,
                    ),
                    const SizedBox(height: 8),
                    _Toolbar(
                      selectedCount: _selectedIds.length,
                      totalVisible: _employees.length,
                      onSelectAll:
                          _employees.isEmpty ? null : _selectAllVisible,
                      onClear:
                          _selectedIds.isEmpty ? null : _clearSelection,
                    ),
                    const SizedBox(height: 8),
                    if (_employees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 40,
                              color: AppColors.textTertiary
                                  .withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Không có nhân viên phù hợp',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_employees.length, (index) {
                        final emp = _employees[index];
                        final ticked = _selectedIds.contains(emp.id);
                        final cfg = _configByEmp[emp.id] ??
                            _defaultDeployConfig(
                              _scheduleByEmp[emp.id] ?? _schedule,
                            );
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _employees.length - 1 ? 0 : 8,
                          ),
                          child: _EmployeeTile(
                            employee: emp,
                            selected: ticked,
                            config: cfg,
                            schedule: _scheduleByEmp[emp.id] ?? _schedule,
                            onToggle: () => _toggleEmp(emp.id),
                            onChanged: (updated) =>
                                _patchEmp(emp.id, updated),
                            onPickTime: _pickTime,
                          ),
                        );
                      }),
                  ],
                ),
              ),
              _Footer(
                reasonController: _reasonController,
                saving: _saving,
                canSubmit: canSubmit,
                selectedCount: _selectedIds.length,
                onCancel: _saving ? null : () => Navigator.pop(context),
                onSubmit: canSubmit ? _submit : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── UI ──────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.workDate,
    required this.onBrand,
    this.onClose,
  });

  final DateTime workDate;
  final Color onBrand;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onBrand.withValues(alpha: 0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: onBrand.withValues(alpha: 0.35),
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: onBrand.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: onBrand.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(Icons.swap_horiz_rounded,
                          color: onBrand, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ĐIỀU ĐỘNG',
                            style: AppTypography.style(
                              color: onBrand.withValues(alpha: 0.72),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hàng loạt',
                            style: AppTypography.style(
                              color: onBrand,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: onBrand.withValues(alpha: 0.14),
                              borderRadius: AppRadius.brPill,
                            ),
                            child: Text(
                              AppFormat.longDateVi(workDate),
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: onBrand.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(Icons.close_rounded,
                            color: onBrand.withValues(alpha: 0.9)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPanel extends StatelessWidget {
  const _QuickPanel({
    required this.timeMode,
    required this.insideScope,
    required this.outsideStart,
    required this.outsideEnd,
    required this.morningStart,
    required this.morningEnd,
    required this.afternoonStart,
    required this.afternoonEnd,
    required this.selectedCount,
    required this.onTimeModeChanged,
    required this.onScopeChanged,
    required this.onPickOutStart,
    required this.onPickOutEnd,
    required this.onPickMorStart,
    required this.onPickMorEnd,
    required this.onPickAftStart,
    required this.onPickAftEnd,
    this.onApply,
  });

  final String timeMode;
  final String insideScope;
  final TimeOfDay outsideStart;
  final TimeOfDay outsideEnd;
  final TimeOfDay? morningStart;
  final TimeOfDay? morningEnd;
  final TimeOfDay? afternoonStart;
  final TimeOfDay? afternoonEnd;
  final int selectedCount;
  final ValueChanged<String> onTimeModeChanged;
  final ValueChanged<String> onScopeChanged;
  final VoidCallback onPickOutStart;
  final VoidCallback onPickOutEnd;
  final VoidCallback onPickMorStart;
  final VoidCallback onPickMorEnd;
  final VoidCallback onPickAftStart;
  final VoidCallback onPickAftEnd;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final isOutside = timeMode == 'OUTSIDE';
    final showMorning =
        !isOutside && (insideScope == 'MORNING' || insideScope == 'FULL_DAY');
    final showAfternoon = !isOutside &&
        (insideScope == 'AFTERNOON' || insideScope == 'FULL_DAY');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _BulkDeploymentSheetState._accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.bolt_rounded,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gán nhanh',
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Text(
                'Áp dụng mẫu đã chọn',
                style: AppTypography.style(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SegChip(
                  label: 'Ngoài ca',
                  icon: Icons.nights_stay_rounded,
                  selected: isOutside,
                  onTap: () => onTimeModeChanged('OUTSIDE'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegChip(
                  label: 'Trong ca',
                  icon: Icons.work_history_rounded,
                  selected: !isOutside,
                  onTap: () => onTimeModeChanged('INSIDE'),
                ),
              ),
            ],
          ),
          if (!isOutside) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (i, item) in [
                  ('MORNING', 'Sáng'),
                  ('AFTERNOON', 'Chiều'),
                  ('FULL_DAY', 'Cả ngày'),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _MiniChip(
                      label: item.$2,
                      selected: insideScope == item.$1,
                      onTap: () => onScopeChanged(item.$1),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (isOutside)
            _TimePair(
              startLabel: _fmtHm(outsideStart),
              endLabel: _fmtHm(outsideEnd),
              onPickStart: onPickOutStart,
              onPickEnd: onPickOutEnd,
              tint: AppColors.primary,
            ),
          if (showMorning)
            _TimePair(
              title: 'Ca sáng',
              icon: Icons.wb_sunny_rounded,
              startLabel: _fmtHm(morningStart),
              endLabel: _fmtHm(morningEnd),
              onPickStart: onPickMorStart,
              onPickEnd: onPickMorEnd,
              tint: AppColors.warning,
            ),
          if (showAfternoon) ...[
            if (showMorning) const SizedBox(height: 8),
            _TimePair(
              title: 'Ca chiều',
              icon: Icons.wb_twilight,
              startLabel: _fmtHm(afternoonStart),
              endLabel: _fmtHm(afternoonEnd),
              onPickStart: onPickAftStart,
              onPickEnd: onPickAftEnd,
              tint: AppColors.info,
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: Text(
                selectedCount == 0
                    ? 'Chọn nhân viên để áp dụng'
                    : 'Áp dụng cho $selectedCount đã chọn',
                style: AppTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _BulkDeploymentSheetState._accent,
                disabledBackgroundColor: AppColors.actionDisabledBackground,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.brControl,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
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
      color: selected
          ? _BulkDeploymentSheetState._accent.withValues(alpha: 0.12)
          : AppColors.surfaceAlt,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brControl,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(
              color: selected
                  ? _BulkDeploymentSheetState._accent.withValues(alpha: 0.4)
                  : AppColors.borderSoft,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
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
      color: selected ? AppColors.primaryDark : AppColors.surfaceAlt,
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.style(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePair extends StatelessWidget {
  const _TimePair({
    required this.startLabel,
    required this.endLabel,
    required this.onPickStart,
    required this.onPickEnd,
    required this.tint,
    this.title,
    this.icon,
  });

  final String? title;
  final IconData? icon;
  final String startLabel;
  final String endLabel;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: AppRadius.brControl,
        border: Border.all(color: tint.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: tint),
                  const SizedBox(width: 6),
                ],
                Text(
                  title!,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _TimeBtn(
                  label: 'Bắt đầu',
                  value: startLabel,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeBtn(
                  label: 'Kết thúc',
                  value: endLabel,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBtn extends StatelessWidget {
  const _TimeBtn({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brControl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 10.5,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.selectedCount,
    required this.totalVisible,
    this.onSelectAll,
    this.onClear,
  });

  final int selectedCount;
  final int totalVisible;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selectedCount > 0
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceHigh,
            borderRadius: AppRadius.brPill,
            border: Border.all(
              color: selectedCount > 0
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : AppColors.borderSoft,
            ),
          ),
          child: Text(
            '$selectedCount đã chọn',
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selectedCount > 0
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const Spacer(),
        if (onSelectAll != null)
          TextButton(
            onPressed: onSelectAll,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              'Chọn $totalVisible',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        if (onClear != null)
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              'Bỏ chọn',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.selected,
    required this.config,
    required this.onToggle,
    required this.onChanged,
    required this.onPickTime,
    this.schedule,
  });

  final EmployeeSummary employee;
  final bool selected;
  final _EmpDeployConfig config;
  final DayShiftSchedule? schedule;
  final VoidCallback onToggle;
  final ValueChanged<_EmpDeployConfig> onChanged;
  final Future<TimeOfDay?> Function(
    TimeOfDay? initial,
    String label, {
    TimeOfDay? suggested,
  }) onPickTime;

  String get _subtitle {
    final parts = <String>[
      if ((employee.employeeCode ?? '').isNotEmpty) employee.employeeCode!,
      if ((employee.departmentName ?? '').isNotEmpty) employee.departmentName!,
    ];
    return parts.join(' · ');
  }

  _EmpDeployConfig _copy({
    String? timeMode,
    String? insideScope,
    TimeOfDay? outsideStart,
    TimeOfDay? outsideEnd,
    TimeOfDay? morningStart,
    TimeOfDay? morningEnd,
    TimeOfDay? afternoonStart,
    TimeOfDay? afternoonEnd,
  }) {
    return (
      timeMode: timeMode ?? config.timeMode,
      insideScope: insideScope ?? config.insideScope,
      outsideStart: outsideStart ?? config.outsideStart,
      outsideEnd: outsideEnd ?? config.outsideEnd,
      morningStart: morningStart ?? config.morningStart,
      morningEnd: morningEnd ?? config.morningEnd,
      afternoonStart: afternoonStart ?? config.afternoonStart,
      afternoonEnd: afternoonEnd ?? config.afternoonEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutside = config.timeMode == 'OUTSIDE';
    final showMorning =
        !isOutside && (config.insideScope == 'MORNING' || config.insideScope == 'FULL_DAY');
    final showAfternoon = !isOutside &&
        (config.insideScope == 'AFTERNOON' || config.insideScope == 'FULL_DAY');

    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.borderSoft,
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected ? AppShadows.soft : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    _CheckDot(selected: selected),
                    const SizedBox(width: 10),
                    AppAvatar(
                      name: employee.fullName,
                      imageUrl: employee.avatarUrl,
                      size: 40,
                      showShadow: false,
                      borderWidth: 1.5,
                      borderColor: selected
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (selected)
                      Flexible(
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.brChip,
                          ),
                          child: Text(
                            _configSummary(config),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SegChip(
                          label: 'Ngoài ca',
                          icon: Icons.nights_stay_rounded,
                          selected: isOutside,
                          onTap: () =>
                              onChanged(_copy(timeMode: 'OUTSIDE')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SegChip(
                          label: 'Trong ca',
                          icon: Icons.work_history_rounded,
                          selected: !isOutside,
                          onTap: () => onChanged(
                            _withInsideTimes(
                              _copy(timeMode: 'INSIDE'),
                              schedule,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isOutside) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final (i, item) in [
                          ('MORNING', 'Sáng'),
                          ('AFTERNOON', 'Chiều'),
                          ('FULL_DAY', 'Cả ngày'),
                        ].indexed) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: _MiniChip(
                              label: item.$2,
                              selected: config.insideScope == item.$1,
                              onTap: () =>
                                  onChanged(_copy(insideScope: item.$1)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (isOutside)
                    _TimePair(
                      startLabel: _fmtHm(config.outsideStart),
                      endLabel: _fmtHm(config.outsideEnd),
                      tint: AppColors.primary,
                      onPickStart: () async {
                        final t = await onPickTime(
                            config.outsideStart, 'Ngoài ca – bắt đầu');
                        if (t != null) onChanged(_copy(outsideStart: t));
                      },
                      onPickEnd: () async {
                        final t = await onPickTime(
                            config.outsideEnd, 'Ngoài ca – kết thúc');
                        if (t != null) onChanged(_copy(outsideEnd: t));
                      },
                    ),
                  if (showMorning)
                    _TimePair(
                      title: 'Ca sáng',
                      icon: Icons.wb_sunny_rounded,
                      startLabel: _fmtHm(config.morningStart),
                      endLabel: _fmtHm(config.morningEnd),
                      tint: AppColors.warning,
                      onPickStart: () async {
                        final t = await onPickTime(
                          config.morningStart,
                          'Ca sáng – bắt đầu',
                          suggested: _parseHm(schedule?.morningStart),
                        );
                        if (t != null) onChanged(_copy(morningStart: t));
                      },
                      onPickEnd: () async {
                        final t = await onPickTime(
                          config.morningEnd,
                          'Ca sáng – kết thúc',
                          suggested: _parseHm(schedule?.morningEnd),
                        );
                        if (t != null) onChanged(_copy(morningEnd: t));
                      },
                    ),
                  if (showAfternoon) ...[
                    if (showMorning) const SizedBox(height: 8),
                    _TimePair(
                      title: 'Ca chiều',
                      icon: Icons.wb_twilight,
                      startLabel: _fmtHm(config.afternoonStart),
                      endLabel: _fmtHm(config.afternoonEnd),
                      tint: AppColors.info,
                      onPickStart: () async {
                        final t = await onPickTime(
                          config.afternoonStart,
                          'Ca chiều – bắt đầu',
                          suggested: _parseHm(schedule?.afternoonStart),
                        );
                        if (t != null) {
                          onChanged(_copy(afternoonStart: t));
                        }
                      },
                      onPickEnd: () async {
                        final t = await onPickTime(
                          config.afternoonEnd,
                          'Ca chiều – kết thúc',
                          suggested: _parseHm(schedule?.afternoonEnd),
                        );
                        if (t != null) onChanged(_copy(afternoonEnd: t));
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.reasonController,
    required this.saving,
    required this.canSubmit,
    required this.selectedCount,
    this.onCancel,
    this.onSubmit,
  });

  final TextEditingController reasonController;
  final bool saving;
  final bool canSubmit;
  final int selectedCount;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14172033),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 1,
                style: AppTypography.body(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Nội dung điều động *',
                  hintStyle: AppTypography.caption(),
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.brControl,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brControl,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brControl,
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.brControl,
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.brControl,
                        boxShadow: canSubmit ? AppShadows.button : null,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onSubmit,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          saving
                              ? 'Đang gửi…'
                              : selectedCount == 0
                                  ? 'Chọn nhân viên'
                                  : 'Điều động $selectedCount',
                          style: AppTypography.style(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.actionDisabledBackground,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.brControl,
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
      ),
    );
  }
}
