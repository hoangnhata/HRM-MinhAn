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
    this.hint,
    this.leading,
  });

  final String label;

  /// Dòng mô tả nhỏ dưới nhãn (tuỳ chọn).
  final String? hint;

  /// Widget đứng trước nhãn, vd. huy hiệu cấp chăm sóc (tuỳ chọn).
  final Widget? leading;
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

    final ringColor = focused
        ? AppColors.primary.withValues(alpha: 0.6)
        : alerting
        ? AppColors.error.withValues(alpha: 0.4)
        : safe > 0
        ? AppColors.primary.withValues(alpha: 0.28)
        : AppColors.border;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: safe > 0 ? FontWeight.w700 : FontWeight.w600,
                    height: 1.35,
                    color: widget.enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                if (widget.hint != null)
                  Text(
                    widget.hint!,
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Viên điều khiển: nền trắng nổi, viền teal khi có giá trị/đang gõ.
          AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: widget.enabled
                  ? (alerting
                        ? Color.alphaBlend(
                            AppColors.error.withValues(alpha: 0.06),
                            AppColors.surface,
                          )
                        : AppColors.surface)
                  : AppColors.actionDisabledBackground,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: ringColor, width: focused ? 1.5 : 1),
              boxShadow: widget.enabled && !focused ? AppShadows.soft : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  enabled: widget.enabled && safe > 0,
                  onTap: () => _applyButtonValue(safe - 1),
                ),
                // Ô số cao đúng bằng nút −/+ và canh giữa theo chiều dọc.
                // Theme đặt minHeight 48 cho mọi ô nhập — ở đây phải ghi đè,
                // nếu không ô cao hơn nút và con số bị đẩy lên phía trên.
                SizedBox(
                  width: 48,
                  height: 38,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    expands: true,
                    maxLines: null,
                    keyboardType: TextInputType.number,
                    // maxLines: null mặc định là phím xuống dòng — đổi thành "Xong".
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _focusNode.unfocus(),
                    enabled: widget.enabled,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AppTypography.style(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                      tabular: true,
                      height: 1.0,
                    ),
                    cursorWidth: _kCursorWidth,
                    cursorHeight: 18,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      constraints: BoxConstraints(),
                      counterText: '',
                      filled: false,
                      // Đệm trái bù đúng phần TextField giữ chỗ cho con trỏ ở
                      // bên phải, nếu không con số canh giữa sẽ lệch trái.
                      contentPadding: EdgeInsets.only(left: _kCaretReserve),
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
                  primary: true,
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
    this.primary = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  /// Nút "+" tông teal nhạt; "−" tông xám — vẫn nhẹ để 20 hàng không thành
  /// một dải khối màu chạy dọc trang.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? Colors.transparent
        : primary
        ? AppColors.primaryContainer
        : AppColors.surfaceMuted;
    final foreground = !enabled
        ? AppColors.textTertiary.withValues(alpha: 0.45)
        : primary
        ? AppColors.primaryDark
        : AppColors.textSecondary;

    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 38,
          child: Icon(icon, size: 19, color: foreground),
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
            Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              decoration: BoxDecoration(
                gradient: AppGradients.tint(accent),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
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
                    child: step == null
                        ? Icon(icon, size: 18, color: Colors.white)
                        : Center(
                            child: Text(
                              step!,
                              style: AppTypography.display(
                                fontSize: 13.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.25,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textPrimary,
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
                  padding: EdgeInsets.only(left: 14, right: 14),
                  child: Divider(height: 1, color: AppColors.divider),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
