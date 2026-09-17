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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: total > 0
            ? accent.withValues(alpha: 0.045)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: total > 0
              ? accent.withValues(alpha: 0.28)
              : AppColors.outline.withValues(alpha: 0.55),
        ),
        boxShadow: _open
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$total',
                        style: AppTypography.style(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
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
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _open
                                ? 'Nhập theo 3 cấp chăm sóc — tổng tự cộng'
                                : total > 0
                                ? 'Cấp 1: ${widget.level1} · Cấp 2: ${widget.level2} · Cấp 3: ${widget.level3}'
                                : 'Nhấn để nhập theo cấp chăm sóc',
                            style: AppTypography.style(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        _open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expand,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Column(
                children: [
                  for (final lv in _levels) ...[
                    const SizedBox(height: 8),
                    _LevelRow(
                      label: lv.label,
                      hint: lv.hint,
                      tone: lv.color,
                      value: _valueFor(lv.key),
                      enabled: widget.enabled,
                      onChanged: (v) => _setLevel(lv.key, v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: [
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
                          style: AppTypography.style(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            height: 1,
                          ),
                        ),
                      ],
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

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.hint,
    required this.tone,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final Color tone;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: tone.withValues(alpha: value > 0 ? 0.3 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tone,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tone.withValues(alpha: 0.25),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      hint,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          NursingIntegerStepper(
            label: 'Số lượng',
            value: value,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
