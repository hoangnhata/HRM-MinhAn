import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../shared/models/attendance_models.dart';
import '../application/attendance_schedule_provider.dart';

/// Khối lịch làm việc mobile — dữ liệu đồng bộ `/v1/attendance/schedule`.
class AttendanceSchedulePanel extends StatelessWidget {
  const AttendanceSchedulePanel({
    super.key,
    required this.view,
    this.onConfigureContinuous,
    this.onProposeShiftConfigChange,
    this.onProposeYoungChild,
    this.loading = false,
  });

  final AttendanceScheduleView view;
  final VoidCallback? onConfigureContinuous;
  final VoidCallback? onProposeShiftConfigChange;
  final VoidCallback? onProposeYoungChild;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final sch = view.schedule;
    final youngChild = sch.youngChild;
    final accent = AppColors.primary;
    final seasonColor =
        sch.summer ? const Color(0xFFB45309) : const Color(0xFF0369A1);

    return Padding(
      padding: AppSpacing.pageH,
      child: AppCard(
        accentColor: youngChild ? const Color(0xFFC2410C) : accent,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    sch.summer
                        ? Icons.wb_sunny_rounded
                        : Icons.ac_unit_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lịch làm việc',
                        style: AppTypography.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          sch.seasonLabel ?? (sch.summer ? 'Mùa hè' : 'Mùa đông'),
                          if ((sch.periodLabel ?? '').isNotEmpty)
                            'Áp dụng ${sch.periodLabel}',
                        ].join(' · '),
                        style: AppTypography.style(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: sch.summer
                      ? Icons.wb_sunny_rounded
                      : Icons.ac_unit_rounded,
                  label: sch.summer ? 'Ca hè' : 'Ca đông',
                  color: seasonColor,
                ),
                if (onProposeShiftConfigChange != null)
                  _ActionChip(
                    icon: Icons.schedule_rounded,
                    label: 'Đề xuất ca sáng/chiều',
                    color: AppColors.primaryDark,
                    onTap: onProposeShiftConfigChange!,
                  ),
                if (youngChild)
                  _StatusChip(
                    icon: Icons.child_care_rounded,
                    label: 'Nuôi con nhỏ (−1h)',
                    color: const Color(0xFFC2410C),
                    emphasized: true,
                  ),
                if (view.continuousDayCount > 0)
                  _StatusChip(
                    icon: Icons.timeline_rounded,
                    label: '${view.continuousDayCount} ngày TT',
                    color: AppColors.success,
                  ),
                if (view.splitDayCount > 0)
                  _StatusChip(
                    icon: Icons.schedule_rounded,
                    label: '${view.splitDayCount} ngày SC',
                    color: AppColors.primaryDark,
                  ),
              ],
            ),
            if (youngChild) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2410C).withValues(alpha: 0.08),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: const Color(0xFFC2410C).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.child_care_rounded,
                      size: 18,
                      color: Color(0xFFC2410C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sch.youngChildLabel ??
                            'Đang áp dụng chế độ nuôi con nhỏ: giảm 1 giờ/ngày · tối thiểu 7h = 1 công.',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          height: 1.35,
                          color: const Color(0xFF9A3412),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ShiftTile(
                    icon: Icons.wb_twilight_rounded,
                    title: 'Ca sáng',
                    meta:
                        '${_hours(sch.morningHours)} · ${sch.morningUnitsText}',
                    timeRange: _range(sch.morningStart, sch.morningEnd),
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShiftTile(
                    icon: Icons.nights_stay_rounded,
                    title: 'Ca chiều',
                    meta:
                        '${_hours(sch.afternoonHours)} · ${sch.afternoonUnitsText}',
                    timeRange: _range(sch.afternoonStart, sch.afternoonEnd),
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            if (onConfigureContinuous != null || onProposeYoungChild != null) ...[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onConfigureContinuous != null)
                        SizedBox(
                          width: width,
                          child: _MiniAction(
                            icon: Icons.edit_calendar_rounded,
                            label: 'Xếp ca theo ngày',
                            color: AppColors.success,
                            onTap: onConfigureContinuous!,
                          ),
                        ),
                      if (onProposeYoungChild != null)
                        SizedBox(
                          width: width,
                          child: _MiniAction(
                            icon: Icons.child_care_rounded,
                            label: youngChild
                                ? 'Đề xuất đổi'
                                : 'Đề xuất chế độ',
                            color: const Color(0xFFC2410C),
                            onTap: onProposeYoungChild!,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _hours(num? value) {
    if (value == null) return '— giờ';
    final text = value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return '$text giờ';
  }

  static String _range(String? start, String? end) {
    final a = DayShiftSchedule.displayTime(start) ?? '—';
    final b = DayShiftSchedule.displayTime(end) ?? '—';
    return '$a → $b';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.16 : 0.1),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: AppRadius.brPill,
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.icon,
    required this.title,
    required this.meta,
    required this.timeRange,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String meta;
  final String timeRange;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timeRange,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: AppRadius.brCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brCard,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
