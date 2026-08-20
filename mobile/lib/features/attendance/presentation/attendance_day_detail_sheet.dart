import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/utils/attendance_notes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/app_time_picker.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../../employees/data/employee_repository.dart';
import '../data/attendance_repository.dart';
import 'attendance_enums.dart';
import 'bulk_deployment_sheet.dart';
import 'bulk_work_supplement_sheet.dart';
import 'work_request_day_logic.dart';

export 'bulk_deployment_sheet.dart' show showBulkDeploymentSheet;

Future<void> showAttendanceDayDetailSheet(
  BuildContext context, {
  required AttendanceDay day,
  required int employeeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AttendanceDayDetailSheet(
      day: day,
      employeeId: employeeId,
    ),
  );
}

/// Mở sheet bổ sung hàng loạt (Công trực + Quang Trung).
void showBulkDutyShiftSheet(
  BuildContext context, {
  required DateTime workDate,
  DayShiftSchedule? schedule,
  BulkSupplementMode initialMode = BulkSupplementMode.duty,
}) {
  showBulkWorkSupplementSheet(
    context,
    workDate: workDate,
    schedule: schedule,
    initialMode: initialMode,
  );
}

class _AttendanceDayDetailSheet extends ConsumerStatefulWidget {
  const _AttendanceDayDetailSheet({
    required this.day,
    required this.employeeId,
  });

  final AttendanceDay day;
  final int employeeId;

  @override
  ConsumerState<_AttendanceDayDetailSheet> createState() =>
      _AttendanceDayDetailSheetState();
}

