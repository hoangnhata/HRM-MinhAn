import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Một ô trong [MetricStrip].
class MetricItem {
  const MetricItem({
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final Color color;
}

/// Dải 2–4 chỉ số nằm ngang, ngăn bằng gạch mỏng.
///
/// Dùng cho thẻ danh sách (báo cáo ĐD, KPI phụ) — không thay hero card.
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.items})
    : assert(items.length >= 2, 'MetricStrip cần ít nhất 2 ô');

  final List<MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 26, color: AppColors.borderSoft),
            Expanded(child: _Cell(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.item});

  final MetricItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.value,
              maxLines: 1,
              style: AppTypography.metric(
                fontSize: 15.5,
                color: item.color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.15,
              height: AppTypography.uppercaseHeight,
            ),
          ),
        ],
      ),
    );
  }
}
