import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

class RequestFlowStep {
  const RequestFlowStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Bước gửi + các bước duyệt (nhãn từ nursing-block / config).
List<RequestFlowStep> requestCreateFlowSteps(List<String> reviewLabels) {
  return [
    const RequestFlowStep(
      icon: Icons.send_rounded,
      title: 'Gửi đơn',
      subtitle: 'Bạn lập và gửi phiếu',
    ),
    for (final label in reviewLabels) _reviewStep(label),
  ];
}

RequestFlowStep _reviewStep(String label) {
  final n = label.toLowerCase();
  if (n.contains('đd') || n.contains('điều dưỡng')) {
    return RequestFlowStep(
      icon: Icons.supervisor_account_rounded,
      title: label,
      subtitle: 'Trưởng phòng Điều dưỡng',
    );
  }
  if (n.contains('hcns')) {
    return RequestFlowStep(
      icon: Icons.apartment_rounded,
      title: label.contains('duyệt') ? label : '$label duyệt',
      subtitle: 'Hành chính nhân sự',
    );
  }
  if (n.contains('giám đốc')) {
    return RequestFlowStep(
      icon: Icons.verified_rounded,
      title: label.contains('duyệt') ? label : '$label duyệt',
      subtitle: 'Duyệt cuối cùng',
    );
  }
  if (n.contains('trưởng khoa') || n.contains('lãnh đạo')) {
    return RequestFlowStep(
      icon: Icons.supervisor_account_rounded,
      title: label.contains('duyệt') ? label : 'Lãnh đạo duyệt',
      subtitle: 'Trưởng khoa / ĐD trưởng',
    );
  }
  return RequestFlowStep(
    icon: Icons.flag_outlined,
    title: label,
    subtitle: 'Bước duyệt',
  );
}

/// Luồng duyệt thu gọn / mở rộng — đồng bộ đơn nghỉ phép và phiếu đề xuất.
class RequestCreateFlowStrip extends StatefulWidget {
  const RequestCreateFlowStrip({
    super.key,
    required this.accent,
    required this.steps,
  });

  final Color accent;
  final List<RequestFlowStep> steps;

  @override
  State<RequestCreateFlowStrip> createState() => _RequestCreateFlowStripState();
}

class _RequestCreateFlowStripState extends State<RequestCreateFlowStrip> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final current = steps.first;
    final accent = widget.accent;
    final total = steps.length;

    return AppCard(
      accentColor: accent,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: AppRadius.brCard,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Icon(
                        Icons.account_tree_rounded,
                        size: 15,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Luồng duyệt',
                            style: AppTypography.style(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: AppDurations.fast,
                            child: Text(
                              _expanded
                                  ? '$total bước · đồng bộ với web'
                                  : 'Bước 1/$total · ${current.title}',
                              key: ValueKey(_expanded),
                              style: AppTypography.style(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Bước 1/$total',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            duration: AppDurations.normal,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _CollapsedStep(
                accent: accent,
                step: current,
                onExpand: _toggle,
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _ExpandedStep(
                      accent: accent,
                      step: steps[i],
                      index: i,
                      active: i == 0,
                      isLast: i == steps.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedStep extends StatelessWidget {
  const _CollapsedStep({
    required this.accent,
    required this.step,
    required this.onExpand,
  });

  final Color accent;
  final RequestFlowStep step;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExpand,
        borderRadius: AppRadius.brMd,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: AppRadius.brMd,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(step.icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      step.subtitle,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  'Hiện tại',
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _ExpandedStep extends StatelessWidget {
  const _ExpandedStep({
    required this.accent,
    required this.step,
    required this.index,
    required this.active,
    required this.isLast,
  });

  final Color accent;
  final RequestFlowStep step;
  final int index;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : AppColors.textTertiary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? accent : AppColors.surfaceMuted,
                    border: Border.all(
                      color: active ? accent : AppColors.borderSoft,
                    ),
                  ),
                  child: active
                      ? Icon(step.icon, size: 14, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.borderSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: active ? accent : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    step.subtitle,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