class _AttendanceDayDetailSheetState
    extends ConsumerState<_AttendanceDayDetailSheet> {
  DayShiftSchedule? _schedule;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final date = widget.day.workDate;
    if (date == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final employeeId = widget.employeeId > 0
          ? widget.employeeId
          : widget.day.employeeId ??
              ref.read(authControllerProvider).employeeId;
      final schedule = await ref.read(attendanceRepositoryProvider).daySchedule(
            date: date,
            employeeId: employeeId,
          );
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'PRESENT' => AppColors.success,
      'PARTIAL' => AppColors.warning,
      'ABSENT' => AppColors.error,
      'LEAVE' || 'SEMINAR' || 'DEPLOYMENT' => AppColors.info,
      'UNPAID_LEAVE' => AppColors.textSecondary,
      'BUSINESS_TRIP' => AppColors.warning,
      _ => AppColors.textTertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final date = day.workDate;
    final name =
        ref.watch(authControllerProvider).currentUser?.displayName ?? '';
    final late = day.lateMinutes;
    final showLate = late > 0 && !day.lateMinutesExempt;
    final scheduleUnknown = _schedule == null;
    final sch = _schedule;
    final isContinuous = sch?.continuousShift ?? false;
    final isSplit = sch?.isSplitDay ?? false;
    final penaltySlots = WorkRequestDayLogic.detectExplanationSlots(
      day: day,
      schedule: sch,
    );
    final canSupplement = day.status == 'PARTIAL' || day.status == 'ABSENT';
    final role = ref.watch(authControllerProvider).role;
    final canManageDutyQuangTrung =
        role == UserRole.admin || role == UserRole.headDepartment;
    final missingMorning = _isMissingShift(
      hasSchedule: _schedule?.morningStart != null ||
          (scheduleUnknown && canSupplement && day.morningWorkUnits <= 0),
      checkIn: day.morningCheckIn,
      checkOut: day.morningCheckOut,
      workUnits: day.morningWorkUnits,
    );
    final missingAfternoon = _isMissingShift(
      hasSchedule: _schedule?.afternoonStart != null ||
          (scheduleUnknown && canSupplement && day.afternoonWorkUnits <= 0),
      checkIn: day.afternoonCheckIn,
      checkOut: day.afternoonCheckOut,
      workUnits: day.afternoonWorkUnits,
    );
    final showUpdate = missingMorning || missingAfternoon;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              10,
              AppSpacing.page,
              bottomInset + AppSpacing.xl,
            ),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.35),
                    borderRadius: AppRadius.brPill,
                  ),
                ),
              ),
              Text(
                'CHI TIẾT CHẤM CÔNG',
                style: AppTypography.style(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                date == null
                    ? 'Không rõ ngày'
                    : AppFormat.longDateVi(date),
                style: AppTypography.style(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.2,
                ),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(name, style: AppTypography.listSubtitle()),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_schedule?.seasonLabel != null)
                    StatusChip(
                      label: _schedule!.seasonLabel!,
                      color: AppColors.warning,
                      dense: true,
                    ),
                  if (isContinuous)
                    StatusChip(
                      label: 'Ca thông tầm',
                      color: AppColors.success,
                      dense: true,
                      icon: Icons.timeline_rounded,
                    ),
                  if (isSplit)
                    StatusChip(
                      label: sch?.dayShiftTypeName ?? 'Ca sáng–chiều',
                      color: AppColors.primaryDark,
                      dense: true,
                      icon: Icons.schedule_rounded,
                    ),
                  StatusChip(
                    label: day.statusLabel,
                    color: _statusColor(day.status),
                    dense: true,
                  ),
                  if (showLate)
                    StatusChip(
                      label: '$late phút muộn/về sớm',
                      color: AppColors.warning,
                      icon: Icons.schedule_rounded,
                      dense: true,
                    ),
                  if (day.lateMinutesExempt && late > 0)
                    StatusChip(
                      label: 'Đã miễn trừ muộn',
                      color: AppColors.success,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (isContinuous)
                  _ShiftPanel(
                    title: 'Ca thông tầm',
                    icon: Icons.timeline_rounded,
                    tint: AppColors.success,
                    scheduleLabel: _scheduleRange(
                      sch?.continuousStart ?? sch?.morningStart,
                      sch?.continuousEnd ?? sch?.afternoonEnd,
                      sch?.continuousHours ?? sch?.effectiveDayHours,
                    ),
                    checkIn: day.morningCheckIn ?? day.checkIn,
                    checkOut: day.afternoonCheckOut ?? day.checkOut,
                    hoursLabel: null,
                    workUnits: day.totalWorkUnits,
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ShiftPanel(
                          title: 'Ca sáng',
                          icon: Icons.wb_sunny_rounded,
                          tint: AppColors.primary,
                          scheduleLabel: _scheduleRange(
                            _schedule?.morningStart,
                            _schedule?.morningEnd,
                            _schedule?.morningHours,
                          ),
                          checkIn: day.morningCheckIn,
                          checkOut: day.morningCheckOut,
                          hoursLabel: _hoursBetween(
                            day.morningCheckIn,
                            day.morningCheckOut,
                          ),
                          workUnits: day.morningWorkUnits,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ShiftPanel(
                          title: 'Ca chiều',
                          icon: Icons.nightlight_round,
                          tint: AppColors.secondary,
                          scheduleLabel: _scheduleRange(
                            _schedule?.afternoonStart,
                            _schedule?.afternoonEnd,
                            _schedule?.afternoonHours,
                          ),
                          checkIn: day.afternoonCheckIn,
                          checkOut: day.afternoonCheckOut,
                          hoursLabel: _hoursBetween(
                            day.afternoonCheckIn,
                            day.afternoonCheckOut,
                          ),
                          workUnits: day.afternoonWorkUnits,
                        ),
                      ),
                    ],
                  ),
                if (isSplit && (sch?.splitDayLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    sch!.splitDayLabel!,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _PunchLogCard(
                  punches: day.punchTimes,
                  continuous: isContinuous,
                ),
                if (showLate || showUpdate) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _DayActionsCard(
                    showLate: showLate,
                    lateMinutes: late,
                    penaltySlots: penaltySlots,
                    showUpdate: showUpdate,
                    missingMorning: missingMorning,
                    missingAfternoon: missingAfternoon,
                    onExplain: date == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            context.push(
                              RoutePaths.attendanceRequestNew,
                              extra: AttendanceRequestPrefill.work(
                                requestType: 'EXPLANATION',
                                workDate: date,
                              ),
                            );
                          },
                    onUpdate: date == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            context.push(
                              RoutePaths.attendanceRequestNew,
                              extra: AttendanceRequestPrefill.work(
                                requestType: 'UPDATE',
                                workDate: date,
                                updateKind:
                                    AttendanceRequestPrefill.updateKindForDay(
                                  missingMorning: missingMorning,
                                  missingAfternoon: missingAfternoon,
                                ),
                              ),
                            );
                          },
                  ),
                ],
                // Nút bổ sung công đã chuyển lên card Tổng công tháng.
                const SizedBox(height: AppSpacing.sm),
                _DaySummaryCard(day: day),
              ],
            ],
          ),
        );
      },
    );
  }

  String? _scheduleRange(String? start, String? end, num? hours) {
    final a = DayShiftSchedule.displayTime(start);
    final b = DayShiftSchedule.displayTime(end);
    if (a == null || b == null) return null;
    final h = hours == null
        ? ''
        : ' (${AppFormat.compactNumber(hours)}h)';
    return '$a – $b$h';
  }

  String? _hoursBetween(String? inn, String? out) {
    if (inn == null || out == null) return null;
    // Giá trị đã dạng 6h47 — chỉ hiện nếu có cả vào/ra.
    return null; // giờ làm đã có trên panel qua check; backend không trả duration riêng
  }

  /// Ca có lịch nhưng chưa có quét / công → thiếu ca, có thể gửi cập nhật công.
  bool _isMissingShift({
    required bool hasSchedule,
    required String? checkIn,
    required String? checkOut,
    required double workUnits,
  }) {
    if (!hasSchedule) return false;
    return checkIn == null && checkOut == null && workUnits <= 0;
  }
}

