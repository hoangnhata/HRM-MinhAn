import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/search_field.dart';
import '../../../shared/models/attendance_models.dart';
import 'attendance_enums.dart';
import 'attendance_request_list_filters.dart';

/// Thanh công cụ mobile: tìm kiếm + lọc + (tuỳ chọn) chọn nhiều.
class AttendanceRequestToolbar extends StatefulWidget {
  const AttendanceRequestToolbar({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
    required this.resultCount,
    required this.sourceItems,
    this.selectMode = false,
    this.onSelectModeChanged,
    this.selectedCount = 0,
    this.selectableCount = 0,
    this.typeOptions = const [],
    this.searchHint = 'Tìm tên, nội dung…',
    this.leading,
  });

  final AttendanceRequestListFilters filters;
  final ValueChanged<AttendanceRequestListFilters> onFiltersChanged;
  final int resultCount;
  final List<AttendanceWorkRequest> sourceItems;
  final bool selectMode;
  final ValueChanged<bool>? onSelectModeChanged;
  final int selectedCount;
  final int selectableCount;
  final List<({String value, String label})> typeOptions;
  final String searchHint;

  /// Chip chế độ (Chờ duyệt / Đã xử lý) — cùng hàng meta với «N đơn».
  final Widget? leading;

  @override
  State<AttendanceRequestToolbar> createState() =>
      _AttendanceRequestToolbarState();
}

class _AttendanceRequestToolbarState extends State<AttendanceRequestToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.query);
  }

  @override
  void didUpdateWidget(covariant AttendanceRequestToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filters.query != _searchController.text &&
        widget.filters.query.isEmpty) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final next = await showAttendanceRequestFilterSheet(
      context,
      initial: widget.filters,
      sourceItems: widget.sourceItems,
      typeOptions: widget.typeOptions,
    );
    if (next != null) widget.onFiltersChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final filters = widget.filters;
    final enableSelect = widget.onSelectModeChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                hintText: widget.searchHint,
                dense: true,
                onChanged: (q) =>
                    widget.onFiltersChanged(filters.copyWith(query: q)),
              ),
            ),
            const SizedBox(width: 6),
            _ToolIconButton(
              tooltip: 'Bộ lọc',
              icon: Icons.tune_rounded,
              active: filters.hasAdvancedFilters,
              badge: filters.advancedFilterCount > 0
                  ? '${filters.advancedFilterCount}'
                  : null,
              onTap: _openFilterSheet,
            ),
            if (enableSelect) ...[
              const SizedBox(width: 4),
              _ToolIconButton(
                tooltip: widget.selectMode ? 'Huỷ chọn' : 'Chọn đơn',
                icon: widget.selectMode
                    ? Icons.close_rounded
                    : Icons.checklist_rtl_rounded,
                active: widget.selectMode,
                onTap: widget.selectableCount == 0 && !widget.selectMode
                    ? null
                    : () => widget.onSelectModeChanged!(!widget.selectMode),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (widget.leading != null) ...[
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: widget.leading!,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.selectMode
                  ? (widget.selectedCount == 0
                      ? '${widget.resultCount} · chọn'
                      : 'Chọn ${widget.selectedCount}/${widget.resultCount}')
                  : '${widget.resultCount} đơn',
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (filters.isActive)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  widget.onFiltersChanged(AttendanceRequestListFilters.empty);
                },
                child: Text(
                  'Xóa lọc',
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        if (filters.hasAdvancedFilters) ...[
          const SizedBox(height: 6),
          _ActiveFilterChips(
            filters: filters,
            typeOptions: widget.typeOptions,
            onChanged: widget.onFiltersChanged,
          ),
        ],
      ],
    );
  }
}

