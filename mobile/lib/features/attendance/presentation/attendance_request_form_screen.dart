import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../shared/models/attendance_models.dart';
import '../../../core/utils/user_role.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_requests_controller.dart';
import '../data/attendance_repository.dart';
import 'attendance_enums.dart';
import 'attendance_work_request_form.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/request_form_widgets.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';

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

  /// Chế độ nghỉ (chỉ với PERSONAL_LEAVE): MARRIAGE / BEREAVEMENT.
  String? _personalLeaveKind;

  bool get _isLeave => AttendanceEnums.isLeaveRequestType(_type);
  bool get _isPersonal => _type == 'PERSONAL_LEAVE';

  /// Chính thức hưởng lương cơ bản; thử việc / thực tập nghỉ không lương.
  /// Backend chốt lại theo hồ sơ, đây chỉ để báo trước cho người gửi.
  bool get _personalLeavePaid =>
      ref.read(authControllerProvider).currentUser?.employeeStatus == 'ACTIVE';

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

  /// Sửa đơn: số ngày của chính đơn này đã nằm trong «chờ duyệt» của hạn mức —
  /// cộng lại để không bị trừ hai lần.
  int get _editingPendingLeaveDays {
    final edit = widget.prefill?.editRequest;
    if (edit == null || edit.requestType != 'LEAVE') return 0;
    if (!edit.status.startsWith('PENDING_')) return 0;
    final start = edit.workDate;
    if (start == null) return 0;
    final balance = _leaveBalance;
    if (balance != null && balance.year != start.year) return 0;
    final end = edit.endDate ?? start;
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  /// Số ngày phép còn xin được (đã cộng lại ngày của đơn đang sửa).
  int get _remainingLeaveDays {
    final balance = _leaveBalance;
    if (balance == null) return 0;
    final remaining = balance.remainingDays + _editingPendingLeaveDays;
    return remaining > balance.entitlementDays
        ? balance.entitlementDays
        : remaining;
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
      _personalLeaveKind = edit.personalLeaveKind;
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
      _endDate = _isPersonal
          ? _workDate.add(
              const Duration(days: AttendanceEnums.personalLeaveMaxDays - 1),
            )
          : _workDate;
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
        if (_isPersonal) {
          // Nghỉ chế độ mặc định trọn 3 ngày từ ngày bắt đầu.
          _endDate = picked.add(
            const Duration(days: AttendanceEnums.personalLeaveMaxDays - 1),
          );
        }
      } else {
        _endDate = picked.isBefore(_workDate) ? _workDate : picked;
      }
    });
    if (isStart && yearChanged) await _loadLeaveBalance();
  }

  /// Kiểm tra tại chỗ đúng theo ràng buộc của backend để tránh lỗi 400.
  String? _validate() {
    if (_isPersonal && _personalLeaveKind == null) {
      return 'Vui lòng chọn chế độ nghỉ: NLĐ kết hôn hoặc người thân NLĐ mất';
    }
    if (_reasonController.text.trim().isEmpty) {
      return _type == 'UNPAID_LEAVE'
          ? 'Vui lòng nhập lý do nghỉ không lương'
          : _isPersonal
          ? 'Vui lòng nhập lý do / thông tin sự việc'
          : 'Vui lòng nhập lý do nghỉ phép';
    }
    if (_isPersonal &&
        _requestedLeaveDays > AttendanceEnums.personalLeaveMaxDays) {
      return 'Nghỉ chế độ tối đa ${AttendanceEnums.personalLeaveMaxDays} ngày, '
          'đơn đang xin $_requestedLeaveDays ngày.';
    }
    if (_type == 'LEAVE' && _leaveBalance != null) {
      final days = _requestedLeaveDays;
      if (days > _remainingLeaveDays) {
        return 'Vượt hạn mức phép: còn $_remainingLeaveDays/'
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
      if (_isPersonal) 'personalLeaveKind': _personalLeaveKind,
    };

    setState(() => _submitting = true);
    final controller = ref.read(attendanceRequestsControllerProvider.notifier);
    final ok = _editRequestId != null
        ? await controller.update(_editRequestId!, payload)
        : await controller.submit(payload);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      HapticFeedback.mediumImpact();
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
    final personal = _isPersonal;
    final personalPaid = _personalLeavePaid;
    final title = _isEditing
        ? 'Chỉnh sửa đơn nghỉ'
        : personal
        ? 'Nghỉ chế độ'
        : (unpaid ? 'Nghỉ không lương' : 'Nghỉ phép năm');
    final subtitle = personal
        ? 'Kết hôn / người thân mất · tối đa 3 ngày · không trừ phép năm'
        : unpaid
        ? 'Ngày duyệt ghi 0 công · không trừ phép năm'
        : 'Trừ vào số ngày phép còn lại trong năm';
    final submitLabel = _isEditing
        ? 'Lưu thay đổi'
        : personal
        ? 'Gửi đơn nghỉ chế độ'
        : (unpaid ? 'Gửi đơn nghỉ không lương' : 'Gửi đơn nghỉ phép');
    final auth = ref.watch(authControllerProvider);
    final me = auth.currentUser;
    final name = me?.displayName ?? auth.fullName ?? '—';
    final department = me?.departmentName?.trim();
    final days = _requestedLeaveDays;
    final overLimit = personal
        ? days > AttendanceEnums.personalLeaveMaxDays
        : unpaid
        ? false
        : (_leaveBalance != null && days > _remainingLeaveDays);

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
                icon: personal
                    ? Icons.volunteer_activism_rounded
                    : unpaid
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
                    _LeaveFlowStrip(
                      steps: _LeaveFlowStrip.stepsFor(
                        ref.read(authControllerProvider).currentUser?.role,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedSwitcher(
                      duration: AppDurations.fast,
                      child: _validationMessage == null
                          ? const SizedBox.shrink()
                          : Padding(
                              key: ValueKey(_validationMessage),
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: NoticeBanner.error(
                                title: 'Kiểm tra lại thông tin',
                                message: _validationMessage!,
                              ),
                            ),
                    ),
                    AppSegmentedControl(
                      enabled: !_isEditing,
                      selectedIndex: switch (_type) {
                        'UNPAID_LEAVE' => 1,
                        'PERSONAL_LEAVE' => 2,
                        _ => 0,
                      },
                      onChanged: (i) => setState(() {
                        _type = switch (i) {
                          1 => 'UNPAID_LEAVE',
                          2 => 'PERSONAL_LEAVE',
                          _ => 'LEAVE',
                        };
                        _validationMessage = null;
                        if (_type == 'PERSONAL_LEAVE') {
                          // Mặc định trọn 3 ngày chế độ, người dùng có thể rút ngắn.
                          _endDate = _workDate.add(
                            const Duration(
                              days: AttendanceEnums.personalLeaveMaxDays - 1,
                            ),
                          );
                        }
                      }),
                      items: const [
                        AppSegmentItem(
                          label: 'Phép năm',
                          icon: Icons.beach_access_rounded,
                        ),
                        AppSegmentItem(
                          label: 'Không lương',
                          icon: Icons.money_off_rounded,
                        ),
                        AppSegmentItem(
                          label: 'Chế độ',
                          icon: Icons.volunteer_activism_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (personal) ...[
                      _PersonalLeaveKindCard(
                        selected: _personalLeaveKind,
                        enabled: !_isEditing,
                        onSelect: (kind) => setState(() {
                          _personalLeaveKind = kind;
                          _validationMessage = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _PersonalLeaveRegimeBanner(paid: personalPaid),
                      const SizedBox(height: AppSpacing.sm),
                    ] else if (!unpaid) ...[
                      _LeaveBalancePanel(
                        balance: _leaveBalance,
                        loading: _loadingBalance,
                        requestedDays: days,
                        overLimit: overLimit,
                        editingPendingDays: _editingPendingLeaveDays,
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
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                      margin: EdgeInsets.zero,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.28,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: AppAvatar(
                              name: name,
                              size: 40,
                              showShadow: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NGƯỜI XIN NGHỈ',
                                  style: AppTypography.uppercase(
                                    fontSize: 9.5,
                                    letterSpacing: 0.7,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    height: AppTypography.uppercaseHeight,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (department == null || department.isEmpty)
                                      ? 'Chưa gắn khoa/phòng'
                                      : department,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        (department == null ||
                                            department.isEmpty)
                                        ? AppColors.textTertiary
                                        : AppColors.textSecondary,
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
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormSectionHeader(
                            icon: Icons.date_range_rounded,
                            title: 'Thời gian nghỉ',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: overLimit
                                    ? AppColors.error.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: AppRadius.brPill,
                              ),
                              child: Text(
                                days <= 0
                                    ? 'Chọn ngày'
                                    : personal
                                    ? 'Xin $days/${AttendanceEnums.personalLeaveMaxDays} ngày'
                                    : 'Xin $days ngày',
                                style: AppTypography.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: AppTypography.uppercaseHeight,
                                  color: overLimit
                                      ? AppColors.errorDark
                                      : AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _PickerField(
                                  label: 'Từ ngày',
                                  value: AppFormat.date(_workDate),
                                  icon: Icons.event_outlined,
                                  onTap: () => _pickDate(isStart: true),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              Expanded(
                                child: _PickerField(
                                  label: 'Đến ngày',
                                  value: AppFormat.date(_endDate ?? _workDate),
                                  icon: Icons.event_available_outlined,
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            personal
                                ? (personalPaid
                                      ? 'Ghi đủ công hưởng lương cơ bản · không trừ phép năm · tối đa 3 ngày.'
                                      : 'Thử việc: ngày duyệt ghi 0 công (không lương) · tối đa 3 ngày.')
                                : unpaid
                                ? 'Ngày duyệt ghi 0 công · không trừ phép năm.'
                                : 'Đơn nghỉ tính cả ngày theo quy định.',
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (overLimit && personal) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Nghỉ chế độ tối đa ${AttendanceEnums.personalLeaveMaxDays} ngày, '
                              'đơn đang xin $days ngày.',
                              style: AppTypography.style(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                                height: 1.35,
                              ),
                            ),
                          ] else if (overLimit) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Đơn xin $days ngày nhưng chỉ còn '
                              '$_remainingLeaveDays ngày phép.',
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
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormSectionHeader(
                            icon: Icons.edit_note_rounded,
                            color: AppColors.secondary,
                            title: personal
                                ? 'Lý do / thông tin sự việc'
                                : unpaid
                                ? 'Lý do nghỉ không lương'
                                : 'Lý do nghỉ phép',
                            subtitle: 'Bắt buộc · người duyệt sẽ đọc phần này',
                          ),
                          const SizedBox(height: 12),
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
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                            decoration:
                                requestFieldDecoration(
                                  hint: personal
                                      ? (_personalLeaveKind == 'BEREAVEMENT'
                                            ? 'Ví dụ: Bố đẻ mất ngày 12/09, lo hậu sự tại quê…'
                                            : 'Ví dụ: Đăng ký kết hôn ngày 20/09, tổ chức lễ cưới…')
                                      : unpaid
                                      ? 'Ví dụ: Việc riêng, không dùng phép năm…'
                                      : 'Ví dụ: Nghỉ phép năm, việc gia đình…',
                                  multiline: true,
                                ).copyWith(
                                  errorText:
                                      (_validationMessage != null &&
                                          _validationMessage!.contains('lý do'))
                                      ? _validationMessage
                                      : null,
                                  errorMaxLines: 2,
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
  const _LeaveFlowStrip({required this.steps});

  final List<(IconData, String, String)> steps;

  /// Bỏ bước duyệt mà chính người gửi đơn là người duyệt (không tự duyệt đơn của mình).
  static List<(IconData, String, String)> stepsFor(UserRole? role) {
    // Trưởng phòng Điều dưỡng lập đơn: bỏ bước lãnh đạo — chỉ HCNS → Giám đốc.
    final isHead = role == UserRole.headDepartment ||
        role == UserRole.headHr ||
        role == UserRole.headNursing;
    final isHr = role == UserRole.hr2 || role == UserRole.headHr;
    return [
      (Icons.send_rounded, 'Gửi đơn', 'Bạn lập và gửi phiếu'),
      if (!isHead)
        (
          Icons.supervisor_account_rounded,
          'Lãnh đạo duyệt',
          'Trưởng khoa / ĐD trưởng',
        ),
      if (!isHr) (Icons.apartment_rounded, 'HCNS duyệt', 'Hành chính nhân sự'),
      (Icons.verified_rounded, 'Giám đốc duyệt', 'Duyệt cuối cùng'),
    ];
  }

  @override
  State<_LeaveFlowStrip> createState() => _LeaveFlowStripState();
}

class _LeaveFlowStripState extends State<_LeaveFlowStrip> {
  /// Mặc định thu gọn để form gọn hơn; nhấn để xem đủ các bước.
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final current = steps.first;

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
                                  ? '${steps.length} bước · đồng bộ với web'
                                  : 'Bước 1/${steps.length} · ${current.$2}',
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
                        'Bước 1/${steps.length}',
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
                  for (var i = 0; i < steps.length; i++)
                    _LeaveFlowStep(
                      icon: steps[i].$1,
                      title: steps[i].$2,
                      subtitle: steps[i].$3,
                      active: i == 0,
                      isLast: i == steps.length - 1,
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

/// Chọn chế độ nghỉ: hai thẻ lớn, chạm để chọn, hiện dấu tick khi được chọn.
class _PersonalLeaveKindCard extends StatelessWidget {
  const _PersonalLeaveKindCard({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelect;

  static const _accent = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      accentColor: _accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Chế độ nghỉ',
                style: AppTypography.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'Điều 115 BLLĐ 2019',
                style: AppTypography.style(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _KindOption(
            kind: 'MARRIAGE',
            title: 'Người lao động kết hôn',
            hint: 'Bản thân nhân viên đăng ký kết hôn',
            icon: Icons.favorite_border_rounded,
            selected: selected == 'MARRIAGE',
            enabled: enabled,
            onTap: () => onSelect('MARRIAGE'),
          ),
          const SizedBox(height: 8),
          _KindOption(
            kind: 'BEREAVEMENT',
            title: 'Người thân NLĐ mất',
            hint: 'Bố, mẹ, vợ, chồng, con hoặc bố mẹ bên vợ/chồng',
            icon: Icons.local_florist_outlined,
            selected: selected == 'BEREAVEMENT',
            enabled: enabled,
            onTap: () => onSelect('BEREAVEMENT'),
          ),
        ],
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.kind,
    required this.title,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String kind;
  final String title;
  final String hint;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  static const _accent = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: enabled,
      selected: selected,
      label: title,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.07) : AppColors.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: selected ? _accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: AppRadius.brMd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: selected ? 0.16 : 0.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: _accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.style(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            key: ValueKey('on'),
                            color: _accent,
                            size: 22,
                          )
                        : Icon(
                            Icons.radio_button_unchecked_rounded,
                            key: const ValueKey('off'),
                            color: AppColors.textTertiary,
                            size: 22,
                          ),
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

/// Báo trước chế độ hưởng lương theo trạng thái nhân viên; backend chốt lại khi nộp.
class _PersonalLeaveRegimeBanner extends StatelessWidget {
  const _PersonalLeaveRegimeBanner({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: paid ? AppColors.successLight : AppColors.warningLight,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            paid ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: 18,
            color: paid ? AppColors.successDark : AppColors.warningText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid
                      ? 'Nhân viên chính thức · 3 ngày hưởng lương cơ bản'
                      : 'Nhân viên thử việc / thực tập · 3 ngày không lương',
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: paid ? AppColors.successDark : AppColors.warningText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  paid
                      ? 'Không trừ vào phép năm. Ngày được duyệt ghi đủ công trên bảng công.'
                      : 'Ngày được duyệt ghi 0 công. Không trừ vào phép năm.',
                  style: AppTypography.style(
                    fontSize: 11.5,
                    height: 1.35,
                    color:
                        (paid ? AppColors.successDark : AppColors.warningText)
                            .withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    this.editingPendingDays = 0,
  });

  final LeaveBalance? balance;
  final bool loading;
  final int requestedDays;
  final bool overLimit;

  /// Ngày phép của chính đơn đang sửa — đã nằm trong «chờ duyệt», cộng lại để không trừ hai lần.
  final int editingPendingDays;

  @override
  Widget build(BuildContext context) {
    final entitlement = balance?.entitlementDays ?? 0;
    final used = balance?.usedDays ?? 0;
    final pending = ((balance?.pendingDays ?? 0) - editingPendingDays).clamp(
      0,
      entitlement,
    );
    final remaining = ((balance?.remainingDays ?? 0) + editingPendingDays)
        .clamp(0, entitlement);
    final after = (remaining - requestedDays).clamp(0, entitlement);
    final year = balance?.year ?? DateTime.now().year;
    final ratio = entitlement == 0
        ? 0.0
        : (remaining / entitlement).clamp(0.0, 1.0);
    final accent = overLimit ? AppColors.error : AppColors.primary;
    final noData = balance == null && !loading;

    return AppCard(
      gradient: TintedCardBackdrop.gradient(accent),
      borderRadius: AppRadius.brCard,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: TintedCardBackdrop(
        accent: accent,
        watermarkIcon: Icons.beach_access_rounded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TintedIconTile(
                    icon: Icons.beach_access_rounded,
                    color: accent,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Phép năm $year',
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    _StatusPill(
                      icon: noData
                          ? Icons.cloud_off_rounded
                          : overLimit
                          ? Icons.error_outline_rounded
                          : Icons.verified_rounded,
                      label: noData
                          ? 'Chưa tải được'
                          : overLimit
                          ? 'Vượt hạn mức'
                          : 'Đã đồng bộ',
                      color: noData
                          ? AppColors.textSecondary
                          : overLimit
                          ? AppColors.error
                          : AppColors.success,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (noData)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Chưa tải được số ngày phép. Bạn vẫn có thể gửi đơn, HCNS sẽ đối chiếu khi duyệt.',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CustomPaint(
                        painter: _FormLeaveRingPainter(
                          progress: ratio,
                          color: accent,
                          trackColor: accent.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$remaining',
                                style: AppTypography.display(
                                  fontSize: 22,
                                  color: Color.lerp(
                                    accent,
                                    AppColors.textPrimary,
                                    0.2,
                                  )!,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'CÒN',
                                style: AppTypography.uppercase(
                                  fontSize: 8.5,
                                  letterSpacing: 0.6,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.brControl,
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _BalanceCell(
                                label: 'Định mức',
                                value: '$entitlement',
                              ),
                              const VerticalDivider(
                                width: 1,
                                color: AppColors.divider,
                              ),
                              _BalanceCell(label: 'Đã dùng', value: '$used'),
                              const VerticalDivider(
                                width: 1,
                                color: AppColors.divider,
                              ),
                              _BalanceCell(
                                label: 'Chờ duyệt',
                                value: '$pending',
                                tone: pending > 0 ? AppColors.warning : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (requestedDays > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.07),
                      borderRadius: AppRadius.brControl,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          overLimit
                              ? Icons.warning_amber_rounded
                              : Icons.calculate_outlined,
                          size: 15,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            overLimit
                                ? 'Đơn xin $requestedDays ngày, vượt số ngày còn lại.'
                                : 'Đơn này xin $requestedDays ngày · còn $after ngày sau khi duyệt',
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: overLimit
                                  ? AppColors.errorDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTypography.metric(
              fontSize: 16,
              color: tone == null
                  ? AppColors.textPrimary
                  : Color.lerp(tone, AppColors.textPrimary, 0.25)!,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.uppercase(
              fontSize: 8.5,
              letterSpacing: 0.4,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
      padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11,
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

/// Tiêu đề khối trong form: icon đặc + tên + dòng phụ + nhãn phải.
class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({
    required this.icon,
    required this.title,
    this.color = AppColors.primary,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color color;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TintedIconTile(icon: icon, color: color, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.style(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  height: AppTypography.uppercaseHeight,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
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
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
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
    return RequestDateTile(label: label, value: value, onTap: onTap);
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
        12,
        AppSpacing.page,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: AppShadows.nav,
      ),
      child: AppActionButton(
        variant: AppActionVariant.primary,
        icon: Icons.send_rounded,
        label: submitting ? savingLabel : label,
        loading: submitting,
        onPressed: onSubmit,
      ),
    );
  }
}
