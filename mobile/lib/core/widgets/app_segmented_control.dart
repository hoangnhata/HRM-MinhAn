import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Kiểu hiển thị của [AppSegmentedControl].
enum AppSegmentStyle {
  /// Con trượt gradient brand, chữ chọn màu trắng.
  /// Dùng cho việc đổi chế độ xem chính của màn hình.
  brand,

  /// Con trượt trắng trên rãnh xám, chữ chọn teal đậm.
  /// Dùng cho bộ lọc phụ, thường kèm số đếm.
  soft,
}

/// Một ô trong [AppSegmentedControl].
class AppSegmentItem {
  const AppSegmentItem({
    required this.label,
    this.icon,
    this.count,
    this.semanticsLabel,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;

  /// Số đếm hiển thị cạnh nhãn. Bỏ qua nếu `null`.
  final int? count;

  /// Nhãn đọc cho trình đọc màn hình; mặc định lấy [label] kèm số đếm.
  final String? semanticsLabel;

  /// `false` thì ô xám và không nhận chạm — dùng khi loại đơn bị khoá.
  final bool enabled;
}

/// Bộ chọn dạng phân đoạn dùng chung cho toàn app.
///
/// Thay cho hàng chục bản sao cục bộ (`_ModeSegment`, `_ViewModeSwitcher`,
/// `_TimingSegment`, `_QuickStatusSwitch`…) từng tự chọn chiều cao, bo góc và
/// cỡ chữ riêng nên mỗi màn một nhịp.
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.style = AppSegmentStyle.brand,
    this.dense = false,
    this.expand = true,
    this.enabled = true,
  }) : assert(items.length >= 2, 'Segment cần ít nhất 2 ô');

  final List<AppSegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final AppSegmentStyle style;

  /// Bản thấp hơn, dùng khi nhồi trong toolbar hoặc thẻ nhỏ.
  final bool dense;

  /// `true` (mặc định): các ô rộng bằng nhau, chiếm hết chiều ngang và có con
  /// trượt chạy. `false`: pill co theo nội dung để nhét cạnh widget khác —
  /// khi đó nền ô chọn đổi tại chỗ thay vì trượt, vì các ô rộng khác nhau.
  final bool expand;

  /// Khoá toàn bộ control (form đang sửa, không đổi loại đơn).
  final bool enabled;

  bool get _brand => style == AppSegmentStyle.brand;

  double get _height => _brand ? (dense ? 40 : 44) : (dense ? 38 : 42);

  double get _trackPad => _brand ? 4 : 3;

  BorderRadius get _trackRadius =>
      _brand ? AppRadius.brPaper : AppRadius.brBase;

  BorderRadius get _itemRadius => _brand ? AppRadius.brBase : AppRadius.brSm;

  @override
  Widget build(BuildContext context) {
    final index = selectedIndex.clamp(0, items.length - 1);

    void select(int i) {
      if (!enabled || !items[i].enabled || i == index) return;
      HapticFeedback.selectionClick();
      onChanged(i);
    }

    final Widget control;
    if (!expand) {
      control = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.brPill,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              Opacity(
                opacity: items[i].enabled ? 1 : 0.45,
                child: _CompactTile(
                  item: items[i],
                  selected: i == index,
                  onTap: items[i].enabled ? () => select(i) : null,
                ),
              ),
          ],
        ),
      );
    } else {
      // Con trượt chạy theo tỉ lệ nên mọi ô luôn rộng bằng nhau.
      final slot = items.length == 1
          ? 0.0
          : -1 + 2 * index / (items.length - 1);

      control = Container(
        height: _height,
        padding: EdgeInsets.all(_trackPad),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: _trackRadius,
          border: _brand
              ? null
              : Border.all(color: AppColors.borderSoft.withValues(alpha: 0.9)),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: AppDurations.normal,
              curve: Curves.easeOutCubic,
              alignment: Alignment(slot, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / items.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _brand ? null : AppColors.surface,
                    gradient: _brand ? AppGradients.brandSoft : null,
                    borderRadius: _itemRadius,
                    border: _brand
                        ? null
                        : Border.all(
                            color: AppColors.primary.withValues(alpha: 0.22),
                          ),
                    boxShadow: _brand
                        ? AppShadows.tinted(AppColors.primary)
                        : AppShadows.soft,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Opacity(
                        opacity: items[i].enabled ? 1 : 0.45,
                        child: _SegmentTile(
                          item: items[i],
                          selected: i == index,
                          brand: _brand,
                          dense: dense,
                          radius: _itemRadius,
                          onTap: items[i].enabled ? () => select(i) : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (enabled) return control;
    return Opacity(opacity: 0.55, child: IgnorePointer(child: control));
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.item,
    required this.selected,
    required this.brand,
    required this.dense,
    required this.radius,
    required this.onTap,
  });

  final AppSegmentItem item;
  final bool selected;
  final bool brand;
  final bool dense;
  final BorderRadius radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = brand ? Colors.white : AppColors.primaryDark;
    final label =
        item.semanticsLabel ??
        (item.count == null ? item.label : '${item.label}, ${item.count}');

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ExcludeSemantics(
            // Màu chữ đổi cùng nhịp con trượt để không bị "nháy" lệch pha.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: selected ? 1 : 0),
              duration: AppDurations.normal,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                final color = Color.lerp(
                  AppColors.textSecondary,
                  selectedColor,
                  t,
                )!;
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.icon != null) ...[
                            Icon(
                              item.icon,
                              size: brand ? 16 : 14,
                              color: color,
                            ),
                            SizedBox(width: brand ? 7 : 5),
                          ],
                          Text(
                            item.label,
                            maxLines: 1,
                            style: AppTypography.style(
                              fontSize: brand
                                  ? (dense ? 12.5 : 13)
                                  : (dense ? 12.5 : 13),
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: color,
                              height: AppTypography.uppercaseHeight,
                            ),
                          ),
                          if (item.count != null) ...[
                            const SizedBox(width: 6),
                            _CountBadge(
                              count: item.count!,
                              selected: selected,
                              brand: brand,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô trong bản compact — nền đổi tại chỗ vì các ô rộng không bằng nhau.
class _CompactTile extends StatelessWidget {
  const _CompactTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppSegmentItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = item.count == null || item.count == 0
        ? item.label
        : '${item.label} ${item.count}';

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: item.semanticsLabel ?? label,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: AppRadius.brPill,
          boxShadow: selected ? AppShadows.soft : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brPill,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null) ...[
                        Icon(
                          item.icon,
                          size: 14,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        style: AppTypography.style(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          height: AppTypography.uppercaseHeight,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.selected,
    required this.brand,
  });

  final int count;
  final bool selected;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final Color border;
    if (brand) {
      background = selected
          ? Colors.white.withValues(alpha: 0.24)
          : AppColors.border.withValues(alpha: 0.5);
      foreground = selected ? Colors.white : AppColors.textSecondary;
      border = Colors.transparent;
    } else if (selected) {
      background = AppColors.primary;
      foreground = Colors.white;
      border = Colors.transparent;
    } else {
      background = AppColors.surface;
      foreground = AppColors.textPrimary;
      border = AppColors.border;
    }

    return AnimatedContainer(
      duration: AppDurations.fast,
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: border),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: AppTypography.style(
          fontSize: brand ? 10.5 : 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
          tabular: true,
          height: 1.25,
        ),
      ),
    );
  }
}
