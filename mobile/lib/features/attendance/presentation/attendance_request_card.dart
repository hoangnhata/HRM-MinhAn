import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/attendance_models.dart';
import 'attendance_enums.dart';

class AttendanceRequestCard extends StatelessWidget {
  const AttendanceRequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.showEmployeeName = false,
    this.selectMode = false,
    this.selected = false,
    this.onSelectedChanged,
    this.highlighted = false,
  });

  final AttendanceWorkRequest request;
  final VoidCallback onTap;
  final bool showEmployeeName;
  final bool selectMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  /// Khoanh card khi mở từ thông báo.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final typeColor = AttendanceEnums.requestTypeColor(request.requestType);
    final statusColor = AttendanceEnums.statusColor(request.status);
    final hasRange =
        request.endDate != null && request.endDate != request.workDate;
    final typeLabel = AttendanceEnums.requestTypeLabel(request.requestType);
    final shortStatus = AttendanceEnums.shortStatusLabel(request.status);
    final fullStatus = AttendanceEnums.statusLabel(request.status);
    final dateLabel = hasRange
        ? '${AppFormat.date(request.workDate)} → ${AppFormat.date(request.endDate)}'
        : AppFormat.date(request.workDate);
    final canToggle = selectMode && onSelectedChanged != null;
    final employeeLine = [
      request.employeeName,
      request.department,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');
    final reason = request.reason?.trim();

    final card = AppCard(
      onTap: canToggle ? () => onSelectedChanged!(!selected) : onTap,
      accentColor: selected
          ? AppColors.primary
          : (highlighted ? AppColors.warning : typeColor),
      borderRadius: AppRadius.brCard,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectMode) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 1),
              child: AnimatedContainer(
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
            ),
          ],
          AppIconBadge(
            icon: AttendanceEnums.requestTypeIcon(request.requestType),
            color: typeColor,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: shortStatus,
                      color: statusColor,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (showEmployeeName && employeeLine.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    employeeLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                      height: 1.3,
                    ),
                  ),
                ],
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  'Gửi ${AppFormat.dateTime(request.createdAt)}',
                  style: AppTypography.caption(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selectMode ? selected : null,
      label:
          '$typeLabel. $dateLabel. Trạng thái $fullStatus. ${request.employeeName ?? ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: HighlightPulse(
            active: highlighted,
            color: AppColors.warning,
            child: card,
          ),
        ),
      ),
    );
  }
}
