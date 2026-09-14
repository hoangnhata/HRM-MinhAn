import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'status_chip.dart';

/// Nhãn nhóm trong danh sách — gạch màu + chữ hoa + số/đuôi.
///
/// Thay các bản `_SectionLabel` / `_SectionTitle` / `_DaySectionHeader` từng
/// tự chọn cỡ chữ 11.5 vs 14 và có/không có gạch.
class ListSectionTitle extends StatelessWidget {
  const ListSectionTitle({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.action,
    this.color = AppColors.primary,
    this.showRail = true,
    this.uppercase = true,
  });

  final String title;
  final int? count;
  final String? trailing;
  final Widget? action;
  final Color color;
  final bool showRail;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final label = uppercase ? title.toUpperCase() : title;

    return Semantics(
      header: true,
      child: Row(
        children: [
          if (showRail) ...[
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadius.brXs,
              ),
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.uppercase(
                fontSize: 11.5,
                color: showRail
                    ? AppColors.textSecondary
                    : AppColors.primaryDark,
                letterSpacing: uppercase ? 0.7 : 0.15,
              ),
            ),
          ),
          if (count != null) ...[
            if (showRail)
              const SizedBox(width: 8)
            else
              const Spacer(),
            CountBadge(count: count!, color: color),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                trailing!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.metricMuted(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
          if (action != null) ...[
            const Spacer(),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Tiêu đề khối có icon vuông — dashboard, form tạo đơn.
class BlockSectionTitle extends StatelessWidget {
  const BlockSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.color = AppColors.primary,
    this.action,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Color color;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    AppSpacing.page,
    AppSpacing.lg,
    AppSpacing.page,
    AppSpacing.sm,
  );

  @override
  Widget build(BuildContext context) {
    final row = Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: AppTypography.uppercaseHeight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null)
            action!
          else if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(48, 40),
                foregroundColor: color,
              ),
              child: Text(
                actionLabel!,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );

    if (padding == null) return row;
    return Padding(padding: padding!, child: row);
  }
}
