import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/app_time_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/search_field.dart';
import '../../../shared/models/attendance_models.dart';
import '../../../shared/models/employee.dart';
import '../../employees/data/employee_repository.dart';
import '../data/attendance_repository.dart';

List<AppOptionItem> _dutyTypeOptions(List<DutyShiftTypeOption> types) {
  return types
      .map(
        (t) => AppOptionItem(
          value: t.code,
          label: t.label,
          subtitle: t.grantsWorkUnits ? 'Có cộng công trực (+0,33)' : 'Không cộng công',
          icon: Icons.nightlight_round,
        ),
      )
      .toList();
}

List<AppOptionItem> _roleOptions(List<DutyShiftRoleTierOption> roles) {
  return roles
      .map(
        (r) => AppOptionItem(
          value: r.code,
          label: r.label,
          icon: Icons.badge_outlined,
        ),
      )
      .toList();
}

enum BulkSupplementMode { duty, quangTrung }

/// Sheet bổ sung hàng loạt: Công trực + Công Quang Trung (cùng API web).
Future<void> showBulkWorkSupplementSheet(
  BuildContext context, {
  required DateTime workDate,
  DayShiftSchedule? schedule,
  BulkSupplementMode initialMode = BulkSupplementMode.duty,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BulkWorkSupplementSheet(
      workDate: workDate,
      schedule: schedule,
      initialMode: initialMode,
    ),
  );
}

typedef _EmpDutyConfig = ({String shiftTypeCode, String roleTierCode});

class _BulkWorkSupplementSheet extends ConsumerStatefulWidget {
  const _BulkWorkSupplementSheet({
    required this.workDate,
    required this.initialMode,
    this.schedule,
  });

  final DateTime workDate;
  final DayShiftSchedule? schedule;
  final BulkSupplementMode initialMode;

  @override
  ConsumerState<_BulkWorkSupplementSheet> createState() =>
      _BulkWorkSupplementSheetState();
}

