import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
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

  bool get _needsAfternoon =>
      _shiftScope == 'FULL_DAY' ||
      _request.requestedAfternoonStart != null ||
      _request.requestedAfternoonEnd != null;

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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scopeLabel = AttendanceEnums.shiftScopeLabel(_shiftScope);
    final morningLabel = _shiftScope == 'AFTERNOON' ? 'Ca chiều' : 'Khung giờ';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSoft,
                borderRadius: AppRadius.brPill,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chỉnh sửa điều động',
                          style: AppTypography.style(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _request.employeeName ?? '—',
                          style: AppTypography.style(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                children: [
                  _FieldTile(
                    label: 'Ngày điều động',
                    value: AppFormat.date(_workDate),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FieldTile(
                    label: 'Buổi',
                    value: scopeLabel,
                    onTap: null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    morningLabel,
                    style: AppTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FieldTile(
                          label: 'Bắt đầu',
                          value: _start == null ? 'Chọn' : _displayTime(_start!),
                          onTap: () async {
                            final t = await _pickTime(_start, 'Giờ bắt đầu');
                            if (t != null) setState(() => _start = t);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FieldTile(
                          label: 'Kết thúc',
                          value: _end == null ? 'Chọn' : _displayTime(_end!),
                          onTap: () async {
                            final t = await _pickTime(_end, 'Giờ kết thúc');
                            if (t != null) setState(() => _end = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_needsAfternoon) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Ca chiều',
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _FieldTile(
                            label: 'Bắt đầu',
                            value: _afternoonStart == null
                                ? 'Chọn'
                                : _displayTime(_afternoonStart!),
                            onTap: () async {
                              final t = await _pickTime(
                                _afternoonStart,
                                'Giờ bắt đầu chiều',
                              );
                              if (t != null) {
                                setState(() => _afternoonStart = t);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FieldTile(
                            label: 'Kết thúc',
                            value: _afternoonEnd == null
                                ? 'Chọn'
                                : _displayTime(_afternoonEnd!),
                            onTap: () async {
                              final t = await _pickTime(
                                _afternoonEnd,
                                'Giờ kết thúc chiều',
                              );
                              if (t != null) {
                                setState(() => _afternoonEnd = t);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    minLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung điều động',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                bottom + AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _save,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_submitting ? 'Đang lưu...' : 'Lưu thay đổi'),
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
    '${t.hour}h${t.minute.toString().padLeft(2, '0')}';

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(
        value,
        style: AppTypography.style(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brControl,
      child: child,
    );
  }
}
