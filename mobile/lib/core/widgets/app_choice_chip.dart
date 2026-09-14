import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Chip chọn nhanh — lọc danh sách (có viền) hoặc tuỳ chọn trong sheet.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.trailing,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? trailing;

  /// Nền xám nhạt, không viền — chip trong bottom sheet.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primaryDark : AppColors.textSecondary;
    final bg = selected
        ? AppColors.primary.withValues(alpha: 0.14)
        : muted
        ? AppColors.surfaceMuted
        : AppColors.surface;

    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      child: Material(
        color: bg,
        borderRadius: AppRadius.brPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brPill,
          child: ExcludeSemantics(
            child: muted
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    child: Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.brPill,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.borderSoft,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count == null ? label : '$label · $count',
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            trailing,
                            size: 14,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
