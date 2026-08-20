import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/approval_signatures_section.dart';
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

  AttendanceWorkRequest? _findInPending(AttendanceRequestsState state) =>
      state.pending.where((r) => r.id == widget.requestId).firstOrNull;

  AttendanceWorkRequest? _findInMine(AttendanceRequestsState state) =>
      state.mine.where((r) => r.id == widget.requestId).firstOrNull;

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
        await ref.read(attendanceRequestsControllerProvider.notifier).refreshQuietly();
      }
      return;
    }
    if (!mounted) return;
    await context.push(
      RoutePaths.attendanceRequestNew,
      extra: AttendanceRequestPrefill.edit(r),
    );
    if (!mounted) return;
    await ref.read(attendanceRequestsControllerProvider.notifier).refreshQuietly();
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

  bool _canWaiveFine(AttendanceWorkRequest r) {
    final atFineStage =
        r.status == 'PENDING_HR' || r.status == 'PENDING_DIRECTOR';
    final finableType =
        r.requestType == 'UPDATE' || r.requestType == 'EXPLANATION';
    return atFineStage && finableType;
  }

  Future<void> _review(AttendanceWorkRequest r, bool approved) async {
    String? comment;
    bool? waiveForgotFine;

    if (approved) {
      if (_canWaiveFine(r)) {
        final decision = await showApprovalWithFineSheet(context, request: r);
        if (decision == null) return;
        waiveForgotFine = decision.waiveForgotFine;
        comment = decision.comment;
      } else {
        final confirm = await showConfirmDialog(
          context,
          title: 'Duyệt đơn',
          message:
              'Đơn sẽ được chuyển sang bước tiếp theo kèm chữ ký của bạn. Xác nhận duyệt?',
          confirmLabel: 'Duyệt',
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
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
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
      'LEAVE' || 'UNPAID_LEAVE' => 'Chi tiết đơn nghỉ',
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
        request.canWithdraw &&
        request.employeeId == myEmployeeId &&
        _findInMine(state) != null;
    final canEdit = request != null &&
        request.canEditPending(
          myEmployeeId: myEmployeeId,
          myUsername: auth.currentUser?.username,
          role: auth.role,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(title: _appBarTitle),
      body: request == null
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
                    child: _Body(request: request),
                  ),
                ),
                if (canReview || canWithdraw || canEdit)
                  _ActionBar(
                    busy: _busy,
                    canReview: canReview,
                    canWithdraw: canWithdraw,
                    canEdit: canEdit,
                    onApprove: () => _review(request, true),
                    onReject: () => _review(request, false),
                    onWithdraw: () => _withdraw(request),
                    onEdit: () => _edit(request),
                  ),
              ],
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.request});

  final AttendanceWorkRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final typeColor = AttendanceEnums.requestTypeColor(r.requestType);

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      children: [
        _HeroHeader(request: r, typeColor: typeColor),
        const SizedBox(height: 10),
        _PersonCard(request: r),
        const SizedBox(height: 10),
        _ContentCard(request: r),
        if (_hasTimeBlock(r)) ...[
          const SizedBox(height: 10),
          _TimeBlock(request: r),
        ],
        const SizedBox(height: 10),
        ApprovalSignaturesSection(steps: _signatureSteps(r)),
      ],
    );
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

    return [
      ApprovalSignatureStep(
        role:
            'Trưởng khoa/phòng · ${person(r.headReviewerName, r.headReviewerUsername, r.flowHeadName, '—')}',
        comment: r.headComment,
        reviewedAt: r.headReviewedAt,
        reviewerUsername: r.headReviewerUsername,
        signatureUrl: r.headSignatureUrl,
        pending: r.status == 'PENDING_HEAD',
        rejected: r.status == 'HEAD_REJECTED',
      ),
      ApprovalSignatureStep(
        role:
            'Trưởng phòng Điều dưỡng · ${person(r.nursingHeadReviewerName, r.nursingHeadReviewerUsername, r.flowNursingHeadName, '—')}',
        comment: r.nursingHeadComment,
        reviewedAt: r.nursingHeadReviewedAt,
        reviewerUsername: r.nursingHeadReviewerUsername,
        signatureUrl: r.nursingHeadSignatureUrl,
        pending: r.status == 'PENDING_NURSING_HEAD',
        rejected: r.status == 'NURSING_HEAD_REJECTED',
      ),
      ApprovalSignatureStep(
        role:
            'HCNS · ${person(r.hrReviewerName, r.hrReviewerUsername, r.flowHrName, '—')}',
        comment: r.hrComment,
        reviewedAt: r.hrReviewedAt,
        reviewerUsername: r.hrReviewerUsername,
        signatureUrl: r.hrSignatureUrl,
        pending: r.status == 'PENDING_HR',
        rejected: r.status == 'HR_REJECTED',
      ),
      ApprovalSignatureStep(
        role:
            'Giám đốc · ${person(r.directorReviewerName, r.directorReviewerUsername, r.flowDirectorName, '—')}',
        comment: r.directorComment,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            if (type == 'LEAVE' || type == 'UNPAID_LEAVE')
              _KV(
                label: type == 'UNPAID_LEAVE'
                    ? 'Số ngày không lương'
                    : 'Số ngày phép',
                value: '${AppFormat.compactNumber(r.leaveDays ?? 1)} ngày',
              ),
            if (type == 'BUSINESS_TRIP') ...[
              _KV(
                label: 'Số ngày công tác',
                value: '${AppFormat.compactNumber(r.tripDays ?? 1)} ngày',
              ),
              if (r.location != null) _KV(label: 'Địa điểm', value: r.location!),
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
          children: [
            for (final row in rows) _KV(label: row.$1, value: row.$2),
          ],
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

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.canReview,
    required this.canWithdraw,
    required this.canEdit,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
    required this.onEdit,
  });

  final bool busy;
  final bool canReview;
  final bool canWithdraw;
  final bool canEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onWithdraw;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: AppShadows.soft,
      ),
      child: busy
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canReview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Từ chối'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: FilledButton(
                            onPressed: onApprove,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Duyệt'),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (canEdit || canWithdraw)
                  Row(
                    children: [
                      if (canEdit)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.45),
                              ),
                              minimumSize: const Size.fromHeight(46),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Chỉnh sửa'),
                          ),
                        ),
                      if (canEdit && canWithdraw) const SizedBox(width: 8),
                      if (canWithdraw)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onWithdraw,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Rút đơn'),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}
