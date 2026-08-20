import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';
import 'request_generic_card.dart';

String typedStatusLabel(String typeKey, String? status) {
  final s = (status ?? '').trim().toUpperCase();
  if (typeKey == 'department-transfer') {
    return switch (s) {
      'PENDING_DIRECTOR' => 'Chờ Giám đốc duyệt',
      'APPROVED' => 'Đã duyệt — chờ ngày hiệu lực',
      'APPLIED' => 'Đã chuyển phòng ban',
      'REJECTED' => 'Từ chối',
      'CANCELLED' => 'Đã huỷ',
      _ => genericRequestStatusLabel(status),
    };
  }
  if (typeKey == 'probation-conversion' && s == 'APPLIED') {
    return 'Đã lên chính thức';
  }
  if (typeKey == 'probation-conversion' && s == 'APPROVED') {
    return 'Đã duyệt — chờ ngày lên chính thức';
  }
  return genericRequestStatusLabel(status);
}

String? typedStr(Map<String, dynamic> raw, String key) {
  final v = raw[key]?.toString().trim();
  return (v == null || v.isEmpty) ? null : v;
}

DateTime? typedDate(Map<String, dynamic> raw, String key) {
  final s = typedStr(raw, key);
  if (s == null) return null;
  return DateTime.tryParse(s);
}

String typedDateLabel(DateTime? dt) =>
    dt == null ? '—' : AppFormat.date(dt);

String typedDateTimeLabel(DateTime? dt) =>
    dt == null ? '—' : AppFormat.dateTime(dt);

String typedDateRange(DateTime? from, DateTime? to) {
  if (from == null && to == null) return '—';
  if (from != null && to != null) {
    return '${AppFormat.date(from)} – ${AppFormat.date(to)}';
  }
  return typedDateLabel(from ?? to);
}

/// Hero + chips + optional pending banner cho chi tiết đơn typed.
class TypedDetailHero extends StatelessWidget {
  const TypedDetailHero({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.status,
    this.statusLabel,
    this.chips = const [],
    this.stageLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? status;
  final String? statusLabel;
  final List<(String, Color)> chips;
  final String? stageLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pageH,
      child: AppCard(
        accentColor: color,
        gradient: AppGradients.tint(color),
        borderRadius: AppRadius.brCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(icon: icon, color: color, size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.style(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: AppTypography.style(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
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
                if (status != null && status!.isNotEmpty)
                  StatusChip(
                    label: statusLabel ?? genericRequestStatusLabel(status),
                    color: _statusColor(status!),
                    dense: true,
                  ),
                for (final chip in chips)
                  StatusChip(
                    label: chip.$1,
                    color: chip.$2,
                    dense: true,
                    showDot: false,
                  ),
              ],
            ),
            if (stageLabel != null && stageLabel!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions_outlined,
                      size: 15,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đang chờ bạn duyệt: $stageLabel',
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
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
    );
  }

  static Color _statusColor(String status) {
    final s = status.toUpperCase();
    if (s.contains('APPROVED') ||
        s.contains('COMPLETED') ||
        s == 'APPLIED') {
      return AppColors.success;
    }
    if (s.contains('REJECT') ||
        s.contains('STOP') ||
        s.contains('CANCEL')) {
      return AppColors.error;
    }
    if (s.contains('PENDING') || s.contains('EXTEND')) {
      return AppColors.warning;
    }
    return AppColors.textSecondary;
  }
}

class TypedDetailSection extends StatelessWidget {
  const TypedDetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pageH,
      child: Container(
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
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class TypedDetailKV extends StatelessWidget {
  const TypedDetailKV({required this.label, required this.value});

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

class TypedDetailNote extends StatelessWidget {
  const TypedDetailNote({
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            color: color.withValues(alpha: 0.05),
            borderRadius: AppRadius.brSm,
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Text(
            value,
            style: AppTypography.style(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shell ListView chuẩn: hero + sections + bottom (timeline).
class TypedDetailScaffold extends StatelessWidget {
  const TypedDetailScaffold({
    super.key,
    required this.hero,
    required this.sections,
    this.bottom,
  });

  final Widget hero;
  final List<Widget> sections;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      children: [
        hero,
        for (final section in sections) ...[
          const SizedBox(height: 10),
          section,
        ],
        if (bottom != null) ...[
          const SizedBox(height: 10),
          bottom!,
        ],
      ],
    );
  }
}
