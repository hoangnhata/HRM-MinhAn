import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_date_picker.dart';
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

  /// Chip chế độ (Chờ duyệt / Đã xử lý) — đặt cùng hàng meta.
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
              Flexible(child: widget.leading!),
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
            width: 40,
            height: 40,
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
                          fontSize: 9,
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
    subtitle: 'Lọc theo phòng ban, ngày gửi và trạng thái.',
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

  Future<String?> _pickOption({
    required String title,
    required List<({String value, String label})> options,
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final o in options)
                ListTile(
                  title: Text(o.label),
                  trailing: o.value == selected
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(o.value),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final departments = attendanceDepartmentOptions(widget.sourceItems);
    final statuses = attendanceStatusFilterOptions(widget.sourceItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.typeOptions.isNotEmpty) ...[
          Text(
            'Loại đơn',
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SelectablePill(
                label: 'Tất cả',
                selected: _draft.requestType.isEmpty,
                onTap: () => setState(
                  () => _draft = _draft.copyWith(requestType: ''),
                ),
              ),
              for (final t in widget.typeOptions)
                SelectablePill(
                  label: t.label,
                  selected: _draft.requestType == t.value,
                  color: AttendanceEnums.requestTypeColor(t.value),
                  onTap: () => setState(
                    () => _draft = _draft.copyWith(
                      requestType:
                          _draft.requestType == t.value ? '' : t.value,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _OptionField(
          label: 'Phòng ban',
          value: _draft.department.isEmpty ? 'Tất cả phòng ban' : _draft.department,
          onTap: () async {
            final picked = await _pickOption(
              title: 'Chọn phòng ban',
              options: [
                (value: '', label: 'Tất cả phòng ban'),
                for (final d in departments) (value: d, label: d),
              ],
              selected: _draft.department,
            );
            if (picked == null) return;
            setState(() => _draft = _draft.copyWith(department: picked));
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _OptionField(
          label: 'Trạng thái',
          value: _draft.status.isEmpty
              ? 'Tất cả trạng thái'
              : AttendanceEnums.statusLabel(_draft.status),
          onTap: () async {
            final picked = await _pickOption(
              title: 'Chọn trạng thái',
              options: [
                (value: '', label: 'Tất cả trạng thái'),
                for (final s in statuses) (value: s.value, label: s.label),
              ],
              selected: _draft.status,
            );
            if (picked == null) return;
            setState(() => _draft = _draft.copyWith(status: picked));
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Từ ngày gửi',
                value: _draft.dateFrom,
                onTap: () => _pickDate(from: true),
                onClear: _draft.dateFrom == null
                    ? null
                    : () => setState(
                          () => _draft = _draft.copyWith(clearDateFrom: true),
                        ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateField(
                label: 'Đến ngày gửi',
                value: _draft.dateTo,
                onTap: () => _pickDate(from: false),
                onClear: _draft.dateTo == null
                    ? null
                    : () => setState(
                          () => _draft = _draft.copyWith(clearDateTo: true),
                        ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(
                  () => _draft = AttendanceRequestListFilters.empty.copyWith(
                    query: widget.initial.query,
                  ),
                ),
                child: const Text('Đặt lại'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_draft),
                child: const Text('Áp dụng'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionField extends StatelessWidget {
  const _OptionField({
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
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(color: AppColors.border),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
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
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brControl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textTertiary,
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
                      value == null ? '—' : AppFormat.date(value),
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: value == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
