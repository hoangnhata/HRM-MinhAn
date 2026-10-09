import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import '../../../shared/models/attendance_models.dart';
import '../application/attendance_schedule_provider.dart';

/// Sắc nhận diện trong khối lịch làm việc.
const Color _summerTone = Color(0xFFB45309);
const Color _winterTone = Color(0xFF0369A1);
const Color _morningTone = Color(0xFFD97706);
const Color _afternoonTone = Color(0xFF7C3AED);
const Color _youngChildTone = Color(0xFFC2410C);
const Color _youngChildText = Color(0xFF9A3412);

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
    final seasonTone = sch.summer ? _summerTone : _winterTone;
    final seasonIcon = sch.summer
        ? Icons.wb_sunny_rounded
        : Icons.ac_unit_rounded;

    final actions = <_PanelAction>[
      if (onConfigureContinuous != null)
        _PanelAction(
          icon: Icons.edit_calendar_rounded,
          label: 'Xếp ca theo ngày',
          color: AppColors.success,
          onTap: onConfigureContinuous!,
        ),
      if (onProposeShiftConfigChange != null)
        _PanelAction(
          icon: Icons.schedule_rounded,
          label: 'Đổi ca sáng/chiều',
          color: AppColors.primary,
          onTap: onProposeShiftConfigChange!,
        ),
      if (onProposeYoungChild != null)
        _PanelAction(
          icon: Icons.child_care_rounded,
          label: youngChild ? 'Đổi chế độ con nhỏ' : 'Chế độ con nhỏ',
          color: _youngChildTone,
          onTap: onProposeYoungChild!,
        ),
    ];

    final tags = <(IconData, String, Color)>[
      if (youngChild)
        (Icons.child_care_rounded, 'Nuôi con nhỏ (−1h)', _youngChildTone),
      if (view.continuousDayCount > 0)
        (
          Icons.timeline_rounded,
          '${view.continuousDayCount} ngày thông tầm',
          AppColors.success,
        ),
      if (view.splitDayCount > 0)
        (
          Icons.call_split_rounded,
          '${view.splitDayCount} ngày sáng–chiều',
          AppColors.primaryDark,
        ),
    ];

    return Padding(
      padding: AppSpacing.pageH,
      child: AppCard(
        gradient: TintedCardBackdrop.gradient(seasonTone),
        borderRadius: AppRadius.brLg,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        child: TintedCardBackdrop(
          accent: seasonTone,
          watermarkIcon: seasonIcon,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Đầu thẻ ────────────────────────────────────────────────
                Row(
                  children: [
                    TintedIconTile(
                      icon: seasonIcon,
                      color: seasonTone,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch làm việc',
                            style: AppTypography.style(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: AppTypography.uppercaseHeight,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (sch.periodLabel ?? '').isNotEmpty
                                ? 'Áp dụng ${sch.periodLabel}'
                                : (sch.seasonLabel ??
                                      (sch.summer ? 'Mùa hè' : 'Mùa đông')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      _SeasonPill(
                        icon: seasonIcon,
                        label: sch.summer ? 'Ca hè' : 'Ca đông',
                        color: seasonTone,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Hai ca trong ngày ──────────────────────────────────────
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ShiftTile(
                          icon: Icons.wb_twilight_rounded,
                          title: 'Ca sáng',
                          start: sch.morningStart,
                          end: sch.morningEnd,
                          hours: _hours(sch.morningHours),
                          units: sch.morningUnitsText,
                          color: _morningTone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ShiftTile(
                          icon: Icons.nights_stay_rounded,
                          title: 'Ca chiều',
                          start: sch.afternoonStart,
                          end: sch.afternoonEnd,
                          hours: _hours(sch.afternoonHours),
                          units: sch.afternoonUnitsText,
                          color: _afternoonTone,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in tags)
                        _InfoTag(icon: t.$1, label: t.$2, color: t.$3),
                    ],
                  ),
                ],
                if (youngChild) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.brControl,
                      border: Border.all(
                        color: _youngChildTone.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TintedIconTile(
                          icon: Icons.child_care_rounded,
                          color: _youngChildTone,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sch.youngChildLabel ??
                                'Đang áp dụng chế độ nuôi con nhỏ: giảm 1 giờ/ngày · tối thiểu 7h = 1 công.',
                            style: AppTypography.style(
                              fontSize: 12.5,
                              height: 1.35,
                              color: _youngChildText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // ── Thao tác ───────────────────────────────────────────────
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, a) in actions.indexed) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _ActionTile(action: a)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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
}

class _PanelAction {
  const _PanelAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Viên mùa ở góc phải đầu thẻ.
class _SeasonPill extends StatelessWidget {
  const _SeasonPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              height: AppTypography.uppercaseHeight,
              color: Color.lerp(color, AppColors.textPrimary, 0.15)!,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn thông tin nhỏ (con nhỏ, số ngày thông tầm / sáng–chiều).
class _InfoTag extends StatelessWidget {
  const _InfoTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: AppTypography.uppercaseHeight,
              color: Color.lerp(color, AppColors.textPrimary, 0.15)!,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô một ca: tên ca + viên số công, giờ vào → ra cỡ lớn, số giờ bên dưới.
class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.icon,
    required this.title,
    required this.start,
    required this.end,
    required this.hours,
    required this.units,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String? start;
  final String? end;
  final String hours;
  final String units;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final a = DayShiftSchedule.displayTime(start) ?? '—';
    final b = DayShiftSchedule.displayTime(end) ?? '—';
    final dark = Color.lerp(color, AppColors.textPrimary, 0.3)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TintedIconTile(icon: icon, color: color, size: 26),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: AppTypography.uppercaseHeight,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a, style: AppTypography.metric(fontSize: 17, color: dark)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
                Text(b, style: AppTypography.metric(fontSize: 17, color: dark)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  hours,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  units,
                  style: AppTypography.metric(fontSize: 10.5, color: dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ô thao tác đáy thẻ: icon đặc trên, nhãn dưới — các ô chia đều bề ngang.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _PanelAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.color;
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brCard,
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        color: AppColors.surface,
        child: InkWell(
          onTap: action.onTap,
          splashColor: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TintedIconTile(icon: action.icon, color: color, size: 30),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: Color.lerp(color, AppColors.textPrimary, 0.35)!,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
