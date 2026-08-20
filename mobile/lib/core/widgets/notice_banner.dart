import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Khung nhắc việc / cảnh báo — nền tint, viền mảnh, icon dẫn ý.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.color = AppColors.info,
    this.action,
  });

  const NoticeBanner.warning({
    super.key,
    required this.message,
    this.title,
    this.action,
  }) : icon = Icons.warning_amber_rounded,
       color = AppColors.warning;

  const NoticeBanner.success({
    super.key,
    required this.message,
    this.title,
    this.action,
  }) : icon = Icons.check_circle_outline_rounded,
       color = AppColors.success;

  const NoticeBanner.error({
    super.key,
    required this.message,
    this.title,
    this.action,
  }) : icon = Icons.error_outline_rounded,
       color = AppColors.error;

  final String message;
  final String? title;
  final IconData? icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: color == AppColors.error,
      label: title == null ? message : '$title. $message',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: AppRadius.brSm,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: AppRadius.brXs,
                ),
                child: Icon(
                  icon ?? Icons.info_outline_rounded,
                  color: color,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null) ...[
                          Text(
                            title!,
                            style: AppTypography.style(
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          message,
                          style: AppTypography.body(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
