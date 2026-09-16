import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Thanh chọn tháng cho tab "Đã xử lý" — lịch sử tải theo từng tháng.
class HistoryMonthBar extends StatelessWidget {
  const HistoryMonthBar({
    super.key,
    required this.month,
    required this.loading,
    required this.onPick,
  });

  final DateTime month;
  final bool loading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        2,
        AppSpacing.page,
        6,
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.brBase,
            child: InkWell(
              onTap: loading ? null : onPick,
              borderRadius: AppRadius.brBase,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tháng ${month.month}/${month.year}',
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 17,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading
                  ? 'Đang tải lịch sử…'
                  : 'Đơn đã duyệt hoặc từ chối trong tháng',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
