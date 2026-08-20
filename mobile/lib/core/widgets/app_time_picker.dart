import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Chọn giờ — bánh xe hoặc nhập bàn phím (`06:45` / `6h45`).
Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String title = 'Chọn giờ',
  String? subtitle,
  TimeOfDay? suggestedTime,
  String? suggestedLabel,
  String confirmLabel = 'Chọn',
  String cancelLabel = 'Huỷ',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.bottomSheet),
      ),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _AppTimePickerSheet(
          initialTime: initialTime,
          title: title,
          subtitle: subtitle,
          suggestedTime: suggestedTime,
          suggestedLabel: suggestedLabel,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
        ),
      );
    },
  );
}

TimeOfDay? _parseTimeInput(String raw) {
  final text = raw.trim().toLowerCase().replaceAll(' ', '');
  if (text.isEmpty) return null;

  final colon = RegExp(r'^(\d{1,2})[:h\.](\d{1,2})$').firstMatch(text);
  if (colon != null) {
    final h = int.tryParse(colon.group(1)!);
    final m = int.tryParse(colon.group(2)!);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  final digits = RegExp(r'^(\d{3,4})$').firstMatch(text);
  if (digits != null) {
    final v = digits.group(1)!;
    final h = int.tryParse(v.length == 3 ? v.substring(0, 1) : v.substring(0, 2));
    final m = int.tryParse(v.length == 3 ? v.substring(1) : v.substring(2));
    if (h == null || m == null || h > 23 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  return null;
}

class _AppTimePickerSheet extends StatefulWidget {
  const _AppTimePickerSheet({
    required this.initialTime,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    this.subtitle,
    this.suggestedTime,
    this.suggestedLabel,
  });

  final TimeOfDay initialTime;
  final String title;
  final String? subtitle;
  final TimeOfDay? suggestedTime;
  final String? suggestedLabel;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<_AppTimePickerSheet> {
  static const _itemExtent = 44.0;

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  late int _hour;
  late int _minute;
  bool _keyboardMode = false;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour.clamp(0, 23);
    _minute = widget.initialTime.minute.clamp(0, 59);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _textCtrl = TextEditingController(text: _fmt(_selected));
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  TimeOfDay get _selected => TimeOfDay(hour: _hour, minute: _minute);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _display(TimeOfDay t) =>
      '${t.hour}h${t.minute.toString().padLeft(2, '0')}';

  void _setTime(TimeOfDay t, {bool animateWheels = true, bool syncText = true}) {
    final h = t.hour.clamp(0, 23);
    final m = t.minute.clamp(0, 59);
    setState(() {
      _hour = h;
      _minute = m;
      _inputError = null;
    });
    if (syncText) {
      final next = _fmt(TimeOfDay(hour: h, minute: m));
      if (_textCtrl.text != next) {
        _textCtrl.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
    if (animateWheels && !_keyboardMode) {
      _hourCtrl.animateToItem(
        h,
        duration: AppDurations.normal,
        curve: Curves.easeOutCubic,
      );
      _minuteCtrl.animateToItem(
        m,
        duration: AppDurations.normal,
        curve: Curves.easeOutCubic,
      );
    } else if (!_keyboardMode) {
      _hourCtrl.jumpToItem(h);
      _minuteCtrl.jumpToItem(m);
    }
  }

  void _applySuggestion() {
    final s = widget.suggestedTime;
    if (s == null) return;
    HapticFeedback.selectionClick();
    _setTime(s);
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _keyboardMode = !_keyboardMode;
      _inputError = null;
    });
    if (_keyboardMode) {
      _textCtrl.text = _fmt(_selected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
        _textCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _textCtrl.text.length,
        );
      });
    } else {
      _focusNode.unfocus();
      final parsed = _parseTimeInput(_textCtrl.text) ?? _selected;
      _setTime(parsed, animateWheels: false);
      _hourCtrl.jumpToItem(_hour);
      _minuteCtrl.jumpToItem(_minute);
    }
  }

  void _onTextChanged(String value) {
    final parsed = _parseTimeInput(value);
    setState(() {
      if (parsed == null) {
        _inputError = value.trim().isEmpty
            ? null
            : 'Nhập dạng 06:45 hoặc 6h45';
      } else {
        _hour = parsed.hour;
        _minute = parsed.minute;
        _inputError = null;
      }
    });
  }

  void _confirm() {
    if (_keyboardMode) {
      final parsed = _parseTimeInput(_textCtrl.text);
      if (parsed == null) {
        setState(() => _inputError = 'Giờ không hợp lệ (vd: 06:45)');
        return;
      }
      Navigator.of(context).pop(parsed);
      return;
    }
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final suggested = widget.suggestedTime;
    final showSuggest = suggested != null &&
        (suggested.hour != _hour || suggested.minute != _minute);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.style(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle!,
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
                IconButton(
                  tooltip: _keyboardMode ? 'Cuộn chọn giờ' : 'Nhập từ bàn phím',
                  onPressed: _toggleMode,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  icon: Icon(
                    _keyboardMode
                        ? Icons.swipe_vertical_rounded
                        : Icons.keyboard_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.primaryLight.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: AppRadius.brCard,
                border: Border.all(
                  color: _inputError != null
                      ? AppColors.error.withValues(alpha: 0.45)
                      : AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _keyboardMode ? 'NHẬP GIỜ' : 'GIỜ ĐÃ CHỌN',
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_keyboardMode)
                    TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.done,
                      style: AppTypography.style(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        letterSpacing: 1.2,
                        height: 1.1,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '06:45',
                        hintStyle: AppTypography.style(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        errorText: _inputError,
                        errorStyle: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9:hH\.]'),
                        ),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _confirm(),
                      onTap: () {
                        _textCtrl.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _textCtrl.text.length,
                        );
                      },
                    )
                  else
                    GestureDetector(
                      onTap: _toggleMode,
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: AppDurations.fast,
                            child: Text(
                              _fmt(_selected),
                              key: ValueKey(_fmt(_selected)),
                              style: AppTypography.style(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                height: 1.05,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_display(_selected)} · nhấn để nhập',
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_keyboardMode && _inputError == null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Gõ 06:45 hoặc 6h45',
                      style: AppTypography.style(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (suggested != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: showSuggest
                      ? AppColors.secondary.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brPill,
                  child: InkWell(
                    onTap: showSuggest ? _applySuggestion : null,
                    borderRadius: AppRadius.brPill,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            showSuggest
                                ? Icons.auto_awesome_rounded
                                : Icons.check_circle_rounded,
                            size: 16,
                            color: showSuggest
                                ? AppColors.secondaryDark
                                : AppColors.successDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            showSuggest
                                ? (widget.suggestedLabel ??
                                    'Dùng gợi ý ${_fmt(suggested)}')
                                : 'Đang dùng giờ gợi ý',
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: showSuggest
                                  ? AppColors.secondaryDark
                                  : AppColors.successDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            AnimatedSwitcher(
              duration: AppDurations.fast,
              child: _keyboardMode
                  ? const SizedBox.shrink(key: ValueKey('kb'))
                  : Container(
                      key: const ValueKey('wheel'),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadius.brCard,
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: Row(
                              children: [
                                Expanded(child: _WheelHeader(label: 'Giờ')),
                                SizedBox(width: 28),
                                Expanded(child: _WheelHeader(label: 'Phút')),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: _itemExtent * 4.2,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                IgnorePointer(
                                  child: Container(
                                    height: _itemExtent,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: AppRadius.brSm,
                                      border: Border.all(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.22),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _WheelColumn(
                                        controller: _hourCtrl,
                                        itemCount: 24,
                                        itemExtent: _itemExtent,
                                        selectedIndex: _hour,
                                        onSelected: (i) {
                                          HapticFeedback.selectionClick();
                                          _setTime(
                                            TimeOfDay(
                                              hour: i,
                                              minute: _minute,
                                            ),
                                            animateWheels: false,
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Center(
                                        child: Text(
                                          ':',
                                          style: AppTypography.style(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _WheelColumn(
                                        controller: _minuteCtrl,
                                        itemCount: 60,
                                        itemExtent: _itemExtent,
                                        selectedIndex: _minute,
                                        onSelected: (i) {
                                          HapticFeedback.selectionClick();
                                          _setTime(
                                            TimeOfDay(
                                              hour: _hour,
                                              minute: i,
                                            ),
                                            animateWheels: false,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: Text(widget.confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelHeader extends StatelessWidget {
  const _WheelHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: AppTypography.style(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.itemCount,
    required this.itemExtent,
    required this.selectedIndex,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final double itemExtent;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      physics: const FixedExtentScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      perspective: 0.002,
      diameterRatio: 1.6,
      squeeze: 1.0,
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final selected = index == selectedIndex;
          return Center(
            child: AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              style: AppTypography.style(
                fontSize: selected ? 24 : 17,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                height: 1,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textTertiary.withValues(alpha: 0.7),
              ),
              child: Text(index.toString().padLeft(2, '0')),
            ),
          );
        },
      ),
    );
  }
}
