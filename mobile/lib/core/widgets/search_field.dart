import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Thanh tìm kiếm chuẩn dùng cho tất cả màn hình danh sách.
///
/// Có debounce sẵn để không gọi API sau từng ký tự người dùng gõ.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Tìm kiếm...',
    this.controller,
    this.debounce = const Duration(milliseconds: 350),
    this.autofocus = false,
    this.dense = false,
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final TextEditingController? controller;
  final Duration debounce;
  final bool autofocus;
  final bool dense;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final hasText = value.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () => widget.onChanged(value));
  }

  void _clear() {
    _controller.clear();
    _handleChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleChanged,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      style: AppTypography.body(fontSize: widget.dense ? 13.5 : 14),
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(Icons.search_rounded, size: widget.dense ? 18 : 20),
        suffixIcon: _hasText
            ? IconButton(
                tooltip: 'Xoá',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _clear,
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: widget.dense ? 10 : 13,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.brPill,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brPill,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brPill,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Bộ lọc dạng chip ngang (trạng thái, phòng ban...) cuộn được.
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final barHeight = 48.0 + ((textScale - 1).clamp(0.0, 2.0) * 14.0);

    return SizedBox(
      height: barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = option == selected;
          return SelectablePill(
            label: option,
            selected: isSelected,
            onTap: () => onSelected(isSelected ? null : option),
          );
        },
      ),
    );
  }
}

/// Chip lựa chọn dùng chung — nền trắng, viền mảnh, chọn thì tô màu chủ đạo.
class SelectablePill extends StatelessWidget {
  const SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: AppRadius.brPill,
          border: Border.all(color: selected ? color : AppColors.border),
          boxShadow: selected ? AppShadows.soft : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            splashColor: color.withValues(alpha: 0.12),
            highlightColor: color.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: foreground),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: foreground,
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
  }
}
