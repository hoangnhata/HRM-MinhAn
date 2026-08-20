import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Dòng nhãn — giá trị dùng trong các màn hình chi tiết (hồ sơ, đơn từ...).
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.valueWidget,
    this.multiline = false,
    this.semanticValue,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final Widget? valueWidget;
  final String? semanticValue;

  /// Giá trị dài (lý do, nhận xét) — xuống dòng dưới nhãn cho dễ đọc.
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final spokenValue =
        semanticValue ?? (value.isEmpty ? 'Chưa có thông tin' : value);
    final labelWidget = Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            label,
            style: AppTypography.style(
              fontSize: 12.3,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );

    final displayValue =
        valueWidget ??
        Text(
          value.isEmpty ? '—' : value,
          textAlign: multiline ? TextAlign.start : TextAlign.end,
          style: AppTypography.style(
            fontSize: 13.2,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: valueColor ?? AppColors.textPrimary,
          ),
        );

    if (multiline) {
      return Semantics(
        label: '$label: $spokenValue',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                SizedBox(width: double.infinity, child: displayValue),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: '$label: $spokenValue',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: labelWidget),
              const SizedBox(width: AppSpacing.xs),
              Expanded(flex: 6, child: displayValue),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung thẻ bọc nội dung với tiêu đề nhỏ — dùng thay cho Paper của MUI.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.trailing,
    this.accentColor,
    this.margin = const EdgeInsets.fromLTRB(
      AppSpacing.page,
      0,
      AppSpacing.page,
      AppSpacing.sm,
    ),
  });

  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsets padding;
  final Widget? trailing;
  final Color? accentColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return AppCard(
      margin: margin,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  AppIconBadge(icon: icon!, color: color, size: 32),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const Divider(height: AppSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}
