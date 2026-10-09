import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import 'nursing_integer_stepper.dart';

/// Accordion nhập NB nội trú theo 3 cấp chăm sóc — tổng = cấp 1+2+3.
class InpatientCareLevelAccordion extends StatefulWidget {
  const InpatientCareLevelAccordion({
    super.key,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.onChanged,
    this.enabled = true,
    this.initiallyExpanded = true,
  });

  final int level1;
  final int level2;
  final int level3;
  final ValueChanged<({int level1, int level2, int level3})> onChanged;
  final bool enabled;
  final bool initiallyExpanded;

  @override
  State<InpatientCareLevelAccordion> createState() =>
      _InpatientCareLevelAccordionState();
}

class _InpatientCareLevelAccordionState
    extends State<InpatientCareLevelAccordion>
    with SingleTickerProviderStateMixin {
  late bool _open;
  late final AnimationController _controller;
  late final Animation<double> _expand;

  static const _levels = [
    (
      key: '1',
      label: 'NB chăm sóc cấp 1',
      hint: 'Chăm sóc toàn diện / nặng',
      color: Color(0xFFBE123C),
    ),
    (
      key: '2',
      label: 'NB chăm sóc cấp 2',
      hint: 'Chăm sóc hỗ trợ',
      color: Color(0xFFB45309),
    ),
    (
      key: '3',
      label: 'NB chăm sóc cấp 3',
      hint: 'Chăm sóc cơ bản',
      color: Color(0xFF0369A1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _open ? 1 : 0,
    );
    _expand = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _total =>
      widget.level1.clamp(0, 1 << 30) +
      widget.level2.clamp(0, 1 << 30) +
      widget.level3.clamp(0, 1 << 30);

  void _toggle() {
    if (!widget.enabled && _open) {
      // Vẫn cho thu gọn khi chỉ xem.
    }
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    HapticFeedback.selectionClick();
  }

  void _setLevel(String key, int value) {
    final safe = value < 0 ? 0 : value;
    widget.onChanged((
      level1: key == '1' ? safe : widget.level1,
      level2: key == '2' ? safe : widget.level2,
      level3: key == '3' ? safe : widget.level3,
    ));
  }

  int _valueFor(String key) => switch (key) {
    '1' => widget.level1,
    '2' => widget.level2,
    _ => widget.level3,
  };

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.info;
    final total = _total;
    final values = [for (final lv in _levels) _valueFor(lv.key)];

    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(
          color: _open || total > 0
              ? accent.withValues(alpha: 0.28)
              : AppColors.border,
        ),
        boxShadow: _open ? AppShadows.tinted(accent) : AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Đầu khối: tổng + tóm tắt 3 cấp, chạm để mở/đóng ────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Ink(
                decoration: BoxDecoration(gradient: AppGradients.tint(accent)),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(accent, Colors.white, 0.12)!,
                                Color.lerp(accent, Colors.black, 0.12)!,
                              ],
                            ),
                            borderRadius: AppRadius.brBase,
                            boxShadow: AppShadows.tinted(accent),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    '$total',
                                    style: AppTypography.display(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                'NB',
                                style: AppTypography.uppercase(
                                  fontSize: 8,
                                  letterSpacing: 0.6,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Người bệnh nội trú',
                                style: AppTypography.style(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  height: AppTypography.uppercaseHeight,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _open
                                    ? 'Nhập theo 3 cấp chăm sóc · tổng tự cộng'
                                    : total > 0
                                    ? 'Đã nhập theo 3 cấp · chạm để sửa'
                                    : 'Chạm để nhập theo cấp chăm sóc',
                                style: AppTypography.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: AppDurations.normal,
                          curve: Curves.easeOutCubic,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.22),
                              ),
                              boxShadow: AppShadows.soft,
                            ),
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Thu gọn mà đã có số: tóm tắt 3 cấp bằng chip màu.
                    if (!_open && total > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final (i, lv) in _levels.indexed) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: _LevelChip(
                                level: lv.key,
                                value: values[i],
                                tone: lv.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // ── Nội dung mở rộng ─────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expand,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1, color: AppColors.borderSoft),
                for (final (i, lv) in _levels.indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 54,
                      endIndent: 12,
                      color: AppColors.divider,
                    ),
                  NursingIntegerStepper(
                    label: lv.label,
                    hint: lv.hint,
                    leading: _LevelBadge(level: lv.key, tone: lv.color),
                    value: values[i],
                    enabled: widget.enabled,
                    onChanged: (v) => _setLevel(lv.key, v),
                  ),
                ],
                // Tổng + thanh phân bổ 3 cấp.
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(accent),
                    borderRadius: AppRadius.brBase,
                    border: Border.all(color: accent.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.functions_rounded,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tổng người bệnh nội trú',
                              style: AppTypography.style(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '$total',
                            style: AppTypography.display(
                              fontSize: 20,
                              color: Color.lerp(
                                accent,
                                AppColors.textPrimary,
                                0.2,
                              )!,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: AppRadius.brPill,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: total <= 0
                            ? null
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, lv) in _levels.indexed)
                                    if (values[i] > 0)
                                      Expanded(
                                        flex: values[i],
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: lv.color,
                                            borderRadius: AppRadius.brPill,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                      ),
                    ],
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

/// Huy hiệu cấp chăm sóc: số cấp trong ô bo màu đặc.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.tone});

  final String level;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: AppRadius.brControl,
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Text(
        level,
        style: AppTypography.display(
          fontSize: 14,
          color: Color.lerp(tone, AppColors.textPrimary, 0.15)!,
        ),
      ),
    );
  }
}

/// Chip tóm tắt một cấp khi khối đang thu gọn: "Cấp 1 · 3".
class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.level,
    required this.value,
    required this.tone,
  });

  final String level;
  final int value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: AppRadius.brControl,
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Cấp $level',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '$value',
            style: AppTypography.display(
              fontSize: 14,
              color: Color.lerp(tone, AppColors.textPrimary, 0.2)!,
            ),
          ),
        ],
      ),
    );
  }
}
