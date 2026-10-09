import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Kiểu nút hành động chính ở đáy màn/sheet.
enum AppActionVariant {
  /// Gradient brand + bóng — hành động chính duy nhất trên màn.
  primary,

  /// Nền đỏ nhạt — hành động phủ định cần cân nhắc (Từ chối).
  tonalDanger,

  /// Nền teal nhạt — hành động phụ (Chỉnh sửa).
  tonalPrimary,

  /// Viền trung tính, chữ đỏ — thao tác huỷ/rút của người lập.
  outlineDanger,

  /// Viền trung tính, chữ thường — thoát/huỷ bỏ thao tác (Huỷ, Đóng).
  outlineNeutral,
}

/// Nút cao 50 (hoặc 44 khi [compact]) có phản hồi nhấn co nhẹ + rung,
/// dùng chung cho thanh duyệt đơn và footer các sheet chỉnh sửa.
class AppActionButton extends StatefulWidget {
  const AppActionButton({
    super.key,
    required this.variant,
    this.icon,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    this.compact = false,
    this.loading = false,
  });

  final AppActionVariant variant;
  final IconData? icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool compact;

  /// Hiện vòng xoay thay cho icon và khoá nút, giữ nguyên độ đậm màu.
  final bool loading;

  @override
  State<AppActionButton> createState() => _AppActionButtonState();
}

class _AppActionButtonState extends State<AppActionButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handleTap() {
    if (widget.variant == AppActionVariant.primary) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final height = widget.compact ? 44.0 : 50.0;
    const radius = AppRadius.brMd;

    final Color foreground;
    final Color? background;
    final Gradient? gradient;
    final BorderSide border;
    final Color splash;
    switch (v) {
      case AppActionVariant.primary:
        foreground = Colors.white;
        background = null;
        gradient = AppGradients.brand;
        border = BorderSide.none;
        splash = Colors.white.withValues(alpha: 0.14);
      case AppActionVariant.tonalDanger:
        foreground = AppColors.errorDark;
        background = AppColors.errorLight;
        gradient = null;
        border = BorderSide(color: AppColors.error.withValues(alpha: 0.22));
        splash = AppColors.error.withValues(alpha: 0.12);
      case AppActionVariant.tonalPrimary:
        foreground = AppColors.primaryDark;
        background = AppColors.primaryContainer;
        gradient = null;
        border = BorderSide(color: AppColors.primary.withValues(alpha: 0.20));
        splash = AppColors.primary.withValues(alpha: 0.12);
      case AppActionVariant.outlineDanger:
        foreground = AppColors.error;
        background = AppColors.surface;
        gradient = null;
        border = const BorderSide(color: AppColors.border);
        splash = AppColors.error.withValues(alpha: 0.08);
      case AppActionVariant.outlineNeutral:
        foreground = AppColors.textPrimary;
        background = AppColors.surface;
        gradient = null;
        border = const BorderSide(color: AppColors.border);
        splash = AppColors.textPrimary.withValues(alpha: 0.06);
    }

    final showShadow =
        v == AppActionVariant.primary &&
        (_enabled || widget.loading) &&
        !_pressed;

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: foreground,
            ),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: widget.compact ? 18 : 20, color: foreground),
        if (widget.loading || widget.icon != null)
          const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: widget.compact ? 14 : 15,
              fontWeight: v == AppActionVariant.primary
                  ? FontWeight.w700
                  : FontWeight.w600,
              letterSpacing: -0.1,
              height: 1.35,
              color: foreground,
            ),
          ),
        ),
      ],
    );

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.97 : 1,
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _enabled || widget.loading ? 1 : 0.55,
          duration: AppDurations.fast,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: showShadow ? AppShadows.button : const [],
            ),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: radius, side: border),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  color: background,
                  gradient: gradient,
                ),
                child: InkWell(
                  onTap: _enabled ? _handleTap : null,
                  onHighlightChanged: _enabled
                      ? (value) => setState(() => _pressed = value)
                      : null,
                  splashColor: splash,
                  highlightColor: splash.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Center(child: content),
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
