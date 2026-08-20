import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/status_chip.dart';
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
    final accent = highlighted
        ? AppColors.warning
        : (accentColor ?? AppColors.primary);
    final meta = [
      position,
      department,
    ]
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

    final footnoteParts = <String>[
      if (reason != null && reason.isNotEmpty) reason,
      if (createdAt != null) 'Gửi ${AppFormat.dateTime(createdAt)}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: HighlightPulse(
        active: highlighted,
        color: AppColors.warning,
        child: AppCard(
          onTap: onTap,
          accentColor: accent,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: title, size: 36),
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.25,
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
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (awaiting) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Bước · $stageLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                    if (footnoteParts.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            createdAt != null
                                ? Icons.schedule_rounded
                                : Icons.notes_outlined,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              footnoteParts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 2, top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