class _BulkWorkSupplementSheetState
    extends ConsumerState<_BulkWorkSupplementSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late BulkSupplementMode _mode;

  final _noteController = TextEditingController();
  final _employeesQueryController = TextEditingController();

  List<DutyShiftTypeOption> _types = const [];
  String _quickShiftTypeCode = '';
  String _quickRoleTierCode = '';

  List<EmployeeSummary> _employees = const [];
  final Set<int> _selectedIds = {};
  final Map<int, _EmpDutyConfig> _configByEmp = {};

  // Quang Trung
  DayShiftSchedule? _schedule;
  String _updateKind = 'MORNING_SUPPLEMENT';
  TimeOfDay? _morningStart;
  TimeOfDay? _morningEnd;
  TimeOfDay? _afternoonStart;
  TimeOfDay? _afternoonEnd;

  static const _qtKinds = <({String key, String label, IconData icon})>[
    (key: 'MORNING_SUPPLEMENT', label: 'Ca sáng', icon: Icons.wb_sunny_rounded),
    (
      key: 'AFTERNOON_SUPPLEMENT',
      label: 'Ca chiều',
      icon: Icons.wb_twilight
    ),
    (
      key: 'FULL_DAY_SUPPLEMENT',
      label: 'Cả ngày',
      icon: Icons.calendar_view_day_rounded
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _schedule = widget.schedule;
    _init();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _employeesQueryController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseHm(String? hhmm) {
    final text = hhmm?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _defaultRoleFor(String typeCode) {
    final tiers = _roleTiersFor(typeCode);
    return tiers.isNotEmpty ? tiers.first.code : '';
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final attRepo = ref.read(attendanceRepositoryProvider);
      final types = await attRepo.dutyShiftTypes();
      final employees = await _loadEmployees(query: '');

      DayShiftSchedule? schedule = _schedule;
      schedule ??= await attRepo.daySchedule(date: widget.workDate);

      final quickType = types.isNotEmpty ? types.first.code : '';
      final quickRole = types.isNotEmpty
          ? (types.first.roleTiers.isNotEmpty
              ? types.first.roleTiers.first.code
              : '')
          : '';

      setState(() {
        _types = types;
        _quickShiftTypeCode = quickType;
        _quickRoleTierCode = quickRole;
        _employees = employees;
        _schedule = schedule;
        _morningStart = _parseHm(schedule?.morningStart);
        _morningEnd = _parseHm(schedule?.morningEnd);
        _afternoonStart = _parseHm(schedule?.afternoonStart);
        _afternoonEnd = _parseHm(schedule?.afternoonEnd);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<EmployeeSummary>> _loadEmployees({required String query}) async {
    final repo = ref.read(employeeRepositoryProvider);
    final page = await repo.list(
      page: 0,
      size: 200,
      query: query.trim().isEmpty ? null : query.trim(),
      statusGroup: 'OFFICIAL',
    );
    return page.content;
  }

  List<DutyShiftRoleTierOption> _roleTiersFor(String typeCode) {
    for (final t in _types) {
      if (t.code == typeCode) return t.roleTiers;
    }
    return const [];
  }

  bool _dutyConfigReady(_EmpDutyConfig cfg) {
    if (cfg.shiftTypeCode.isEmpty) return false;
    final tiers = _roleTiersFor(cfg.shiftTypeCode);
    if (tiers.isEmpty) return true;
    return cfg.roleTierCode.isNotEmpty;
  }

  void _setMode(BulkSupplementMode mode) {
    if (_mode == mode) return;
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
  }

  void _toggleEmp(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _configByEmp.remove(id);
      } else {
        _selectedIds.add(id);
        if (_mode == BulkSupplementMode.duty) {
          _configByEmp[id] = (
            shiftTypeCode: _quickShiftTypeCode,
            roleTierCode: _quickRoleTierCode.isNotEmpty
                ? _quickRoleTierCode
                : _defaultRoleFor(_quickShiftTypeCode),
          );
        }
      }
    });
  }

  void _selectAllVisible() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final emp in _employees) {
        if (_selectedIds.add(emp.id) && _mode == BulkSupplementMode.duty) {
          _configByEmp[emp.id] = (
            shiftTypeCode: _quickShiftTypeCode,
            roleTierCode: _quickRoleTierCode.isNotEmpty
                ? _quickRoleTierCode
                : _defaultRoleFor(_quickShiftTypeCode),
          );
        }
      }
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
    if (_quickShiftTypeCode.isEmpty || _selectedIds.isEmpty) return;
    final role = _quickRoleTierCode.isNotEmpty
        ? _quickRoleTierCode
        : _defaultRoleFor(_quickShiftTypeCode);
    HapticFeedback.mediumImpact();
    setState(() {
      for (final id in _selectedIds) {
        _configByEmp[id] = (
          shiftTypeCode: _quickShiftTypeCode,
          roleTierCode: role,
        );
      }
    });
  }

  void _setEmpShiftType(int id, String code) {
    setState(() {
      final cur = _configByEmp[id];
      final roleTiers = _roleTiersFor(code);
      final roleCode = cur != null &&
              roleTiers.any((r) => r.code == cur.roleTierCode)
          ? cur.roleTierCode
          : (roleTiers.isNotEmpty ? roleTiers.first.code : '');
      _configByEmp[id] = (shiftTypeCode: code, roleTierCode: roleCode);
      if (code.isNotEmpty) _selectedIds.add(id);
    });
  }

  void _setEmpRoleTier(int id, String code) {
    setState(() {
      final cur = _configByEmp[id] ??
          (shiftTypeCode: _quickShiftTypeCode, roleTierCode: '');
      _configByEmp[id] = (
        shiftTypeCode: cur.shiftTypeCode,
        roleTierCode: code,
      );
    });
  }

  List<({int employeeId, String shiftTypeCode, String? roleTierCode})>
      get _dutySubmitItems {
    final items =
        <({int employeeId, String shiftTypeCode, String? roleTierCode})>[];
    for (final id in _selectedIds) {
      final cfg = _configByEmp[id];
      if (cfg != null && _dutyConfigReady(cfg)) {
        items.add((
          employeeId: id,
          shiftTypeCode: cfg.shiftTypeCode,
          roleTierCode:
              cfg.roleTierCode.isEmpty ? null : cfg.roleTierCode,
        ));
      }
    }
    return items;
  }

  Future<void> _pickTime({
    required TimeOfDay? current,
    required String title,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showAppTimePicker(
      context,
      initialTime: current ?? TimeOfDay.now(),
      title: title,
      suggestedTime: current,
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _saveDuty(
    List<({int employeeId, String shiftTypeCode, String? roleTierCode})>
        items,
  ) async {
    setState(() => _saving = true);
    try {
      await ref.read(attendanceRepositoryProvider).bulkUpsertDutyShifts(
            workDate: widget.workDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            items: items,
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Đã lưu công trực cho ${items.length} nhân viên',
        isSuccess: true,
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _saveQuangTrung() async {
    if (_selectedIds.isEmpty) {
      showAppSnackBar(context, 'Vui lòng chọn ít nhất 1 nhân viên',
          isError: true);
      return;
    }

    final needMorning = _updateKind != 'AFTERNOON_SUPPLEMENT';
    final needAfternoon = _updateKind != 'MORNING_SUPPLEMENT';
    if (needMorning && (_morningStart == null || _morningEnd == null)) {
      showAppSnackBar(context, 'Vui lòng chọn đủ giờ ca sáng', isError: true);
      return;
    }
    if (needAfternoon && (_afternoonStart == null || _afternoonEnd == null)) {
      showAppSnackBar(context, 'Vui lòng chọn đủ giờ ca chiều', isError: true);
      return;
    }

    final requestedStart = needMorning
        ? _fmtTime(_morningStart!)
        : _fmtTime(_afternoonStart!);
    final requestedEnd =
        needMorning ? _fmtTime(_morningEnd!) : _fmtTime(_afternoonEnd!);
    final afternoonStart =
        _updateKind == 'FULL_DAY_SUPPLEMENT' ? _fmtTime(_afternoonStart!) : null;
    final afternoonEnd =
        _updateKind == 'FULL_DAY_SUPPLEMENT' ? _fmtTime(_afternoonEnd!) : null;

    setState(() => _saving = true);
    try {
      await ref.read(attendanceRepositoryProvider).bulkApplyQuangTrungSupplement(
            workDate: widget.workDate,
            updateKind: _updateKind,
            reason: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            requestedStart: requestedStart,
            requestedEnd: requestedEnd,
            requestedAfternoonStart: afternoonStart,
            requestedAfternoonEnd: afternoonEnd,
            employeeIds: _selectedIds.toList(),
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Đã lưu công Quang Trung cho ${_selectedIds.length} nhân viên',
        isSuccess: true,
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDuty = _mode == BulkSupplementMode.duty;
    final dutyItems = _dutySubmitItems;
    final missingDuty = _selectedIds.length - dutyItems.length;
    final quickRoleTiers = _roleTiersFor(_quickShiftTypeCode);
    final accent = isDuty ? AppColors.primary : AppColors.success;
    final canSaveDuty =
        !_saving && dutyItems.isNotEmpty && missingDuty == 0;
    final canSaveQt = !_saving && _selectedIds.isNotEmpty;
    final canSave = isDuty ? canSaveDuty : canSaveQt;
    final onBrand = Theme.of(context).colorScheme.onPrimary;

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
              mode: _mode,
              onBrand: onBrand,
              onModeChanged: _setMode,
              onClose: _saving ? null : () => Navigator.pop(context),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Center(
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
                    if (isDuty) ...[
                      _QuickAssignCard(
                        accent: accent,
                        selectedCount: _selectedIds.length,
                        shiftTypeCode: _quickShiftTypeCode,
                        roleTierCode: _quickRoleTierCode,
                        types: _types,
                        roleTiers: quickRoleTiers,
                        onShiftChanged: (v) => setState(() {
                          _quickShiftTypeCode = v;
                          _quickRoleTierCode =
                              _defaultRoleFor(_quickShiftTypeCode);
                        }),
                        onRoleChanged: (v) =>
                            setState(() => _quickRoleTierCode = v),
                        onApply: _selectedIds.isEmpty
                            ? null
                            : _applyQuickToSelected,
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      _QtKindSection(
                        updateKind: _updateKind,
                        onChanged: (v) => setState(() => _updateKind = v),
                      ),
                      const SizedBox(height: 10),
                      _QtTimeSection(
                        updateKind: _updateKind,
                        morningStart: _morningStart,
                        morningEnd: _morningEnd,
                        afternoonStart: _afternoonStart,
                        afternoonEnd: _afternoonEnd,
                        onPickMorningStart: () => _pickTime(
                          current: _morningStart,
                          title: 'Vào ca sáng',
                          onPicked: (t) => _morningStart = t,
                        ),
                        onPickMorningEnd: () => _pickTime(
                          current: _morningEnd,
                          title: 'Ra ca sáng',
                          onPicked: (t) => _morningEnd = t,
                        ),
                        onPickAfternoonStart: () => _pickTime(
                          current: _afternoonStart,
                          title: 'Vào ca chiều',
                          onPicked: (t) => _afternoonStart = t,
                        ),
                        onPickAfternoonEnd: () => _pickTime(
                          current: _afternoonEnd,
                          title: 'Ra ca chiều',
                          onPicked: (t) => _afternoonEnd = t,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    AppSearchField(
                      controller: _employeesQueryController,
                      hintText: 'Tìm nhân viên…',
                      dense: true,
                      onChanged: (v) {
                        _loadEmployees(query: v).then((list) {
                          if (!mounted) return;
                          setState(() => _employees = list);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _SelectionToolbar(
                      readyCount: isDuty ? dutyItems.length : _selectedIds.length,
                      selectedCount: _selectedIds.length,
                      missingCount: isDuty ? missingDuty : 0,
                      totalVisible: _employees.length,
                      readyLabel: isDuty ? 'sẵn sàng' : 'đã chọn',
                      onSelectAll:
                          _employees.isEmpty ? null : _selectAllVisible,
                      onClear: _selectedIds.isEmpty ? null : _clearSelection,
                    ),
                    const SizedBox(height: 8),
                    if (_employees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
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
                        final cfg = _configByEmp[emp.id];
                        final shiftCode = cfg?.shiftTypeCode ?? '';
                        final roleCode = cfg?.roleTierCode ?? '';
                        final roleTiers = _roleTiersFor(shiftCode);
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _employees.length - 1 ? 0 : 8,
                          ),
                          child: _EmployeeTile(
                            employee: emp,
                            selected: ticked,
                            showDutyConfig: isDuty,
                            shiftCode: shiftCode,
                            roleCode: roleCode,
                            types: _types,
                            roleTiers: roleTiers,
                            accent: accent,
                            onToggle: () => _toggleEmp(emp.id),
                            onShiftChanged: (v) =>
                                _setEmpShiftType(emp.id, v),
                            onRoleChanged: (v) =>
                                _setEmpRoleTier(emp.id, v),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              _Footer(
                noteController: _noteController,
                noteHint: isDuty ? 'Ghi chú (tuỳ chọn)' : 'Lý do (tuỳ chọn)',
                saving: _saving,
                canSave: canSave,
                accent: accent,
                saveLabel: () {
                  if (_saving) return 'Đang lưu…';
                  if (isDuty) {
                    if (missingDuty > 0) {
                      return '$missingDuty người thiếu loại ca/vị trí';
                    }
                    if (dutyItems.isEmpty) return 'Chọn nhân viên để lưu';
                    return 'Lưu ${dutyItems.length} người';
                  }
                  if (_selectedIds.isEmpty) return 'Chọn nhân viên để lưu';
                  return 'Lưu ${_selectedIds.length} người';
                }(),
                onCancel: _saving ? null : () => Navigator.pop(context),
                onSave: !canSave
                    ? null
                    : () => isDuty
                        ? _saveDuty(dutyItems)
                        : _saveQuangTrung(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── UI pieces ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.workDate,
    required this.mode,
    required this.onBrand,
    required this.onModeChanged,
    this.onClose,
  });

  final DateTime workDate;
  final BulkSupplementMode mode;
  final Color onBrand;
  final ValueChanged<BulkSupplementMode> onModeChanged;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isDuty = mode == BulkSupplementMode.duty;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDuty
            ? AppGradients.brand
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.successDark,
                  AppColors.success,
                  Color(0xFF2AA67A),
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: (isDuty ? AppColors.primaryDark : AppColors.successDark)
                .withValues(alpha: 0.2),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
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
                      child: Icon(
                        isDuty
                            ? Icons.nightlight_round
                            : Icons.location_on_rounded,
                        color: onBrand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BỔ SUNG HÀNG LOẠT',
                            style: AppTypography.style(
                              color: onBrand.withValues(alpha: 0.72),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDuty ? 'Công trực' : 'Công Quang Trung',
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
                const SizedBox(height: 12),
                Container(
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: onBrand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: onBrand.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeTab(
                          label: 'Công trực',
                          icon: Icons.nightlight_round,
                          selected: isDuty,
                          onBrand: onBrand,
                          onTap: () => onModeChanged(BulkSupplementMode.duty),
                        ),
                      ),
                      Expanded(
                        child: _ModeTab(
                          label: 'Quang Trung',
                          icon: Icons.location_on_rounded,
                          selected: !isDuty,
                          onBrand: onBrand,
                          onTap: () =>
                              onModeChanged(BulkSupplementMode.quangTrung),
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
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onBrand,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color onBrand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.primaryDark
                    : onBrand.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.primaryDark
                      : onBrand.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAssignCard extends StatelessWidget {
  const _QuickAssignCard({
    required this.accent,
    required this.selectedCount,
    required this.shiftTypeCode,
    required this.roleTierCode,
    required this.types,
    required this.roleTiers,
    required this.onShiftChanged,
    required this.onRoleChanged,
    this.onApply,
  });

  final Color accent;
  final int selectedCount;
  final String shiftTypeCode;
  final String roleTierCode;
  final List<DutyShiftTypeOption> types;
  final List<DutyShiftRoleTierOption> roleTiers;
  final ValueChanged<String> onShiftChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
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
                  color: accent,
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
                'Chọn rồi áp dụng',
                style: AppTypography.style(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppOptionField(
            label: 'Loại ca',
            pickerTitle: 'Chọn loại ca trực',
            pickerSubtitle: 'Hiển thị đủ tên — không bị cắt chữ',
            value: shiftTypeCode.isEmpty ? null : shiftTypeCode,
            options: _dutyTypeOptions(types),
            hint: 'Chọn loại ca',
            accent: accent,
            dense: true,
            onChanged: onShiftChanged,
          ),
          if (roleTiers.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppOptionField(
              label: 'Vị trí',
              pickerTitle: 'Chọn vị trí trực',
              value: roleTierCode.isEmpty ? null : roleTierCode,
              options: _roleOptions(roleTiers),
              hint: 'Chọn vị trí',
              accent: accent,
              dense: true,
              requiredMark: true,
              onChanged: onRoleChanged,
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: Text(
                selectedCount == 0
                    ? 'Chọn nhân viên để áp dụng'
                    : 'Áp dụng cho $selectedCount đã chọn',
                style: AppTypography.style(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.actionDisabledBackground,
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

class _QtKindSection extends StatelessWidget {
  const _QtKindSection({
    required this.updateKind,
    required this.onChanged,
  });

  final String updateKind;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loại bổ sung',
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Áp dụng trực tiếp, không trừ phạt quên chấm',
            style: AppTypography.style(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, k) in _BulkWorkSupplementSheetState._qtKinds.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _KindChip(
                    label: k.label,
                    icon: k.icon,
                    selected: updateKind == k.key,
                    onTap: () => onChanged(k.key),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
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
          ? AppColors.success.withValues(alpha: 0.12)
          : AppColors.surfaceAlt,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brControl,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(
              color: selected
                  ? AppColors.success.withValues(alpha: 0.45)
                  : AppColors.borderSoft,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.successDark : AppColors.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.successDark
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

class _QtTimeSection extends StatelessWidget {
  const _QtTimeSection({
    required this.updateKind,
    required this.morningStart,
    required this.morningEnd,
    required this.afternoonStart,
    required this.afternoonEnd,
    required this.onPickMorningStart,
    required this.onPickMorningEnd,
    required this.onPickAfternoonStart,
    required this.onPickAfternoonEnd,
  });

  final String updateKind;
  final TimeOfDay? morningStart;
  final TimeOfDay? morningEnd;
  final TimeOfDay? afternoonStart;
  final TimeOfDay? afternoonEnd;
  final VoidCallback onPickMorningStart;
  final VoidCallback onPickMorningEnd;
  final VoidCallback onPickAfternoonStart;
  final VoidCallback onPickAfternoonEnd;

  String _label(TimeOfDay? t) {
    if (t == null) return 'Chọn giờ';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final showMorning = updateKind != 'AFTERNOON_SUPPLEMENT';
    final showAfternoon = updateKind != 'MORNING_SUPPLEMENT';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Khung giờ công',
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Áp dụng chung cho mọi nhân viên đã chọn',
            style: AppTypography.style(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (showMorning) ...[
            const SizedBox(height: 12),
            _TimeRow(
              title: 'Ca sáng',
              icon: Icons.wb_sunny_rounded,
              tint: AppColors.warning,
              startLabel: _label(morningStart),
              endLabel: _label(morningEnd),
              onPickStart: onPickMorningStart,
              onPickEnd: onPickMorningEnd,
            ),
          ],
          if (showAfternoon) ...[
            const SizedBox(height: 10),
            _TimeRow(
              title: 'Ca chiều',
              icon: Icons.wb_twilight,
              tint: AppColors.info,
              startLabel: _label(afternoonStart),
              endLabel: _label(afternoonEnd),
              onPickStart: onPickAfternoonStart,
              onPickEnd: onPickAfternoonEnd,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.title,
    required this.icon,
    required this.tint,
    required this.startLabel,
    required this.endLabel,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final String startLabel;
  final String endLabel;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

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
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: tint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Vào ca',
                  value: startLabel,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeButton(
                  label: 'Ra ca',
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

class _TimeButton extends StatelessWidget {
  const _TimeButton({
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

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.readyCount,
    required this.selectedCount,
    required this.missingCount,
    required this.totalVisible,
    required this.readyLabel,
    this.onSelectAll,
    this.onClear,
  });

  final int readyCount;
  final int selectedCount;
  final int missingCount;
  final int totalVisible;
  final String readyLabel;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(
          icon: Icons.check_circle_outline_rounded,
          label: '$readyCount $readyLabel',
          color: AppColors.success,
          on: readyCount > 0,
        ),
        const SizedBox(width: 6),
        _Pill(
          icon: Icons.touch_app_rounded,
          label: '$selectedCount chọn',
          color: missingCount > 0 ? AppColors.warning : AppColors.primary,
          on: selectedCount > 0,
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.on,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: 0.12) : AppColors.surfaceHigh,
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: on ? color.withValues(alpha: 0.22) : AppColors.borderSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: on ? color : AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: on ? color : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.selected,
    required this.showDutyConfig,
    required this.shiftCode,
    required this.roleCode,
    required this.types,
    required this.roleTiers,
    required this.accent,
    required this.onToggle,
    required this.onShiftChanged,
    required this.onRoleChanged,
  });

  final EmployeeSummary employee;
  final bool selected;
  final bool showDutyConfig;
  final String shiftCode;
  final String roleCode;
  final List<DutyShiftTypeOption> types;
  final List<DutyShiftRoleTierOption> roleTiers;
  final Color accent;
  final VoidCallback onToggle;
  final ValueChanged<String> onShiftChanged;
  final ValueChanged<String> onRoleChanged;

  String get _subtitle {
    final parts = <String>[
      if ((employee.employeeCode ?? '').isNotEmpty) employee.employeeCode!,
      if ((employee.departmentName ?? '').isNotEmpty) employee.departmentName!,
    ];
    return parts.join(' · ');
  }

  String get _shiftLabel {
    for (final t in types) {
      if (t.code == shiftCode) return t.label;
    }
    return shiftCode;
  }

  String get _roleLabel {
    for (final r in roleTiers) {
      if (r.code == roleCode) return r.label;
    }
    return roleCode;
  }

  @override
  Widget build(BuildContext context) {
    final ready = !showDutyConfig
        ? selected
        : selected &&
            shiftCode.isNotEmpty &&
            (roleTiers.isEmpty || roleCode.isNotEmpty);

    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.3)
              : AppColors.borderSoft,
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected ? AppShadows.soft : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              InkWell(
                onTap: onToggle,
                borderRadius: AppRadius.brControl,
                child: Row(
                  children: [
                    _CheckDot(selected: selected, color: accent),
                    const SizedBox(width: 10),
                    AppAvatar(
                      name: employee.fullName,
                      imageUrl: employee.avatarUrl,
                      size: 40,
                      showShadow: false,
                      borderWidth: 1.5,
                      borderColor: selected
                          ? accent.withValues(alpha: 0.35)
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
                    if (selected && showDutyConfig)
                      Flexible(
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ready
                                ? AppColors.successLight
                                : AppColors.errorLight,
                            borderRadius: AppRadius.brChip,
                          ),
                          child: Text(
                            ready
                                ? (roleCode.isNotEmpty
                                    ? _roleLabel
                                    : _shiftLabel)
                                : 'Thiếu vị trí',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: ready
                                  ? AppColors.successDark
                                  : AppColors.errorText,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected && showDutyConfig) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: accent.withValues(alpha: 0.12)),
                const SizedBox(height: 10),
                AppOptionField(
                  label: 'Loại ca',
                  pickerTitle: 'Loại ca trực — ${employee.fullName}',
                  value: shiftCode.isEmpty ? null : shiftCode,
                  options: _dutyTypeOptions(types),
                  hint: 'Chọn loại ca',
                  accent: accent,
                  dense: true,
                  onChanged: onShiftChanged,
                ),
                if (roleTiers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AppOptionField(
                    label: 'Vị trí',
                    pickerTitle: 'Vị trí trực — ${employee.fullName}',
                    value: roleCode.isEmpty ? null : roleCode,
                    options: _roleOptions(roleTiers),
                    hint: 'Chọn vị trí',
                    accent: accent,
                    dense: true,
                    requiredMark: true,
                    onChanged: onRoleChanged,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : AppColors.border,
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
    required this.noteController,
    required this.noteHint,
    required this.saving,
    required this.canSave,
    required this.accent,
    required this.saveLabel,
    this.onCancel,
    this.onSave,
  });

  final TextEditingController noteController;
  final String noteHint;
  final bool saving;
  final bool canSave;
  final Color accent;
  final String saveLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

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
                controller: noteController,
                maxLines: 1,
                style: AppTypography.body(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: noteHint,
                  hintStyle: AppTypography.caption(),
                  prefixIcon: const Icon(Icons.notes_rounded,
                      size: 18, color: AppColors.textTertiary),
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
                    borderSide:
                        BorderSide(color: accent, width: 1.3),
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
                    child: ElevatedButton(
                      onPressed: onSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: accent,
                        disabledBackgroundColor:
                            AppColors.actionDisabledBackground,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.brControl,
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              saveLabel,
                              style: AppTypography.style(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: canSave
                                    ? Colors.white
                                    : AppColors.textTertiary,
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
