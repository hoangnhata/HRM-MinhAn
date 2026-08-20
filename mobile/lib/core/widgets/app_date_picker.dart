import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _fmtDateInput(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

DateTime? _parseDateInput(String raw) {
  final text = raw.trim().replaceAll('-', '/').replaceAll('.', '/');
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  final month = int.tryParse(m.group(2)!);
  final year = int.tryParse(m.group(3)!);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final candidate = DateTime(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day) {
    return null;
  }
  return _dateOnly(candidate);
}

/// Chọn ngày — lịch hoặc nhập bàn phím (`dd/MM/yyyy`).
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Chọn ngày',
  String confirmLabel = 'Chọn',
  String cancelLabel = 'Huỷ',
}) {
  assert(!lastDate.isBefore(firstDate));
  var initial = _dateOnly(initialDate);
  final first = _dateOnly(firstDate);
  final last = _dateOnly(lastDate);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showModalBottomSheet<DateTime>(
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
        child: _AppDatePickerSheet(
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          title: title,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
        ),
      );
    },
  );
}

class _AppDatePickerSheet extends StatefulWidget {
  const _AppDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  late DateTime _selected;
  late DateTime _visibleMonth;
  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  bool _keyboardMode = false;
  String? _inputError;

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(_selected.year, _selected.month);
    _textCtrl = TextEditingController(text: _fmtDateInput(_selected));
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _inRange(DateTime d) {
    final x = _dateOnly(d);
    return !x.isBefore(widget.firstDate) && !x.isAfter(widget.lastDate);
  }

  void _syncText(DateTime d) {
    final next = _fmtDateInput(d);
    if (_textCtrl.text != next) {
      _textCtrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  void _selectDate(DateTime d, {bool syncText = true}) {
    final x = _dateOnly(d);
    setState(() {
      _selected = x;
      _visibleMonth = DateTime(x.year, x.month);
      _inputError = null;
    });
    if (syncText) _syncText(x);
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (next.isBefore(firstMonth) || next.isAfter(lastMonth)) return;
    HapticFeedback.selectionClick();
    setState(() => _visibleMonth = next);
  }

  void _goToday() {
    final today = _dateOnly(DateTime.now());
    if (!_inRange(today)) return;
    HapticFeedback.selectionClick();
    _selectDate(today);
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _keyboardMode = !_keyboardMode;
      _inputError = null;
    });
    if (_keyboardMode) {
      _syncText(_selected);
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
      final parsed = _parseDateInput(_textCtrl.text);
      if (parsed != null && _inRange(parsed)) {
        _selectDate(parsed);
      } else {
        _syncText(_selected);
      }
    }
  }

  void _onTextChanged(String value) {
    final parsed = _parseDateInput(value);
    setState(() {
      if (parsed == null) {
        _inputError =
            value.trim().isEmpty ? null : 'Nhập dạng dd/MM/yyyy (vd: 11/08/2026)';
        return;
      }
      if (!_inRange(parsed)) {
        _inputError =
            'Ngày ngoài khoảng cho phép (${_fmtDateInput(widget.firstDate)} – ${_fmtDateInput(widget.lastDate)})';
        return;
      }
      _selected = parsed;
      _visibleMonth = DateTime(parsed.year, parsed.month);
      _inputError = null;
    });
  }

  void _confirm() {
    if (_keyboardMode) {
      final parsed = _parseDateInput(_textCtrl.text);
      if (parsed == null) {
        setState(
          () => _inputError = 'Ngày không hợp lệ (vd: 11/08/2026)',
        );
        return;
      }
      if (!_inRange(parsed)) {
        setState(() => _inputError = 'Ngày ngoài khoảng cho phép');
        return;
      }
      Navigator.of(context).pop(parsed);
      return;
    }
    Navigator.of(context).pop(_selected);
  }

