import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/search_field.dart';
import '../../../shared/models/department.dart';

/// Kết quả chọn phòng ban — phân biệt “Tất cả” / dismiss.
class DepartmentPickResult {
  const DepartmentPickResult.clear()
      : department = null,
        cleared = true;
  const DepartmentPickResult.selected(this.department) : cleared = false;

  final Department? department;
  final bool cleared;
}

/// Kết quả chọn bộ phận.
class WorkUnitPickResult {
  const WorkUnitPickResult.clear()
      : name = null,
        cleared = true;
  const WorkUnitPickResult.value(this.name) : cleared = false;

  final String? name;
  final bool cleared;
}

/// Bottom sheet chọn phòng ban — tìm kiếm, thẻ đẹp, không hiện mã UUID.
Future<DepartmentPickResult?> showDepartmentPicker(
  BuildContext context, {
  required List<Department> departments,
  int? selectedId,
  bool allowClear = true,
  String title = 'Chọn phòng ban',
}) {
  return showModalBottomSheet<DepartmentPickResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OrgPickerSheet(
      title: title,
      subtitle: '${departments.length} khoa/phòng',
      searchHint: 'Tìm khoa, phòng…',
      allowClear: allowClear,
      clearLabel: 'Tất cả phòng ban',
      items: [
        for (var i = 0; i < departments.length; i++)
          _OrgPickerItem(
            id: departments[i].id,
            title: _prettyName(departments[i].name),
            subtitle: _departmentSubtitle(departments[i]),
            icon: Icons.apartment_rounded,
            color: AppColors.chartPalette[i % AppColors.chartPalette.length],
            selected: departments[i].id == selectedId,
            onTap: () => Navigator.pop(
              ctx,
              DepartmentPickResult.selected(departments[i]),
            ),
          ),
      ],
      onClear: allowClear
          ? () => Navigator.pop(ctx, const DepartmentPickResult.clear())
          : null,
      clearSelected: selectedId == null,
      filterMatch: (item, q) {
        final raw = departments.firstWhere((d) => d.id == item.id);
        final query = q.toLowerCase();
        return raw.name.toLowerCase().contains(query) ||
            raw.code.toLowerCase().contains(query) ||
            (raw.headName?.toLowerCase().contains(query) ?? false) ||
            item.title.toLowerCase().contains(query);
      },
    ),
  );
}

/// Bottom sheet chọn bộ phận trong một phòng ban.
Future<WorkUnitPickResult?> showWorkUnitPicker(
  BuildContext context, {
  required List<WorkUnit> units,
  String? selectedName,
  bool allowClear = true,
  String title = 'Chọn bộ phận',
  String clearLabel = 'Tất cả bộ phận',
  String? departmentName,
}) {
  return showModalBottomSheet<WorkUnitPickResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OrgPickerSheet(
      title: title,
      subtitle: departmentName == null
          ? '${units.length} bộ phận'
          : '${_prettyName(departmentName)} · ${units.length} bộ phận',
      searchHint: 'Tìm bộ phận…',
      allowClear: allowClear,
      clearLabel: clearLabel,
      items: [
        for (var i = 0; i < units.length; i++)
          _OrgPickerItem(
            id: units[i].id,
            title: _prettyName(units[i].name),
            subtitle: null,
            icon: Icons.meeting_room_rounded,
            color: AppColors.chartPalette[(i + 2) % AppColors.chartPalette.length],
            selected: units[i].name == selectedName,
            onTap: () => Navigator.pop(
              ctx,
              WorkUnitPickResult.value(units[i].name),
            ),
          ),
      ],
      onClear: allowClear
          ? () => Navigator.pop(ctx, const WorkUnitPickResult.clear())
          : null,
      clearSelected: selectedName == null || selectedName.isEmpty,
      filterMatch: (item, q) => item.title.toLowerCase().contains(q.toLowerCase()),
    ),
  );
}

String _prettyName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
  if (letters.isEmpty) return trimmed;
  var upper = 0;
  for (final u in letters.runes) {
    final ch = String.fromCharCode(u);
    if (ch == ch.toUpperCase()) upper++;
  }
  if (upper / letters.length < 0.65) return trimmed;
  return trimmed
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) {
        if (w.isEmpty) return w;
        if (w.length <= 3 && RegExp(r'^[a-zà-ỹ]+$').hasMatch(w)) {
          return w.toUpperCase();
        }
        return '${w[0].toUpperCase()}${w.substring(1)}';
      })
      .join(' ');
}

String? _departmentSubtitle(Department d) {
  final head = d.headName?.trim();
  if (head != null && head.isNotEmpty) return 'Phụ trách: $head';
  // Không hiện mã UUID thô — chỉ hiện mã ngắn nếu trông “đọc được”.
  final code = d.code.trim();
  if (code.isEmpty) return null;
  if (RegExp(r'^[A-Za-z0-9]{8,}$').hasMatch(code) &&
      !RegExp(r'^[A-Z]{2,}-\d+').hasMatch(code) &&
      code.length >= 10) {
    return null;
  }
  return 'Mã: $code';
}

class _OrgPickerItem {
  const _OrgPickerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
}

class _OrgPickerSheet extends StatefulWidget {
  const _OrgPickerSheet({
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.items,
    required this.allowClear,
    required this.clearLabel,
    required this.clearSelected,
    required this.filterMatch,
    this.onClear,
  });

  final String title;
  final String subtitle;
  final String searchHint;
  final List<_OrgPickerItem> items;
  final bool allowClear;
  final String clearLabel;
  final bool clearSelected;
  final bool Function(_OrgPickerItem item, String query) filterMatch;
  final VoidCallback? onClear;

  @override
  State<_OrgPickerSheet> createState() => _OrgPickerSheetState();
}

class _OrgPickerSheetState extends State<_OrgPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? widget.items
        : widget.items
            .where((e) => widget.filterMatch(e, _query.trim()))
            .toList();
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.style(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AppSearchField(
              hintText: widget.searchHint,
              dense: true,
              autofocus: false,
              debounce: const Duration(milliseconds: 180),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (widget.allowClear && widget.onClear != null && _query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _ClearOptionTile(
                label: widget.clearLabel,
                selected: widget.clearSelected,
                onTap: widget.onClear!,
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Không tìm thấy kết quả',
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Thử từ khoá khác',
                            style: AppTypography.caption(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _OrgItemTile(item: item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClearOptionTile extends StatelessWidget {
  const _ClearOptionTile({
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
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.apps_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: AppColors.textTertiary.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgItemTile extends StatelessWidget {
  const _OrgItemTile({required this.item});

  final _OrgPickerItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.selected
          ? item.color.withValues(alpha: 0.1)
          : AppColors.surfaceMuted.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.selected
                  ? item.color.withValues(alpha: 0.45)
                  : AppColors.borderSoft,
              width: item.selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.color.withValues(alpha: 0.22),
                      item.color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                        height: 1.25,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: item.selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('on'),
                        color: item.color,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey('off'),
                        color: AppColors.textTertiary.withValues(alpha: 0.45),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
