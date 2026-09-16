import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../data/professional_qualification_repository.dart';

class ProfessionalQualificationReportScreen extends ConsumerStatefulWidget {
  const ProfessionalQualificationReportScreen({super.key});

  @override
  ConsumerState<ProfessionalQualificationReportScreen> createState() =>
      _ProfessionalQualificationReportScreenState();
}

class _ProfessionalQualificationReportScreenState
    extends ConsumerState<ProfessionalQualificationReportScreen> {
  ProfessionalQualificationReport? _report;
  bool _loading = true;
  String? _error;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await ref
          .read(professionalQualificationRepositoryProvider)
          .overview();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được báo cáo trình độ chuyên môn';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppScreenHeader(
            dense: true,
            title: 'Trình độ chuyên môn',
            icon: Icons.school_rounded,
            eyebrow: 'Báo cáo nhân sự',
            subtitle: report?.generatedAtLabel.isNotEmpty == true
                ? 'Cập nhật ${report!.generatedAtLabel}'
                : 'Phân bố bằng cấp theo đối tượng',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _loading
                  ? const LoadingState(label: 'Đang tải báo cáo...')
                  : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Không tải được',
                          message: _error!,
                          action: FilledButton(
                            onPressed: _load,
                            child: const Text('Thử lại'),
                          ),
                        ),
                      ],
                    )
                  : report == null
                  ? const EmptyState(
                      icon: Icons.insights_outlined,
                      title: 'Chưa có dữ liệu',
                      message: 'Hệ thống chưa tổng hợp được báo cáo.',
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.sm,
                        AppSpacing.page,
                        AppSpacing.xxl,
                      ),
                      children: [
                        _KpiRow(report: report),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Theo đối tượng',
                          style: AppTypography.style(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final p in report.byProfession) ...[
                          _ProfessionTile(
                            block: p,
                            expanded: _expanded == p.code,
                            onToggle: () => setState(() {
                              _expanded = _expanded == p.code ? null : p.code;
                            }),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (report.practiceCertificate != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _PracticeCertificateSection(
                            data: report.practiceCertificate!,
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

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.report});
  final ProfessionalQualificationReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Trong phạm vi',
            value: '${report.totalInScope}',
            color: AppColors.primary,
            icon: Icons.groups_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: 'Có bằng',
            value: '${report.withDegreeCount}',
            color: AppColors.success,
            icon: Icons.verified_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: 'Thiếu bằng',
            value: '${report.missingDegreeCount}',
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.style(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.body(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionTile extends StatelessWidget {
  const _ProfessionTile({
    required this.block,
    required this.expanded,
    required this.onToggle,
  });

  final ProfessionBlock block;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final missingPct = block.missingPercent;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.brMd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.label,
                          style: AppTypography.style(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${block.total} người · thiếu bằng ${missingPct.toStringAsFixed(0)}%',
                          style: AppTypography.body(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theo trình độ',
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final d in block.byDegreeLevel)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${d['label'] ?? d['code'] ?? ''}',
                              style: AppTypography.body(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${d['count'] ?? 0}',
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (block.byDepartment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Theo khoa/phòng',
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final d in block.byDepartment.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${d['departmentName'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${d['count'] ?? 0}',
                              style: AppTypography.style(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Chứng chỉ hành nghề ─────────────────────────

Color _certStatusColor(String code) => switch (code) {
  'EXPIRED' => AppColors.error,
  'EXPIRING_SOON' => AppColors.warning,
  'MISSING' => AppColors.warningDark,
  'NO_DATE' => AppColors.textSecondary,
  'VALID' => AppColors.success,
  'UNLIMITED' => AppColors.info,
  _ => AppColors.textSecondary,
};

/// Khối chứng chỉ hành nghề: KPI, tỉ lệ theo đối tượng, và danh sách cần xử lý.
class _PracticeCertificateSection extends StatefulWidget {
  const _PracticeCertificateSection({required this.data});

  final PracticeCertificateReport data;

  @override
  State<_PracticeCertificateSection> createState() =>
      _PracticeCertificateSectionState();
}

class _PracticeCertificateSectionState
    extends State<_PracticeCertificateSection> {
  String _filter = 'ATTENTION';
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final alerts = d.expired + d.expiringSoon;
    final rows = d.details.where((r) {
      return switch (_filter) {
        'ATTENTION' => r.needsAttention,
        'ALL' => true,
        _ => r.statusCode == _filter,
      };
    }).toList();
    final visible = _showAll ? rows : rows.take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Chứng chỉ hành nghề',
                style: AppTypography.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (d.needsAttention > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  '${d.needsAttention} cần xử lý',
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.errorText,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Giấy phép cấp từ 2024 tính hạn 5 năm · chứng chỉ cấp trước đó không thời hạn',
          style: AppTypography.style(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Có CCHN · ${d.coveragePercent.toStringAsFixed(1)}%',
                value: '${d.withCert}',
                color: AppColors.success,
                icon: Icons.verified_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                label: 'Chưa có',
                value: '${d.missing}',
                color: AppColors.warningDark,
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                label: 'Hết / sắp hết hạn',
                value: '$alerts',
                color: alerts > 0 ? AppColors.error : AppColors.textTertiary,
                icon: Icons.event_busy_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tỉ lệ có chứng chỉ theo đối tượng',
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final p in d.byProfession)
                if (((p['total'] as num?)?.toInt() ?? 0) > 0)
                  _CoverageRow(
                    label: p['label']?.toString() ?? '',
                    withCert: (p['withCert'] as num?)?.toInt() ?? 0,
                    total: (p['total'] as num?)?.toInt() ?? 0,
                    percent: (p['coveragePercent'] as num?)?.toDouble() ?? 0,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final chip in const [
                ('ATTENTION', 'Cần xử lý'),
                ('EXPIRED', 'Hết hạn'),
                ('EXPIRING_SOON', 'Sắp hết hạn'),
                ('MISSING', 'Chưa có'),
                ('NO_DATE', 'Thiếu ngày cấp'),
                ('ALL', 'Tất cả'),
              ]) ...[
                _FilterChip(
                  label: chip.$2,
                  count: switch (chip.$1) {
                    'ATTENTION' => d.needsAttention,
                    'ALL' => d.total,
                    'EXPIRED' => d.expired,
                    'EXPIRING_SOON' => d.expiringSoon,
                    'MISSING' => d.missing,
                    'NO_DATE' => d.noDate,
                    _ => 0,
                  },
                  color: chip.$1 == 'ALL'
                      ? AppColors.primary
                      : chip.$1 == 'ATTENTION'
                      ? AppColors.error
                      : _certStatusColor(chip.$1),
                  selected: _filter == chip.$1,
                  onTap: () => setState(() {
                    _filter = chip.$1;
                    _showAll = false;
                  }),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _filter == 'ATTENTION'
                        ? 'Không có chứng chỉ nào cần xử lý.'
                        : 'Không có nhân sự ở trạng thái này.',
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final r in visible) ...[
            _CertRow(row: r),
            const SizedBox(height: 6),
          ],
          if (!_showAll && rows.length > visible.length)
            TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text('Xem thêm ${rows.length - visible.length} người'),
            ),
        ],
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.label,
    required this.withCert,
    required this.total,
    required this.percent,
  });

  final String label;
  final int withCert;
  final int total;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 95
        ? AppColors.success
        : percent >= 80
        ? AppColors.info
        : percent >= 60
        ? AppColors.warning
        : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$withCert/$total · ',
                style: AppTypography.metricMuted(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: AppTypography.metric(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withValues(alpha: 0.08),
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brPill,
            border: Border.all(
              color: color.withValues(alpha: selected ? 1 : 0.22),
            ),
          ),
          child: Center(
            child: Text(
              '$label · $count',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CertRow extends StatelessWidget {
  const _CertRow({required this.row});

  final PracticeCertificateDetail row;

  @override
  Widget build(BuildContext context) {
    final color = _certStatusColor(row.statusCode);
    final urgent =
        row.statusCode == 'EXPIRED' || row.statusCode == 'EXPIRING_SOON';
    final days = row.daysToExpiry;
    final expiryHint = days == null
        ? null
        : days < 0
        ? 'quá ${-days} ngày'
        : 'còn $days ngày';
    final secondary = [
      if (row.professionLabel.isNotEmpty) row.professionLabel,
      if (row.departmentName.isNotEmpty) row.departmentName,
    ].join(' · ');
    final certLine = row.certNumber.isEmpty
        ? 'Chưa có số CCHN'
        : [
            'Số ${row.certNumber}',
            if (row.issueDateLabel.isNotEmpty)
              'cấp ${row.issueDateLabel}'
            else if (row.certDateRaw.isNotEmpty)
              'ngày cấp "${row.certDateRaw}" không đọc được',
            if (row.expiryDateLabel.isNotEmpty)
              'hết hạn ${row.expiryDateLabel}${expiryHint != null ? ' ($expiryHint)' : ''}',
          ].join(' · ');

    return AppCard(
      accentColor: urgent ? color : null,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              switch (row.statusCode) {
                'EXPIRED' => Icons.event_busy_rounded,
                'EXPIRING_SOON' => Icons.schedule_rounded,
                'MISSING' => Icons.badge_outlined,
                'NO_DATE' => Icons.help_outline_rounded,
                _ => Icons.verified_outlined,
              },
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        row.statusLabel,
                        style: AppTypography.style(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  certLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metricMuted(
                    fontSize: 11.5,
                    color: urgent ? color : AppColors.textSecondary,
                  ),
                ),
                if (row.scope.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    row.scope,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
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
