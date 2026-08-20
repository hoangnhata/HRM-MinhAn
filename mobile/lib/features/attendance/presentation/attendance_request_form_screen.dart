import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_requests_controller.dart';
import '../data/attendance_repository.dart';
import 'attendance_enums.dart';
import 'attendance_work_request_form.dart';

class AttendanceRequestFormScreen extends ConsumerStatefulWidget {
  const AttendanceRequestFormScreen({super.key, this.prefill});

  final AttendanceRequestPrefill? prefill;

  @override
  ConsumerState<AttendanceRequestFormScreen> createState() =>
      _AttendanceRequestFormScreenState();
}

class _AttendanceRequestFormScreenState
    extends ConsumerState<AttendanceRequestFormScreen> {
  late String _type;
  late DateTime _workDate;
  DateTime? _endDate;

  final _reasonController = TextEditingController();
  final _scrollController = ScrollController();
  LeaveBalance? _leaveBalance;
  bool _loadingBalance = false;
  bool _submitting = false;
  String? _validationMessage;

  bool get _isLeave => _type == 'LEAVE' || _type == 'UNPAID_LEAVE';

  bool get _isEditing => widget.prefill?.editRequest != null;

  int? get _editRequestId => widget.prefill?.editRequest?.id;

  /// Form mở từ danh sách nghỉ phép (hoặc đang chọn loại nghỉ).
  bool get _leaveFormMode {
    final allowed = widget.prefill?.allowedTypes;
    if (allowed != null && allowed.isNotEmpty) {
      return allowed.every(AttendanceEnums.isLeaveRequestType);
    }
    return _isLeave;
  }

  int get _requestedLeaveDays {
    final start = DateTime(_workDate.year, _workDate.month, _workDate.day);
    final endRaw = _endDate ?? _workDate;
    final end = DateTime(endRaw.year, endRaw.month, endRaw.day);
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    final edit = prefill?.editRequest;
    if (edit != null) {
      _type = edit.requestType;
      _workDate = edit.workDate ?? DateTime.now();
      _endDate = edit.endDate ?? _workDate;
      _reasonController.text = edit.reason?.trim() ?? '';
      _loadLeaveBalance();
      return;
    }
    final allowed = prefill?.allowedTypes;
    final preferLeave = allowed != null && allowed.isNotEmpty
        ? allowed.every(AttendanceEnums.isLeaveRequestType)
        : true;
    _type = prefill?.requestType ?? (preferLeave ? 'LEAVE' : 'EXPLANATION');
    _workDate = prefill?.workDate ?? DateTime.now();
    if (_leaveFormMode) {
      _endDate = _workDate;
      _loadLeaveBalance();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveBalance() async {
    setState(() => _loadingBalance = true);
    try {
      final balance = await ref
          .read(attendanceRepositoryProvider)
          .leaveBalance(year: _workDate.year);
      if (!mounted) return;
      setState(() => _leaveBalance = balance);
    } catch (_) {
      // Giữ form gửi được; backend vẫn kiểm hạn mức.
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showAppDatePicker(
      context,
      initialDate: isStart ? _workDate : (_endDate ?? _workDate),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      title: isStart ? 'Từ ngày' : 'Đến ngày',
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
    if (picked == null) return;

    final yearChanged = picked.year != _workDate.year;
    setState(() {
      _validationMessage = null;
      if (isStart) {
        _workDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
        _endDate ??= picked;
      } else {
        _endDate = picked.isBefore(_workDate) ? _workDate : picked;
      }
    });
    if (isStart && yearChanged) await _loadLeaveBalance();
  }

  /// Kiểm tra tại chỗ đúng theo ràng buộc của backend để tránh lỗi 400.
  String? _validate() {
    if (_reasonController.text.trim().isEmpty) {
      return _type == 'UNPAID_LEAVE'
          ? 'Vui lòng nhập lý do nghỉ không lương'
          : 'Vui lòng nhập lý do nghỉ phép';
    }
    if (_type == 'LEAVE' && _leaveBalance != null) {
      final days = _requestedLeaveDays;
      if (days > _leaveBalance!.remainingDays) {
        return 'Vượt hạn mức phép: còn ${_leaveBalance!.remainingDays}/'
            '${_leaveBalance!.entitlementDays} ngày, đơn xin $days ngày.';
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

    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
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
      'endDate': _fmtDate(_endDate ?? _workDate),
      'reason': _reasonController.text.trim(),
      // Backend đánh dấu shiftScope là @NotNull cho mọi loại đơn.
      'shiftScope': 'FULL_DAY',
    };

    setState(() => _submitting = true);
    final controller = ref.read(attendanceRequestsControllerProvider.notifier);
    final ok = _editRequestId != null
        ? await controller.update(_editRequestId!, payload)
        : await controller.submit(payload);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      showAppSnackBar(
        context,
        _isEditing ? 'Đã lưu thay đổi' : 'Đã gửi đơn nghỉ thành công',
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

  @override
  Widget build(BuildContext context) {
    if (_leaveFormMode) {
      return _buildLeaveScaffold();
    }
    return AttendanceWorkRequestForm(prefill: widget.prefill);
  }

  Widget _buildLeaveScaffold() {
    final unpaid = _type == 'UNPAID_LEAVE';
    final title = _isEditing
        ? 'Chỉnh sửa đơn nghỉ'
        : (unpaid ? 'Nghỉ không lương' : 'Nghỉ phép năm');
    final subtitle = unpaid
        ? 'Ngày duyệt ghi 0 công · không trừ phép năm'
        : 'Trừ vào số ngày phép còn lại trong năm';
    final submitLabel = _isEditing
        ? 'Lưu thay đổi'
        : (unpaid ? 'Gửi đơn nghỉ không lương' : 'Gửi đơn nghỉ phép');
    final auth = ref.watch(authControllerProvider);
    final me = auth.currentUser;
    final name = me?.displayName ?? auth.fullName ?? '—';
    final department = me?.departmentName?.trim();
    final days = _requestedLeaveDays;
    final overLimit = unpaid
        ? false
        : (_leaveBalance != null && days > _leaveBalance!.remainingDays);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.9)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: title,
                subtitle: subtitle,
                icon: unpaid
                    ? Icons.money_off_rounded
                    : Icons.beach_access_rounded,
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
                    const _LeaveFlowStrip(),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedSwitcher(
                      duration: AppDurations.fast,
                      child: _validationMessage == null
                          ? const SizedBox.shrink()
                          : Padding(
                              key: ValueKey(_validationMessage),
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: NoticeBanner.error(
                                title: 'Kiểm tra lại thông tin',
                                message: _validationMessage!,
                              ),
                            ),
                    ),
                    _LeaveTypeSwitch(
                      selected: _type,
                      onChanged: _isEditing
                          ? null
                          : (value) => setState(() {
                                _type = value;
                                _validationMessage = null;
                              }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (!unpaid) ...[
                      _LeaveBalancePanel(
                        balance: _leaveBalance,
                        loading: _loadingBalance,
                        requestedDays: days,
                        overLimit: overLimit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ] else ...[
                      const NoticeBanner(
                        title: 'Nghỉ không lương',
                        message:
                            'Ngày được duyệt sẽ ghi 0 công trên bảng công. Không trừ ngày phép năm.',
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
                                    height: 1.25,
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
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
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
                                'Thời gian nghỉ',
                                style: AppTypography.style(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: overLimit
                                      ? AppColors.error.withValues(alpha: 0.1)
                                      : AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderRadius: AppRadius.brPill,
                                ),
                                child: Text(
                                  days <= 0
                                      ? 'Chọn ngày'
                                      : 'Xin $days ngày',
                                  style: AppTypography.style(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: overLimit
                                        ? AppColors.error
                                        : AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PickerField(
                            label: 'Từ ngày',
                            value: AppFormat.date(_workDate),
                            icon: Icons.event_outlined,
                            onTap: () => _pickDate(isStart: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _PickerField(
                            label: 'Đến ngày',
                            value: AppFormat.date(_endDate ?? _workDate),
                            icon: Icons.event_available_outlined,
                            onTap: () => _pickDate(isStart: false),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            unpaid
                                ? 'Ngày duyệt ghi 0 công · không trừ phép năm.'
                                : 'Đơn nghỉ tính cả ngày theo quy định.',
                            style: AppTypography.caption(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (overLimit) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Đơn xin $days ngày nhưng chỉ còn '
                              '${_leaveBalance!.remainingDays} ngày phép.',
                              style: AppTypography.style(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      accentColor: AppColors.secondary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unpaid ? 'Lý do nghỉ không lương' : 'Lý do nghỉ phép',
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonController,
                            maxLines: 5,
                            minLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) {
                              if (_validationMessage != null) {
                                setState(() => _validationMessage = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: unpaid
                                  ? 'Ví dụ: Việc riêng, không dùng phép năm…'
                                  : 'Ví dụ: Nghỉ phép năm, việc gia đình…',
                              errorText: (_validationMessage != null &&
                                      _validationMessage!
                                          .contains('lý do'))
                                  ? _validationMessage
                                  : null,
                              errorMaxLines: 2,
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
              _SubmitBar(
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

class _LeaveFlowStrip extends StatefulWidget {
  const _LeaveFlowStrip();

  static const _steps = [
    (
      Icons.send_rounded,
      'Gửi đơn',
      'Bạn lập và gửi phiếu',
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
      'Duyệt cuối cùng',
    ),
  ];

  @override
  State<_LeaveFlowStrip> createState() => _LeaveFlowStripState();
}

class _LeaveFlowStripState extends State<_LeaveFlowStrip> {
  /// Mặc định thu gọn để form gọn hơn; nhấn để xem đủ 4 bước.
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final current = _LeaveFlowStrip._steps.first;

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
                                  ? '4 bước · đồng bộ với web'
                                  : 'Bước 1/4 · ${current.$2}',
                              key: ValueKey(_expanded),
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
                      child: Icon(
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
              child: _LeaveFlowCollapsedSummary(
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
                  for (var i = 0; i < _LeaveFlowStrip._steps.length; i++)
                    _LeaveFlowStep(
                      icon: _LeaveFlowStrip._steps[i].$1,
                      title: _LeaveFlowStrip._steps[i].$2,
                      subtitle: _LeaveFlowStrip._steps[i].$3,
                      active: i == 0,
                      isLast: i == _LeaveFlowStrip._steps.length - 1,
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

class _LeaveFlowCollapsedSummary extends StatelessWidget {
  const _LeaveFlowCollapsedSummary({
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

class _LeaveFlowStep extends StatelessWidget {
  const _LeaveFlowStep({
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

class _LeaveTypeSwitch extends StatelessWidget {
  const _LeaveTypeSwitch({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _LeaveTypeChip(
              label: 'Nghỉ phép năm',
              icon: Icons.beach_access_rounded,
              selected: selected == 'LEAVE',
              onTap: onChanged == null ? null : () => onChanged!('LEAVE'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _LeaveTypeChip(
              label: 'Không lương',
              icon: Icons.money_off_rounded,
              selected: selected == 'UNPAID_LEAVE',
              onTap: onChanged == null ? null : () => onChanged!('UNPAID_LEAVE'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveTypeChip extends StatelessWidget {
  const _LeaveTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surfaceMuted,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: AnimatedContainer(
          duration: AppDurations.fast,
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
                size: 18,
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
    );
  }
}

class _LeaveBalancePanel extends StatelessWidget {
  const _LeaveBalancePanel({
    required this.balance,
    required this.loading,
    required this.requestedDays,
    required this.overLimit,
  });

  final LeaveBalance? balance;
  final bool loading;
  final int requestedDays;
  final bool overLimit;

  @override
  Widget build(BuildContext context) {
    final remaining = balance?.remainingDays ?? 0;
    final entitlement = balance?.entitlementDays ?? 0;
    final used = balance?.usedDays ?? 0;
    final pending = balance?.pendingDays ?? 0;
    final year = balance?.year ?? DateTime.now().year;
    final ratio =
        entitlement == 0 ? 0.0 : (remaining / entitlement).clamp(0.0, 1.0);
    final accent = overLimit ? AppColors.error : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brCard,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.12),
            AppColors.surface,
            AppColors.surface,
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.beach_access_rounded, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'Phép $year',
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: overLimit
                            ? AppColors.errorDark
                            : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  overLimit ? 'Vượt hạn mức' : 'Đồng bộ web',
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: overLimit ? AppColors.error : AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (balance == null && !loading)
            Text(
              'Chưa tải được số ngày phép. Bạn vẫn có thể gửi đơn.',
              style: AppTypography.style(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            )
          else ...[
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _FormLeaveRingPainter(
                      progress: ratio,
                      color: accent,
                      trackColor: accent.withValues(alpha: 0.14),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$remaining',
                            style: AppTypography.style(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              height: 1,
                            ),
                          ),
                          Text(
                            'còn',
                            style: AppTypography.style(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overLimit
                            ? 'Đơn xin $requestedDays ngày vượt số còn lại.'
                            : 'Còn $remaining/$entitlement ngày · đơn này xin $requestedDays ngày.',
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MiniPill(label: 'Định mức $entitlement'),
                          const SizedBox(width: 6),
                          _MiniPill(label: 'Đã dùng $used'),
                          if (pending > 0) ...[
                            const SizedBox(width: 6),
                            _MiniPill(
                              label: 'Chờ $pending',
                              warn: true,
                            ),
                          ],
                        ],
                      ),
                    ],
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

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, this.warn = false});

  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? AppColors.warning : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: AppTypography.style(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: warn ? AppColors.warningText : AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _FormLeaveRingPainter extends CustomPainter {
  _FormLeaveRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 8) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FormLeaveRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brControl,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                suffixIcon: const Icon(Icons.expand_more_rounded, size: 20),
              ),
              child: Text(
                value,
                style: AppTypography.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.submitting,
    required this.onSubmit,
    this.label = 'Gửi đơn',
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
