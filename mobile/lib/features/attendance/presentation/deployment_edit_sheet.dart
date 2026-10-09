import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_time_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../shared/models/attendance_models.dart';
import '../application/attendance_requests_controller.dart';
import 'attendance_enums.dart';

Future<bool?> showDeploymentEditSheet(
  BuildContext context, {
  required AttendanceWorkRequest request,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Sheet tự vẽ thanh kéo — tắt thanh mặc định của theme để không bị trùng.
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeploymentEditSheet(request: request),
  );
}

String _fmtSubmit(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

TimeOfDay? _parseHm(String? s) {
  if (s == null || s.length < 4) return null;
  final parts = s.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

class _DeploymentEditSheet extends ConsumerStatefulWidget {
  const _DeploymentEditSheet({required this.request});

  final AttendanceWorkRequest request;

  @override
  ConsumerState<_DeploymentEditSheet> createState() =>
      _DeploymentEditSheetState();
}

class _DeploymentEditSheetState extends ConsumerState<_DeploymentEditSheet> {
  late DateTime _workDate;
  late String _shiftScope;
  TimeOfDay? _start;
  TimeOfDay? _end;
  TimeOfDay? _afternoonStart;
  TimeOfDay? _afternoonEnd;
  final _reasonController = TextEditingController();
  bool _submitting = false;

  AttendanceWorkRequest get _request => widget.request;

  bool get _isMixed => _request.deploymentMixedShift;

  bool get _needsAfternoon =>
      !_isMixed &&
      (_shiftScope == 'FULL_DAY' ||
          _request.requestedAfternoonStart != null ||
          _request.requestedAfternoonEnd != null);

  @override
  void initState() {
    super.initState();
    final r = _request;
    _workDate = r.workDate ?? DateTime.now();
    _shiftScope = r.shiftScope ?? 'FULL_DAY';
    _start = _parseHm(r.requestedStart);
    _end = _parseHm(r.requestedEnd);
    _afternoonStart = _parseHm(r.requestedAfternoonStart);
    _afternoonEnd = _parseHm(r.requestedAfternoonEnd);
    _reasonController.text = r.reason?.trim() ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initialDate: _workDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 31)),
      title: 'Ngày điều động',
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
    if (picked == null) return;
    setState(() => _workDate = picked);
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial, String title) {
    return showAppTimePicker(
      context,
      initialTime: initial ?? TimeOfDay.now(),
      title: title,
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
  }

  String? _validate() {
    if (_reasonController.text.trim().isEmpty) {
      return 'Vui lòng nhập nội dung điều động';
    }
    if (_start == null || _end == null) {
      return 'Vui lòng nhập giờ bắt đầu và kết thúc';
    }
    if (_needsAfternoon && (_afternoonStart == null || _afternoonEnd == null)) {
      return 'Vui lòng nhập đủ khung giờ ca chiều';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final error = _validate();
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }

    final employeeId = _request.employeeId;
    if (employeeId == null) {
      showAppSnackBar(context, 'Thiếu thông tin nhân viên', isError: true);
      return;
    }

    final payload = <String, dynamic>{
      'requestType': 'DEPLOYMENT',
      'employeeId': employeeId,
      'workDate': _fmtDate(_workDate),
      'shiftScope': _shiftScope,
      'reason': _reasonController.text.trim(),
      'requestedStart': _fmtSubmit(_start!),
      'requestedEnd': _fmtSubmit(_end!),
    };
    if (_needsAfternoon) {
      payload['requestedAfternoonStart'] = _fmtSubmit(_afternoonStart!);
      payload['requestedAfternoonEnd'] = _fmtSubmit(_afternoonEnd!);
    }

    setState(() => _submitting = true);
    final ok = await ref
        .read(attendanceRequestsControllerProvider.notifier)
        .update(_request.id, payload);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      showAppSnackBar(context, 'Đã lưu thay đổi', isSuccess: true);
      Navigator.of(context).pop(true);
    } else {
      showAppSnackBar(
        context,
        ref.read(attendanceRequestsControllerProvider).error ??
            'Cập nhật thất bại',
        isError: true,
      );
    }
  }

  Future<void> _pickRange({
    required bool afternoon,
    required bool start,
  }) async {
    final current = afternoon
        ? (start ? _afternoonStart : _afternoonEnd)
        : (start ? _start : _end);
    final title = afternoon
        ? (start ? 'Giờ bắt đầu chiều' : 'Giờ kết thúc chiều')
        : (start ? 'Giờ bắt đầu' : 'Giờ kết thúc');
    final t = await _pickTime(current, title);
    if (t == null) return;
    setState(() {
      if (afternoon) {
        start ? _afternoonStart = t : _afternoonEnd = t;
      } else {
        start ? _start = t : _end = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scopeLabel = _isMixed
        ? 'Trong ca & ngoài ca'
        : AttendanceEnums.shiftScopeLabel(_shiftScope);
    final morningLabel = _isMixed
        ? 'Khung giờ liên tục'
        : _shiftScope == 'AFTERNOON'
        ? 'Ca chiều'
        : _needsAfternoon
        ? 'Ca sáng'
        : 'Khung giờ';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brSheetTop,
          boxShadow: AppShadows.overlay,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 36,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: AppRadius.brPill,
              ),
            ),
            _SheetHeader(
              employeeName: _request.employeeName,
              onClose: _submitting ? null : () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.md,
                ),
                children: [
                  const _SectionLabel('Ngày & buổi'),
                  _GroupCard(
                    children: [
                      _PickerRow(
                        icon: Icons.event_rounded,
                        label: 'Ngày điều động',
                        value: AppFormat.date(_workDate),
                        caption: AppFormat.weekday(_workDate),
                        onTap: _submitting ? null : _pickDate,
                      ),
                      _PickerRow(
                        icon: Icons.wb_twilight_rounded,
                        label: 'Buổi',
                        value: scopeLabel,
                        locked: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionLabel(
                    morningLabel,
                    trailing: _DurationPill(start: _start, end: _end),
                  ),
                  _TimeRangeCard(
                    start: _start,
                    end: _end,
                    enabled: !_submitting,
                    onPickStart: () =>
                        _pickRange(afternoon: false, start: true),
                    onPickEnd: () => _pickRange(afternoon: false, start: false),
                  ),
                  if (_needsAfternoon) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel(
                      'Ca chiều',
                      trailing: _DurationPill(
                        start: _afternoonStart,
                        end: _afternoonEnd,
                      ),
                    ),
                    _TimeRangeCard(
                      start: _afternoonStart,
                      end: _afternoonEnd,
                      enabled: !_submitting,
                      onPickStart: () =>
                          _pickRange(afternoon: true, start: true),
                      onPickEnd: () =>
                          _pickRange(afternoon: true, start: false),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionLabel('Nội dung điều động'),
                  TextField(
                    controller: _reasonController,
                    enabled: !_submitting,
                    maxLines: 5,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.style(
                      fontSize: 14.5,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Mô tả công việc được điều động…',
                      fillColor: AppColors.surfaceAlt,
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.borderSoft)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  bottom + AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppActionButton(
                        variant: AppActionVariant.outlineNeutral,
                        label: 'Huỷ',
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 3,
                      child: AppActionButton(
                        variant: AppActionVariant.primary,
                        icon: Icons.check_rounded,
                        label: _submitting ? 'Đang lưu…' : 'Lưu thay đổi',
                        loading: _submitting,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _displayTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.employeeName, required this.onClose});

  final String? employeeName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final name = employeeName?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.tint(AppColors.moduleDeployment),
              borderRadius: AppRadius.brBase,
              border: Border.all(
                color: AppColors.moduleDeployment.withValues(alpha: 0.16),
              ),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.moduleDeployment,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chỉnh sửa điều động',
                  style: AppTypography.style(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        name == null || name.isEmpty ? '—' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              foregroundColor: AppColors.textSecondary,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Khối nhóm các dòng chọn, ngăn cách bằng divider mảnh.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 60, color: AppColors.borderSoft),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null && !locked;
    final spoken = caption == null ? value : '$value, $caption';
    return Semantics(
      button: interactive,
      label: '$label: $spoken',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: interactive ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs + 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: locked
                          ? AppColors.surfaceHigh
                          : AppColors.primaryContainer,
                      borderRadius: AppRadius.brControl,
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: locked
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text.rich(
                          TextSpan(
                            text: value,
                            children: [
                              if (caption != null)
                                TextSpan(
                                  text: '  ·  $caption',
                                  style: AppTypography.style(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    const _LockedBadge()
                  else if (interactive)
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

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            'Cố định',
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cặp ô giờ Bắt đầu → Kết thúc trong cùng một khối.
class _TimeRangeCard extends StatelessWidget {
  const _TimeRangeCard({
    required this.start,
    required this.end,
    required this.enabled,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool enabled;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxs + 2),
      child: Row(
        children: [
          Expanded(
            child: _TimeCell(
              label: 'Bắt đầu',
              icon: Icons.login_rounded,
              value: start,
              onTap: enabled ? onPickStart : null,
            ),
          ),
          const SizedBox(
            width: 28,
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
          Expanded(
            child: _TimeCell(
              label: 'Kết thúc',
              icon: Icons.logout_rounded,
              value: end,
              onTap: enabled ? onPickEnd : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final TimeOfDay? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = value;
    final spoken = time == null ? 'chưa chọn' : _displayTime(time);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$label: $spoken',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brBase,
          side: BorderSide(
            color: time == null
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.borderSoft,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        label,
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time == null ? 'Chọn giờ' : _displayTime(time),
                    style: time == null
                        ? AppTypography.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: AppColors.primary,
                          )
                        : AppTypography.metric(fontSize: 19, height: 1.35),
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

/// Tổng thời lượng khung giờ, chỉ hiện khi giờ kết thúc sau giờ bắt đầu.
class _DurationPill extends StatelessWidget {
  const _DurationPill({required this.start, required this.end});

  final TimeOfDay? start;
  final TimeOfDay? end;

  @override
  Widget build(BuildContext context) {
    final s = start;
    final e = end;
    if (s == null || e == null) return const SizedBox.shrink();
    final minutes = (e.hour * 60 + e.minute) - (s.hour * 60 + s.minute);
    if (minutes <= 0) return const SizedBox.shrink();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final text = h == 0
        ? '$m phút'
        : m == 0
        ? '$h giờ'
        : '$h giờ $m phút';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 12,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
              tabular: true,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
