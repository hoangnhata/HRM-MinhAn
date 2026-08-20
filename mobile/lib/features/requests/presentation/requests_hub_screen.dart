import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/nursing_block.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../attendance/application/attendance_requests_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../data/request_type_config.dart';

class _HubEntry {
  const _HubEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.stages,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> stages;
  final String route;
}

class _HubGroup {
  const _HubGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<_HubEntry> entries;
}

List<_HubGroup> _buildGroups(String? positionTitle) {
  _HubEntry fromConfig(String key) {
    final c = RequestTypeConfig.byKey(key);
    final stages = switch (key) {
      'probation-conversion' => probationFlowLabels(positionTitle),
      'main-duty-authorization' => mainDutyFlowLabels(positionTitle),
      _ => filterDisplayStages(
          c.stages.map((s) => s.label),
          positionTitle: positionTitle,
        ),
    };
    return _HubEntry(
      title: c.label,
      description: c.description,
      icon: c.icon,
      color: c.color,
      stages: stages,
      route: RoutePaths.requestTypeListPath(key),
    );
  }

  final attendanceStages = attendanceFlowLabels(positionTitle);

  return [
    _HubGroup(
      title: 'Công & nghỉ',
      subtitle: 'Nghỉ phép, điều chỉnh chấm công và điều động',
      icon: Icons.event_available_outlined,
      entries: [
        _HubEntry(
          title: 'Đơn nghỉ phép',
          description: 'Nghỉ phép năm và nghỉ không lương.',
          icon: Icons.beach_access_rounded,
          color: AppColors.success,
          stages: attendanceStages,
          route: RoutePaths.attendanceLeaveRequests,
        ),
        _HubEntry(
          title: 'Đơn công',
          description: 'Giải trình muộn/sớm và cập nhật quên chấm công.',
          icon: Icons.assignment_outlined,
          color: AppColors.primary,
          stages: attendanceStages,
          route: RoutePaths.attendanceWorkRequests,
        ),
        _HubEntry(
          title: 'Đơn điều động',
          description:
              'Lập bởi Trưởng khoa/ĐD trưởng; lãnh đạo duyệt theo luồng.',
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFF0F766E),
          stages: deploymentFlowLabels(positionTitle),
          route: RoutePaths.attendanceDeploymentRequests,
        ),
      ],
    ),
    _HubGroup(
      title: 'Nhân sự & chế độ',
      subtitle: 'Hợp đồng, luân chuyển và chế độ đặc thù',
      icon: Icons.badge_outlined,
      entries: [
        fromConfig('young-child'),
        fromConfig('department-transfer'),
        fromConfig('probation-conversion'),
        fromConfig('main-duty-authorization'),
      ],
    ),
    _HubGroup(
      title: 'Đào tạo & hội thảo',
      subtitle: 'Cử cán bộ học tập, hội thảo chuyên môn',
      icon: Icons.school_outlined,
      entries: [
        fromConfig('training-proposal'),
        fromConfig('seminar-proposal'),
      ],
    ),
    _HubGroup(
      title: 'Ca làm việc',
      subtitle: 'Điều chỉnh khung giờ theo mùa',
      icon: Icons.schedule_outlined,
      entries: [fromConfig('shift-config-change')],
    ),
  ];
}

class RequestsHubScreen extends ConsumerWidget {
  const RequestsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final groups = _buildGroups(auth.currentUser?.positionTitle);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppReveal(
            offset: 8,
            child: const AppScreenHeader(
              eyebrow: 'Trung tâm tác vụ',
              title: 'Đơn từ',
              icon: Icons.folder_copy_rounded,
              subtitle: 'Gửi đề xuất, theo dõi trạng thái và ký duyệt.',
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref
                  .read(attendanceRequestsControllerProvider.notifier)
                  .refreshAll(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (final (groupIndex, group) in groups.indexed) ...[
                    AppReveal(
                      delay: AppStagger.delayFor(groupIndex),
                      child: _GroupHeader(
                        title: group.title,
                        subtitle: group.subtitle,
                        icon: group.icon,
                      ),
                    ),
                    for (final (itemIndex, entry) in group.entries.indexed)
                      AppReveal(
                        delay: AppStagger.delayFor(groupIndex + 1 + itemIndex),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            0,
                            AppSpacing.page,
                            10,
                          ),
                          child: _RequestTypeCard(
                            entry: entry,
                            onTap: () => context.push(entry.route),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTypeCard extends StatelessWidget {
  const _RequestTypeCard({
    required this.entry,
    required this.onTap,
  });

  final _HubEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = entry.color;

    return AppCard(
      onTap: onTap,
      borderRadius: AppRadius.brCard,
      accentColor: color,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.16),
                      color.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(entry.icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: AppTypography.style(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                        height: 1.2,
                      ),
                    ),
                    if (entry.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (entry.stages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: AppRadius.brSm,
                border: Border.all(color: color.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.route_rounded,
                    size: 14,
                    color: color.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (i, stage) in entry.stages.indexed) ...[
                          if (i > 0)
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 9,
                              color: color.withValues(alpha: 0.45),
                            ),
                          _StageChip(label: stage, color: color),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