class _ToolIconButton extends StatelessWidget {
  const _ToolIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppColors.primary
            : AppColors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: !enabled
                      ? AppColors.textTertiary
                      : active
                          ? Colors.white
                          : AppColors.textSecondary,
                ),
                if (badge != null)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: active ? Colors.white : AppColors.warning,
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        badge!,
                        style: AppTypography.style(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: active ? AppColors.primary : Colors.white,
                        ),
                      ),
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

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.filters,
    required this.typeOptions,
    required this.onChanged,
  });

  final AttendanceRequestListFilters filters;
  final List<({String value, String label})> typeOptions;
  final ValueChanged<AttendanceRequestListFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filters.requestType.isNotEmpty) {
      final match = typeOptions.where((t) => t.value == filters.requestType);
      final label = match.isEmpty ? null : match.first.label;
      chips.add(
        _RemovableChip(
          label: label ??
              AttendanceEnums.requestTypeLabel(filters.requestType),
          onRemove: () => onChanged(filters.copyWith(requestType: '')),
        ),
      );
    }
    if (filters.department.isNotEmpty) {
      chips.add(
        _RemovableChip(
          label: filters.department,
          onRemove: () => onChanged(filters.copyWith(department: '')),
        ),
      );
    }
    if (filters.status.isNotEmpty) {
      chips.add(
        _RemovableChip(
          label: AttendanceEnums.statusLabel(filters.status),
          onRemove: () => onChanged(filters.copyWith(status: '')),
        ),
      );
    }
    if (filters.dateFrom != null) {
      chips.add(
        _RemovableChip(
          label: 'Từ ${AppFormat.date(filters.dateFrom)}',
          onRemove: () => onChanged(filters.copyWith(clearDateFrom: true)),
        ),
      );
    }
    if (filters.dateTo != null) {
      chips.add(
        _RemovableChip(
          label: 'Đến ${AppFormat.date(filters.dateTo)}',
          onRemove: () => onChanged(filters.copyWith(clearDateTo: true)),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in chips) ...[
            c,
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onRemove,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<AttendanceRequestListFilters?> showAttendanceRequestFilterSheet(
  BuildContext context, {
  required AttendanceRequestListFilters initial,
  required List<AttendanceWorkRequest> sourceItems,
  List<({String value, String label})> typeOptions = const [],
}) {
  return showAppBottomSheet<AttendanceRequestListFilters>(
    context,
    title: 'Bộ lọc đơn',
    subtitle: 'Thu hẹp danh sách theo loại, khoa và trạng thái',
    child: _FilterSheetBody(
      initial: initial,
      sourceItems: sourceItems,
      typeOptions: typeOptions,
    ),
  );
}

class _FilterSheetBody extends StatefulWidget {
  const _FilterSheetBody({
    required this.initial,
    required this.sourceItems,
    required this.typeOptions,
  });

  final AttendanceRequestListFilters initial;
  final List<AttendanceWorkRequest> sourceItems;
  final List<({String value, String label})> typeOptions;

  @override
  State<_FilterSheetBody> createState() => _FilterSheetBodyState();
}

class _FilterSheetBodyState extends State<_FilterSheetBody> {
  late AttendanceRequestListFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final initial = (from ? _draft.dateFrom : _draft.dateTo) ?? now;
    final picked = await showAppDatePicker(
      context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      title: from ? 'Từ ngày gửi' : 'Đến ngày gửi',
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
    if (picked == null) return;
    setState(() {
      _draft = from
          ? _draft.copyWith(dateFrom: picked)
          : _draft.copyWith(dateTo: picked);
    });
  }

  Future<void> _pickDepartment() async {
    final departments = attendanceDepartmentOptions(widget.sourceItems);
    final picked = await showAppOptionPicker(
      context,
      title: 'Phòng ban',
      subtitle: 'Lọc đơn theo khoa / phòng',
      selectedValue: _draft.department,
      options: [
        const AppOptionItem(
          value: '',
          label: 'Tất cả phòng ban',
          icon: Icons.apartment_outlined,
        ),
        for (final d in departments)
          AppOptionItem(
            value: d,
            label: d,
            icon: Icons.meeting_room_outlined,
          ),
      ],
    );
    if (picked == null) return;
    setState(() => _draft = _draft.copyWith(department: picked));
  }

  Future<void> _pickStatus() async {
    final statuses = attendanceStatusFilterOptions(widget.sourceItems);
    final picked = await showAppOptionPicker(
      context,
      title: 'Trạng thái',
      subtitle: 'Lọc theo tiến độ xử lý đơn',
      selectedValue: _draft.status,
      options: [
        const AppOptionItem(
          value: '',
          label: 'Tất cả trạng thái',
          icon: Icons.filter_list_rounded,
        ),
        for (final s in statuses)
          AppOptionItem(
            value: s.value,
            label: s.label,
            icon: Icons.flag_outlined,
          ),
      ],
    );
    if (picked == null) return;
    setState(() => _draft = _draft.copyWith(status: picked));
  }

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _draft = AttendanceRequestListFilters.empty.copyWith(
        query: widget.initial.query,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDept = _draft.department.isNotEmpty;
    final hasStatus = _draft.status.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.typeOptions.isNotEmpty) ...[
          const _FilterSectionLabel(
            icon: Icons.category_outlined,
            label: 'Loại đơn',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Tất cả',
                selected: _draft.requestType.isEmpty,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _draft = _draft.copyWith(requestType: ''));
                },
              ),
              for (final t in widget.typeOptions)
                _FilterChip(
                  label: t.label,
                  selected: _draft.requestType == t.value,
                  accent: AttendanceEnums.requestTypeColor(t.value),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _draft = _draft.copyWith(
                        requestType:
                            _draft.requestType == t.value ? '' : t.value,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        const _FilterSectionLabel(
          icon: Icons.tune_rounded,
          label: 'Phạm vi',
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              _OptionTile(
                icon: Icons.apartment_outlined,
                label: 'Phòng ban',
                value: hasDept ? _draft.department : 'Tất cả phòng ban',
                muted: !hasDept,
                onTap: _pickDepartment,
                showDivider: true,
              ),
              _OptionTile(
                icon: Icons.flag_outlined,
                label: 'Trạng thái',
                value: hasStatus
                    ? AttendanceEnums.statusLabel(_draft.status)
                    : 'Tất cả trạng thái',
                muted: !hasStatus,
                onTap: _pickStatus,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _FilterSectionLabel(
          icon: Icons.date_range_rounded,
          label: 'Ngày gửi',
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Từ ngày',
                    value: _draft.dateFrom,
                    onTap: () => _pickDate(from: true),
                    onClear: _draft.dateFrom == null
                        ? null
                        : () => setState(
                              () => _draft =
                                  _draft.copyWith(clearDateFrom: true),
                            ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.textTertiary.withValues(alpha: 0.8),
                  ),
                ),
                Expanded(
                  child: _DateTile(
                    label: 'Đến ngày',
                    value: _draft.dateTo,
                    onTap: () => _pickDate(from: false),
                    onClear: _draft.dateTo == null
                        ? null
                        : () => setState(
                              () =>
                                  _draft = _draft.copyWith(clearDateTo: true),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.primaryDark,
                  backgroundColor: AppColors.surfaceMuted,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Đặt lại'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(_draft);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Áp dụng'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primaryDark),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? accent.withValues(alpha: 0.12)
        : AppColors.surfaceMuted;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
    this.showDivider = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: showDivider
                ? AppRadius.brSheetTop
                : const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: muted
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: ColoredBox(
              color: AppColors.border.withValues(alpha: 0.35),
              child: const SizedBox(height: 1, width: double.infinity),
            ),
          ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final empty = value == null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: empty ? AppColors.textTertiary : AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty ? 'Chọn ngày' : AppFormat.date(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: empty
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
