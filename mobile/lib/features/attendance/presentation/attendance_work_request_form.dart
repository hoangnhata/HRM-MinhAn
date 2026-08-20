import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_time_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_requests_controller.dart';
import '../data/attendance_repository.dart';
import 'attendance_enums.dart';
import 'work_request_day_logic.dart';

String _formatTimeOfDay(TimeOfDay t) =>
    '${t.hour}h${t.minute.toString().padLeft(2, '0')}';

/// Form tạo đơn công (giải trình / cập nhật) — UI mobile, logic đồng bộ web.
class AttendanceWorkRequestForm extends ConsumerStatefulWidget {
  const AttendanceWorkRequestForm({super.key, this.prefill});

  final AttendanceRequestPrefill? prefill;

  @override
  ConsumerState<AttendanceWorkRequestForm> createState() =>
      _AttendanceWorkRequestFormState();
}

class _AttendanceWorkRequestFormState
    extends ConsumerState<AttendanceWorkRequestForm> {
  late String _type;
  late DateTime _workDate;
  late String _updateKind;

  TimeOfDay? _morningStart;
  TimeOfDay? _morningEnd;
  TimeOfDay? _afternoonStart;
  TimeOfDay? _afternoonEnd;

  final Map<String, TimeOfDay> _explainedEdits = {};
  final Set<String> _selectedSlots = {};

  final _reasonController = TextEditingController();
  final _scrollController = ScrollController();

  DayShiftSchedule? _schedule;
  AttendanceDay? _day;
  UpdateScenario? _updateScenario;
  List<ExplanationPenaltySlot> _penaltySlots = const [];
  bool _loadingDay = false;
  bool _submitting = false;
  bool _kindLocked = false;
  String? _validationMessage;

  bool get _isUpdate => _type == 'UPDATE';
  bool get _isExplanation => _type == 'EXPLANATION';
  bool get _isEditing => widget.prefill?.editRequest != null;
  int? get _editRequestId => widget.prefill?.editRequest?.id;
  bool get _isFullDayUpdate => _updateKind == 'FULL_DAY_SUPPLEMENT';
  bool get _needsMorningTimes =>
      _isUpdate && (_isFullDayUpdate || _updateKind == 'MORNING_SUPPLEMENT');
  bool get _needsAfternoonTimes =>
      _isUpdate && (_isFullDayUpdate || _updateKind == 'AFTERNOON_SUPPLEMENT');

  int get _forgotUnits =>
      WorkRequestDayLogic.forgotUnitsForChoice(_updateKind, _updateScenario);

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    final edit = prefill?.editRequest;
    if (edit != null) {
      _type = edit.requestType;
      _workDate = edit.workDate ?? DateTime.now();
      _updateKind = edit.updateKind ?? 'MORNING_SUPPLEMENT';
      _reasonController.text = edit.reason?.trim() ?? '';
      _applyEditTimes(edit);
    } else {
      _type = prefill?.requestType ?? 'EXPLANATION';
      _workDate = prefill?.workDate ?? DateTime.now();
      _updateKind = prefill?.updateKind ?? 'MORNING_SUPPLEMENT';
    }
    _reloadDayContext();
  }

  void _applyEditTimes(AttendanceWorkRequest edit) {
    if (edit.requestType == 'UPDATE') {
      _morningStart = _parse(edit.requestedStart);
      _morningEnd = _parse(edit.requestedEnd);
      _afternoonStart = _parse(edit.requestedAfternoonStart);
      _afternoonEnd = _parse(edit.requestedAfternoonEnd);
      return;
    }
    if (edit.requestType == 'EXPLANATION') {
      void addSlot(String key, String? time) {
        if (time == null) return;
        _selectedSlots.add(key);
        final t = _parse(time);
        if (t != null) _explainedEdits[key] = t;
      }

      addSlot('morningIn', edit.explainedMorningIn);
      addSlot('morningOut', edit.explainedMorningOut);
      addSlot('afternoonIn', edit.explainedAfternoonIn);
      addSlot('afternoonOut', edit.explainedAfternoonOut);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reloadDayContext() async {
    final employeeId = ref.read(authControllerProvider).employeeId;
    setState(() => _loadingDay = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final results = await Future.wait([
        repo.daySchedule(date: _workDate, employeeId: employeeId),
        if (employeeId != null)
          repo.dayRange(employeeId, _workDate, _workDate)
        else
          Future.value(const <AttendanceDay>[]),
      ]);
      if (!mounted) return;
      final schedule = results[0] as DayShiftSchedule;
      final days = results[1] as List<AttendanceDay>;
      final day = days.isEmpty ? null : days.first;
      final scenario = WorkRequestDayLogic.detectUpdate(day);
      final slots = WorkRequestDayLogic.detectExplanationSlots(
        day: day,
        schedule: schedule,
      );
      final canExplain = slots.isNotEmpty || WorkRequestDayLogic.canExplain(day);
      final needsUpdate = WorkRequestDayLogic.needsUpdate(day);

      var nextType = _type;
      if (!_isEditing) {
        if (canExplain && !needsUpdate) {
          nextType = 'EXPLANATION';
        } else if (needsUpdate && !canExplain) {
          nextType = 'UPDATE';
        } else if (canExplain && needsUpdate) {
          if (_type != 'EXPLANATION' && _type != 'UPDATE') {
            nextType = widget.prefill?.requestType == 'UPDATE'
                ? 'UPDATE'
                : 'EXPLANATION';
          }
        } else if (widget.prefill?.requestType == 'UPDATE' ||
            widget.prefill?.updateKind != null) {
          nextType = 'UPDATE';
        }
      }

      setState(() {
        _schedule = schedule;
        _day = day;
        _updateScenario = scenario;
        _penaltySlots = slots;
        _type = nextType;
        if (nextType == 'UPDATE') {
          if (_isEditing) {
            _updateKind = widget.prefill?.editRequest?.updateKind ??
                widget.prefill?.updateKind ??
                _updateKind;
            _kindLocked = true;
          } else {
            _updateKind = widget.prefill?.updateKind ?? scenario.updateKind;
            _kindLocked = scenario.locked && widget.prefill?.updateKind == null;
            _applyScheduleTimes(schedule, scenario);
          }
        } else {
          _kindLocked = false;
          if (!_isEditing) {
            _selectedSlots
              ..clear()
              ..addAll(slots.map((s) => s.key));
            _explainedEdits
              ..clear()
              ..addEntries(
                slots.map((s) {
                  final parts = WorkRequestDayLogic.parseTimeOfDay(s.expected);
                  return MapEntry(
                    s.key,
                    parts == null
                        ? const TimeOfDay(hour: 7, minute: 0)
                        : TimeOfDay(hour: parts.hour, minute: parts.minute),
                  );
                }),
              );
          }
        }
        if (!_isEditing || nextType == 'UPDATE') {
          _morningStart ??= _parse(schedule.continuousStart ?? schedule.morningStart);
          _morningEnd ??= _parse(schedule.morningEnd);
          _afternoonStart ??= _parse(schedule.afternoonStart);
          _afternoonEnd ??=
              _parse(schedule.continuousEnd ?? schedule.afternoonEnd);
        }
        _loadingDay = false;
        _validationMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDay = false);
    }
  }

  void _applyScheduleTimes(DayShiftSchedule schedule, UpdateScenario scenario) {
    _morningStart = _parse(
          scenario.existingMorningIn ??
              schedule.continuousStart ??
              schedule.morningStart,
        ) ??
        _morningStart;
    _morningEnd = _parse(scenario.existingMorningOut ?? schedule.morningEnd) ??
        _morningEnd;
    _afternoonStart =
        _parse(scenario.existingAfternoonIn ?? schedule.afternoonStart) ??
            _afternoonStart;
    _afternoonEnd = _parse(
          scenario.existingAfternoonOut ??
              schedule.continuousEnd ??
              schedule.afternoonEnd,
        ) ??
        _afternoonEnd;
  }

  static TimeOfDay? _parse(String? hhmm) {
    final parts = WorkRequestDayLogic.parseTimeOfDay(hhmm);
    if (parts == null) return null;
    return TimeOfDay(hour: parts.hour, minute: parts.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initialDate: _workDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      title: 'Ngày áp dụng',
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
    if (picked == null) return;
    setState(() => _workDate = picked);
    await _reloadDayContext();
  }

  Future<TimeOfDay?> _pickTime(
    TimeOfDay? initial,
    String title, {
    String? subtitle,
    TimeOfDay? suggested,
    String? suggestedLabel,
  }) {
    return showAppTimePicker(
      context,
      initialTime: initial ?? suggested ?? TimeOfDay.now(),
      title: title,
      subtitle: subtitle,
      suggestedTime: suggested,
      suggestedLabel: suggestedLabel,
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
  }

  String? _validate() {
    if (_reasonController.text.trim().isEmpty) {
      return _isExplanation
          ? 'Vui lòng nhập lý do giải trình'
          : 'Vui lòng nhập lý do cập nhật';
    }
    if (_isExplanation) {
      if (_selectedSlots.isEmpty) {
        return 'Chọn ít nhất một khung giờ cần giải trình';
      }
      for (final key in _selectedSlots) {
        if (!_explainedEdits.containsKey(key)) {
          return 'Nhập giờ thay thế cho khung đã chọn';
        }
      }
    }
    if (_isUpdate) {
      if (_needsMorningTimes &&
          (_morningStart == null || _morningEnd == null)) {
        return 'Vui lòng nhập giờ bắt đầu và kết thúc ca sáng';
      }
      if (_needsAfternoonTimes &&
          (_afternoonStart == null || _afternoonEnd == null)) {
        return 'Vui lòng nhập giờ bắt đầu và kết thúc ca chiều';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final error = _validate();
    if (error != null) {
      setState(() => _validationMessage = error);
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted) return;
      showAppSnackBar(context, error, isError: true);
      return;
    }

    final employeeId = _isEditing
        ? widget.prefill!.editRequest!.employeeId
        : ref.read(authControllerProvider).employeeId;
    if (employeeId == null) {
      showAppSnackBar(
        context,
        'Tài khoản chưa liên kết hồ sơ nhân viên',
        isError: true,
      );
      return;
    }

    final payload = <String, dynamic>{
      'requestType': _type,
      'employeeId': employeeId,
      'workDate': _fmtDate(_workDate),
      'reason': _reasonController.text.trim(),
    };

    if (_isUpdate) {
      payload['updateKind'] = _updateKind;
      payload['shiftScope'] =
          WorkRequestDayLogic.shiftScopeFromUpdateKind(_updateKind);
      if (_isFullDayUpdate) {
        payload['requestedStart'] = _fmtTime(_morningStart);
        payload['requestedEnd'] = _fmtTime(_morningEnd);
        payload['requestedAfternoonStart'] = _fmtTime(_afternoonStart);
        payload['requestedAfternoonEnd'] = _fmtTime(_afternoonEnd);
      } else if (_updateKind == 'AFTERNOON_SUPPLEMENT') {
        payload['requestedStart'] = _fmtTime(_afternoonStart);
        payload['requestedEnd'] = _fmtTime(_afternoonEnd);
      } else {
        payload['requestedStart'] = _fmtTime(_morningStart);
        payload['requestedEnd'] = _fmtTime(_morningEnd);
      }
    }

    if (_isExplanation) {
      payload['shiftScope'] =
          WorkRequestDayLogic.shiftScopeFromExplanationKeys(_selectedSlots);
      for (final key in _selectedSlots) {
        final field = switch (key) {
          'morningOut' => 'explainedMorningOut',
          'afternoonIn' => 'explainedAfternoonIn',
          'afternoonOut' => 'explainedAfternoonOut',
          _ => 'explainedMorningIn',
        };
        payload[field] = _fmtTime(_explainedEdits[key]);
      }
    }

    setState(() {
      _submitting = true;
      _validationMessage = null;
    });
    final controller = ref.read(attendanceRequestsControllerProvider.notifier);
    final ok = _editRequestId != null
        ? await controller.update(_editRequestId!, payload)
        : await controller.submit(payload);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      showAppSnackBar(
        context,
        _isEditing
            ? 'Đã lưu thay đổi'
            : (_isExplanation ? 'Đã gửi giải trình' : 'Đã gửi đơn cập nhật công'),
        isSuccess: true,
      );
      Navigator.of(context).maybePop();
    } else {
      final message = ref.read(attendanceRequestsControllerProvider).error;
      showAppSnackBar(
        context,
        message ?? 'Gửi đơn thất bại. Vui lòng kiểm tra lại thông tin.',
        isError: true,
      );
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? _fmtTime(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String get _scheduleHint {
    final sch = _schedule;
    if (sch == null) return 'Đang tải lịch ca…';
    if (sch.continuousShift) {
      final a = DayShiftSchedule.displayTime(
            sch.continuousStart ?? sch.morningStart,
          ) ??
          '—';
      final b = DayShiftSchedule.displayTime(
            sch.continuousEnd ?? sch.afternoonEnd,
          ) ??
          '—';
      return 'Ca thông tầm: $a – $b';
    }
    if (sch.isSplitDay) {
      final ms = DayShiftSchedule.displayTime(sch.morningStart) ?? '—';
      final me = DayShiftSchedule.displayTime(sch.morningEnd) ?? '—';
      final as_ = DayShiftSchedule.displayTime(sch.afternoonStart) ?? '—';
      final ae = DayShiftSchedule.displayTime(sch.afternoonEnd) ?? '—';
      final name = sch.dayShiftTypeName?.trim();
      final prefix = name != null && name.isNotEmpty ? '$name · ' : '';
      return '$prefix Ca sáng–chiều: sáng $ms–$me · chiều $as_–$ae';
    }
    final ms = DayShiftSchedule.displayTime(sch.morningStart) ?? '—';
    final me = DayShiftSchedule.displayTime(sch.morningEnd) ?? '—';
    final as_ = DayShiftSchedule.displayTime(sch.afternoonStart) ?? '—';
    final ae = DayShiftSchedule.displayTime(sch.afternoonEnd) ?? '—';
    return 'Lịch: sáng $ms–$me · chiều $as_–$ae';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.currentUser;
    final name = me?.displayName ?? auth.fullName ?? '—';
    final department = me?.departmentName?.trim();
    final canExplain =
        _penaltySlots.isNotEmpty || WorkRequestDayLogic.canExplain(_day);
    final needsUpdate = WorkRequestDayLogic.needsUpdate(_day);
    final headerTitle = _isEditing
        ? 'Chỉnh sửa đơn công'
        : (_isExplanation ? 'Giải trình công' : 'Cập nhật công');
    final submitLabel = _isEditing
        ? 'Lưu thay đổi'
        : (_isExplanation ? 'Gửi giải trình' : 'Gửi đơn cập nhật');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.85)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: headerTitle,
                subtitle: _isExplanation
                    ? 'Điều chỉnh giờ muộn / về sớm'
                    : 'Bổ sung ca quên chấm công',
                icon: _isExplanation
                    ? Icons.schedule_rounded
                    : Icons.touch_app_rounded,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.md,
                  ),
                  children: [
                    _WorkFlowStrip(isExplanation: _isExplanation),
                    const SizedBox(height: AppSpacing.sm),
                    if (_validationMessage != null) ...[
                      NoticeBanner.error(
                        title: 'Kiểm tra lại thông tin',
                        message: _validationMessage!,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          AppIconBadge(
                            icon: Icons.person_outline_rounded,
                            color: AppColors.primary,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: AppTypography.style(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (department == null || department.isEmpty)
                                      ? 'Chưa gắn phòng ban'
                                      : department,
                                  style: AppTypography.style(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_loadingDay)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      accentColor: AppColors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Ngày áp dụng',
                                style: AppTypography.style(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              if (_schedule?.seasonLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: AppRadius.brPill,
                                  ),
                                  child: Text(
                                    _schedule!.seasonLabel!,
                                    style: AppTypography.style(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _TapField(
                            label: 'Ngày cần xử lý',
                            value: AppFormat.date(_workDate),
                            icon: Icons.event_outlined,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _scheduleHint,
                            style: AppTypography.caption(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DayInsightBanner(
                      canExplain: canExplain,
                      needsUpdate: needsUpdate,
                      slots: _penaltySlots,
                      forgotUnits: _forgotUnits,
                      forgotShifts: _day?.forgotShifts,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TypeSwitch(
                      selected: _type,
                      canExplain: canExplain || _type == 'EXPLANATION',
                      canUpdate: needsUpdate || _type == 'UPDATE',
                      locked: _isEditing,
                      onChanged: (v) => setState(() {
                        _type = v;
                        _validationMessage = null;
                        if (v == 'UPDATE' && _updateScenario != null) {
                          _updateKind = _updateScenario!.updateKind;
                          _kindLocked = _updateScenario!.locked;
                          if (_schedule != null) {
                            _applyScheduleTimes(_schedule!, _updateScenario!);
                          }
                        }
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_isExplanation) ...[
                      _ExplanationSlotsCard(
                        slots: _penaltySlots,
                        selected: _selectedSlots,
                        edits: _explainedEdits,
                        onToggle: (key) {
                          setState(() {
                            if (_selectedSlots.contains(key)) {
                              _selectedSlots.remove(key);
                            } else {
                              _selectedSlots.add(key);
                              final slot = _penaltySlots
                                  .firstWhere((s) => s.key == key);
                              _explainedEdits.putIfAbsent(key, () {
                                final p = WorkRequestDayLogic.parseTimeOfDay(
                                  slot.expected,
                                );
                                return p == null
                                    ? const TimeOfDay(hour: 7, minute: 0)
                                    : TimeOfDay(
                                        hour: p.hour,
                                        minute: p.minute,
                                      );
                              });
                            }
                            _validationMessage = null;
                          });
                        },
                        onPickReplacement: (key) async {
                          ExplanationPenaltySlot? slot;
                          for (final s in _penaltySlots) {
                            if (s.key == key) {
                              slot = s;
                              break;
                            }
                          }
                          final suggested = _parse(slot?.expected);
                          final t = await _pickTime(
                            _explainedEdits[key] ?? suggested,
                            'Giờ thay thế',
                            subtitle: slot == null
                                ? null
                                : '${slot.kindLabel} · ${slot.label}',
                            suggested: suggested,
                            suggestedLabel: suggested == null
                                ? null
                                : 'Dùng giờ lịch ${_formatTimeOfDay(suggested)}',
                          );
                          if (t != null) {
                            setState(() {
                              _explainedEdits[key] = t;
                              _selectedSlots.add(key);
                              _validationMessage = null;
                            });
                          }
                        },
                      ),
                    ] else ...[
                      _UpdateKindCard(
                        selected: _updateKind,
                        locked: _kindLocked,
                        scenario: _updateScenario,
                        onChanged: (v) => setState(() {
                          _updateKind = v;
                          _validationMessage = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RequestedTimesCard(
                        needsMorning: _needsMorningTimes,
                        needsAfternoon: _needsAfternoonTimes,
                        morningStart: _morningStart,
                        morningEnd: _morningEnd,
                        afternoonStart: _afternoonStart,
                        afternoonEnd: _afternoonEnd,
                        scheduleHint: _scheduleHint,
                        onPickMorningStart: () async {
                          final t = await _pickTime(
                            _morningStart,
                            'Vào ca sáng',
                            subtitle: 'Khung giờ đề nghị bổ sung',
                            suggested: _morningStart,
                          );
                          if (t != null) {
                            setState(() => _morningStart = t);
                          }
                        },
                        onPickMorningEnd: () async {
                          final t = await _pickTime(
                            _morningEnd,
                            'Ra ca sáng',
                            subtitle: 'Khung giờ đề nghị bổ sung',
                            suggested: _morningEnd,
                          );
                          if (t != null) {
                            setState(() => _morningEnd = t);
                          }
                        },
                        onPickAfternoonStart: () async {
                          final t = await _pickTime(
                            _afternoonStart,
                            'Vào ca chiều',
                            subtitle: 'Khung giờ đề nghị bổ sung',
                            suggested: _afternoonStart,
                          );
                          if (t != null) {
                            setState(() => _afternoonStart = t);
                          }
                        },
                        onPickAfternoonEnd: () async {
                          final t = await _pickTime(
                            _afternoonEnd,
                            'Ra ca chiều',
                            subtitle: 'Khung giờ đề nghị bổ sung',
                            suggested: _afternoonEnd,
                          );
                          if (t != null) {
                            setState(() => _afternoonEnd = t);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      accentColor: AppColors.secondary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isExplanation
                                ? 'Lý do giải trình'
                                : 'Lý do cập nhật',
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonController,
                            maxLines: 4,
                            minLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) {
                              if (_validationMessage != null) {
                                setState(() => _validationMessage = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: _isExplanation
                                  ? 'Ví dụ: kẹt xe, việc đột xuất…'
                                  : 'Ví dụ: quên chấm công ca chiều, máy lỗi…',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const NoticeBanner(
                      message:
                          'Chữ ký số được đính kèm khi gửi. Có thể rút đơn khi chưa được duyệt.',
                    ),
                  ],
                ),
              ),
              _WorkSubmitBar(
                submitting: _submitting,
                label: submitLabel,
                savingLabel: _isEditing ? 'Đang lưu...' : 'Đang gửi...',
                onSubmit: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayInsightBanner extends StatelessWidget {
  const _DayInsightBanner({
    required this.canExplain,
    required this.needsUpdate,
    required this.slots,
    required this.forgotUnits,
    this.forgotShifts,
  });

  final bool canExplain;
  final bool needsUpdate;
  final List<ExplanationPenaltySlot> slots;
  final int forgotUnits;
  final String? forgotShifts;

  @override
  Widget build(BuildContext context) {
    if (!canExplain && !needsUpdate) {
      return const NoticeBanner(
        title: 'Ngày này',
        message:
            'Chưa phát hiện muộn/về sớm hay thiếu ca. Bạn vẫn có thể gửi đơn nếu cần.',
      );
    }
    if (canExplain && needsUpdate) {
      return NoticeBanner.warning(
        title: 'Ngày có cả muộn và thiếu ca',
        message:
            'Có ${slots.length} khung phạt muộn/sớm và có thể cập nhật công '
            '(khoảng $forgotUnits lần quên chấm). Chọn đúng loại đơn bên dưới.',
      );
    }
    if (canExplain) {
      final detail = slots
          .map((s) => '${s.kindLabel} ${s.label.toLowerCase()} (${s.minutes} phút)')
          .join(' · ');
      return NoticeBanner(
        title: 'Phát hiện đi muộn / về sớm',
        message: detail.isEmpty
            ? 'Hệ thống đã ghi nhận phút muộn trên ngày này.'
            : detail,
        color: AppColors.secondary,
      );
    }
    return NoticeBanner(
      title: 'Có thể cập nhật công',
      message: forgotShifts != null && forgotShifts!.isNotEmpty
          ? 'Thiếu: $forgotShifts · đơn này trừ khoảng $forgotUnits lần quên chấm.'
          : 'Thiếu mốc chấm · đơn này trừ khoảng $forgotUnits lần quên chấm.',
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({
    required this.selected,
    required this.canExplain,
    required this.canUpdate,
    required this.onChanged,
    this.locked = false,
  });

  final String selected;
  final bool canExplain;
  final bool canUpdate;
  final ValueChanged<String> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(6),
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Row(
          children: [
            Expanded(
              child: _TypeChip(
                label: 'Giải trình',
                icon: Icons.schedule_rounded,
                selected: selected == 'EXPLANATION',
                enabled: !locked && (canExplain || selected == 'EXPLANATION'),
                onTap: () => onChanged('EXPLANATION'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _TypeChip(
                label: 'Cập nhật công',
                icon: Icons.touch_app_rounded,
                selected: selected == 'UPDATE',
                enabled: !locked && (canUpdate || selected == 'UPDATE'),
                onTap: () => onChanged('UPDATE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceMuted,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.brMd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
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

class _ExplanationSlotsCard extends StatelessWidget {
  const _ExplanationSlotsCard({
    required this.slots,
    required this.selected,
    required this.edits,
    required this.onToggle,
    required this.onPickReplacement,
  });

  final List<ExplanationPenaltySlot> slots;
  final Set<String> selected;
  final Map<String, TimeOfDay> edits;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onPickReplacement;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      accentColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Khung giờ bị trừ tiền',
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slots.isEmpty
                ? 'Không phát hiện mốc muộn/về sớm theo lịch ca.'
                : '${slots.length} khung — tích chọn khung cần giải trình',
            style: AppTypography.style(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (slots.isEmpty)
            Text(
              'Thử chọn ngày khác hoặc chuyển sang cập nhật công nếu thiếu ca.',
              style: AppTypography.style(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            )
          else
            for (final slot in slots) ...[
              _PenaltySlotTile(
                slot: slot,
                selected: selected.contains(slot.key),
                replacement: edits[slot.key],
                onToggle: () => onToggle(slot.key),
                onPickReplacement: () => onPickReplacement(slot.key),
              ),
              if (slot != slots.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _PenaltySlotTile extends StatelessWidget {
  const _PenaltySlotTile({
    required this.slot,
    required this.selected,
    required this.replacement,
    required this.onToggle,
    required this.onPickReplacement,
  });

  final ExplanationPenaltySlot slot;
  final bool selected;
  final TimeOfDay? replacement;
  final VoidCallback onToggle;
  final VoidCallback onPickReplacement;

  @override
  Widget build(BuildContext context) {
    final accent =
        slot.kind == 'LATE' ? AppColors.warning : AppColors.secondary;
    return AnimatedContainer(
      duration: AppDurations.fast,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.08)
            : AppColors.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.45)
              : AppColors.borderSoft,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.brSm,
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: selected ? accent : AppColors.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${slot.kindLabel} · ${slot.label}',
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${slot.minutes} phút · lịch ${DayShiftSchedule.displayTime(slot.expected) ?? slot.expected}',
                        style: AppTypography.style(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ReadonlyTime(
                    label: 'Máy chấm',
                    value: DayShiftSchedule.displayTime(slot.current) ??
                        slot.current,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TapField(
                    label: 'Thay thế',
                    value: replacement == null
                        ? 'Chọn'
                        : _formatTimeOfDay(replacement!),
                    icon: Icons.schedule_rounded,
                    onTap: onPickReplacement,
                    placeholder: replacement == null,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: AppRadius.brSm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 15,
                    color: AppColors.infoDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Gợi ý theo lịch: ${DayShiftSchedule.displayTime(slot.expected) ?? slot.expected}',
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.infoDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpdateKindCard extends StatelessWidget {
  const _UpdateKindCard({
    required this.selected,
    required this.locked,
    required this.onChanged,
    this.scenario,
  });

  final String selected;
  final bool locked;
  final UpdateScenario? scenario;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loại cập nhật',
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 4),
            Text(
              'Hệ thống đã chọn loại phù hợp theo mốc thiếu trên bảng công.',
              style: AppTypography.style(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final opt in WorkRequestDayLogic.updateKindOptions) ...[
            Builder(
              builder: (context) {
                final units = WorkRequestDayLogic.forgotUnitsForChoice(
                  opt.value,
                  scenario,
                );
                final isOn = selected == opt.value;
                final enabled = !locked || isOn;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Opacity(
                    opacity: enabled ? 1 : 0.4,
                    child: Material(
                      color: isOn
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceMuted,
                      borderRadius: AppRadius.brMd,
                      child: InkWell(
                        onTap: enabled ? () => onChanged(opt.value) : null,
                        borderRadius: AppRadius.brMd,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.brMd,
                            border: Border.all(
                              color: isOn
                                  ? AppColors.primary.withValues(alpha: 0.45)
                                  : AppColors.borderSoft,
                              width: isOn ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOn
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 20,
                                color: isOn
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${opt.label} · trừ $units lần quên chấm',
                                  style: AppTypography.style(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isOn
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestedTimesCard extends StatelessWidget {
  const _RequestedTimesCard({
    required this.needsMorning,
    required this.needsAfternoon,
    required this.morningStart,
    required this.morningEnd,
    required this.afternoonStart,
    required this.afternoonEnd,
    required this.scheduleHint,
    required this.onPickMorningStart,
    required this.onPickMorningEnd,
    required this.onPickAfternoonStart,
    required this.onPickAfternoonEnd,
  });

  final bool needsMorning;
  final bool needsAfternoon;
  final TimeOfDay? morningStart;
  final TimeOfDay? morningEnd;
  final TimeOfDay? afternoonStart;
  final TimeOfDay? afternoonEnd;
  final String scheduleHint;
  final VoidCallback onPickMorningStart;
  final VoidCallback onPickMorningEnd;
  final VoidCallback onPickAfternoonStart;
  final VoidCallback onPickAfternoonEnd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Khung giờ đề nghị',
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Điều chỉnh nếu khác lịch ca mặc định. $scheduleHint',
            style: AppTypography.style(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (needsMorning) ...[
            const SizedBox(height: 12),
            Text(
              'Ca sáng',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TapField(
                    label: 'Vào ca',
                    value: morningStart == null
                        ? 'Chọn'
                        : _formatTimeOfDay(morningStart!),
                    icon: Icons.login_rounded,
                    onTap: onPickMorningStart,
                    placeholder: morningStart == null,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TapField(
                    label: 'Ra ca',
                    value: morningEnd == null
                        ? 'Chọn'
                        : _formatTimeOfDay(morningEnd!),
                    icon: Icons.logout_rounded,
                    onTap: onPickMorningEnd,
                    placeholder: morningEnd == null,
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
          if (needsAfternoon) ...[
            const SizedBox(height: 12),
            Text(
              'Ca chiều',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TapField(
                    label: 'Vào ca',
                    value: afternoonStart == null
                        ? 'Chọn'
                        : _formatTimeOfDay(afternoonStart!),
                    icon: Icons.login_rounded,
                    onTap: onPickAfternoonStart,
                    placeholder: afternoonStart == null,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TapField(
                    label: 'Ra ca',
                    value: afternoonEnd == null
                        ? 'Chọn'
                        : _formatTimeOfDay(afternoonEnd!),
                    icon: Icons.logout_rounded,
                    onTap: onPickAfternoonEnd,
                    placeholder: afternoonEnd == null,
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadonlyTime extends StatelessWidget {
  const _ReadonlyTime({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 8 : 10,
        compact ? 10 : 12,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brControl,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_clock_rounded,
                size: compact ? 14 : 18,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: AppTypography.style(
              fontSize: compact ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool placeholder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brControl,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brControl,
            border: Border.all(
              color: placeholder
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.borderSoft,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              compact ? 8 : 10,
              compact ? 8 : 10,
              compact ? 8 : 10,
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: AppTypography.style(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: placeholder
                              ? AppColors.textTertiary
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Icon(icon, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: AppTypography.style(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: AppTypography.style(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: placeholder
                                    ? AppColors.textTertiary
                                    : AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _WorkFlowStrip extends StatefulWidget {
  const _WorkFlowStrip({required this.isExplanation});

  final bool isExplanation;

  static const _steps = [
    (
      Icons.send_rounded,
      'Gửi đơn',
      'Nhân viên',
    ),
    (
      Icons.supervisor_account_rounded,
      'Lãnh đạo duyệt',
      'Trưởng khoa / ĐD trưởng',
    ),
    (
      Icons.apartment_rounded,
      'HCNS duyệt',
      'Hành chính nhân sự',
    ),
    (
      Icons.verified_rounded,
      'Giám đốc duyệt',
      'Quyết định trừ tiền',
    ),
  ];

  @override
  State<_WorkFlowStrip> createState() => _WorkFlowStripState();
}

class _WorkFlowStripState extends State<_WorkFlowStrip> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final current = _WorkFlowStrip._steps.first;
    final hint = widget.isExplanation
        ? 'Giải trình muộn/sớm · trừ tiền nếu duyệt'
        : 'Cập nhật quên chấm · trừ tiền nếu duyệt';

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: AppRadius.brCard,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: const Icon(
                        Icons.account_tree_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Luồng duyệt',
                            style: AppTypography.style(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: AppDurations.fast,
                            child: Text(
                              _expanded
                                  ? '4 bước · $hint'
                                  : 'Bước 1/4 · ${current.$2}',
                              key: ValueKey('${_expanded}_$hint'),
                              style: AppTypography.style(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Bước 1/4',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            duration: AppDurations.normal,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _WorkFlowCollapsedSummary(
                icon: current.$1,
                title: current.$2,
                subtitle: current.$3,
                onExpand: _toggle,
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  for (var i = 0; i < _WorkFlowStrip._steps.length; i++)
                    _WorkFlowStep(
                      icon: _WorkFlowStrip._steps[i].$1,
                      title: _WorkFlowStrip._steps[i].$2,
                      subtitle: _WorkFlowStrip._steps[i].$3,
                      active: i == 0,
                      isLast: i == _WorkFlowStrip._steps.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkFlowCollapsedSummary extends StatelessWidget {
  const _WorkFlowCollapsedSummary({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onExpand,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExpand,
        borderRadius: AppRadius.brMd,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryLight,
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  'Hiện tại',
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _WorkFlowStep extends StatelessWidget {
  const _WorkFlowStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final lineColor = active
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.borderSoft;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryLight,
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                          )
                        : null,
                    color: active ? null : AppColors.surfaceMuted,
                    border: active
                        ? null
                        : Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: active ? Colors.white : AppColors.textTertiary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            lineColor,
                            AppColors.borderSoft.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.07)
                      : AppColors.surfaceMuted.withValues(alpha: 0.55),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.28)
                        : AppColors.borderSoft,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: active
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          'Hiện tại',
                          style: AppTypography.style(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkSubmitBar extends StatelessWidget {
  const _WorkSubmitBar({
    required this.submitting,
    required this.onSubmit,
    required this.label,
    this.savingLabel = 'Đang gửi...',
  });

  final bool submitting;
  final VoidCallback onSubmit;
  final String label;
  final String savingLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: submitting ? null : onSubmit,
          icon: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                    strokeCap: StrokeCap.round,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(submitting ? savingLabel : label),
        ),
      ),
    );
  }
}
