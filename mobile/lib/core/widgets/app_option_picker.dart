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
Future<String?> showAppOptionPicker(
  BuildContext context, {
  required String title,
  required List<AppOptionItem> options,
  String? selectedValue,
  String? subtitle,
  Color accent = AppColors.primary,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppOptionPickerSheet(
      title: title,
      subtitle: subtitle,
      options: options,
      selectedValue: selectedValue,
      accent: accent,
    ),
  );
}

class _AppOptionPickerSheet extends StatelessWidget {
  const _AppOptionPickerSheet({
    required this.title,
    required this.options,
    required this.accent,
    this.subtitle,
    this.selectedValue,
  });

  final String title;
  final String? subtitle;
  final List<AppOptionItem> options;
  final String? selectedValue;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.35),
              borderRadius: AppRadius.brPill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.style(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: AppTypography.style(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
          const Divider(height: 1, color: AppColors.borderSoft),
          Flexible(
            child: options.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Không có lựa chọn',
                      style: AppTypography.style(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final selected = opt.value == selectedValue;
                      return _OptionCard(
                        item: opt,
                        selected: selected,
                        accent: accent,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context, opt.value);
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
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
    return Material(
      color: selected ? accent.withValues(alpha: 0.08) : AppColors.surfaceAlt,
      borderRadius: AppRadius.brCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brCard,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brCard,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.45)
                  : AppColors.borderSoft,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? AppShadows.soft : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.16)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.25)
                        : AppColors.borderSoft,
                  ),
                ),
                child: Icon(
                  item.icon ?? Icons.check_circle_outline_rounded,
                  size: 18,
                  color: selected ? accent : AppColors.textTertiary,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    if ((item.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle!,
                        style: AppTypography.style(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? accent : AppColors.border,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
