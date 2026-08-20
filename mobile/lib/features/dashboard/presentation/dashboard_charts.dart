import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../data/dashboard_models.dart';

/// Thẻ hero tổng nhân sự — điểm nhấn đầu khối phân tích trên mobile.
class HeroMetricCard extends StatelessWidget {
  const HeroMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.icon = Icons.groups_rounded,
  });

  final int value;
  final String label;
  final String? caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.style(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppFormat.number(value),
                    style: AppTypography.metric(
                      fontSize: 34,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    caption!,
                    style: AppTypography.style(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
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

/// Lưới KPI 2 cột — vừa khung mobile.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items});

  final List<(String label, int value, IconData icon, Color color)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pageH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = AppSpacing.sm;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final singleColumn = constraints.maxWidth < 340 || textScale > 1.3;
          final tileW = singleColumn
              ? constraints.maxWidth
              : (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$3,
                    color: item.$4,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppFormat.number(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metric(fontSize: 22, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Donut + legend — dí giữ để xem chi tiết, nhả tay thì ẩn.
class StatusDonutChart extends StatefulWidget {
  const StatusDonutChart({super.key, required this.status});

  final StatusBreakdown status;

  @override
  State<StatusDonutChart> createState() => _StatusDonutChartState();
}

class _StatusDonutChartState extends State<StatusDonutChart> {
  int? _touched;

  static const _colors = [
    AppColors.primary,
    Color(0xFFE85D4C),
    Color(0xFF5B8DEF),
    AppColors.warning,
  ];

  void _press(int? index) {
    if (_touched == index) return;
    setState(() => _touched = index);
  }

  void _release() {
    if (_touched == null) return;
    setState(() => _touched = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final slices = [
      (label: 'Đang làm việc', value: s.working, color: _colors[0]),
      (label: 'Nghỉ thai sản', value: s.maternityLeave, color: _colors[1]),
      (label: 'Thử việc / tập sự', value: s.trial, color: _colors[2]),
      (label: 'Đã nghỉ', value: s.terminated, color: _colors[3]),
    ];
    final visible = slices.where((e) => e.value > 0).toList();

    final total = s.total;
    if (total <= 0 || visible.isEmpty) {
      return const _ChartEmpty(message: 'Chưa có dữ liệu trạng thái nhân sự');
    }

    final activeIndex = _touched;
    final focus = activeIndex != null &&
            activeIndex >= 0 &&
            activeIndex < visible.length
        ? visible[activeIndex]
        : null;
    final focusPercent =
        focus == null ? 0.0 : (focus.value / total) * 100;

    final chartSummary = visible
        .map(
          (item) =>
              '${item.label}: ${item.value} người, ${((item.value / total) * 100).toStringAsFixed(0)} phần trăm',
        )
        .join('. ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartTitle(
            title: 'Trạng thái nhân sự',
            subtitle:
                'Tổng ${AppFormat.number(total)} hồ sơ · giữ để xem chi tiết',
            icon: Icons.donut_large_rounded,
          ),
          const SizedBox(height: 16),
          Semantics(
            image: true,
            label:
                'Biểu đồ trạng thái nhân sự. Tổng $total người. $chartSummary',
            child: ExcludeSemantics(
              child: Center(
                child: SizedBox(
                  width: 176,
                  height: 176,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: AppDurations.fast,
                        curve: Curves.easeOutCubic,
                        width: 176,
                        height: 176,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              (focus?.color ?? AppColors.primary)
                                  .withValues(alpha: focus == null ? 0.06 : 0.12),
                              (focus?.color ?? AppColors.primary)
                                  .withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            enabled: true,
                            touchCallback: (event, response) {
                              final ended = event is FlTapUpEvent ||
                                  event is FlPanEndEvent ||
                                  event is FlLongPressEnd ||
                                  event is FlPointerExitEvent ||
                                  !event.isInterestedForInteractions;
                              if (ended) {
                                _release();
                                return;
                              }
                              final idx =
                                  response?.touchedSection?.touchedSectionIndex;
                              if (idx != null &&
                                  idx >= 0 &&
                                  idx < visible.length) {
                                _press(idx);
                              }
                            },
                          ),
                          sectionsSpace: 0.8,
                          centerSpaceRadius: 54,
                          startDegreeOffset: -90,
                          sections: [
                            for (var i = 0; i < visible.length; i++)
                              PieChartSectionData(
                                color: visible[i].color,
                                // Phần nhỏ (1–3%) dễ bị khoảng trắng “nuốt” —
                                // giữ tối thiểu ~2.5% vòng để màu vẫn thấy.
                                value: math.max(
                                  visible[i].value.toDouble(),
                                  total * 0.025,
                                ),
                                title: '',
                                radius: _touched == i ? 26 : 23,
                                borderSide: BorderSide.none,
                              ),
                          ],
                        ),
                        duration: AppDurations.fast,
                        curve: Curves.easeOutCubic,
                      ),
                      IgnorePointer(
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          curve: Curves.easeOutCubic,
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            boxShadow: [
                              BoxShadow(
                                color: (focus?.color ?? AppColors.primaryDark)
                                    .withValues(alpha: focus == null ? 0.06 : 0.14),
                                blurRadius: focus == null ? 10 : 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: (focus?.color ?? AppColors.borderSoft)
                                  .withValues(alpha: focus == null ? 0.35 : 0.55),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: AppDurations.fast,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.92, end: 1)
                                      .animate(anim),
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              key: ValueKey(
                                focus == null
                                    ? 'total-$total'
                                    : 'focus-${focus.label}-${focus.value}',
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppFormat.number(focus?.value ?? total),
                                    style: AppTypography.metric(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: focus?.color ??
                                          AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    focus?.label ?? 'Tổng nhân sự',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.style(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (focus != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${focusPercent.toStringAsFixed(1)}%',
                                      style: AppTypography.style(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: focus.color,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: focus == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AnimatedOpacity(
                      duration: AppDurations.fast,
                      opacity: 1,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: focus.color.withValues(alpha: 0.08),
                          borderRadius: AppRadius.brMd,
                          border: Border.all(
                            color: focus.color.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 16,
                              color: focus.color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${focus.label}: ${AppFormat.number(focus.value)} người '
                                '(${focusPercent.toStringAsFixed(1)}% tổng hồ sơ)',
                                style: AppTypography.style(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _StatusLegendRow(
              color: visible[i].color,
              label: visible[i].label,
              value: visible[i].value,
              percent: (visible[i].value / total) * 100,
              selected: _touched == i,
              onPress: () => _press(i),
              onRelease: _release,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLegendRow extends StatelessWidget {
  const _StatusLegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
    required this.selected,
    required this.onPress,
    required this.onRelease,
  });

  final Color color;
  final String label;
  final int value;
  final double percent;
  final bool selected;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$label, ${AppFormat.number(value)} người, ${percent.toStringAsFixed(0)} phần trăm',
      hint: 'Giữ để xem chi tiết',
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: (_) => onPress(),
          onPointerUp: (_) => onRelease(),
          onPointerCancel: (_) => onRelease(),
          child: AnimatedScale(
            scale: selected ? 1.015 : 1,
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.1)
                    : AppColors.surfaceMuted.withValues(alpha: 0.55),
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.32)
                      : AppColors.borderSoft,
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        AppFormat.number(value),
                        style: AppTypography.metric(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: AppRadius.brPill,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: (percent / 100).clamp(0.0, 1.0),
                      ),
                      duration: AppDurations.slow,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.7),
                          valueColor: AlwaysStoppedAnimation(color),
                        );
                      },
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

Color nursingSubGroupColor(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('điều dưỡng') || lower == 'dd') {
    return const Color(0xFF0F766E);
  }
  if (lower.contains('ktv')) return const Color(0xFF0369A1);
  if (lower.contains('hộ sinh') || lower.contains('ho sinh')) {
    return const Color(0xFF7C3AED);
  }
  if (lower.contains('thư ký') || lower.contains('thu ky')) {
    return const Color(0xFFBE185D);
  }
  return const Color(0xFFB45309);
}

/// Phân bổ chức danh khối ĐD–KTV–HS–Thư ký — đồng bộ `bySubGroup` web.
class NursingSubGroupChart extends StatefulWidget {
  const NursingSubGroupChart({super.key, required this.items});

  final List<SubGroupCount> items;

  @override
  State<NursingSubGroupChart> createState() => _NursingSubGroupChartState();
}

class _NursingSubGroupChartState extends State<NursingSubGroupChart> {
  int? _touched;

  void _press(int? index) {
    if (_touched == index) return;
    setState(() => _touched = index);
  }

  void _release() {
    if (_touched == null) return;
    setState(() => _touched = null);
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final item in widget.items)
        if (item.count > 0)
          (
            label: item.label,
            value: item.count,
            color: nursingSubGroupColor(item.label),
          ),
    ];
    final total = visible.fold<int>(0, (sum, e) => sum + e.value);

    if (total <= 0 || visible.isEmpty) {
      return const _ChartEmpty(message: 'Chưa có dữ liệu phân bổ chức danh');
    }

    final activeIndex = _touched;
    final focus = activeIndex != null &&
            activeIndex >= 0 &&
            activeIndex < visible.length
        ? visible[activeIndex]
        : null;
    final focusPercent = focus == null ? 0.0 : (focus.value / total) * 100;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ChartTitle(
            title: 'Phân bổ theo chức danh',
            subtitle: 'Tỷ lệ ĐD · KTV · Hộ sinh · Thư ký trong khối',
            icon: Icons.pie_chart_outline_rounded,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback: (event, response) {
                            final ended = event is FlTapUpEvent ||
                                event is FlPanEndEvent ||
                                event is FlLongPressEnd ||
                                event is FlPointerExitEvent ||
                                !event.isInterestedForInteractions;
                            if (ended) {
                              _release();
                              return;
                            }
                            final idx =
                                response?.touchedSection?.touchedSectionIndex;
                            if (idx != null &&
                                idx >= 0 &&
                                idx < visible.length) {
                              _press(idx);
                            }
                          },
                        ),
                        sectionsSpace: 1,
                        centerSpaceRadius: 40,
                        startDegreeOffset: -90,
                        sections: [
                          for (var i = 0; i < visible.length; i++)
                            PieChartSectionData(
                              color: visible[i].color,
                              value: math.max(
                                visible[i].value.toDouble(),
                                total * 0.025,
                              ),
                              title: '',
                              radius: _touched == i ? 22 : 19,
                              borderSide: BorderSide.none,
                            ),
                        ],
                      ),
                      duration: AppDurations.fast,
                      curve: Curves.easeOutCubic,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppFormat.number(focus?.value ?? total),
                          style: AppTypography.metric(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: focus?.color ?? AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          focus?.label ?? 'nhân viên',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _SubGroupLegendRow(
                        label: visible[i].label,
                        value: visible[i].value,
                        total: total,
                        color: visible[i].color,
                        selected: _touched == i,
                        percent: focus == visible[i]
                            ? focusPercent
                            : (visible[i].value / total) * 100,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubGroupLegendRow extends StatelessWidget {
  const _SubGroupLegendRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.selected,
    required this.percent,
  });

  final String label;
  final int value;
  final int total;
  final Color color;
  final bool selected;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: AppRadius.brSm,
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                AppFormat.number(value),
                style: AppTypography.metric(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${percent.round()}%',
                style: AppTypography.style(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: total <= 0 ? 0 : value / total,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Danh sách phòng ban — thu gọn / mở rộng xem đủ, thanh tiến độ chi tiết.
class DepartmentBarChart extends StatefulWidget {
  const DepartmentBarChart({
    super.key,
    required this.departments,
    this.maxItems = 6,
    this.title = 'Nhân sự theo phòng ban',
    this.subtitle = 'Top khoa/phòng có nhiều nhân viên nhất',
    this.compact = false,
  });

  final List<DepartmentCount> departments;
  final int maxItems;
  final String title;
  final String subtitle;

  /// `true` = không hiện tiêu đề trong card (đã có section header ngoài).
  final bool compact;

  static const _palette = [
    AppColors.primary,
    Color(0xFF2A9D8F),
    Color(0xFF457B9D),
    Color(0xFF5C6BC0),
    Color(0xFFE9A825),
    Color(0xFF78909C),
  ];

  @override
  State<DepartmentBarChart> createState() => _DepartmentBarChartState();
}

class _DepartmentBarChartState extends State<DepartmentBarChart> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final departments = widget.departments;
    if (departments.isEmpty) {
      return const _ChartEmpty(message: 'Chưa có dữ liệu phòng ban');
    }

    final canExpand = departments.length > widget.maxItems;
    final items = _expanded || !canExpand
        ? departments
        : departments.take(widget.maxItems).toList();
    final maxCount = departments
        .map((e) => e.count)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final totalStaff = departments.fold<int>(0, (sum, e) => sum + e.count);
    final hidden = departments.length - widget.maxItems;

    return AppCard(
      padding: EdgeInsets.fromLTRB(14, widget.compact ? 12 : 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.compact) ...[
            _ChartTitle(
              title: widget.title,
              subtitle: widget.subtitle,
              icon: Icons.apartment_rounded,
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${departments.length} khoa/phòng',
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                Text(
                  '${AppFormat.number(totalStaff)} nhân sự',
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: AppDurations.normal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _DeptBarRow(
                    index: i + 1,
                    department: items[i],
                    maxCount: maxCount,
                    totalStaff: totalStaff,
                    color: DepartmentBarChart
                        ._palette[i % DepartmentBarChart._palette.length],
                  ),
                ],
              ],
            ),
          ),
          if (canExpand) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: AppRadius.brMd,
                child: Ink(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _expanded
                              ? 'Thu gọn danh sách'
                              : 'Xem thêm $hidden khoa/phòng',
                          style: AppTypography.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: AppDurations.fast,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeptBarRow extends StatelessWidget {
  const _DeptBarRow({
    required this.index,
    required this.department,
    required this.maxCount,
    required this.totalStaff,
    required this.color,
  });

  final int index;
  final DepartmentCount department;
  final int maxCount;
  final int totalStaff;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = (department.count / maxCount).clamp(0.0, 1.0);
    final share = totalStaff <= 0
        ? 0.0
        : (department.count / totalStaff) * 100;
    final name = _titleCase(department.departmentName);
    final detail = [
      if (department.officialCount > 0)
        '${department.officialCount} chính thức',
      if (department.trialCount > 0) '${department.trialCount} thử việc',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: index.isOdd
            ? AppColors.surfaceMuted.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Text(
              '$index',
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
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
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppFormat.number(department.count),
                      style: AppTypography.metric(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.brPill,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: ratio),
                          duration: AppDurations.slow,
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 7,
                              backgroundColor: color.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(color),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${share.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _titleCase(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
    if (letters.isEmpty) return trimmed;

    var upperCount = 0;
    for (final unit in letters.runes) {
      final ch = String.fromCharCode(unit);
      if (ch == ch.toUpperCase()) upperCount++;
    }
    if (upperCount / letters.length < 0.7) return trimmed;

    return trimmed
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          if (w.length <= 3 && RegExp(r'^[a-zà-ỹ]+$').hasMatch(w)) {
            return w.toUpperCase();
          }
          return '${w[0].toUpperCase()}${w.substring(1)}';
        })
        .join(' ');
  }
}

/// Biểu đồ vùng tuyển dụng — dí giữ để xem tháng, nhả tay thì ẩn.
class HiresAreaChart extends StatefulWidget {
  const HiresAreaChart({super.key, required this.hires});

  final List<HireMonth> hires;

  @override
  State<HiresAreaChart> createState() => _HiresAreaChartState();
}

class _HiresAreaChartState extends State<HiresAreaChart> {
  int? _pressed;

  void _press(int? index) {
    if (_pressed == index) return;
    setState(() => _pressed = index);
  }

  void _release() {
    if (_pressed == null) return;
    setState(() => _pressed = null);
  }

  @override
  Widget build(BuildContext context) {
    final hires = widget.hires;
    if (hires.isEmpty) {
      return const _ChartEmpty(message: 'Chưa có dữ liệu tuyển dụng');
    }

    final maxCount = hires
        .map((e) => e.count)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final maxY = _niceMax(maxCount.toDouble());
    final yInterval = maxY / 4;
    final spots = [
      for (var i = 0; i < hires.length; i++)
        FlSpot(i.toDouble(), hires[i].count.toDouble()),
    ];
    final peak = hires.reduce((a, b) => a.count >= b.count ? a : b);
    final peakIndex = hires.indexOf(peak);
    final totalHires = hires.fold<int>(0, (sum, e) => sum + e.count);
    final avgHires = totalHires / hires.length;
    final latest = hires.last;
    final prev = hires.length > 1 ? hires[hires.length - 2] : null;
    final delta = prev == null ? 0 : latest.count - prev.count;
    final focus = _pressed != null &&
            _pressed! >= 0 &&
            _pressed! < hires.length
        ? hires[_pressed!]
        : null;
    final focusPrev = focus == null || _pressed! <= 0
        ? null
        : hires[_pressed! - 1];
    final focusDelta = focus == null || focusPrev == null
        ? null
        : focus.count - focusPrev.count;

    // Nhãn X: khoảng đều ~5–6 điểm.
    final xStep = (hires.length / 5).ceil().clamp(1, 3);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleExtra = (textScale - 1).clamp(0.0, 2.0);
    final chartHeight = 198.0 + (scaleExtra * 34);
    final leftReserved = 30.0 + (scaleExtra * 12);
    final bottomReserved = 28.0 + (scaleExtra * 12);
    final dataSummary = hires
        .map((item) => '${item.label}: ${item.count} người')
        .join('. ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartTitle(
            title: 'Tuyển dụng theo tháng',
            subtitle: '12 tháng gần nhất · giữ điểm để xem chi tiết',
            icon: Icons.show_chart_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HireStatChip(
                  label: 'Tổng kỳ',
                  value: AppFormat.number(totalHires),
                  hint: 'người',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HireStatChip(
                  label: 'Trung bình',
                  value: avgHires.toStringAsFixed(avgHires >= 10 ? 0 : 1),
                  hint: '/tháng',
                  color: const Color(0xFF5C6BC0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HireStatChip(
                  label: 'Cao nhất',
                  value: AppFormat.number(peak.count),
                  hint: peak.label,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            image: true,
            label:
                'Biểu đồ tuyển dụng theo tháng. Cao nhất ${peak.label}: ${peak.count} người. $dataSummary',
            child: ExcludeSemantics(
              child: SizedBox(
                height: chartHeight,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    minX: -0.15,
                    maxX: (hires.length - 1).toDouble() + 0.15,
                    clipData: const FlClipData.all(),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchSpotThreshold: 28,
                      getTouchLineStart: (_, _) => 0,
                      getTouchLineEnd: (_, _) => maxY,
                      touchCallback: (event, response) {
                        final ended = event is FlTapUpEvent ||
                            event is FlPanEndEvent ||
                            event is FlLongPressEnd ||
                            event is FlPointerExitEvent ||
                            !event.isInterestedForInteractions;
                        if (ended) {
                          _release();
                          return;
                        }
                        final touched = response?.lineBarSpots;
                        if (touched == null || touched.isEmpty) return;
                        final idx =
                            touched.first.x.round().clamp(0, hires.length - 1);
                        _press(idx);
                      },
                      getTouchedSpotIndicator: (bar, indexes) => indexes
                          .map(
                            (i) => TouchedSpotIndicatorData(
                              FlLine(
                                color: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                                strokeWidth: 1.4,
                                dashArray: [5, 5],
                              ),
                              FlDotData(
                                getDotPainter:
                                    (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                          radius: 7.5,
                                          color: AppColors.surface,
                                          strokeWidth: 3.2,
                                          strokeColor: AppColors.primary,
                                        ),
                              ),
                            ),
                          )
                          .toList(),
                      // Ẩn tooltip mặc định — dùng thẻ chi tiết bên dưới.
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => Colors.transparent,
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 0,
                        getTooltipItems: (_) => [],
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.borderSoft,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: leftReserved,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) {
                            if (value < 0 || value > maxY + 0.01) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                value.toInt().toString(),
                                textAlign: TextAlign.right,
                                style: AppTypography.style(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: bottomReserved,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.round();
                            if ((value - idx).abs() > 0.01) {
                              return const SizedBox.shrink();
                            }
                            if (idx < 0 || idx >= hires.length) {
                              return const SizedBox.shrink();
                            }
                            final isPressed = idx == _pressed;
                            final isPeak = idx == peakIndex;
                            // Khi đang giữ 1 điểm: ẩn nhãn kề bên để tránh chồng chữ.
                            if (_pressed != null &&
                                !isPressed &&
                                (idx - _pressed!).abs() == 1) {
                              return const SizedBox.shrink();
                            }
                            if (idx % xStep != 0 &&
                                idx != hires.length - 1 &&
                                !isPeak &&
                                !isPressed) {
                              return const SizedBox.shrink();
                            }
                            final label = isPressed
                                ? hires[idx].label
                                : 'T${hires[idx].month}';
                            return SideTitleWidget(
                              meta: meta,
                              space: 6,
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: AppTypography.style(
                                  fontSize: isPressed ? 10 : 9,
                                  color: isPressed
                                      ? AppColors.primary
                                      : isPeak
                                          ? AppColors.secondaryDark
                                          : AppColors.textTertiary,
                                  fontWeight: isPressed || isPeak
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.32,
                        preventCurveOverShooting: true,
                        color: AppColors.primary,
                        barWidth: focus == null ? 3 : 3.4,
                        isStrokeCapRound: true,
                        shadow: Shadow(
                          color: AppColors.primary.withValues(
                            alpha: focus == null ? 0.22 : 0.32,
                          ),
                          blurRadius: focus == null ? 8 : 12,
                          offset: const Offset(0, 4),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            final isPressed = index == _pressed;
                            final isPeak = index == peakIndex;
                            final isEdge =
                                index == 0 || index == hires.length - 1;
                            if (isPressed) {
                              return FlDotCirclePainter(
                                radius: 6.5,
                                color: AppColors.surface,
                                strokeWidth: 3,
                                strokeColor: AppColors.primary,
                              );
                            }
                            if (!isPeak && !isEdge) {
                              return FlDotCirclePainter(
                                radius: 2.2,
                                color: AppColors.primary.withValues(
                                  alpha: focus == null ? 0.55 : 0.28,
                                ),
                                strokeWidth: 0,
                                strokeColor: Colors.transparent,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: isPeak ? 5.2 : 3.4,
                              color: AppColors.surface,
                              strokeWidth: isPeak ? 2.8 : 2.1,
                              strokeColor: isPeak
                                  ? AppColors.secondary
                                  : AppColors.primary.withValues(
                                      alpha: focus == null ? 1 : 0.55,
                                    ),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(
                                alpha: focus == null ? 0.26 : 0.34,
                              ),
                              AppColors.primary.withValues(alpha: 0.08),
                              AppColors.primary.withValues(alpha: 0.0),
                            ],
                            stops: const [0, 0.55, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: AppDurations.fast,
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: focus == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _HireFocusCard(
                      month: focus,
                      delta: focusDelta,
                      prevLabel: focusPrev?.label,
                      isPeak: _pressed == peakIndex,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: focus == null
                  ? AppColors.surfaceMuted
                  : AppColors.primary.withValues(alpha: 0.06),
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: focus == null
                    ? AppColors.borderSoft
                    : AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  focus != null
                      ? Icons.touch_app_rounded
                      : delta >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                  size: 18,
                  color: focus != null
                      ? AppColors.primary
                      : delta >= 0
                          ? AppColors.success
                          : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: Text(
                      key: ValueKey(
                        focus == null
                            ? 'latest-${latest.label}'
                            : 'focus-${focus.label}',
                      ),
                      focus == null
                          ? (prev == null
                              ? 'Tháng ${latest.label}: ${latest.count} người tuyển mới'
                              : 'Tháng ${latest.label}: ${latest.count} người '
                                  '(${delta >= 0 ? '+' : ''}$delta so với ${prev.label})')
                          : 'Đang xem ${focus.label} · nhả tay để ẩn chi tiết',
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Làm tròn maxY về bậc đẹp (…, 20, 25, 30…) để trục Y không “lệch”.
  static double _niceMax(double raw) {
    if (raw <= 0) return 4;
    final padded = raw * 1.18;
    final magnitude = math
        .pow(10, (math.log(padded) / math.ln10).floor())
        .toDouble();
    final residual = padded / magnitude;
    final nice = residual <= 1
        ? 1.0
        : residual <= 2
        ? 2.0
        : residual <= 2.5
        ? 2.5
        : residual <= 5
        ? 5.0
        : 10.0;
    return nice * magnitude;
  }
}

class _HireFocusCard extends StatelessWidget {
  const _HireFocusCard({
    required this.month,
    required this.delta,
    required this.prevLabel,
    required this.isPeak,
  });

  final HireMonth month;
  final int? delta;
  final String? prevLabel;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (month.officialCount > 0) '${month.officialCount} chính thức',
      if (month.trialCount > 0) '${month.trialCount} thử việc',
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: AppRadius.brSm,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              size: 22,
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
                        month.label,
                        style: AppTypography.style(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    if (isPeak)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.14),
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          'Cao nhất',
                          style: AppTypography.style(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${AppFormat.number(month.count)} người tuyển'
                  '${detail.isEmpty ? '' : ' · $detail'}',
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (delta != null && prevLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${delta! >= 0 ? '+' : ''}$delta so với $prevLabel',
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: delta! >= 0 ? AppColors.success : AppColors.error,
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

class _HireStatChip extends StatelessWidget {
  const _HireStatChip({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.metric(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hàng chỉ số phụ gọn.
class MetricListCard extends StatelessWidget {
  const MetricListCard({super.key, required this.items});

  final List<(String label, int value, IconData icon, Color color)> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 56, color: AppColors.borderSoft),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 2,
              ),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: items[i].$4.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(items[i].$3, size: 18, color: items[i].$4),
              ),
              title: Text(items[i].$1, style: AppTypography.listTitle()),
              trailing: Text(
                AppFormat.compactNumber(items[i].$2),
                style: AppTypography.metric(fontSize: 16, color: items[i].$4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class KpiHighlightRow extends StatelessWidget {
  const KpiHighlightRow({super.key, required this.items});

  final List<(String label, int value, IconData icon, Color color)> items;

  @override
  Widget build(BuildContext context) => KpiGrid(items: items);
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.listTitle()),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            message,
            style: AppTypography.caption(color: AppColors.textTertiary),
          ),
        ),
      ),
    );
  }
}
