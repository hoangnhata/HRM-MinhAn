import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

/// Bề rộng con trỏ nhập của ô số.
const double _kCursorWidth = 2;

/// `RenderEditable` giữ chỗ bên phải bằng bề rộng con trỏ cộng 1px khe hở, nên
/// vùng dựng chữ hẹp hơn ô 3px và chữ canh giữa bị đẩy lệch trái ~1.5px. Đệm
/// trái đúng bằng số này thì con số nằm chính giữa hai nút.
const double _kCaretReserve = _kCursorWidth + 1;

/// Hàng nhập số tự nhiên — nhãn bên trái, cụm [-] 0 [+] bên phải.
///
/// Bố cục hàng giúp một màn hình phone hiển thị được nhiều chỉ số hơn so với
/// kiểu nhãn nằm trên; các hàng được gom trong [NursingReportSection].
class NursingIntegerStepper extends StatefulWidget {
  const NursingIntegerStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.alertWhenPositive = false,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// Chỉ số sự cố: tô đỏ khi khác 0 để nổi bật trong phiếu.
  final bool alertWhenPositive;

  @override
  State<NursingIntegerStepper> createState() => _NursingIntegerStepperState();
}

class _NursingIntegerStepperState extends State<NursingIntegerStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${widget.value.clamp(0, 1 << 30)}',
    );
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant NursingIntegerStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = '${widget.value.clamp(0, 1 << 30)}';
    if (!_focusNode.hasFocus && _controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      // Bôi đen sẵn để gõ đè nhanh, không phải xoá số cũ.
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      setState(() {});
      return;
    }
    final text = '${widget.value < 0 ? 0 : widget.value}';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    setState(() {});
  }

  void _applyButtonValue(int value) {
    HapticFeedback.selectionClick();
    final text = '${value < 0 ? 0 : value}';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final safe = widget.value < 0 ? 0 : widget.value;
    final alerting = widget.alertWhenPositive && safe > 0;
    final valueColor = alerting
        ? AppColors.errorText
        : (safe > 0 ? AppColors.textPrimary : AppColors.textTertiary);
    final focused = _focusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.32,
                color: widget.enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: AppDurations.fast,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? AppColors.surfaceAlt
                  : AppColors.actionDisabledBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: focused
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : (alerting
                          ? AppColors.error.withValues(alpha: 0.3)
                          : AppColors.borderSoft),
                width: focused ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  enabled: widget.enabled && safe > 0,
                  onTap: () => _applyButtonValue(safe - 1),
                ),
                SizedBox(
                  width: 44,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    enabled: widget.enabled,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    // Chữ số nằm trên baseline, phần chỗ trống cho nét thòng
                    // bên dưới bỏ không, nên với cách chia leading mặc định
                    // (theo tỉ lệ ascent/descent) mực chữ bị đẩy cao hơn tâm ô.
                    // Chia leading đều hai bên thì số nằm đúng hàng với −/+.
                    style:
                        AppTypography.metric(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: valueColor,
                        ).copyWith(
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                    strutStyle: const StrutStyle(
                      fontSize: 16,
                      height: 1.1,
                      leadingDistribution: TextLeadingDistribution.even,
                      forceStrutHeight: true,
                    ),
                    cursorWidth: _kCursorWidth,
                    decoration: const InputDecoration(
                      isDense: true,
                      counterText: '',
                      filled: false,
                      // Đệm trái bù đúng phần TextField giữ chỗ cho con trỏ ở
                      // bên phải, nếu không con số canh giữa sẽ lệch trái.
                      contentPadding: EdgeInsets.fromLTRB(
                        _kCaretReserve,
                        8,
                        0,
                        8,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                    onChanged: (raw) => widget.onChanged(
                      raw.isEmpty ? 0 : int.tryParse(raw) ?? 0,
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  enabled: widget.enabled,
                  onTap: () => _applyButtonValue(safe + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Hai nút cùng sức nặng thị giác: phiếu có 20 chỉ số nên nút "+" tô đặc sẽ
    // tạo thành một dải khối teal chạy dọc trang. Nút bị khoá vẫn giữ nguyên
    // hình tròn để cụm điều khiển không bị khuyết một bên.
    final background = enabled
        ? AppColors.primary.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.04);
    final foreground = enabled
        ? AppColors.primary
        : AppColors.textTertiary.withValues(alpha: 0.5);

    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: foreground),
        ),
      ),
    );
  }
}

/// Nhóm chỉ số của phiếu — thẻ có tiêu đề đánh số và các hàng nhập liệu.
class NursingReportSection extends StatelessWidget {
  const NursingReportSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.step,
    this.icon = Icons.tune_rounded,
    this.accent = AppColors.primary,
  });

  final String title;
  final String? subtitle;

  /// Số thứ tự hiển thị trên huy hiệu, ví dụ "01".
  final String? step;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: step == null
                        ? Icon(icon, size: 17, color: accent)
                        : Center(
                            child: Text(
                              step!,
                              style: AppTypography.metric(
                                fontSize: 13,
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.style(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.15,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.32,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final (index, child) in children.indexed) ...[
              if (index == 0)
                const Divider(height: 1, color: AppColors.borderSoft)
              else
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Divider(height: 1, color: AppColors.borderSoft),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
