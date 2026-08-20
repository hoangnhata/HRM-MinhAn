import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'auth_image_preview.dart';
import 'auth_network_image.dart';

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
}

/// Khối lịch sử duyệt + ảnh chữ ký — dùng chung đơn công / đơn generic.
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

    return Padding(
      padding: AppSpacing.pageH,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
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
                Icon(Icons.draw_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Chữ ký số lưu kèm từng bước duyệt (đồng bộ với web).',
              style: AppTypography.style(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < visible.length; i++) ...[
              _SignatureStepCard(step: visible[i]),
              if (i != visible.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignatureStepCard extends StatelessWidget {
  const _SignatureStepCard({required this.step});

  final ApprovalSignatureStep step;

  @override
  Widget build(BuildContext context) {
    final color = step.rejected
        ? AppColors.error
        : step.pending
            ? AppColors.warning
            : step.hasSignature || step.reviewedAt != null
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 88,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.brXs,
                  border: Border.all(color: AppColors.borderSoft),
                ),
                clipBehavior: Clip.antiAlias,
                child: step.hasSignature
                    ? Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => showAuthImagePreview(
                            context,
                            url: AppConfig.resolveUrl(
                              step.signatureUrl!.trim(),
                            ),
                            title: step.role,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AuthNetworkImage(
                              url: AppConfig.resolveUrl(
                                step.signatureUrl!.trim(),
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        step.pending
                            ? Icons.hourglass_top_rounded
                            : step.rejected
                                ? Icons.close_rounded
                                : Icons.draw_outlined,
                        color: color,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.role,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if ((step.reviewerUsername?.isNotEmpty ?? false) ||
                        step.reviewedAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (step.reviewerUsername?.isNotEmpty ?? false)
                            step.reviewerUsername!,
                          if (step.reviewedAt != null)
                            AppFormat.dateTime(step.reviewedAt),
                        ].join(' · '),
                        style: AppTypography.style(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (step.comment != null && step.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.brXs,
              ),
              child: Text(
                step.comment!.trim(),
                style: AppTypography.style(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
