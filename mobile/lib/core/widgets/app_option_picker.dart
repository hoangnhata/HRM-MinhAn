import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Mục chọn dùng chung cho bottom sheet / field.
class AppOptionItem {
  const AppOptionItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final String value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// Bottom sheet chọn 1 option — tối ưu mobile, không cắt chữ như dropdown web.
///
/// Lựa chọn có giá trị `ALL` / rỗng được tách thành thẻ nổi bật ở đầu; các
/// lựa chọn còn lại nằm chung một thẻ danh sách có radio. Danh sách dài (> 8)
/// tự hiện ô tìm kiếm không dấu.
Future<String?> showAppOptionPicker(
  BuildContext context, {
  required String title,
  required List<AppOptionItem> options,
  String? selectedValue,
  String? subtitle,
  Color accent = AppColors.primary,
  IconData icon = Icons.tune_rounded,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Sheet tự vẽ thanh kéo — tắt thanh mặc định của theme để không bị trùng.
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppOptionPickerSheet(
      title: title,
      subtitle: subtitle,
      options: options,
      selectedValue: selectedValue,
      accent: accent,
      icon: icon,
    ),
  );
}

bool _isAllOption(AppOptionItem o) {
  final v = o.value.trim().toUpperCase();
  return v == 'ALL' || v.isEmpty;
}

class _AppOptionPickerSheet extends StatefulWidget {
  const _AppOptionPickerSheet({
    required this.title,
    required this.options,
    required this.accent,
    required this.icon,
    this.subtitle,
    this.selectedValue,
  });

  final String title;
  final String? subtitle;
  final List<AppOptionItem> options;
  final String? selectedValue;
  final Color accent;
  final IconData icon;

