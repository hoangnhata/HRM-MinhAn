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