  List<DateTime?> _daysInGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lead = first.weekday - 1;
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final cells = <DateTime?>[];
    for (var i = 0; i < lead; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final cells = _daysInGrid();

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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _keyboardMode ? null : _toggleMode,
                        child: Text(
                          AppFormat.longDateVi(_selected),
                          style: AppTypography.style(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_inRange(today))
                  TextButton(
                    onPressed: _goToday,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Hôm nay'),
                  ),
                IconButton(
                  tooltip:
                      _keyboardMode ? 'Chọn trên lịch' : 'Nhập từ bàn phím',
                  onPressed: _toggleMode,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  icon: Icon(
                    _keyboardMode
                        ? Icons.calendar_month_rounded
                        : Icons.keyboard_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_keyboardMode) ...[
              TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                style: AppTypography.style(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.6,
                ),
                decoration: InputDecoration(
                  labelText: 'Nhập ngày',
                  hintText: 'dd/MM/yyyy',
                  helperText: 'Ví dụ: 11/08/2026',
                  errorText: _inputError,
                  prefixIcon: const Icon(Icons.edit_calendar_rounded),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/\-.]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: _onTextChanged,
                onSubmitted: (_) => _confirm(),
                onTap: () {
                  _textCtrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _textCtrl.text.length,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AnimatedSwitcher(
              duration: AppDurations.fast,
              child: _keyboardMode
                  ? const SizedBox.shrink(key: ValueKey('kb-cal'))
                  : Container(
                      key: const ValueKey('cal'),
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadius.brCard,
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _NavIcon(
                                icon: Icons.chevron_left_rounded,
                                enabled: DateTime(
                                  _visibleMonth.year,
                                  _visibleMonth.month,
                                ).isAfter(
                                  DateTime(
                                    widget.firstDate.year,
                                    widget.firstDate.month,
                                  ),
                                ),
                                onTap: () => _shiftMonth(-1),
                              ),
                              Expanded(
                                child: Text(
                                  AppFormat.monthLabelVi(_visibleMonth),
                                  textAlign: TextAlign.center,
                                  style: AppTypography.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              _NavIcon(
                                icon: Icons.chevron_right_rounded,
                                enabled: DateTime(
                                  _visibleMonth.year,
                                  _visibleMonth.month,
                                ).isBefore(
                                  DateTime(
                                    widget.lastDate.year,
                                    widget.lastDate.month,
                                  ),
                                ),
                                onTap: () => _shiftMonth(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final w in _weekdays)
                                Expanded(
                                  child: Text(
                                    w,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.style(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          for (var row = 0; row < cells.length / 7; row++)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  for (var col = 0; col < 7; col++)
                                    Expanded(
                                      child: _DayCell(
                                        date: cells[row * 7 + col],
                                        selected: cells[row * 7 + col] !=
                                                null &&
                                            _dateOnly(
                                                  cells[row * 7 + col]!,
                                                ) ==
                                                _selected,
                                        isToday: cells[row * 7 + col] !=
                                                null &&
                                            _dateOnly(
                                                  cells[row * 7 + col]!,
                                                ) ==
                                                today,
                                        enabled: cells[row * 7 + col] !=
                                                null &&
                                            _inRange(cells[row * 7 + col]!),
                                        onTap: cells[row * 7 + col] == null
                                            ? null
                                            : () {
                                                final d =
                                                    cells[row * 7 + col]!;
                                                if (!_inRange(d)) return;
                                                HapticFeedback.selectionClick();
                                                _selectDate(d);
                                              },
                                      ),
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

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: enabled ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final DateTime? date;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const SizedBox(height: 40);
    }

    final fg = !enabled
        ? AppColors.textTertiary.withValues(alpha: 0.35)
        : selected
            ? Colors.white
            : AppColors.textPrimary;

    return Center(
      child: Material(
        color: selected
            ? AppColors.primary
            : isToday
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isToday && !selected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.45))
                  : null,
            ),
            child: Center(
              child: Text(
                '${date!.day}',
                style: AppTypography.style(
                  fontSize: 13.5,
                  fontWeight: selected || isToday
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
