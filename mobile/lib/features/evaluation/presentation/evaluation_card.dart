import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../shared/models/nursing_evaluation.dart';
import 'evaluation_enums.dart';

class EvaluationCard extends StatelessWidget {
  const EvaluationCard({
    super.key,
    required this.record,
    required this.onTap,
    this.showEmployeeName = false,
    this.highlighted = false,
  });

  final NursingEvaluationRecord record;
  final VoidCallback onTap;
  final bool showEmployeeName;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final gradeColor = EvaluationEnums.gradeColor(record.overallGrade);
    final statusColor = EvaluationEnums.statusColor(record.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HighlightPulse(
        active: highlighted,
        color: AppColors.warning,
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brMd,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              decoration: BoxDecoration(
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: highlighted
                      ? AppColors.warning.withValues(alpha: 0.45)
                      : AppColors.borderSoft,
                ),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: record.totalScore != null
                        ? Text(
                            AppFormat.compactNumber(record.totalScore),
                            style: AppTypography.metric(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: gradeColor,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${record.periodMonth}',
                                style: AppTypography.metric(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: gradeColor,
                                ),
                              ),
                              Text(
                                'Th',
                                style: AppTypography.style(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: gradeColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tháng ${record.periodMonth}/${record.periodYear}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (showEmployeeName &&
                            (record.employeeName ?? '').isNotEmpty)
                          Text(
                            [
                              record.employeeName,
                              record.departmentName,
                            ]
                                .whereType<String>()
                                .where((e) => e.isNotEmpty)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                EvaluationEnums.statusLabel(record.status),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            if (record.overallGrade != null) ...[
                              Text(
                                '  ·  ${record.overallGrade}',
                                style: AppTypography.style(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: gradeColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
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
