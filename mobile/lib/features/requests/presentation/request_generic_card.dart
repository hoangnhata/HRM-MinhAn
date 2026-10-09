import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import 'generic_request_ui.dart';

/// Nhãn trạng thái dùng chung cho thẻ và màn chi tiết đơn generic.
String genericRequestStatusLabel(String? raw) {
  final status = (raw ?? '').trim().toUpperCase();
  const labels = <String, String>{
    'DRAFT': 'Nháp',
    'PENDING': 'Chờ duyệt',
    'PENDING_HEAD': 'Chờ Trưởng khoa/phòng',
    'PENDING_NURSING_HEAD': 'Chờ Trưởng phòng Điều dưỡng',
    'PENDING_HR': 'Chờ HCNS duyệt',
    'PENDING_DIRECTOR': 'Chờ Giám đốc duyệt',
    'HEAD_REJECTED': 'Trưởng khoa/phòng từ chối',
    'NURSING_HEAD_REJECTED': 'Trưởng phòng Điều dưỡng từ chối',
    'HR_REJECTED': 'HCNS từ chối',
    'DIRECTOR_REJECTED': 'Giám đốc từ chối',
    'REJECTED': 'Đã từ chối',
    'APPROVED': 'Đã duyệt',
    'COMPLETED': 'Đã hoàn thành',
    'CANCELLED': 'Đã huỷ',
    'WITHDRAWN': 'Đã thu hồi',
    'APPLIED': 'Đã lên chính thức',
    'HR_EXTEND_PROBATION': 'HCNS đề xuất gia hạn thử việc',
    'HR_STOP_COOPERATION': 'HCNS đề xuất ngừng hợp tác',
  };

  if (labels.containsKey(status)) return labels[status]!;
  if (status.startsWith('PENDING')) return 'Chờ duyệt';
  if (status.contains('REJECT')) return 'Đã từ chối';
  if (status.contains('APPROVED')) return 'Đã duyệt';
  if (status.contains('COMPLETED')) return 'Đã hoàn thành';
  if (status.contains('CANCEL')) return 'Đã huỷ';
  if (status.contains('WITHDRAW')) return 'Đã thu hồi';
  return GenericRequestUi.humanizeStatus(raw);
}

/// Nhãn ngắn cho thẻ danh sách (tránh chip quá dài).
String genericRequestStatusShortLabel(String? raw) {
  final status = (raw ?? '').trim().toUpperCase();
  const labels = <String, String>{
    'DRAFT': 'Nháp',
    'PENDING': 'Chờ duyệt',
    'PENDING_HEAD': 'Chờ TK/TP',
    'PENDING_NURSING_HEAD': 'Chờ TP ĐD',
    'PENDING_HR': 'Chờ HCNS',
    'PENDING_DIRECTOR': 'Chờ GĐ',
    'HEAD_REJECTED': 'TK/TP từ chối',
    'NURSING_HEAD_REJECTED': 'TP ĐD từ chối',
    'HR_REJECTED': 'HCNS từ chối',
    'DIRECTOR_REJECTED': 'GĐ từ chối',
    'REJECTED': 'Từ chối',
    'APPROVED': 'Đã duyệt',
    'COMPLETED': 'Hoàn thành',
    'CANCELLED': 'Đã huỷ',
    'WITHDRAWN': 'Thu hồi',
    'APPLIED': 'Chính thức',
    'HR_EXTEND_PROBATION': 'Gia hạn TV',
    'HR_STOP_COOPERATION': 'Ngừng HT',
  };
  if (labels.containsKey(status)) return labels[status]!;
  return genericRequestStatusLabel(raw);
}

class RequestGenericCard extends StatelessWidget {
  const RequestGenericCard({
    super.key,
    required this.raw,
    required this.onTap,
    this.stageLabel,
    this.accentColor,
    this.highlighted = false,
  });

  final Map<String, dynamic> raw;
  final VoidCallback onTap;

  /// Bước duyệt đang chờ — chỉ có ở tab "Chờ duyệt".
  final String? stageLabel;

  /// Màu nhận diện loại đơn (dải accent bên trái).
  final Color? accentColor;

  /// Khoanh card khi mở từ thông báo.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final employeeName =
        raw['employeeName'] as String? ?? raw['fullName'] as String?;
    final department =
        raw['department'] as String? ?? raw['departmentName'] as String?;
    final position = raw['positionTitle'] as String?;
    final status = raw['status'] as String?;
    final reason = (raw['reason'] as String?)?.trim();
    final createdAt = raw['createdAt'] != null
        ? DateTime.tryParse(raw['createdAt'] as String)
        : null;
    final title = employeeName ?? 'Đơn #${raw['id']}';
    final meta = [position, department]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' · ');
    final awaiting = stageLabel != null && stageLabel!.trim().isNotEmpty;
    final statusLabel = awaiting
        ? 'Chờ bạn duyệt'
        : (status == null ? null : genericRequestStatusShortLabel(status));
    final statusColor = awaiting
        ? AppColors.warning
        : (status == null
              ? AppColors.textSecondary
              : GenericRequestUi.statusColor(status));

    final accent = accentColor ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      child: HighlightPulse(
        active: highlighted,
        color: AppColors.warning,
        child: AppCard(
          onTap: onTap,
          gradient: TintedCardBackdrop.gradient(accent),
          borderRadius: AppRadius.brLg,
          padding: EdgeInsets.zero,
          child: TintedCardBackdrop(
            accent: accent,
            watermarkIcon: Icons.description_rounded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.55),
                          accent.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      child: AppAvatar(
                        name: title,
                        size: 36,
                        showShadow: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  height: AppTypography.uppercaseHeight,
                                  letterSpacing: -0.2,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (statusLabel != null) ...[
                              const SizedBox(width: 8),
                              StatusChip(
                                label: statusLabel,
                                color: statusColor,
                                dense: true,
                              ),
                            ],
                          ],
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.apartment_rounded,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    height: AppTypography.uppercaseHeight,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (awaiting) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: AppRadius.brChip,
                              border: Border.all(
                                color: AppColors.warning.withValues(
                                  alpha: 0.24,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 13,
                                  color: AppColors.warningText,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Bước · $stageLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.style(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      height: AppTypography.uppercaseHeight,
                                      color: AppColors.warningText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (reason != null && reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: AppRadius.brControl,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              reason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 12.5,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (createdAt != null) ...[
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Gửi ${AppFormat.dateTime(createdAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.metricMuted(
                                    fontSize: 11.5,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ] else
                              const Spacer(),
                            TintedChevron(accent: accent),
                          ],
                        ),
                      ],
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
