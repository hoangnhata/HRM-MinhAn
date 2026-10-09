import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/approval_action_bar.dart';
import '../../../core/widgets/auth_image_preview.dart';
import '../../../core/widgets/auth_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/info_row.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../application/evaluation_controller.dart';
import '../data/evaluation_repository.dart';
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

  Future<void> _refresh() async {
    await ref.read(evaluationControllerProvider.notifier).refreshQuietly();
    if (!mounted) return;
    _retryFetch();
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
      HapticFeedback.mediumImpact();
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
      body: Column(
        children: [
          AppScreenHeader(
            dense: true,
            title: 'Phiếu đánh giá',
            icon: Icons.fact_check_rounded,
            eyebrow: 'Đánh giá',
            subtitle: record == null
                ? null
                : 'Kỳ tháng ${record.periodMonth}/${record.periodYear}',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: record == null
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
                          child: RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _refresh,
                            child: _Body(record: record),
                          ),
                        ),
                      ),
                      if (canReview)
                        ApprovalActionBar(
                          busy: _busy,
                          onApprove: () => _review(record, true),
                          onReject: () => _review(record, false),
                          approveLabel: 'Duyệt & ký',
                          approveIcon: Icons.draw_outlined,
                          approveSemanticLabel: 'Duyệt và ký phiếu đánh giá',
                          rejectSemanticLabel: 'Từ chối phiếu đánh giá',
                          busySemanticLabel:
                              'Đang xử lý phiếu đánh giá, vui lòng chờ',
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
  const _Body({required this.record});

  final NursingEvaluationRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final stepStates = _evaluationStepStates(r);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: AppSpacing.pageH,
          child: _ScoreCard(record: r),
        ),
        const SizedBox(height: AppSpacing.md),
        if (r.scores.isNotEmpty) _CriteriaSection(record: r),
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
                username: r.evaluatorName,
                reviewedAt: r.evaluatorSignedAt,
                signatureUrl: r.evaluatorSignatureUrl,
                state: stepStates[0],
                currentLabel: 'Đang lập phiếu',
              ),
              const _SignatureDivider(),
              _SignatureRow(
                role: 'Trưởng phòng ĐD',
                username: r.headReviewerName,
                reviewedAt: r.headReviewedAt,
                signatureUrl: r.headSignatureUrl,
                comment: r.headComment,
                state: stepStates[1],
              ),
              const _SignatureDivider(),
              _SignatureRow(
                role: 'Hành chính - Nhân sự',
                username: r.hrReviewerName,
                reviewedAt: r.hrReviewedAt,
                signatureUrl: r.hrSignatureUrl,
                comment: r.hrComment,
                state: stepStates[2],
              ),
              const _SignatureDivider(),
              _SignatureRow(
                role: 'Giám đốc',
                username: r.directorReviewerName,
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

/// Mẫu phiếu theo mã — để hiện tên/điểm tối đa từng tiêu chí ở màn chi tiết.
final _detailTemplateProvider =
    FutureProvider.family<NursingEvalTemplate, String>((ref, code) {
      return ref.watch(evaluationRepositoryProvider).template(code: code);
    });

/// Điểm của một tiêu chí: hỗ trợ cả dạng số trơn lẫn dạng `{points, note}`.
double? _criterionPoints(NursingEvaluationRecord r, String id) {
  final raw = r.scores[id];
  if (raw is num) return raw.toDouble();
  return r.scorePoints(id);
}

/// Thẻ hero tổng điểm: vòng điểm (số nằm trong vòng) + người được đánh giá,
/// xếp loại, trạng thái; chân thẻ là dải kỳ đánh giá · ngày lập phiếu.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.record});

  final NursingEvaluationRecord record;

  /// Sắc xếp loại trên nền teal đậm (dùng cho vòng điểm).
  static Color _gradeTone(String? grade) {
    final g = (grade ?? '').toUpperCase();
    if (g.contains('XUẤT SẮC') || g == 'A') return const Color(0xFFFCD34D);
    if (g.contains('TỐT')) return AppColors.onBrandRing;
    if (g.contains('KHÁ') || g == 'B') return const Color(0xFF93C5FD);
    if (g.contains('TRUNG BÌNH') || g == 'C') return const Color(0xFFFDBA74);
    if (g.isEmpty) return AppColors.onBrandRing;
    return const Color(0xFFFCA5A5);
  }

  /// Sắc trạng thái trên nền teal đậm.
  static Color _statusTone(String status) {
    if (status.contains('REJECT')) return const Color(0xFFFCA5A5);
    if (status == 'APPROVED' || status == 'COMPLETED') {
      return AppColors.onBrandRing;
    }
    return const Color(0xFFFCD34D);
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    final name = (r.employeeName ?? '').trim();
    final dept = (r.departmentName ?? '').trim();
    final signedAt = r.evaluatorSignedAt == null
        ? null
        : DateTime.tryParse(r.evaluatorSignedAt!);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.26),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brXl,
        child: GradientHeader(
          safeAreaTop: false,
          bottomRadius: 0,
          gradient: AppGradients.brandHero,
          ornamentIcon: Icons.workspace_premium_rounded,
          ornamentScale: 0.85,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  children: [
                    _BigScoreRing(
                      score: r.totalScore,
                      color: _gradeTone(r.overallGrade),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryLight,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondaryLight
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'KẾT QUẢ ĐÁNH GIÁ',
                                style: AppTypography.uppercase(
                                  fontSize: 9.5,
                                  letterSpacing: 1.0,
                                  color: AppColors.secondaryLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name.isEmpty ? 'Phiếu đánh giá' : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTypography.style(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: AppTypography.uppercaseHeight,
                                  color: Colors.white,
                                ).copyWith(
                                  shadows: [
                                    Shadow(
                                      color: AppColors.primaryDark.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                          ),
                          if (dept.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.apartment_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    dept,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.style(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (r.overallGrade != null)
                                _HeroBadge(
                                  icon: Icons.workspace_premium_rounded,
                                  label: r.overallGrade!,
                                  gold: true,
                                ),
                              _HeroBadge(
                                dotColor: _statusTone(r.status),
                                label: EvaluationEnums.statusLabel(r.status),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Chân thẻ: dải kính tối, hai mốc thời gian ngăn bằng vạch mảnh.
              Container(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.14),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _FooterInfo(
                          icon: Icons.calendar_month_rounded,
                          label: 'Kỳ đánh giá',
                          value: 'Tháng ${r.periodMonth}/${r.periodYear}',
                        ),
                      ),
                      if (signedAt != null) ...[
                        VerticalDivider(
                          width: 24,
                          thickness: 1,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        Expanded(
                          child: _FooterInfo(
                            icon: Icons.send_rounded,
                            label: 'Ngày lập phiếu',
                            value: AppFormat.dateTime(signedAt),
                          ),
                        ),
                      ],
                    ],
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

/// Vòng điểm lớn: số điểm (font hiển thị) + "/100" nằm giữa vòng.
class _BigScoreRing extends StatelessWidget {
  const _BigScoreRing({required this.score, required this.color});

  final double? score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = score;
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Quầng sáng cùng sắc xếp loại phía sau vòng.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.14),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 22),
              ],
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          if (value != null)
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: color,
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value == null ? '—' : AppFormat.score(value),
                style: AppTypography.display(fontSize: 30, color: Colors.white),
              ),
              Text(
                '/ 100 điểm',
                style: AppTypography.style(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterInfo extends StatelessWidget {
  const _FooterInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: AppRadius.brControl,
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.uppercase(
                  fontSize: 8.5,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: AppTypography.uppercaseHeight,
                  tabular: true,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    this.icon,
    this.dotColor,
    this.gold = false,
  });

  final String label;
  final IconData? icon;
  final Color? dotColor;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        gradient: gold ? AppGradients.gold : null,
        color: gold ? null : Colors.black.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
        border: gold
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: gold
            ? [
                BoxShadow(
                  color: AppColors.secondaryDark.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ] else if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: AppTypography.uppercaseHeight,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chi tiết tiêu chí nhóm theo phần của mẫu phiếu: số thứ tự, tên, điểm/tối đa
/// và thanh tỉ lệ. Không tải được mẫu thì liệt kê theo mã như trước.
class _CriteriaSection extends ConsumerWidget {
  const _CriteriaSection({required this.record});

  final NursingEvaluationRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = record;
    final template = ref.watch(_detailTemplateProvider(r.templateCode)).value;
    final criteria = template?.criteriaGroups ?? const <NursingEvalCriterion>[];
    final known = criteria.where((c) => r.scores.containsKey(c.id)).toList();

    final Widget body;
    if (known.isEmpty) {
      body = Column(
        children: [
          for (final (i, id) in r.scores.keys.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            _CriterionRow(
              no: id,
              title: null,
              points: _criterionPoints(r, id),
              max: null,
              note: r.scoreNote(id),
            ),
          ],
        ],
      );
    } else {
      final sections = <String, List<NursingEvalCriterion>>{};
      for (final c in known) {
        sections.putIfAbsent(c.section, () => []).add(c);
      }
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (si, entry) in sections.entries.indexed) ...[
            if (si > 0) const SizedBox(height: AppSpacing.sm),
            _SectionHeader(
              title: entry.key,
              got: entry.value.fold<double>(
                0,
                (s, c) => s + (_criterionPoints(r, c.id) ?? 0),
              ),
              max: entry.value.first.sectionPoints,
            ),
            for (final (i, c) in entry.value.indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.divider),
              _CriterionRow(
                no: c.no.isEmpty ? c.id : c.no,
                title: c.title.isEmpty ? null : c.title,
                points: _criterionPoints(r, c.id),
                max: c.maxPoints,
                note: r.scoreNote(c.id),
                bonus: c.bonus,
                penalty: c.penalty,
              ),
            ],
          ],
        ],
      );
    }

    return SectionCard(
      title: 'Chi tiết tiêu chí',
      icon: Icons.checklist_rounded,
      accentColor: AppColors.primary,
      trailing: r.totalScore == null
          ? null
          : Text(
              '${AppFormat.score(r.totalScore)}/100',
              style: AppTypography.display(
                fontSize: 14,
                color: AppColors.primaryDark,
              ),
            ),
      child: body,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.got, this.max});

  final String title;
  final double got;
  final double? max;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        gradient: AppGradients.tint(AppColors.primary),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: AppTypography.uppercaseHeight,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            max == null
                ? AppFormat.score(got)
                : '${AppFormat.score(got)}/${AppFormat.score(max)}',
            style: AppTypography.display(
              fontSize: 13,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.no,
    required this.title,
    required this.points,
    required this.max,
    this.note,
    this.bonus = false,
    this.penalty = false,
  });

  final String no;
  final String? title;
  final double? points;
  final double? max;
  final String? note;
  final bool bonus;
  final bool penalty;

  @override
  Widget build(BuildContext context) {
    final value = points;
    final ratio = (value != null && max != null && max! > 0)
        ? (value / max!).clamp(0.0, 1.0)
        : null;
    final color = penalty
        ? AppColors.error
        : bonus
        ? AppColors.success
        : ratio == null
        ? AppColors.primary
        : ratio >= 0.8
        ? AppColors.success
        : ratio >= 0.5
        ? AppColors.warning
        : AppColors.error;
    final ink = Color.lerp(color, AppColors.textPrimary, 0.2)!;
    final sign = penalty && (value ?? 0) > 0 ? '−' : (bonus ? '+' : '');
    final valueText = value == null ? '—' : AppFormat.score(value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppRadius.brChipSmall,
            ),
            child: Text(
              no,
              style: AppTypography.style(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                tabular: true,
                height: AppTypography.uppercaseHeight,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title ?? 'Tiêu chí $no',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: '$sign$valueText',
                          style: AppTypography.display(
                            fontSize: 13,
                            color: ink,
                          ),
                          children: [
                            TextSpan(
                              text: max == null
                                  ? ' đ'
                                  : '/${AppFormat.score(max)}',
                              style: AppTypography.style(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ink.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (ratio != null && !bonus && !penalty) ...[
                  const SizedBox(height: 7),
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: AppRadius.brPill,
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      heightFactor: 1,
                      widthFactor: ratio,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.brPill,
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(color, Colors.white, 0.3)!,
                              color,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.sticky_note_2_outlined,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          note!,
                          style: AppTypography.style(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
