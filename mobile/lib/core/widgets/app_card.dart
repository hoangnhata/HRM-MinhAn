import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Thẻ nền trắng bóng mềm — khối xây dựng cơ bản của mọi trang.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
    this.borderRadius,
    this.accentColor,
    this.gradient,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  /// Khi có giá trị, phủ nhẹ wash + hairline trên thẻ (nhấn loại/ngữ cảnh).
  final Color? accentColor;
  final Gradient? gradient;
  final bool elevated;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  Color _borderColor(Color? accent) {
    if (_pressed) {
      return (accent ?? AppColors.primary).withValues(alpha: 0.28);
    }
    if (accent == null) return AppColors.border;
    return Color.alphaBlend(
      accent.withValues(alpha: 0.16),
      AppColors.border,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadius.brMd;
    final accent = widget.accentColor;

    Widget content = Padding(padding: widget.padding, child: widget.child);

    if (accent != null) {
      // Wash gradient + hairline mảnh thay dải màu đặc — nhẹ, hiện đại hơn.
      content = Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.09),
                    accent.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.28, 0.62],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    accent.withValues(alpha: 0.72),
                    accent.withValues(alpha: 0.28),
                    accent.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          content,
        ],
      );
    }

    return Semantics(
      button: widget.onTap != null,
      child: AnimatedScale(
        scale: _pressed ? 0.992 : 1,
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOutCubic,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: widget.gradient == null ? AppColors.surface : null,
            gradient: widget.gradient,
            borderRadius: radius,
            border: Border.all(color: _borderColor(accent)),
            boxShadow: widget.elevated
                ? (_pressed ? AppShadows.soft : AppShadows.card)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: widget.onTap == null
                ? content
                : InkWell(
                    onTap: widget.onTap,
                    onHighlightChanged: _setPressed,
                    borderRadius: radius,
                    splashColor: (accent ?? AppColors.primary)
                        .withValues(alpha: 0.08),
                    highlightColor: (accent ?? AppColors.primary)
                        .withValues(alpha: 0.035),
                    focusColor: (accent ?? AppColors.primary)
                        .withValues(alpha: 0.06),
                    hoverColor: (accent ?? AppColors.primary)
                        .withValues(alpha: 0.035),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề nhóm nội dung trong trang (chữ nhỏ, in đậm, kèm icon và hành động).
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.lg,
      AppSpacing.page,
      AppSpacing.xs,
    ),
  });

  final String title;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: AppTypography.sectionTitle()),
              ),
            ),
            if (action != null)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Align(alignment: Alignment.centerRight, child: action),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ô icon nền tint tròn — dùng trước tiêu đề thẻ, hàng danh sách, thống kê.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 40,
    this.iconSize,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  /// `true` → nền đặc màu [color], icon trắng. `false` → nền tint nhạt.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final iconColor = filled ? Theme.of(context).colorScheme.onPrimary : color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: iconColor),
    );
  }
}

/// Hàng thông tin nhãn — giá trị, canh phải giá trị để dễ đọc theo cột.
class AppKeyValueRow extends StatelessWidget {
  const AppKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.dense = false,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final bool dense;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: 6),
          ],
          Expanded(
            flex: 5,
            child: Text(label, style: AppTypography.listSubtitle()),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 6,
            child:
                valueWidget ??
                Text(
                  value.isEmpty ? '—' : value,
                  textAlign: TextAlign.right,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
