import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_motion.dart';

/// Thẻ thống kê — nền gradient tint theo ngữ cảnh, số liệu là điểm nhấn chính.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: subtitle == null ? '$label: $value' : '$label: $value, $subtitle',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: color.withValues(alpha: 0.16)),
            boxShadow: AppShadows.soft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.brMd,
              splashColor: color.withValues(alpha: 0.08),
              child: Stack(
                children: [
                  Positioned(
                    top: -22,
                    right: -22,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: AppGradients.tint(color),
                            borderRadius: AppRadius.brXs,
                            border: Border.all(
                              color: color.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: AppTypography.metric(fontSize: 24),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: AppTypography.caption(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Khối "action" nhanh trên Dashboard (grid icon + nhãn, điều hướng route).
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    this.color,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final String route;
  final Color? color;

  /// Số việc cần xử lý — hiện dưới dạng badge đỏ góc icon.
  final int? badgeCount;
}

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({
    super.key,
    required this.actions,
    required this.onTap,
    this.crossAxisCount = 4,
  });

  final List<QuickAction> actions;
  final void Function(QuickAction) onTap;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final compact = constraints.maxWidth < 340 || scale > 1.2;
        final columns = compact ? math.min(3, crossAxisCount) : crossAxisCount;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            childAspectRatio: compact ? 0.72 : 0.78,
          ),
          itemCount: actions.length,
          itemBuilder: (context, i) {
            final action = actions[i];
            final color = action.color ?? AppColors.primary;
            final badge = action.badgeCount ?? 0;
            final semanticsLabel = badge > 0
                ? '${action.label}, $badge việc cần xử lý'
                : action.label;

            return AppReveal(
              delay: AppStagger.delayFor(i, stepMs: 38),
              offset: 9,
              child: Semantics(
                button: true,
                label: semanticsLabel,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: () => onTap(action),
                    borderRadius: AppRadius.brSm,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Badge(
                          isLabelVisible: badge > 0,
                          label: Text(
                            badge > 99 ? '99+' : '$badge',
                            textScaler: TextScaler.noScaling,
                          ),
                          backgroundColor: AppColors.error,
                          offset: const Offset(-2, 2),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppGradients.tint(color),
                              borderRadius: AppRadius.brMd,
                              border: Border.all(
                                color: color.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Icon(action.icon, color: color, size: 23),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Flexible(
                          child: Text(
                            action.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
