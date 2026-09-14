import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Chip phạm vi truy cập — gọn trên mobile, không copy layout web.
class AccessScopeChip extends StatelessWidget {
  const AccessScopeChip({
    super.key,
    required this.label,
    this.detail,
    this.icon = Icons.filter_alt_outlined,
    this.color = AppColors.primary,
  });

  /// Phạm vi bộ phận (workUnitScoped).
  factory AccessScopeChip.workUnit({
    required String workUnit,
    String? departmentName,
  }) {
    final dept = departmentName?.trim();
    return AccessScopeChip(
      label: 'Phạm vi bộ phận',
      detail: (dept == null || dept.isEmpty) ? workUnit : '$dept · $workUnit',
      icon: Icons.apartment_rounded,
      color: AppColors.info,
    );
  }

  /// Xem hồ sơ toàn viện nhờ flag HOSPITAL_EMPLOYEE_VIEWER.
  const AccessScopeChip.hospitalWide({super.key})
      : label = 'Xem toàn viện',
        detail = 'Được cấp quyền xem danh sách nhân viên toàn bệnh viện',
        icon = Icons.travel_explore_rounded,
        color = AppColors.primary;

  final String label;
  final String? detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.brSm,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brXs,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (detail != null && detail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
