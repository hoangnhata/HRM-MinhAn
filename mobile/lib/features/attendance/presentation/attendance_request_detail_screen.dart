import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/approval_action_bar.dart';
import '../../../core/widgets/approval_signatures_section.dart';
import '../../../core/widgets/app_time_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_requests_controller.dart';
import 'approval_fine_sheet.dart';
import 'attendance_enums.dart';
import 'deployment_edit_sheet.dart';

class AttendanceRequestDetailScreen extends ConsumerStatefulWidget {
  const AttendanceRequestDetailScreen({
    super.key,
    required this.requestId,
    this.highlight = false,
  });

  final int requestId;
  final bool highlight;

  @override
  ConsumerState<AttendanceRequestDetailScreen> createState() =>
      _AttendanceRequestDetailScreenState();
}

class _AttendanceRequestDetailScreenState
    extends ConsumerState<AttendanceRequestDetailScreen> {
  bool _busy = false;
  int? _deployTimesRequestId;
  TimeOfDay? _deployStart;
  TimeOfDay? _deployEnd;
  TimeOfDay? _deployAfternoonStart;
  TimeOfDay? _deployAfternoonEnd;

  bool _canAdjustDeployment(AttendanceWorkRequest r, bool canReview) {
    return canReview &&
        r.requestType == 'DEPLOYMENT' &&
        (r.status == 'PENDING_HR' || r.status == 'PENDING_NURSING_HEAD');
  }

  void _syncDeployTimes(AttendanceWorkRequest r) {
    if (_deployTimesRequestId == r.id) return;
    _deployTimesRequestId = r.id;
    _deployStart = _parseHm(r.requestedStart);
    _deployEnd = _parseHm(r.requestedEnd);
    _deployAfternoonStart = _parseHm(r.requestedAfternoonStart);
    _deployAfternoonEnd = _parseHm(r.requestedAfternoonEnd);
  }

  bool _needsAfternoon(AttendanceWorkRequest r) =>
      r.requestedAfternoonStart != null || r.requestedAfternoonEnd != null;

  bool _sameTime(TimeOfDay a, TimeOfDay b) =>
      a.hour == b.hour && a.minute == b.minute;

  String? _deployTimeError(AttendanceWorkRequest r) {
    if (_deployStart == null ||
        _deployEnd == null ||
        _sameTime(_deployStart!, _deployEnd!)) {
      return 'Nhập khung giờ điều động hợp lệ.';
    }
    if (_needsAfternoon(r) &&
        (_deployAfternoonStart == null ||
            _deployAfternoonEnd == null ||
            _sameTime(_deployAfternoonStart!, _deployAfternoonEnd!))) {
      return 'Nhập đủ khung giờ điều động buổi chiều.';
    }
    return null;
  }

  String _fmtApi(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDeployTime(String field) async {
    final current = switch (field) {
      'start' => _deployStart,
      'end' => _deployEnd,
      'afternoonStart' => _deployAfternoonStart,
      _ => _deployAfternoonEnd,
    };
    final title = switch (field) {
      'start' => 'Bắt đầu điều động',
      'end' => 'Kết thúc điều động',
      'afternoonStart' => 'Bắt đầu buổi chiều',
      _ => 'Kết thúc buổi chiều',
    };
    final picked = await showAppTimePicker(
      context,
      initialTime: current ?? TimeOfDay.now(),
      title: title,
      confirmLabel: 'Chọn',
      cancelLabel: 'Huỷ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (field) {
        case 'start':
          _deployStart = picked;
        case 'end':
          _deployEnd = picked;
        case 'afternoonStart':
          _deployAfternoonStart = picked;
        default:
          _deployAfternoonEnd = picked;
      }
    });
  }

  AttendanceWorkRequest? _findInPending(AttendanceRequestsState state) =>
      state.pending.where((r) => r.id == widget.requestId).firstOrNull;

  AttendanceWorkRequest? _find(AttendanceRequestsState state) {
    for (final list in [state.pending, state.mine, state.history]) {
      final found = list.where((r) => r.id == widget.requestId).firstOrNull;
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _edit(AttendanceWorkRequest r) async {
    if (r.requestType == 'DEPLOYMENT') {
      final ok = await showDeploymentEditSheet(context, request: r);
      if (ok == true && mounted) {
        await ref
            .read(attendanceRequestsControllerProvider.notifier)
            .refreshQuietly();
      }
      return;
    }
    if (!mounted) return;
    await context.push(
      RoutePaths.attendanceRequestNew,
      extra: AttendanceRequestPrefill.edit(r),
    );
    if (!mounted) return;
    await ref
        .read(attendanceRequestsControllerProvider.notifier)
        .refreshQuietly();
  }

  Future<void> _withdraw(AttendanceWorkRequest r) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Rút đơn',
      message:
          'Đơn sẽ bị huỷ và không tiếp tục quy trình duyệt. Bạn có chắc chắn?',
      confirmLabel: 'Rút đơn',
      danger: true,
      icon: Icons.undo_rounded,
    );
    if (!confirm) return;

    setState(() => _busy = true);
    final ok = await ref
        .read(attendanceRequestsControllerProvider.notifier)
        .withdraw(r.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      showAppSnackBar(context, 'Đã rút đơn', isSuccess: true);
      Navigator.of(context).maybePop();
    } else {
      showAppSnackBar(
        context,
        ref.read(attendanceRequestsControllerProvider).error ??
            'Rút đơn thất bại',
        isError: true,
      );
    }
  }

  bool _canWaiveFine(AttendanceWorkRequest r) =>
      AttendanceEnums.directorDecidesFine(r);

  Future<void> _review(AttendanceWorkRequest r, bool approved) async {
    String? comment;
    bool? waiveForgotFine;
    bool? keepOriginalPunchTimes;
    String? requestedStart;
    String? requestedEnd;
    String? requestedAfternoonStart;
    String? requestedAfternoonEnd;

    if (approved && _canAdjustDeployment(r, true)) {
      final error = _deployTimeError(r);
      if (error != null) {
        showAppSnackBar(context, error, isError: true);
        return;
      }
      requestedStart = _fmtApi(_deployStart!);
      requestedEnd = _fmtApi(_deployEnd!);
      if (_needsAfternoon(r)) {
        requestedAfternoonStart = _fmtApi(_deployAfternoonStart!);
        requestedAfternoonEnd = _fmtApi(_deployAfternoonEnd!);
      }
    }

    if (approved) {
      if (_canWaiveFine(r)) {
        final decision = await showApprovalWithFineSheet(context, request: r);
        if (decision == null) return;
        waiveForgotFine = decision.waiveForgotFine;
        keepOriginalPunchTimes = decision.keepOriginalPunchTimes;
        comment = decision.comment;
      } else {
        final toDirector = r.status == 'PENDING_HR' &&
            r.requestType != 'BUSINESS_TRIP';
        final isHrWorkConfirm = r.status == 'PENDING_HR' &&
            (r.requestType == 'UPDATE' || r.requestType == 'EXPLANATION');
        final confirm = await showConfirmDialog(
          context,
          title: 'Duyệt đơn',
          message: isHrWorkConfirm
              ? 'HCNS chỉ xác nhận hồ sơ. Sau khi duyệt, đơn chuyển Giám đốc — người quyết định trừ tiền hay miễn phạt.'
              : toDirector
                  ? 'Đơn sẽ được chuyển Giám đốc kèm chữ ký của bạn. Xác nhận duyệt?'
                  : 'Đơn sẽ được chuyển sang bước tiếp theo kèm chữ ký của bạn. Xác nhận duyệt?',
          confirmLabel: toDirector ? 'Duyệt — chuyển Giám đốc' : 'Duyệt',
          icon: Icons.check_circle_outline_rounded,
        );
        if (!confirm) return;
      }
    } else {
      comment = await showNoteInputDialog(
        context,
        title: 'Từ chối đơn',
        label: 'Lý do từ chối',
        hint: 'Nêu rõ lý do để người gửi nắm được...',
        required: true,
        confirmLabel: 'Từ chối',
        confirmColor: AppColors.error,
      );
      if (comment == null) return;
    }

    setState(() => _busy = true);
    final ok = await ref
        .read(attendanceRequestsControllerProvider.notifier)
        .review(
          r,
          approved: approved,
          comment: comment,
          waiveForgotFine: waiveForgotFine,
          keepOriginalPunchTimes: keepOriginalPunchTimes == true ? true : null,
          requestedStart: requestedStart,
          requestedEnd: requestedEnd,
          requestedAfternoonStart: requestedAfternoonStart,
          requestedAfternoonEnd: requestedAfternoonEnd,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      HapticFeedback.mediumImpact();
      showAppSnackBar(
        context,
        approved ? 'Đã duyệt đơn' : 'Đã từ chối đơn',
        isSuccess: true,
      );
      Navigator.of(context).maybePop();
    } else {
      showAppSnackBar(
        context,
        ref.read(attendanceRequestsControllerProvider).error ??
            'Thao tác thất bại',
        isError: true,
      );
    }
  }

  String get _appBarTitle {
    final r = _find(ref.read(attendanceRequestsControllerProvider));
    if (r == null) return 'Chi tiết đơn';
    return switch (r.requestType) {
      'LEAVE' || 'UNPAID_LEAVE' || 'PERSONAL_LEAVE' => 'Chi tiết đơn nghỉ',
      'DEPLOYMENT' => 'Chi tiết điều động',
      _ => 'Chi tiết đơn công',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceRequestsControllerProvider);
    final request = _find(state);
    final auth = ref.watch(authControllerProvider);
    final canReview = _findInPending(state) != null;
    final myEmployeeId = auth.employeeId;
    final canWithdraw =
        request != null &&
        request.canWithdrawBy(
          myEmployeeId: myEmployeeId,
          myUsername: auth.currentUser?.username,
          role: auth.role,
        );
    final canEdit =
        request != null &&
        request.canEditPending(
          myEmployeeId: myEmployeeId,
          myUsername: auth.currentUser?.username,
          role: auth.role,
        );
    final adjustDeployment =
        request != null && _canAdjustDeployment(request, canReview);
    if (request != null && request.requestType == 'DEPLOYMENT') {
      _syncDeployTimes(request);
    }
    final selectedDeployTimes = <String>{
      if (_deployStart != null) _fmtApi(_deployStart!),
      if (_deployEnd != null) _fmtApi(_deployEnd!),
      if (_deployAfternoonStart != null) _fmtApi(_deployAfternoonStart!),
      if (_deployAfternoonEnd != null) _fmtApi(_deployAfternoonEnd!),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppScreenHeader(
            dense: true,
            title: _appBarTitle,
            icon: Icons.description_outlined,
            eyebrow: 'Chấm công',
            onBack: () => context.pop(),
          ),
          Expanded(
            child: request == null
                ? state.loading
                      ? const LoadingState(label: 'Đang tải đơn...')
                      : const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Không tìm thấy đơn',
                          message:
                              'Đơn có thể đã bị rút hoặc bạn không còn quyền xem.',
                        )
                : Column(
                    children: [
                      Expanded(
                        child: HighlightPulse(
                          active: widget.highlight,
                          child: RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () => ref
                                .read(
                                  attendanceRequestsControllerProvider.notifier,
                                )
                                .refreshQuietly(),
                            child: _Body(
                              request: request,
                              adjustDeployment: adjustDeployment,
                              deployStart: _deployStart,
                              deployEnd: _deployEnd,
                              deployAfternoonStart: _deployAfternoonStart,
                              deployAfternoonEnd: _deployAfternoonEnd,
                              onPickDeployTime: _pickDeployTime,
                              highlightedPunchTimes: adjustDeployment
                                  ? selectedDeployTimes
                                  : const {},
                            ),
                          ),
                        ),
                      ),
                      if (canReview || canWithdraw || canEdit)
                        ApprovalActionBar(
                          busy: _busy,
                          onApprove:
                              canReview ? () => _review(request, true) : null,
                          onReject:
                              canReview ? () => _review(request, false) : null,
                          onWithdraw:
                              canWithdraw ? () => _withdraw(request) : null,
                          onEdit: canEdit ? () => _edit(request) : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.request,
    this.adjustDeployment = false,
    this.deployStart,
    this.deployEnd,
    this.deployAfternoonStart,
    this.deployAfternoonEnd,
    this.onPickDeployTime,
    this.highlightedPunchTimes = const {},
  });

  final AttendanceWorkRequest request;
  final bool adjustDeployment;
  final TimeOfDay? deployStart;
  final TimeOfDay? deployEnd;
  final TimeOfDay? deployAfternoonStart;
  final TimeOfDay? deployAfternoonEnd;
  final ValueChanged<String>? onPickDeployTime;
  final Set<String> highlightedPunchTimes;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final typeColor = AttendanceEnums.requestTypeColor(r.requestType);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      children: [
        _HeroHeader(request: r, typeColor: typeColor),
        const SizedBox(height: 10),
        _PersonCard(request: r),
        const SizedBox(height: 10),
        _ContentCard(request: r),
        if (_showPunchLog(r)) ...[
          const SizedBox(height: 10),
          _PunchLogCard(
            times: r.attendancePunchTimes,
            highlighted: highlightedPunchTimes,
          ),
        ],
        if (adjustDeployment) ...[
          const SizedBox(height: 10),
          _DeploymentTimeAdjust(
            nursingHead: r.status == 'PENDING_NURSING_HEAD',
            needsAfternoon:
                r.requestedAfternoonStart != null ||
                r.requestedAfternoonEnd != null,
            start: deployStart,
            end: deployEnd,
            afternoonStart: deployAfternoonStart,
            afternoonEnd: deployAfternoonEnd,
            onPick: onPickDeployTime ?? (_) {},
          ),
        ] else if (_hasTimeBlock(r)) ...[
          const SizedBox(height: 10),
          _TimeBlock(request: r),
        ],
        const SizedBox(height: 10),
        ApprovalSignaturesSection(
          title: 'Lịch sử duyệt',
          steps: _signatureSteps(r),
        ),
      ],
    );
  }

  bool _showPunchLog(AttendanceWorkRequest r) {
    return (r.requestType == 'UPDATE' ||
            r.requestType == 'EXPLANATION' ||
            r.requestType == 'DEPLOYMENT') &&
        r.attendancePunchTimes.isNotEmpty;
  }

  bool _hasTimeBlock(AttendanceWorkRequest r) {
    return switch (r.requestType) {
      'UPDATE' =>
        r.requestedStart != null ||
            r.requestedEnd != null ||
            r.requestedAfternoonStart != null,
      'EXPLANATION' =>
        r.explainedMorningIn != null ||
            r.explainedMorningOut != null ||
            r.explainedAfternoonIn != null ||
            r.explainedAfternoonOut != null,
      'DEPLOYMENT' => r.requestedStart != null && r.requestedEnd != null,
      _ => false,
    };
  }

  List<ApprovalSignatureStep> _signatureSteps(AttendanceWorkRequest r) {
    String person(String? a, String? b, String? c, String fallback) {
      for (final v in [a, b, c]) {
        final t = v?.trim();
        if (t != null && t.isNotEmpty) return t;
      }
      return fallback;
    }

    String? note(String? comment, {required bool pending, required bool rejected}) {
      final text = comment?.trim();
      if (text != null && text.isNotEmpty) return comment;
      if (pending) return 'Đang chờ duyệt ký.';
      if (rejected) return 'Đã từ chối.';
      return null;
    }

    return [
      ApprovalSignatureStep(
        role: 'Người lập phiếu · ${r.requestedByUsername ?? r.employeeName ?? '—'}',
        comment: (r.requesterSignatureUrl?.trim().isNotEmpty ?? false)
            ? 'Chữ ký số được gắn khi gửi phiếu.'
            : 'Phiếu này chưa lưu chữ ký người lập.',
        reviewedAt: r.createdAt,
        reviewerUsername: r.requestedByUsername,
        signatureUrl: r.requesterSignatureUrl,
      ),
      if (!r.headSkipped)
        ApprovalSignatureStep(
          role:
              'Trưởng khoa/phòng · ${person(r.headReviewerName, r.headReviewerUsername, r.flowHeadName, r.status == 'PENDING_HEAD' ? 'Đang chờ' : '—')}',
          comment: note(
            r.headComment,
            pending: r.status == 'PENDING_HEAD',
            rejected: r.status == 'HEAD_REJECTED',
          ),
          reviewedAt: r.headReviewedAt,
          reviewerUsername: r.headReviewerUsername,
          signatureUrl: r.headSignatureUrl,
          pending: r.status == 'PENDING_HEAD',
          rejected: r.status == 'HEAD_REJECTED',
        ),
      ApprovalSignatureStep(
        role:
            'Trưởng phòng Điều dưỡng · ${person(r.nursingHeadReviewerName, r.nursingHeadReviewerUsername, r.flowNursingHeadName, r.status == 'PENDING_NURSING_HEAD' ? 'Đang chờ' : '—')}',
        comment: note(
          r.nursingHeadComment,
          pending: r.status == 'PENDING_NURSING_HEAD',
          rejected: r.status == 'NURSING_HEAD_REJECTED',
        ),
        reviewedAt: r.nursingHeadReviewedAt,
        reviewerUsername: r.nursingHeadReviewerUsername,
        signatureUrl: r.nursingHeadSignatureUrl,
        pending: r.status == 'PENDING_NURSING_HEAD',
        rejected: r.status == 'NURSING_HEAD_REJECTED',
      ),
      ApprovalSignatureStep(
        role:
            'HCNS · ${person(r.hrReviewerName, r.hrReviewerUsername, r.flowHrName, r.status == 'PENDING_HR' ? 'Đang chờ' : '—')}',
        comment: note(
          r.hrComment,
          pending: r.status == 'PENDING_HR',
          rejected: r.status == 'HR_REJECTED',
        ),
        reviewedAt: r.hrReviewedAt,
        reviewerUsername: r.hrReviewerUsername,
        signatureUrl: r.hrSignatureUrl,
        pending: r.status == 'PENDING_HR',
        rejected: r.status == 'HR_REJECTED',
      ),
      ApprovalSignatureStep(
        role:
            'Giám đốc · ${person(r.directorReviewerName, r.directorReviewerUsername, r.flowDirectorName, r.status == 'PENDING_DIRECTOR' ? 'Đang chờ' : '—')}',
        comment: note(
          r.directorComment,
          pending: r.status == 'PENDING_DIRECTOR',
          rejected: r.status == 'DIRECTOR_REJECTED',
        ),
        reviewedAt: r.directorReviewedAt,
        reviewerUsername: r.directorReviewerUsername,
        signatureUrl: r.directorSignatureUrl,
        pending: r.status == 'PENDING_DIRECTOR',
        rejected: r.status == 'DIRECTOR_REJECTED',
      ),
    ];
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.request, required this.typeColor});

  final AttendanceWorkRequest request;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    final statusColor = AttendanceEnums.statusColor(request.status);
    final statusLabel = AttendanceEnums.statusLabel(request.status);
    final statusIcon =
        request.status == 'APPROVED' || request.status == 'APPROVED_NO_FINE'
        ? Icons.check_circle_outline_rounded
        : request.status.endsWith('_REJECTED')
        ? Icons.cancel_outlined
        : request.status == 'WITHDRAWN'
        ? Icons.undo_rounded
        : Icons.hourglass_top_rounded;

    return Padding(
      padding: AppSpacing.pageH,
      child: AppCard(
        accentColor: typeColor,
        gradient: AppGradients.tint(typeColor),
        borderRadius: AppRadius.brCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(
                  icon: AttendanceEnums.requestTypeIcon(request.requestType),
                  color: typeColor,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AttendanceEnums.requestTypeLabel(request.requestType),
                        style: AppTypography.style(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusChip(
                        label: statusLabel,
                        color: statusColor,
                        icon: statusIcon,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(icon: Icons.tag_rounded, text: '#${request.id}'),
                _Chip(
                  icon: Icons.event_outlined,
                  text: AppFormat.date(request.workDate),
                ),
                if (request.employeeName?.isNotEmpty == true)
                  _Chip(
                    icon: Icons.person_outline_rounded,
                    text: request.employeeName!,
                  ),
              ],
            ),
            if (request.status == 'WITHDRAWN') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  'Đơn đã được người gửi rút khỏi quy trình.',
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchLogCard extends StatelessWidget {
  const _PunchLogCard({required this.times, this.highlighted = const {}});

  final List<String> times;
  final Set<String> highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pageH,
      child: _Section(
        title: 'Log máy chấm',
        icon: Icons.fingerprint_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giờ máy ghi nhận trong ngày đơn (đã sắp xếp).',
              style: AppTypography.body(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in times)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: highlighted.contains(t)
                          ? AppColors.primary.withValues(alpha: 0.22)
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.brSm,
                      border: Border.all(
                        color: highlighted.contains(t)
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.22),
                        width: highlighted.contains(t) ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t,
                          style: AppTypography.style(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.request});

  final AttendanceWorkRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Padding(
      padding: AppSpacing.pageH,
      child: _Section(
        title: 'Người liên quan',
        icon: Icons.badge_outlined,
        child: Column(
          children: [
            if (r.employeeName != null)
              _KV(label: 'Họ tên', value: r.employeeName!),
            if (r.positionTitle != null)
              _KV(label: 'Chức danh', value: r.positionTitle!),
            if (r.department != null)
              _KV(label: 'Phòng ban', value: r.department!),
            _KV(label: 'Ngày gửi', value: AppFormat.dateTime(r.createdAt)),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.request});

  final AttendanceWorkRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final hasRange = r.endDate != null && r.endDate != r.workDate;
    final type = r.requestType;

    return Padding(
      padding: AppSpacing.pageH,
      child: _Section(
        title: 'Nội dung đơn',
        icon: Icons.description_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KV(
              label: hasRange ? 'Từ ngày' : 'Ngày áp dụng',
              value: AppFormat.date(r.workDate),
            ),
            if (hasRange)
              _KV(label: 'Đến ngày', value: AppFormat.date(r.endDate)),
            // Chỉ hiện field đúng loại đơn (web WorkRequestDetailDialog).
            if (type == 'PERSONAL_LEAVE') ...[
              _KV(
                label: 'Chế độ nghỉ',
                value:
                    r.personalLeaveKindLabel ??
                    AttendanceEnums
                        .personalLeaveKindLabels[r.personalLeaveKind ?? ''] ??
                    '—',
              ),
              _KV(
                label: 'Hưởng lương',
                value: r.personalLeavePaid == false
                    ? 'Không lương (thử việc)'
                    : 'Lương cơ bản, không trừ phép năm',
              ),
            ],
            if (type == 'LEAVE' ||
                type == 'UNPAID_LEAVE' ||
                type == 'PERSONAL_LEAVE')
              _KV(
                label: type == 'UNPAID_LEAVE'
                    ? 'Số ngày không lương'
                    : type == 'PERSONAL_LEAVE'
                    ? 'Số ngày nghỉ chế độ'
                    : 'Số ngày phép',
                value: '${AppFormat.score(r.leaveDays ?? 1)} ngày',
              ),
            if (type == 'BUSINESS_TRIP') ...[
              _KV(
                label: 'Số ngày công tác',
                value: '${AppFormat.score(r.tripDays ?? 1)} ngày',
              ),
              if (r.location != null)
                _KV(label: 'Địa điểm', value: r.location!),
            ],
            if (type == 'UPDATE' && r.updateKind != null)
              _KV(
                label: 'Loại cập nhật',
                value: AttendanceEnums.updateKindLabel(r.updateKind),
              ),
            if ((type == 'UPDATE' || type == 'EXPLANATION') &&
                r.shiftScope != null)
              _KV(
                label: 'Buổi',
                value: AttendanceEnums.shiftScopeLabel(r.shiftScope),
              ),
            if (type == 'EXPLANATION' && r.explanationKind != null)
              _KV(
                label: 'Loại giải trình',
                value: AttendanceEnums.explanationKindLabel(r.explanationKind),
              ),
            if (type == 'DEPLOYMENT') ...[
              _KV(
                label: 'Hình thức',
                value: r.deploymentMixedShift
                    ? 'Trong ca & ngoài ca'
                    : r.deploymentInsideShift
                        ? 'Trong ca'
                        : 'Ngoài ca',
              ),
              if (r.deploymentActualHours != null &&
                  r.deploymentCreditedHours != null)
                _KV(
                  label: 'Công ×1,5',
                  value:
                      '${r.deploymentActualHours}h → ${r.deploymentCreditedHours}h công',
                )
              else if (!r.deploymentInsideShift)
                const _KV(label: 'Hệ số', value: 'Công ×1,5'),
            ],
            if (r.reason != null && r.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Lý do',
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  r.reason!.trim(),
                  style: AppTypography.style(
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.request});

  final AttendanceWorkRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final rows = <(String, String)>[];

    if (r.requestType == 'UPDATE') {
      if (r.requestedStart != null && r.requestedEnd != null) {
        rows.add(('Ca sáng / buổi', '${r.requestedStart} – ${r.requestedEnd}'));
      }
      if (r.requestedAfternoonStart != null &&
          r.requestedAfternoonEnd != null) {
        rows.add((
          'Ca chiều',
          '${r.requestedAfternoonStart} – ${r.requestedAfternoonEnd}',
        ));
      }
    } else if (r.requestType == 'EXPLANATION') {
      void add(String label, String? explained, String? original) {
        if (explained == null) return;
        rows.add((
          original != null ? '$label: $original' : label,
          original != null ? '→ $explained' : explained,
        ));
      }

      add('Vào sáng', r.explainedMorningIn, r.originalMorningIn);
      add('Ra sáng', r.explainedMorningOut, r.originalMorningOut);
      add('Vào chiều', r.explainedAfternoonIn, r.originalAfternoonIn);
      add('Ra chiều', r.explainedAfternoonOut, r.originalAfternoonOut);
    } else if (r.requestType == 'DEPLOYMENT' &&
        r.requestedStart != null &&
        r.requestedEnd != null) {
      rows.add(('Giờ điều động', '${r.requestedStart} – ${r.requestedEnd}'));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: AppSpacing.pageH,
      child: _Section(
        title: r.requestType == 'EXPLANATION'
            ? 'Thời gian giải trình'
            : 'Khung giờ đề nghị',
        icon: Icons.schedule_outlined,
        child: Column(
          children: [for (final row in rows) _KV(label: row.$1, value: row.$2)],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.style(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TimeOfDay? _parseHm(String? s) {
  if (s == null || s.length < 4) return null;
  final parts = s.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

String _displayHm(TimeOfDay? t) {
  if (t == null) return 'Chọn';
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DeploymentTimeAdjust extends StatelessWidget {
  const _DeploymentTimeAdjust({
    required this.nursingHead,
    required this.needsAfternoon,
    required this.start,
    required this.end,
    required this.afternoonStart,
    required this.afternoonEnd,
    required this.onPick,
  });

  final bool nursingHead;
  final bool needsAfternoon;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final TimeOfDay? afternoonStart;
  final TimeOfDay? afternoonEnd;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final morningStartLabel = needsAfternoon
        ? 'Bắt đầu buổi sáng'
        : 'Bắt đầu điều động';
    final morningEndLabel = needsAfternoon
        ? 'Kết thúc buổi sáng'
        : 'Kết thúc điều động';
    return Padding(
      padding: AppSpacing.pageH,
      child: _Section(
        title: nursingHead
            ? 'Trưởng phòng ĐD hiệu chỉnh khung giờ'
            : 'HCNS hiệu chỉnh khung giờ',
        icon: Icons.edit_calendar_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nursingHead
                  ? 'Đối chiếu log máy chấm và sửa thời gian trước khi chuyển HCNS duyệt.'
                  : 'Kiểm tra và sửa lại thời gian chính xác trước khi chuyển Giám đốc duyệt.',
              style: AppTypography.body(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimePick(
                    label: morningStartLabel,
                    value: _displayHm(start),
                    onTap: () => onPick('start'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimePick(
                    label: morningEndLabel,
                    value: _displayHm(end),
                    onTap: () => onPick('end'),
                  ),
                ),
              ],
            ),
            if (needsAfternoon) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimePick(
                      label: 'Bắt đầu buổi chiều',
                      value: _displayHm(afternoonStart),
                      onTap: () => onPick('afternoonStart'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TimePick(
                      label: 'Kết thúc buổi chiều',
                      value: _displayHm(afternoonEnd),
                      onTap: () => onPick('afternoonEnd'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              nursingHead
                  ? 'Giờ Trưởng phòng ĐD xác nhận sẽ thay thế giờ đề nghị và chuyển HCNS duyệt.'
                  : 'Giờ HCNS xác nhận sẽ thay thế giờ đề nghị ban đầu và là khung giờ Giám đốc duyệt cuối.',
              style: AppTypography.body(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePick extends StatelessWidget {
  const _TimePick({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadius.brSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
