import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
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
    final typeIcon = AttendanceEnums.requestTypeIcon(request.requestType);
    final statusColor = AttendanceEnums.statusColor(request.status);
    final hasRange =
        request.endDate != null && request.endDate != request.workDate;
    final typeLabel = AttendanceEnums.requestTypeLabel(request.requestType);
    final shortStatus = AttendanceEnums.shortStatusLabel(request.status);
    final fullStatus = AttendanceEnums.statusLabel(request.status);
    // Kèm số ngày nghỉ/công tác để không phải nhẩm từ khoảng ngày.
    final days = request.leaveDays ?? request.tripDays;
    final daysLabel = days != null && days > 0
        ? '${AppFormat.score(days)} ngày'
        : null;
    final dateRange = hasRange
        ? '${AppFormat.date(request.workDate)} → ${AppFormat.date(request.endDate)}'
        : AppFormat.date(request.workDate);
    final dateLabel = daysLabel == null ? dateRange : '$dateRange · $daysLabel';
    final canToggle = selectMode && onSelectedChanged != null;
    final employeeName = request.employeeName?.trim() ?? '';
    final department = request.department?.trim() ?? '';
    final reason = request.reason?.trim();
    // Sắc nền: đang chọn → teal, mở từ thông báo → vàng, còn lại theo loại đơn.
    final accent = selected
        ? AppColors.primary
        : (highlighted ? AppColors.warning : typeColor);

    final card = AppCard(
      onTap: canToggle ? () => onSelectedChanged!(!selected) : onTap,
      // Chỉ bật wash + hairline của AppCard khi đang chọn để trạng thái chọn nổi rõ.
      accentColor: selected ? AppColors.primary : null,
      gradient: TintedCardBackdrop.gradient(accent),
      borderRadius: AppRadius.brLg,
      padding: EdgeInsets.zero,
      child: TintedCardBackdrop(
        accent: accent,
        watermarkIcon: typeIcon,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectMode) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 9),
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
              TintedIconTile(icon: typeIcon, color: typeColor),
              const SizedBox(width: AppSpacing.sm),
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
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              height: AppTypography.uppercaseHeight,
                              color: AppColors.textPrimary,
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
                    const SizedBox(height: 4),
                    _MetaLine(
                      icon: Icons.event_rounded,
                      text: dateLabel,
                      color: AppColors.textPrimary,
                      weight: FontWeight.w700,
                      tabular: true,
                    ),
                    if (showEmployeeName && employeeName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _EmployeeLine(name: employeeName, department: department),
                    ],
                    if (reason != null && reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _ReasonBox(text: reason, accent: accent),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MetaLine(
                            icon: Icons.schedule_rounded,
                            text:
                                'Gửi ${AppFormat.dateTime(request.createdAt)}',
                            color: AppColors.textTertiary,
                            fontSize: 11.5,
                            iconSize: 13,
                            tabular: true,
                          ),
                        ),
                        if (!selectMode) TintedChevron(accent: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selectMode ? selected : null,
      label:
          '$typeLabel. $dateLabel. Trạng thái $fullStatus. ${request.employeeName ?? ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.color,
    this.weight = FontWeight.w500,
    this.fontSize = 12.5,
    this.iconSize = 14,
    this.tabular = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final FontWeight weight;
  final double fontSize;
  final double iconSize;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: fontSize,
              fontWeight: weight,
              height: AppTypography.uppercaseHeight,
              tabular: tabular,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Người làm đơn (đậm, teal) · khoa (chữ thường) — hai cấp thông tin rõ ràng.
class _EmployeeLine extends StatelessWidget {
  const _EmployeeLine({required this.name, required this.department});

  final String name;
  final String department;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.person_outline_rounded,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: name,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
              children: [
                if (department.isNotEmpty)
                  TextSpan(
                    text: '  ·  $department',
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(height: AppTypography.uppercaseHeight),
          ),
        ),
      ],
    );
  }
}

/// Lý do trong khung trích dẫn mảnh — tách nội dung tự do khỏi dữ liệu hệ thống.
class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Viền một phía không đi cùng borderRadius được — vẽ vạch nhấn bằng thanh riêng.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: AppRadius.brControl,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent.withValues(alpha: 0.55)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 6, 10, 6),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