class _ShiftPanel extends StatelessWidget {
  const _ShiftPanel({
    required this.title,
    required this.icon,
    required this.tint,
    required this.scheduleLabel,
    required this.checkIn,
    required this.checkOut,
    required this.hoursLabel,
    required this.workUnits,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final String? scheduleLabel;
  final String? checkIn;
  final String? checkOut;
  final String? hoursLabel;
  final double workUnits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: tint.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
                ),
              ),
            ],
          ),
          if (scheduleLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lịch $scheduleLabel',
              style: AppTypography.style(
                fontSize: 10.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _kv('Giờ vào', checkIn ?? '—'),
          _kv('Giờ ra', checkOut ?? '—'),
          if (hoursLabel != null) _kv('Số giờ làm', hoursLabel!),
          _kv(
            'Công ca',
            '${AppFormat.compactNumber(workUnits)} công',
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.style(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: emphasize ? tint : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchLogCard extends StatelessWidget {
  const _PunchLogCard({
    required this.punches,
    this.continuous = false,
  });

  final List<String> punches;
  final bool continuous;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log máy chấm (${punches.length} lần)',
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (punches.isEmpty)
            Text(
              'Không có lần quét trong ngày.',
              style: AppTypography.listSubtitle(),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in punches)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: AppRadius.brPill,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      p,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            continuous
                ? 'Giờ vào/ra ca thông tầm được suy ra từ các lần quẹt theo khung ca và cửa sổ chấm công.'
                : 'Giờ ca sáng/chiều được suy ra từ các lần quét theo lịch ca và cửa sổ chấm công.',
            style: AppTypography.style(
              fontSize: 11.5,
              color: AppColors.textTertiary,
              height: 1.4,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _DayActionsCard extends StatelessWidget {
  const _DayActionsCard({
    required this.showLate,
    required this.lateMinutes,
    required this.penaltySlots,
    required this.showUpdate,
    required this.missingMorning,
    required this.missingAfternoon,
    required this.onExplain,
    required this.onUpdate,
  });

  final bool showLate;
  final int lateMinutes;
  final List<ExplanationPenaltySlot> penaltySlots;
  final bool showUpdate;
  final bool missingMorning;
  final bool missingAfternoon;
  final VoidCallback? onExplain;
  final VoidCallback? onUpdate;

  String get _missingLabel {
    if (missingMorning && missingAfternoon) return 'Thiếu cả ca sáng và ca chiều';
    if (missingMorning) return 'Thiếu ca sáng — chưa có giờ vào/ra';
    return 'Thiếu ca chiều — chưa có giờ vào/ra';
  }

  @override
  Widget build(BuildContext context) {
    final title = showLate && showUpdate
        ? 'Điều chỉnh công ngày này'
        : showUpdate
            ? 'Thiếu ca'
            : 'Khung giờ bị trừ tiền';
    final subtitle = showLate && showUpdate
        ? 'Gửi đơn giải trình muộn/về sớm hoặc cập nhật công cho ca còn thiếu.'
        : showUpdate
            ? 'Gửi đơn cập nhật công nếu bạn đã làm nhưng quên chấm.'
            : 'Gửi đơn giải trình nếu có lý do chính đáng.';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.caption()),
          if (showLate) ...[
            const SizedBox(height: 12),
            for (final slot in penaltySlots) ...[
              _ActionIssueTile(
                color: AppColors.warning,
                icon: Icons.schedule_rounded,
                title: '${slot.kindLabel} · ${slot.label}',
                detail: [
                  if (slot.current.isNotEmpty) 'Máy chấm ${slot.current}',
                  if (slot.expected.isNotEmpty) 'Lịch ${slot.expected}',
                  '${slot.minutes} phút',
                ].join(' · '),
              ),
              if (slot != penaltySlots.last) const SizedBox(height: 8),
            ],
            if (penaltySlots.isEmpty)
              _ActionIssueTile(
                color: AppColors.warning,
                icon: Icons.schedule_rounded,
                title: 'Đi muộn / về sớm',
                detail: '$lateMinutes phút',
              ),
          ],
          if (showUpdate) ...[
            const SizedBox(height: 10),
            _ActionIssueTile(
              color: AppColors.info,
              icon: Icons.event_busy_rounded,
              title: 'Thiếu ca',
              detail: _missingLabel,
            ),
          ],
          if (showLate) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onExplain,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Giải trình muộn / về sớm',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (showUpdate) ...[
            SizedBox(height: showLate ? 8 : 12),
            if (showLate)
              OutlinedButton.icon(
                onPressed: onUpdate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info, width: 1.4),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                ),
                icon: const Icon(Icons.touch_app_outlined, size: 18),
                label: const Text(
                  'Cập nhật công',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              FilledButton.icon(
                onPressed: onUpdate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                ),
                icon: const Icon(Icons.touch_app_outlined, size: 18),
                label: const Text(
                  'Cập nhật công',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionIssueTile extends StatelessWidget {
  const _ActionIssueTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: AppTypography.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.day});

  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Tổng công', AppFormat.compactNumber(day.totalWorkUnits)),
      if (day.overtimeWorkUnits > 0)
        (
          'Ngoài giờ',
          AppFormat.compactNumber(day.overtimeWorkUnits),
        ),
      (
        'Muộn / về sớm',
        day.lateMinutesExempt
            ? 'Miễn trừ'
            : day.lateMinutes > 0
                ? '${day.lateMinutes} phút'
                : '0 phút',
      ),
    ];
    final notes = parseAttendanceNotes(day.note);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng hợp ngày',
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: AppTypography.style(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú',
              style: AppTypography.style(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (n.timeRange != null || n.hoursLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [n.timeRange, n.hoursLine]
                              .whereType<String>()
                              .join(' · '),
                          style: AppTypography.style(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (n.breakdown != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          n.breakdown!,
                          style: AppTypography.style(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (n.reason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          n.reason!,
                          style: AppTypography.style(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (n.ref != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          n.ref!,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

enum _SupplementKind { duty, quangTrung }

class _SupplementModeSheet extends StatelessWidget {
  const _SupplementModeSheet({
    required this.kind,
    required this.onEmployee,
    required this.onBulk,
    this.onBulkDeployment,
  });

  final _SupplementKind kind;
  final VoidCallback onEmployee;
  final VoidCallback onBulk;
  /// Nếu không null, hiển thị hàng "Điều động hàng loạt" (chỉ dùng cho duty).
  final VoidCallback? onBulkDeployment;

  String get _title => switch (kind) {
        _SupplementKind.duty => 'Công trực',
        _SupplementKind.quangTrung => 'Công Quang Trung',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.35),
                borderRadius: AppRadius.brPill,
              ),
            ),
            Row(
              children: [
                Icon(
                  kind == _SupplementKind.duty
                      ? Icons.spa_rounded
                      : Icons.nights_stay_rounded,
                  size: 18,
                  color: kind == _SupplementKind.duty
                      ? AppColors.primary
                      : AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chọn thao tác — $_title',
                    style: AppTypography.style(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ModeRow(
              icon: Icons.person_outline_rounded,
              title: 'Theo nhân viên',
              subtitle: 'Chỉ áp dụng cho 1 nhân viên',
              onTap: () {
                Navigator.of(context).pop();
                onEmployee();
              },
            ),
            const SizedBox(height: 8),
            _ModeRow(
              icon: Icons.group_add_rounded,
              title: 'Theo hàng loạt',
              subtitle: 'Mỗi nhân viên có thể chọn loại ca khác nhau',
              onTap: () {
                Navigator.of(context).pop();
                onBulk();
              },
            ),
            if (onBulkDeployment != null) ...[
              const SizedBox(height: 8),
              _ModeRow(
                icon: Icons.swap_horiz_rounded,
                title: 'Điều động hàng loạt',
                subtitle: 'Cấu hình giờ điều động riêng từng người',
                onTap: () {
                  Navigator.of(context).pop();
                  onBulkDeployment!();
                },
              ),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DutyQuangTrungSupplementCard extends StatelessWidget {
  const _DutyQuangTrungSupplementCard({
    required this.employeeId,
    required this.workDate,
    required this.schedule,
  });

  final int employeeId;
  final DateTime workDate;
  final DayShiftSchedule? schedule;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bổ sung công trực & công Quang Trung',
                  style: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _SupplementModeSheet(
                        kind: _SupplementKind.duty,
                        onEmployee: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _DutyShiftSupplementSheet(
                              employeeId: employeeId,
                              workDate: workDate,
                            ),
                          );
                        },
                        onBulk: () {
                          showBulkWorkSupplementSheet(
                            context,
                            workDate: workDate,
                            schedule: schedule,
                            initialMode: BulkSupplementMode.duty,
                          );
                        },
                        onBulkDeployment: () {
                          showBulkDeploymentSheet(
                            context,
                            workDate: workDate,
                            schedule: schedule,
                          );
                        },
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                    foregroundColor: AppColors.primaryDark,
                  ),
                  icon: const Icon(Icons.spa_rounded, size: 18),
                  label: Text(
                    'Công trực',
                    style: AppTypography.style(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _SupplementModeSheet(
                        kind: _SupplementKind.quangTrung,
                        onEmployee: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _QuangTrungSupplementSheet(
                              employeeId: employeeId,
                              workDate: workDate,
                              schedule: schedule,
                            ),
                          );
                        },
                        onBulk: () {
                          showBulkWorkSupplementSheet(
                            context,
                            workDate: workDate,
                            schedule: schedule,
                            initialMode: BulkSupplementMode.quangTrung,
                          );
                        },
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.35)),
                    foregroundColor: AppColors.secondaryDark,
                  ),
                  icon: const Icon(Icons.nights_stay_rounded, size: 18),
                  label: Text(
                    'Công Quang Trung',
                    style: AppTypography.style(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DutyShiftSupplementSheet extends ConsumerStatefulWidget {
  const _DutyShiftSupplementSheet({
    required this.employeeId,
    required this.workDate,
  });

  final int employeeId;
  final DateTime workDate;

  @override
  ConsumerState<_DutyShiftSupplementSheet> createState() =>
      _DutyShiftSupplementSheetState();
}

class _DutyShiftSupplementSheetState
    extends ConsumerState<_DutyShiftSupplementSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<DutyShiftTypeOption> _types = const [];
  DutyShiftEntry? _existing;

  String? _selectedShiftTypeCode;
  String? _selectedRoleTierCode;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final types = await repo.dutyShiftTypes(employeeId: widget.employeeId);
      final shifts = await repo.dutyShifts(
        employeeId: widget.employeeId,
        from: widget.workDate,
        to: widget.workDate,
      );
      final existing = shifts.isNotEmpty ? shifts.first : null;
      String? roleCode = existing?.roleTierCode;
      final selectedType = existing?.shiftTypeCode;
      if (selectedType != null && (roleCode == null || roleCode.isEmpty)) {
        for (final t in types) {
          if (t.code == selectedType && t.roleTiers.isNotEmpty) {
            roleCode = t.roleTiers.first.code;
            break;
          }
        }
      }
      setState(() {
        _types = types;
        _existing = existing;
        _selectedShiftTypeCode = existing?.shiftTypeCode;
        _selectedRoleTierCode = roleCode;
        _noteController.text = existing?.raw['note']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleTiersForSelected = (() {
      if (_selectedShiftTypeCode == null) return null;
      for (final t in _types) {
        if (t.code == _selectedShiftTypeCode) return t.roleTiers;
      }
      return null;
    })();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.page,
          right: AppSpacing.page,
          top: AppSpacing.sm,
          bottom: AppSpacing.xl,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.35),
                    borderRadius: AppRadius.brPill,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.spa_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bổ sung công trực',
                      style: AppTypography.style(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppFormat.longDateVi(widget.workDate),
                style: AppTypography.caption(),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: AppTypography.style(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_types.isNotEmpty) ...[
                  AppOptionField(
                    label: 'Loại ca trực',
                    pickerTitle: 'Chọn loại ca trực',
                    pickerSubtitle: 'Hiển thị đủ tên loại ca',
                    value: _selectedShiftTypeCode,
                    options: _types
                        .map(
                          (t) => AppOptionItem(
                            value: t.code,
                            label: t.label,
                            subtitle: t.grantsWorkUnits
                                ? 'Có cộng công trực (+0,33)'
                                : 'Không cộng công',
                            icon: Icons.nightlight_round,
                          ),
                        )
                        .toList(),
                    hint: 'Chọn loại ca',
                    requiredMark: true,
                    onChanged: (v) {
                      setState(() {
                        _selectedShiftTypeCode = v;
                        final tiers = (() {
                          for (final t in _types) {
                            if (t.code == v) return t.roleTiers;
                          }
                          return null;
                        })();
                        if (tiers == null || tiers.isEmpty) {
                          _selectedRoleTierCode = null;
                        } else {
                          final current = _selectedRoleTierCode;
                          final ok = tiers.any((x) => x.code == current);
                          _selectedRoleTierCode =
                              ok ? current : tiers.first.code;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ] else
                  Text(
                    'Không có danh mục ca trực để chọn.',
                    style: AppTypography.caption(),
                  ),

                if (roleTiersForSelected != null &&
                    roleTiersForSelected.isNotEmpty) ...[
                  AppOptionField(
                    label: 'Vị trí trực',
                    pickerTitle: 'Chọn vị trí trực',
                    value: _selectedRoleTierCode,
                    options: roleTiersForSelected
                        .map(
                          (rt) => AppOptionItem(
                            value: rt.code,
                            label: rt.label,
                            icon: Icons.badge_outlined,
                          ),
                        )
                        .toList(),
                    hint: 'Chọn vị trí',
                    requiredMark: true,
                    onChanged: (v) => setState(() {
                      _selectedRoleTierCode = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (tuỳ chọn)',
                    labelStyle: AppTypography.caption(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final shiftTypeCode = _selectedShiftTypeCode;
                                if (shiftTypeCode == null ||
                                    shiftTypeCode.trim().isEmpty) {
                                  showAppSnackBar(context,
                                      'Vui lòng chọn loại ca trực',
                                      isError: true);
                                  return;
                                }
                                if (roleTiersForSelected != null &&
                                    roleTiersForSelected.isNotEmpty &&
                                    (_selectedRoleTierCode == null ||
                                        _selectedRoleTierCode!.isEmpty)) {
                                  showAppSnackBar(context,
                                      'Vui lòng chọn vị trí trực',
                                      isError: true);
                                  return;
                                }
                                setState(() => _saving = true);
                                try {
                                  final repo = ref.read(
                                      attendanceRepositoryProvider);
                                  await repo.upsertDutyShift(
                                    employeeId: widget.employeeId,
                                    workDate: widget.workDate,
                                    shiftTypeCode: shiftTypeCode,
                                    roleTierCode: _selectedRoleTierCode,
                                    note: _noteController.text,
                                  );
                                  if (!mounted) return;
                                  showAppSnackBar(context, 'Đã lưu công trực',
                                      isSuccess: true);
                                  Navigator.of(context).maybePop();
                                } catch (e) {
                                  if (!mounted) return;
                                  showAppSnackBar(context, e.toString(),
                                      isError: true);
                                  setState(() => _saving = false);
                                }
                              },
                        icon: const Icon(Icons.save_rounded),
                        label: Text(_existing == null ? 'Lưu' : 'Cập nhật'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _QuangTrungSupplementSheet extends ConsumerStatefulWidget {
  const _QuangTrungSupplementSheet({
    required this.employeeId,
    required this.workDate,
    required this.schedule,
  });

  final int employeeId;
  final DateTime workDate;
  final DayShiftSchedule? schedule;

  @override
  ConsumerState<_QuangTrungSupplementSheet> createState() =>
      _QuangTrungSupplementSheetState();
}

class _QuangTrungSupplementSheetState
    extends ConsumerState<_QuangTrungSupplementSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _updateKind = 'FULL_DAY_SUPPLEMENT';
  String _reason = '';
  final _reasonController = TextEditingController();

  TimeOfDay? _morningStart;
  TimeOfDay? _morningEnd;
  TimeOfDay? _afternoonStart;
  TimeOfDay? _afternoonEnd;

  QuangTrungSupplementView? _existing;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<TimeOfDay?> pickTime(
      TimeOfDay? initial,
      String title, {
      TimeOfDay? suggested,
    }) async {
      return showAppTimePicker(
        context,
        initialTime: initial ?? suggested ?? TimeOfDay.now(),
        title: title,
        suggestedTime: suggested,
        confirmLabel: 'Chọn',
        cancelLabel: 'Huỷ',
      );
    }

    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.successDark,
                    AppColors.success,
                    Color(0xFF2AA67A),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: onBrand.withValues(alpha: 0.35),
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: onBrand.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.location_on_rounded,
                            color: onBrand, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BỔ SUNG CÔNG',
                              style: AppTypography.style(
                                color: onBrand.withValues(alpha: 0.72),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Công Quang Trung',
                              style: AppTypography.style(
                                color: onBrand,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormat.longDateVi(widget.workDate),
                              style: AppTypography.style(
                                fontSize: 12,
                                color: onBrand.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.close_rounded,
                            color: onBrand.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: AppTypography.style(
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: AppRadius.brControl,
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: AppColors.info),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Áp dụng trực tiếp công làm tại Quang Trung, không trừ phạt quên chấm.',
                                  style: AppTypography.style(
                                    fontSize: 12.5,
                                    color: AppColors.infoDark,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loại bổ sung',
                          style: AppTypography.style(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final (i, k) in [
                              (key: 'MORNING_SUPPLEMENT', label: 'Ca sáng', icon: Icons.wb_sunny_rounded),
                              (key: 'AFTERNOON_SUPPLEMENT', label: 'Ca chiều', icon: Icons.wb_twilight),
                              (key: 'FULL_DAY_SUPPLEMENT', label: 'Cả ngày', icon: Icons.calendar_view_day_rounded),
                            ].indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: Material(
                                  color: _updateKind == k.key
                                      ? AppColors.success.withValues(alpha: 0.12)
                                      : AppColors.surface,
                                  borderRadius: AppRadius.brControl,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _updateKind = k.key),
                                    borderRadius: AppRadius.brControl,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: AppRadius.brControl,
                                        border: Border.all(
                                          color: _updateKind == k.key
                                              ? AppColors.success
                                                  .withValues(alpha: 0.45)
                                              : AppColors.borderSoft,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            k.icon,
                                            size: 18,
                                            color: _updateKind == k.key
                                                ? AppColors.successDark
                                                : AppColors.textTertiary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            k.label,
                                            style: AppTypography.style(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: _updateKind == k.key
                                                  ? AppColors.successDark
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        _TimeBlock(
                          title: 'Giờ ca sáng',
                          visible: _updateKind != 'AFTERNOON_SUPPLEMENT',
                          morningStart: _morningStart,
                          morningEnd: _morningEnd,
                          suggestedStart: _suggestedMorningStart,
                          suggestedEnd: _suggestedMorningEnd,
                          onPickStart: (v) =>
                              setState(() => _morningStart = v),
                          onPickEnd: (v) => setState(() => _morningEnd = v),
                          pickTime: pickTime,
                        ),
                        const SizedBox(height: 12),
                        _TimeBlock(
                          title: 'Giờ ca chiều',
                          visible: _updateKind != 'MORNING_SUPPLEMENT',
                          morningStart: _afternoonStart,
                          morningEnd: _afternoonEnd,
                          suggestedStart: _suggestedAfternoonStart,
                          suggestedEnd: _suggestedAfternoonEnd,
                          onPickStart: (v) =>
                              setState(() => _afternoonStart = v),
                          onPickEnd: (v) =>
                              setState(() => _afternoonEnd = v),
                          pickTime: pickTime,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Lý do (tuỳ chọn)',
                            labelStyle: AppTypography.caption(),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.brControl,
                            ),
                          ),
                          controller: _reasonController,
                          onChanged: (v) => _reason = v,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () =>
                                        Navigator.of(context).maybePop(),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _saving
                                    ? null
                                    : () async {
                                        final reason = _reason.trim();
                                        bool ok = true;
                                        String? err;
                                        if (_updateKind ==
                                            'FULL_DAY_SUPPLEMENT') {
                                          ok = _morningStart != null &&
                                              _morningEnd != null &&
                                              _afternoonStart != null &&
                                              _afternoonEnd != null;
                                          err =
                                              'Vui lòng nhập đủ giờ ca sáng và ca chiều';
                                        } else if (_updateKind ==
                                            'MORNING_SUPPLEMENT') {
                                          ok = _morningStart != null &&
                                              _morningEnd != null;
                                          err =
                                              'Vui lòng nhập đủ giờ ca sáng';
                                        } else {
                                          ok = _afternoonStart != null &&
                                              _afternoonEnd != null;
                                          err =
                                              'Vui lòng nhập đủ giờ ca chiều';
                                        }
                                        if (!ok) {
                                          showAppSnackBar(
                                            context,
                                            err ?? 'Thiếu thông tin',
                                            isError: true,
                                          );
                                          return;
                                        }

                                        setState(() => _saving = true);
                                        try {
                                          final repo = ref.read(
                                              attendanceRepositoryProvider);
                                          String fmt(TimeOfDay t) {
                                            return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
                                          }

                                          late String requestedStart;
                                          late String requestedEnd;
                                          String? requestedAfternoonStart;
                                          String? requestedAfternoonEnd;

                                          if (_updateKind ==
                                              'FULL_DAY_SUPPLEMENT') {
                                            requestedStart =
                                                fmt(_morningStart!);
                                            requestedEnd = fmt(_morningEnd!);
                                            requestedAfternoonStart =
                                                fmt(_afternoonStart!);
                                            requestedAfternoonEnd =
                                                fmt(_afternoonEnd!);
                                          } else if (_updateKind ==
                                              'MORNING_SUPPLEMENT') {
                                            requestedStart =
                                                fmt(_morningStart!);
                                            requestedEnd = fmt(_morningEnd!);
                                          } else {
                                            requestedStart =
                                                fmt(_afternoonStart!);
                                            requestedEnd =
                                                fmt(_afternoonEnd!);
                                          }

                                          await repo
                                              .applyQuangTrungSupplement(
                                            employeeId: widget.employeeId,
                                            workDate: widget.workDate,
                                            updateKind: _updateKind,
                                            requestedStart: requestedStart,
                                            requestedEnd: requestedEnd,
                                            reason: reason.isEmpty
                                                ? null
                                                : reason,
                                            requestedAfternoonStart:
                                                requestedAfternoonStart,
                                            requestedAfternoonEnd:
                                                requestedAfternoonEnd,
                                          );
                                          if (!mounted) return;
                                          showAppSnackBar(
                                            context,
                                            'Đã lưu công Quang Trung',
                                            isSuccess: true,
                                          );
                                          Navigator.of(context).maybePop();
                                        } catch (e) {
                                          if (!mounted) return;
                                          showAppSnackBar(
                                            context,
                                            e.toString(),
                                            isError: true,
                                          );
                                          setState(() => _saving = false);
                                        }
                                      },
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _existing == null
                                            ? 'Lưu'
                                            : 'Cập nhật',
                                        style: AppTypography.style(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay? get _suggestedMorningStart => _parseHm(widget.schedule?.morningStart);
  TimeOfDay? get _suggestedMorningEnd => _parseHm(widget.schedule?.morningEnd);
  TimeOfDay? get _suggestedAfternoonStart => _parseHm(widget.schedule?.afternoonStart);
  TimeOfDay? get _suggestedAfternoonEnd => _parseHm(widget.schedule?.afternoonEnd);

  static TimeOfDay? _parseHm(String? hm) {
    final text = hm?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final view = await repo.quangTrungSupplement(
        employeeId: widget.employeeId,
        workDate: widget.workDate,
      );
      final exists = view.exists;
      setState(() {
        _existing = view.exists ? view : null;
        _error = null;
        // We'll parse times in a separate block to keep state readable.
      });

      if (exists) {
        final morningStartRaw =
            QuangTrungSupplementView.parseHm(view.morningCheckIn);
        final morningEndRaw =
            QuangTrungSupplementView.parseHm(view.morningCheckOut);
        final afternoonStartRaw =
            QuangTrungSupplementView.parseHm(view.afternoonCheckIn);
        final afternoonEndRaw =
            QuangTrungSupplementView.parseHm(view.afternoonCheckOut);

        TimeOfDay? toTime(({int hour, int minute})? raw) {
          if (raw == null) return null;
          return TimeOfDay(hour: raw.hour, minute: raw.minute);
        }

        setState(() {
          _morningStart = toTime(morningStartRaw);
          _morningEnd = toTime(morningEndRaw);
          _afternoonStart = toTime(afternoonStartRaw);
          _afternoonEnd = toTime(afternoonEndRaw);

          _updateKind = view.updateKind.isNotEmpty ? view.updateKind : 'MORNING_SUPPLEMENT';
          _reason = view.reason ?? '';
          _reasonController.text = _reason;
          _loading = false;
        });
      } else {
        setState(() {
          _updateKind = 'FULL_DAY_SUPPLEMENT';
          _morningStart = _suggestedMorningStart;
          _morningEnd = _suggestedMorningEnd;
          _afternoonStart = _suggestedAfternoonStart;
          _afternoonEnd = _suggestedAfternoonEnd;
          _reason = '';
          _reasonController.text = '';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
}


class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.title,
    required this.visible,
    required this.morningStart,
    required this.morningEnd,
    required this.suggestedStart,
    required this.suggestedEnd,
    required this.onPickStart,
    required this.onPickEnd,
    required this.pickTime,
  });

  final String title;
  final bool visible;
  final TimeOfDay? morningStart;
  final TimeOfDay? morningEnd;
  final TimeOfDay? suggestedStart;
  final TimeOfDay? suggestedEnd;
  final ValueChanged<TimeOfDay> onPickStart;
  final ValueChanged<TimeOfDay> onPickEnd;
  final Future<TimeOfDay?> Function(TimeOfDay? initial, String title, {TimeOfDay? suggested}) pickTime;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    Future<void> _pickStart() async {
      final t = await pickTime(
        morningStart,
        '$title - bắt đầu',
        suggested: suggestedStart,
      );
      if (t != null) onPickStart(t);
    }

    Future<void> _pickEnd() async {
      final t = await pickTime(
        morningEnd,
        '$title - kết thúc',
        suggested: suggestedEnd,
      );
      if (t != null) onPickEnd(t);
    }

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Bắt đầu',
                  value: morningStart != null ? fmt(morningStart!) : '—',
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeField(
                  label: 'Kết thúc',
                  value: morningEnd != null ? fmt(morningEnd!) : '—',
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption(),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.style(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
