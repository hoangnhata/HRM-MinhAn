import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auth_image_preview.dart';
import '../../../core/widgets/auth_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../application/evaluation_controller.dart';
import 'evaluation_enums.dart';

class EvaluationDetailScreen extends ConsumerStatefulWidget {
  const EvaluationDetailScreen({
    super.key,
    required this.evaluationId,
    this.highlight = false,
  });

  final int evaluationId;
  final bool highlight;

  @override
  ConsumerState<EvaluationDetailScreen> createState() =>
      _EvaluationDetailScreenState();
}

class _EvaluationDetailScreenState
    extends ConsumerState<EvaluationDetailScreen> {
  bool _busy = false;

  /// Phiếu tải riêng theo id khi không có trong danh sách đã nạp.
  NursingEvaluationRecord? _fetched;
  bool _fetching = false;
  bool _fetchFailed = false;

  NursingEvaluationRecord? _find(EvaluationState state) {
    for (final list in [state.pending, state.mine, state.history]) {
      for (final r in list) {
        if (r.id == widget.evaluationId) return r;
      }
    }
    return _fetched;
  }

  /// Chỉ gọi API khi các danh sách đã nạp xong mà vẫn không thấy phiếu.
  void _ensureFetched(EvaluationState state) {
    if (state.loading || _fetching || _fetched != null || _fetchFailed) return;
    _fetching = true;
    Future.microtask(() async {
      final record = await ref
          .read(evaluationControllerProvider.notifier)
          .fetchById(widget.evaluationId);
      if (!mounted) return;
      setState(() {
        _fetched = record;
        _fetching = false;
        _fetchFailed = record == null;
      });
    });
  }

  void _retryFetch() {
    setState(() {
      _fetched = null;
      _fetching = false;
      _fetchFailed = false;
    });
  }

  bool _isPending(EvaluationState state) =>
      state.pending.any((r) => r.id == widget.evaluationId);

  Future<void> _review(NursingEvaluationRecord record, bool approved) async {
    String? comment;
    if (approved) {
      final confirm = await showConfirmDialog(
        context,
        title: 'Duyệt & ký phiếu',
        message:
            'Chữ ký của bạn sẽ được chèn vào phiếu và phiếu chuyển sang bước tiếp theo.',
        confirmLabel: 'Duyệt & ký',
        icon: Icons.draw_outlined,
      );
      if (!confirm) return;
    } else {
      comment = await showNoteInputDialog(
        context,
        title: 'Từ chối phiếu',
        label: 'Lý do từ chối',
        hint: 'Nêu rõ điểm cần chỉnh sửa...',
        required: true,
        confirmLabel: 'Từ chối',
        confirmColor: AppColors.error,
      );
      if (comment == null) return;
    }

    setState(() => _busy = true);
    final ok = await ref
        .read(evaluationControllerProvider.notifier)
        .review(record, approved: approved, comment: comment);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      showAppSnackBar(
        context,
        approved
            ? 'Đã duyệt và ký phiếu đánh giá'
            : 'Đã từ chối phiếu đánh giá',
        isSuccess: true,
      );
      Navigator.of(context).maybePop();
    } else {
      showAppSnackBar(
        context,
        ref.read(evaluationControllerProvider).error ?? 'Thao tác thất bại',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evaluationControllerProvider);
    final record = _find(state);
    final canReview = _isPending(state);
    if (record == null) _ensureFetched(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: 'Phiếu đánh giá',
        subtitle: record == null
            ? null
            : 'Kỳ tháng ${record.periodMonth}/${record.periodYear}',
      ),
      body: record == null
          ? (state.loading || _fetching)
                ? const LoadingState(label: 'Đang tải phiếu đánh giá...')
                : state.error != null
                ? ErrorState(message: state.error!, onRetry: _retryFetch)
                : EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Không tìm thấy phiếu đánh giá',
                    message:
                        'Phiếu có thể đã bị thu hồi hoặc bạn không có quyền xem.',
                    action: OutlinedButton.icon(
                      onPressed: _retryFetch,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Tải lại'),
                    ),
                  )
          : Column(
              children: [
                Expanded(
                  child: HighlightPulse(
                    active: widget.highlight,
                    child: _Body(record: record),
                  ),
                ),
                if (canReview)
                  _ActionBar(
                    busy: _busy,
                    onApprove: () => _review(record, true),
                    onReject: () => _review(record, false),
                  ),
              ],
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.record});

  final NursingEvaluationRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final stepStates = _evaluationStepStates(r);

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: AppSpacing.pageH,
          child: _ScoreCard(record: r),
        ),
        if (r.scores.isNotEmpty)
          SectionCard(
            title: 'Chi tiết tiêu chí',
            icon: Icons.checklist_rounded,
            accentColor: AppColors.primary,
            child: Column(
              children: [
                for (final entry in r.scores.entries)
                  _CriterionRow(label: entry.key, raw: entry.value),
              ],
            ),
          ),
        if (r.comments != null && r.comments!.isNotEmpty)
          SectionCard(
            title: 'Nhận xét chung',
            icon: Icons.notes_rounded,
            accentColor: AppColors.info,
            child: Text(
              r.comments!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        SectionCard(
          title: 'Tiến trình xác nhận',
          icon: Icons.account_tree_outlined,
          accentColor: AppColors.success,
          child: Column(
            children: [
              _SignatureRow(
                role: 'Người lập (Trưởng khoa/ĐDT)',
                username: r.evaluatorUsername,
                reviewedAt: r.evaluatorSignedAt,
                signatureUrl: r.evaluatorSignatureUrl,
                state: stepStates[0],
                currentLabel: 'Đang lập phiếu',
              ),
              const _SignatureDivider(),
              _SignatureRow(
                role: 'Trưởng phòng ĐD',
                reviewedAt: r.headReviewedAt,
                signatureUrl: r.headSignatureUrl,
                comment: r.headComment,
                state: stepStates[1],
              ),
              const _SignatureDivider(),
              _SignatureRow(
                role: 'Hành chính - Nhân sự',
                reviewedAt: r.hrReviewedAt,
                signatureUrl: r.hrSignatureUrl,
                comment: r.hrComment,
                state: stepStates[2],
              ),
              const _SignatureDivider(),
              _SignatureRow(
                role: 'Giám đốc',
                reviewedAt: r.directorReviewedAt,
                signatureUrl: r.directorSignatureUrl,
                comment: r.directorComment,
                state: stepStates[3],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ nổi bật hiển thị tổng điểm và xếp loại của kỳ đánh giá.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.record});

  final NursingEvaluationRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final gradeColor = EvaluationEnums.gradeColor(r.overallGrade);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(gradient: AppGradients.tint(gradeColor)),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineLabel(text: 'Tổng điểm'),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          r.totalScore == null
                              ? '—'
                              : r.totalScore!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            letterSpacing: -1,
                            color: gradeColor,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'điểm',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (r.overallGrade != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: gradeColor,
                          borderRadius: AppRadius.brPill,
                          boxShadow: AppShadows.tinted(gradeColor),
                        ),
                        child: Text(
                          'Xếp loại ${r.overallGrade}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    StatusChip(
                      label: EvaluationEnums.statusLabel(r.status),
                      color: EvaluationEnums.statusColor(r.status),
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                if (r.employeeName != null)
                  InfoRow(
                    label: 'Nhân viên',
                    value: r.employeeName!,
                    icon: Icons.person_outline_rounded,
                  ),
                if (r.departmentName != null)
                  InfoRow(
                    label: 'Khoa/phòng',
                    value: r.departmentName!,
                    icon: Icons.apartment_outlined,
                  ),
                InfoRow(
                  label: 'Kỳ đánh giá',
                  value: 'Tháng ${r.periodMonth}/${r.periodYear}',
                  icon: Icons.event_outlined,
                ),
                if (r.evaluatorSignedAt != null)
                  InfoRow(
                    label: 'Ngày lập phiếu',
                    value: AppFormat.dateTime(
                      DateTime.tryParse(r.evaluatorSignedAt!),
                    ),
                    icon: Icons.send_outlined,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({required this.label, required this.raw});

  final String label;
  final dynamic raw;

  @override
  Widget build(BuildContext context) {
    final points = raw is Map ? raw['points'] : raw;
    final maxPoints = raw is Map ? raw['maxPoints'] ?? raw['max'] : null;
    final note = raw is Map ? raw['note'] as String? : null;

    final value = (points as num?)?.toDouble();
    final max = (maxPoints as num?)?.toDouble();
    final ratio = (value != null && max != null && max > 0)
        ? (value / max).clamp(0.0, 1.0)
        : null;
    final color = ratio == null
        ? AppColors.primary
        : ratio >= 0.8
        ? AppColors.success
        : ratio >= 0.5
        ? AppColors.warning
        : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                max == null
                    ? '${AppFormat.compactNumber(value)} điểm'
                    : '${AppFormat.compactNumber(value)}/${AppFormat.compactNumber(max)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: AppRadius.brPill,
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11.8,
                fontStyle: FontStyle.italic,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignatureDivider extends StatelessWidget {
  const _SignatureDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: AppSpacing.lg, color: AppColors.divider);
}

enum _EvaluationStepState { completed, current, rejected, upcoming, stopped }

List<_EvaluationStepState> _evaluationStepStates(
  NursingEvaluationRecord record,
) {
  final status = record.status.toUpperCase();
  final evidence = <bool>[
    _hasValue(record.evaluatorSignatureUrl) ||
        _hasValue(record.evaluatorSignedAt),
    _hasValue(record.headSignatureUrl) || _hasValue(record.headReviewedAt),
    _hasValue(record.hrSignatureUrl) || _hasValue(record.hrReviewedAt),
    _hasValue(record.directorSignatureUrl) ||
        _hasValue(record.directorReviewedAt),
  ];
  final currentIndex = switch (status) {
    'DRAFT' => 0,
    'PENDING_NURSING_HEAD' => 1,
    'PENDING_HR' => 2,
    'PENDING_DIRECTOR' => 3,
    _ => -1,
  };
  final rejectedIndex = switch (status) {
    'NURSING_HEAD_REJECTED' => 1,
    'HR_REJECTED' => 2,
    'DIRECTOR_REJECTED' => 3,
    _ => -1,
  };

  return List.generate(4, (index) {
    if (rejectedIndex >= 0) {
      if (index < rejectedIndex) return _EvaluationStepState.completed;
      if (index == rejectedIndex) return _EvaluationStepState.rejected;
      return _EvaluationStepState.stopped;
    }
    if (status == 'APPROVED') return _EvaluationStepState.completed;
    if (currentIndex >= 0) {
      if (index < currentIndex) return _EvaluationStepState.completed;
      if (index == currentIndex) return _EvaluationStepState.current;
      return _EvaluationStepState.upcoming;
    }
    if (status == 'CANCELLED') {
      return evidence[index]
          ? _EvaluationStepState.completed
          : _EvaluationStepState.stopped;
    }
    return evidence[index]
        ? _EvaluationStepState.completed
        : _EvaluationStepState.upcoming;
  });
}

bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.role,
    required this.reviewedAt,
    required this.signatureUrl,
    required this.state,
    this.username,
    this.comment,
    this.currentLabel = 'Đang chờ duyệt',
  });

  final String role;
  final String? reviewedAt;
  final String? signatureUrl;
  final String? username;
  final String? comment;
  final _EvaluationStepState state;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    final signed = signatureUrl != null && signatureUrl!.isNotEmpty;
    final color = _evaluationStepColor(state);
    final statusText = _evaluationStepLabel(
      state,
      signed: signed,
      reviewedAt: reviewedAt,
      currentLabel: currentLabel,
    );

    return Semantics(
      container: true,
      label:
          '$role. $statusText'
          '${comment == null || comment!.isEmpty ? '' : '. Ý kiến: $comment'}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 74,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: AppRadius.brXs,
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              clipBehavior: Clip.antiAlias,
              child: signed
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => showAuthImagePreview(
                          context,
                          url: AppConfig.resolveUrl(signatureUrl!),
                          title: role,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AuthNetworkImage(
                            url: AppConfig.resolveUrl(signatureUrl!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  : Icon(_evaluationStepIcon(state), color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.8,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          _evaluationStepIcon(state),
                          size: 12,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$statusText'
                          '${username != null && username!.isNotEmpty ? ' · $username' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: color,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (comment != null && comment!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.brXs,
                      ),
                      child: Text(
                        comment!,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _evaluationStepLabel(
  _EvaluationStepState state, {
  required bool signed,
  required String? reviewedAt,
  required String currentLabel,
}) {
  final date = _hasValue(reviewedAt)
      ? AppFormat.dateTime(DateTime.tryParse(reviewedAt!))
      : null;
  return switch (state) {
    _EvaluationStepState.completed =>
      signed
          ? 'Đã ký${date == null ? '' : ' · $date'}'
          : 'Đã hoàn tất bước${date == null ? '' : ' · $date'}',
    _EvaluationStepState.current => currentLabel,
    _EvaluationStepState.rejected =>
      'Đã từ chối${date == null ? '' : ' · $date'}',
    _EvaluationStepState.upcoming => 'Chưa đến bước',
    _EvaluationStepState.stopped => 'Quy trình đã dừng',
  };
}

Color _evaluationStepColor(_EvaluationStepState state) {
  return switch (state) {
    _EvaluationStepState.completed => AppColors.success,
    _EvaluationStepState.current => AppColors.warning,
    _EvaluationStepState.rejected => AppColors.error,
    _EvaluationStepState.upcoming => AppColors.textTertiary,
    _EvaluationStepState.stopped => AppColors.textSecondary,
  };
}

IconData _evaluationStepIcon(_EvaluationStepState state) {
  return switch (state) {
    _EvaluationStepState.completed => Icons.check_circle_rounded,
    _EvaluationStepState.current => Icons.schedule_rounded,
    _EvaluationStepState.rejected => Icons.cancel_rounded,
    _EvaluationStepState.upcoming => Icons.lock_outline_rounded,
    _EvaluationStepState.stopped => Icons.block_rounded,
  };
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              Semantics(
                liveRegion: true,
                label: 'Đang xử lý phiếu đánh giá, vui lòng chờ',
                child: const LinearProgressIndicator(minHeight: 2),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final stack = constraints.maxWidth < 330 || textScale > 1.25;
                  final reject = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.45),
                      ),
                    ),
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Từ chối'),
                  );
                  final approve = ElevatedButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.draw_outlined, size: 18),
                    label: const Text('Duyệt & ký'),
                  );
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        approve,
                        const SizedBox(height: AppSpacing.xs),
                        reject,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: reject),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(flex: 3, child: approve),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
