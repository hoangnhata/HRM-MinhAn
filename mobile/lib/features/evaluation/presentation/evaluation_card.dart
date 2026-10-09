import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import '../../../shared/models/nursing_evaluation.dart';
import 'evaluation_enums.dart';

class EvaluationCard extends StatelessWidget {
  const EvaluationCard({
    super.key,
    required this.record,
    required this.onTap,
    this.showEmployeeName = false,
    this.highlighted = false,
    this.selectMode = false,
    this.selected = false,
    this.onSelectedChanged,
  });

  final NursingEvaluationRecord record;
  final VoidCallback onTap;
  final bool showEmployeeName;
  final bool highlighted;

  /// Chế độ chọn nhiều (tab Duyệt): chạm thẻ để chọn/bỏ chọn thay vì mở phiếu.
  final bool selectMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final gradeColor = EvaluationEnums.gradeColor(record.overallGrade);
    final statusColor = EvaluationEnums.statusColor(record.status);
    final canToggle = selectMode && onSelectedChanged != null;
    final accent = selected ? AppColors.primary : gradeColor;
    final name = (record.employeeName ?? '').trim();
    final dept = (record.departmentName ?? '').trim();
    final period = 'Tháng ${record.periodMonth}/${record.periodYear}';
    // Danh sách duyệt: người được đánh giá là thông tin chính, kỳ lùi xuống phụ.
    final personFirst = showEmployeeName && name.isNotEmpty;

    final card = AppCard(
      onTap: canToggle ? () => onSelectedChanged!(!selected) : onTap,
      borderRadius: AppRadius.brLg,
      padding: EdgeInsets.zero,
      accentColor: selected ? AppColors.primary : null,
      gradient: TintedCardBackdrop.gradient(accent),
      child: TintedCardBackdrop(
        accent: accent,
        watermarkIcon: Icons.fact_check_rounded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              if (selectMode) ...[
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : AppColors.surface,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: 1.6,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
              ],
              _ScoreRing(
                score: record.totalScore,
                month: record.periodMonth,
                color: gradeColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personFirst ? name : period,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(
                          personFirst
                              ? Icons.calendar_month_rounded
                              : Icons.apartment_rounded,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (personFirst)
                                  TextSpan(
                                    text: period,
                                    style: AppTypography.style(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                if (personFirst && dept.isNotEmpty)
                                  const TextSpan(text: '  ·  '),
                                if (dept.isNotEmpty)
                                  TextSpan(text: dept)
                                else if (!personFirst)
                                  const TextSpan(text: 'Phiếu đánh giá'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: AppTypography.uppercaseHeight,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _EvalTag(
                          label: EvaluationEnums.statusLabel(record.status),
                          color: statusColor,
                          dot: true,
                        ),
                        if (record.overallGrade != null)
                          _EvalTag(
                            label: record.overallGrade!,
                            color: gradeColor,
                            icon: Icons.workspace_premium_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectMode) ...[
                const SizedBox(width: 8),
                TintedChevron(accent: accent),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      child: HighlightPulse(
        active: highlighted,
        color: AppColors.warning,
        child: Semantics(
          button: true,
          selected: selectMode ? selected : null,
          label: [
            if (personFirst) name,
            period,
            EvaluationEnums.statusLabel(record.status),
            if (record.totalScore != null)
              '${AppFormat.score(record.totalScore)} điểm',
            ?record.overallGrade,
          ].join('. '),
          excludeSemantics: true,
          child: card,
        ),
      ),
    );
  }
}

/// Điểm tổng trong vòng tiến độ theo thang 100, tô sắc xếp loại.
/// Chưa có điểm: hiện tháng của kỳ đánh giá.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.score,
    required this.month,
    required this.color,
  });

  final double? score;
  final int month;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = score;
    final ink = Color.lerp(color, AppColors.textPrimary, 0.2)!;
    return SizedBox.square(
      dimension: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 4,
              color: color.withValues(alpha: 0.14),
            ),
          ),
          if (value != null)
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  color: color,
                ),
              ),
            ),
          if (value != null)
            Text(
              AppFormat.score(value),
              style: AppTypography.display(fontSize: 18, color: ink),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TH',
                  style: AppTypography.uppercase(
                    fontSize: 8.5,
                    letterSpacing: 0.6,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  '$month',
                  style: AppTypography.display(fontSize: 17, color: ink),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Nhãn gọn: chấm hoặc icon + chữ trên nền pha nhạt, viền mảnh cùng sắc.
class _EvalTag extends StatelessWidget {
  const _EvalTag({
    required this.label,
    required this.color,
    this.dot = false,
    this.icon,
  });

  final String label;
  final Color color;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = Color.lerp(color, AppColors.textPrimary, 0.25)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brChip,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 12, color: ink),
            ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: AppTypography.uppercaseHeight,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