  @override
  State<_AppOptionPickerSheet> createState() => _AppOptionPickerSheetState();
}

class _AppOptionPickerSheetState extends State<_AppOptionPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(AppOptionItem o) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, o.value);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = widget.accent;
    final all = widget.options.where(_isAllOption).toList();
    final rest = widget.options.where((o) => !_isAllOption(o)).toList();
    final q = _foldVi(_query);
    final visible = q.isEmpty
        ? rest
        : rest
              .where(
                (o) => _foldVi('${o.label} ${o.subtitle ?? ''}').contains(q),
              )
              .toList();
    final showSearch = rest.length > 8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brSheetTop,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: AppRadius.brPill,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(accent, Colors.white, 0.12)!,
                        Color.lerp(accent, Colors.black, 0.12)!,
                      ],
                    ),
                    borderRadius: AppRadius.brBase,
                    boxShadow: AppShadows.tinted(accent),
                  ),
                  child: Icon(widget.icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.style(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.subtitle ?? '${rest.length} lựa chọn',
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceMuted,
                    foregroundColor: AppColors.textSecondary,
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                height: 42,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE6EFEE), Color(0xFFF0F6F5)],
                  ),
                  borderRadius: AppRadius.brPaper,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: 'Tìm trong ${rest.length} lựa chọn…',
                    hintStyle: AppTypography.style(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          Flexible(
            child: widget.options.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Không có lựa chọn',
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 2, 16, 16 + bottom),
                    children: [
                      if (q.isEmpty)
                        for (final o in all) ...[
                          _AllOptionCard(
                            item: o,
                            selected:
                                o.value == widget.selectedValue ||
                                (widget.selectedValue == null &&
                                    _isAllOption(o)),
                            accent: accent,
                            onTap: () => _pick(o),
                          ),
                          const SizedBox(height: 12),
                        ],
                      if (rest.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 6),
                          child: Text(
                            q.isEmpty
                                ? 'LỰA CHỌN · ${rest.length}'
                                : 'KẾT QUẢ · ${visible.length}',
                            style: AppTypography.uppercase(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  size: 30,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Không có lựa chọn phù hợp',
                                  style: AppTypography.style(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.brLg,
                              border: Border.all(color: AppColors.borderSoft),
                              boxShadow: AppShadows.soft,
                            ),
                            child: ClipRRect(
                              borderRadius: AppRadius.brLg,
                              child: Column(
                                children: [
                                  for (final (i, o) in visible.indexed) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        indent: 60,
                                        color: AppColors.divider,
                                      ),
                                    _OptionRow(
                                      item: o,
                                      selected: o.value == widget.selectedValue,
                                      accent: accent,
                                      onTap: () => _pick(o),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Lựa chọn "tất cả" — thẻ nổi bật với icon gradient.
class _AllOptionCard extends StatelessWidget {
  const _AllOptionCard({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AppOptionItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          gradient: AppGradients.tint(accent),
          color: AppColors.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(
            color: accent.withValues(alpha: selected ? 0.5 : 0.16),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? AppShadows.tinted(accent) : AppShadows.soft,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brLg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(accent, Colors.white, 0.12)!,
                          Color.lerp(accent, Colors.black, 0.12)!,
                        ],
                      ),
                      borderRadius: AppRadius.brBase,
                      boxShadow: AppShadows.tinted(accent),
                    ),
                    child: Icon(
                      item.icon ?? Icons.select_all_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: AppTypography.style(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            height: AppTypography.uppercaseHeight,
                            color: Color.lerp(
                              accent,
                              AppColors.textPrimary,
                              0.3,
                            ),
                          ),
                        ),
                        Text(
                          (item.subtitle ?? '').isNotEmpty
                              ? item.subtitle!
                              : 'Không giới hạn theo mục này',
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _OptionRadio(selected: selected, accent: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AppOptionItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSub = (item.subtitle ?? '').isNotEmpty;
    return Semantics(
      button: true,
      selected: selected,
      label: hasSub ? '${item.label}, ${item.subtitle}' : item.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.07) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.14)
                        : AppColors.surfaceMuted,
                    borderRadius: AppRadius.brControl,
                  ),
                  child: Icon(
                    item.icon ?? Icons.label_outline_rounded,
                    size: 18,
                    color: selected ? accent : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _prettyLabel(item.label),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          height: AppTypography.uppercaseHeight,
                          color: selected
                              ? Color.lerp(accent, AppColors.textPrimary, 0.3)
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (hasSub)
                        Text(
                          item.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _OptionRadio(selected: selected, accent: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vòng radio: rỗng → đĩa đặc có dấu ✓.
class _OptionRadio extends StatelessWidget {
  const _OptionRadio({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// Nhãn in hoa toàn bộ → viết hoa đầu chữ ("KHOA SẢN" → "Khoa Sản").
String _prettyLabel(String raw) {
  final t = raw.trim();
  final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
  if (letters.length < 4 || letters != letters.toUpperCase()) return t;
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

/// Bỏ dấu tiếng Việt + chữ thường để tìm không cần gõ dấu.
String _foldVi(String raw) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final buf = StringBuffer();
  for (final ch in raw.toLowerCase().characters) {
    var out = ch;
    for (final e in groups.entries) {
      if (e.value.contains(ch)) {
        out = e.key;
        break;
      }
    }
    buf.write(out);
  }
  return buf.toString();
}

/// Field bấm để mở [showAppOptionPicker] — thay dropdown native trên mobile.
class AppOptionField extends StatelessWidget {
  const AppOptionField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.hint = 'Chọn…',
    this.pickerTitle,
    this.pickerSubtitle,
    this.accent = AppColors.primary,
    this.enabled = true,
    this.dense = false,
    this.requiredMark = false,
  });

  final String label;
  final String? value;
  final List<AppOptionItem> options;
  final ValueChanged<String> onChanged;
  final String hint;
  final String? pickerTitle;
  final String? pickerSubtitle;
  final Color accent;
  final bool enabled;
  final bool dense;
  final bool requiredMark;

  AppOptionItem? get _selected {
    if (value == null || value!.isEmpty) return null;
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled || options.isEmpty) return;
    HapticFeedback.selectionClick();
    final picked = await showAppOptionPicker(
      context,
      title: pickerTitle ?? label,
      subtitle: pickerSubtitle,
      options: options,
      selectedValue: value,
      accent: accent,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final hasValue = selected != null;

    return Material(
      color: enabled ? AppColors.surfaceAlt : AppColors.surfaceHigh,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        borderRadius: AppRadius.brControl,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 9 : 11,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(
              color: hasValue
                  ? accent.withValues(alpha: 0.28)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requiredMark ? '$label *' : label,
                      style: AppTypography.style(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected?.label ?? hint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: dense ? 13 : 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: hasValue
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: enabled
                    ? (hasValue ? accent : AppColors.textTertiary)
                    : AppColors.actionDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
