import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Chip trạng thái — nền tint nhạt + chấm màu, dùng xuyên suốt danh sách đơn.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
    this.showDot = true,
    this.icon,
  });

  final String label;
  final Color color;
  final bool dense;
  final bool showDot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trạng thái: $label',
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minHeight: dense ? 22 : 28),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 7 : 10,
            vertical: dense ? 2 : 5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.brPill,
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 12 : 14, color: color),
                const SizedBox(width: 5),
              ] else if (showDot) ...[
                Container(
                  width: dense ? 5 : 6,
                  height: dense ? 5 : 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: AppTypography.style(
                  color: color,
                  fontSize: dense ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn nhỏ dạng overline — chữ hoa, giãn ký tự.
class OverlineLabel extends StatelessWidget {
  const OverlineLabel({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}
