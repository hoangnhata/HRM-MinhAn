import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'auth_image_preview.dart';
import 'auth_network_image.dart';
import 'tinted_card_backdrop.dart';

/// Một bước duyệt kèm chữ ký số (đồng bộ URL từ API web).
class ApprovalSignatureStep {
  const ApprovalSignatureStep({
    required this.role,
    this.comment,
    this.reviewedAt,
    this.reviewerUsername,
    this.signatureUrl,
    this.pending = false,
    this.rejected = false,
  });

  final String role;
  final String? comment;
  final DateTime? reviewedAt;
  final String? reviewerUsername;
  final String? signatureUrl;
  final bool pending;
  final bool rejected;

  bool get hasSignature =>
      signatureUrl != null && signatureUrl!.trim().isNotEmpty;

  bool get hasEvidence =>
      hasSignature ||
      pending ||
      rejected ||
      (comment != null && comment!.trim().isNotEmpty) ||
      reviewedAt != null;

  bool get done =>
      !pending && !rejected && (hasSignature || reviewedAt != null);
}

/// Khối lịch sử duyệt + ảnh chữ ký — dùng chung đơn công / đơn generic.
///
/// Trình bày dạng dòng thời gian dọc: mỗi bước một nút tròn, đường nối xanh
/// khi bước đã xong, chữ ký và ý kiến nằm ngay dưới tên bước.
class ApprovalSignaturesSection extends StatelessWidget {
  const ApprovalSignaturesSection({
    super.key,
    required this.steps,
    this.title = 'Chữ ký & quá trình duyệt',
  });

  final List<ApprovalSignatureStep> steps;
  final String title;

  @override
  Widget build(BuildContext context) {
    final visible = steps.where((s) => s.hasEvidence).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    const accent = AppColors.info;

    return Padding(
      padding: AppSpacing.pageH,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brCard,
          border: Border.all(color: accent.withValues(alpha: 0.14)),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
              decoration: BoxDecoration(gradient: AppGradients.tint(accent)),
              child: Row(
                children: [
                  const TintedIconTile(
                    icon: Icons.draw_rounded,
                    color: accent,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.style(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chữ ký số lưu kèm từng bước duyệt',
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < visible.length; i++)
                    _SignatureStepTile(
                      step: visible[i],
                      isLast: i == visible.length - 1,
                      lineDone:
                          visible[i].done &&
                          i + 1 < visible.length &&
                          !visible[i + 1].pending &&
                          visible[i + 1].hasEvidence,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignatureStepTile extends StatelessWidget {
  const _SignatureStepTile({
    required this.step,
    required this.isLast,
    required this.lineDone,
  });

  final ApprovalSignatureStep step;
  final bool isLast;
  final bool lineDone;

  @override
  Widget build(BuildContext context) {
    final color = step.rejected
        ? AppColors.error
        : step.pending
        ? AppColors.warning
        : step.done
        ? AppColors.success
        : AppColors.textSecondary;
    final status = step.rejected
        ? 'Từ chối'
        : step.pending
        ? 'Đang chờ'
        : step.hasSignature
        ? 'Đã ký duyệt'
        : step.reviewedAt != null
        ? 'Đã duyệt'
        : '—';
    final icon = step.pending
        ? Icons.hourglass_top_rounded
        : step.rejected
        ? Icons.close_rounded
        : Icons.check_rounded;
    final comment = step.comment?.trim() ?? '';
    final meta = [
      if (step.reviewerUsername?.isNotEmpty ?? false) step.reviewerUsername!,
      if (step.reviewedAt != null) AppFormat.dateTime(step.reviewedAt),
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                TintedIconTile(icon: icon, color: color, size: 34),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: lineDone
                            ? AppColors.success.withValues(alpha: 0.35)
                            : AppColors.borderSoft,
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.role,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(7, 2, 8, 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: AppRadius.brPill,
                          border: Border.all(
                            color: color.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          status,
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: AppTypography.uppercaseHeight,
                            color: Color.lerp(
                              color,
                              AppColors.textPrimary,
                              0.2,
                            )!,
                          ),
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  if (step.hasSignature) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: AppColors.surfaceAlt,
                      borderRadius: AppRadius.brControl,
                      child: InkWell(
                        onTap: () => showAuthImagePreview(
                          context,
                          url: AppConfig.resolveUrl(step.signatureUrl!.trim()),
                          title: step.role,
                        ),
                        borderRadius: AppRadius.brControl,
                        child: Container(
                          width: double.infinity,
                          height: 124,
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.brControl,
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: AuthNetworkImage(
                                  url: AppConfig.resolveUrl(
                                    step.signatureUrl!.trim(),
                                  ),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Icon(
                                  Icons.zoom_out_map_rounded,
                                  size: 14,
                                  color: AppColors.textTertiary.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: AppRadius.brControl,
                        border: Border.all(
                          color: color.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              comment,
                              style: AppTypography.style(
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
