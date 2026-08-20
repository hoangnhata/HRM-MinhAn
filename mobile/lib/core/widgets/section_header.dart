import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Tương đương PageHeader bên web: overline + title + description + actions.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    this.overline,
    required this.title,
    this.description,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  final String? overline;
  final String title;
  final String? description;
  final Widget? actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackActions = actions != null && constraints.maxWidth < 420;
          final heading = Semantics(
            header: true,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (overline != null) ...[
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (overline != null) ...[
                          Text(
                            overline!.toUpperCase(),
                            style: AppTypography.style(
                              color: AppColors.primaryDark,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.75,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Text(
                              description!,
                              style: AppTypography.body(
                                fontSize: 13.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: AppSpacing.sm),
                actions!,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (actions != null) ...[
                const SizedBox(width: AppSpacing.md),
                actions!,
              ],
            ],
          );
        },
      ),
    );
  }
}
