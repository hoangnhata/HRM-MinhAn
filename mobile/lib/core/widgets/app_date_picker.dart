import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'app_action_button.dart';
import 'tinted_card_backdrop.dart';

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
        _inputError = value.trim().isEmpty
            ? null
            : 'Nhập dạng dd/MM/yyyy (vd: 11/08/2026)';
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
        setState(() => _inputError = 'Ngày không hợp lệ (vd: 11/08/2026)');
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
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
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

  static const _weekdayNames = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final cells = _daysInGrid();
    final canPrev = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
    ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));
    final canNext = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
    ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));
    final isToday = _selected == today;

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
            // ── Đầu sheet: ngày đang chọn ─────────────────────────────────
            Row(
              children: [
                const TintedIconTile(
                  icon: Icons.event_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _keyboardMode ? null : _toggleMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.uppercase(
                            fontSize: 9.5,
                            letterSpacing: 0.7,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _fmtDateInput(_selected),
                              style: AppTypography.metric(
                                fontSize: 20,
                                color: AppColors.textPrimary,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 1),
                                child: Text(
                                  isToday
                                      ? '${_weekdayNames[_selected.weekday - 1]} · hôm nay'
                                      : _weekdayNames[_selected.weekday - 1],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_inRange(today) && !isToday) ...[
                  _PillButton(
                    icon: Icons.today_rounded,
                    label: 'Hôm nay',
                    onTap: _goToday,
                  ),
                  const SizedBox(width: 6),
                ],
                _RoundButton(
                  icon: _keyboardMode
                      ? Icons.calendar_month_rounded
                      : Icons.keyboard_rounded,
                  tooltip: _keyboardMode
                      ? 'Chọn trên lịch'
                      : 'Nhập từ bàn phím',
                  active: _keyboardMode,
                  onTap: _toggleMode,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_keyboardMode) ...[
              TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                style: AppTypography.metric(
                  fontSize: 22,
                  color: AppColors.primaryDark,
                ),
                decoration: InputDecoration(
                  labelText: 'Nhập ngày',
                  hintText: 'dd/MM/yyyy',
                  helperText: 'Ví dụ: 11/08/2026',
                  errorText: _inputError,
                  prefixIcon: const Icon(Icons.edit_calendar_rounded),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: AppRadius.brControl),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brControl,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brControl,
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
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
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.brCard,
                        border: Border.all(color: AppColors.borderSoft),
                        boxShadow: AppShadows.soft,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _NavIcon(
                                icon: Icons.chevron_left_rounded,
                                enabled: canPrev,
                                onTap: () => _shiftMonth(-1),
                              ),
                              Expanded(
                                child: Text(
                                  AppFormat.monthLabelVi(_visibleMonth),
                                  textAlign: TextAlign.center,
                                  style: AppTypography.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: AppTypography.uppercaseHeight,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              _NavIcon(
                                icon: Icons.chevron_right_rounded,
                                enabled: canNext,
                                onTap: () => _shiftMonth(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final (i, w) in _weekdays.indexed)
                                Expanded(
                                  child: Text(
                                    w,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.uppercase(
                                      fontSize: 10,
                                      letterSpacing: 0.3,
                                      color: i >= 5
                                          ? AppColors.errorDark.withValues(
                                              alpha: 0.7,
                                            )
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (var row = 0; row < cells.length / 7; row++)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  for (var col = 0; col < 7; col++)
                                    Expanded(
                                      child: _DayCell(
                                        date: cells[row * 7 + col],
                                        weekend: col >= 5,
                                        selected:
                                            cells[row * 7 + col] != null &&
                                            _dateOnly(cells[row * 7 + col]!) ==
                                                _selected,
                                        isToday:
                                            cells[row * 7 + col] != null &&
                                            _dateOnly(cells[row * 7 + col]!) ==
                                                today,
                                        enabled:
                                            cells[row * 7 + col] != null &&
                                            _inRange(cells[row * 7 + col]!),
                                        onTap: cells[row * 7 + col] == null
                                            ? null
                                            : () {
                                                final d = cells[row * 7 + col]!;
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
                  flex: 2,
                  child: AppActionButton(
                    variant: AppActionVariant.outlineNeutral,
                    label: widget.cancelLabel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: AppActionButton(
                    variant: AppActionVariant.primary,
                    icon: Icons.check_rounded,
                    label: widget.confirmLabel,
                    onPressed: _confirm,
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

/// Viên nút nhỏ viền mảnh ("Hôm nay").
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brPill,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 11, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: AppTypography.uppercaseHeight,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút tròn đổi chế độ lịch / bàn phím.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.primary : AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: active
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 19,
              color: active ? Colors.white : AppColors.primary,
            ),
          ),
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
      color: enabled ? AppColors.surfaceAlt : Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(
          color: enabled ? AppColors.borderSoft : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? AppColors.primaryDark
                : AppColors.textTertiary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// Ô ngày kiểu lịch hiện đại: ngày chọn = hình tròn gradient brand có quầng
/// sáng; hôm nay = số teal đậm + chấm nhỏ (không khung); cuối tuần = số đỏ
/// nhạt; ngoài khoảng cho phép = mờ.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
    this.weekend = false,
  });

  final DateTime? date;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final bool weekend;
  final VoidCallback? onTap;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox(height: _size);

    final Color fg = !enabled
        ? AppColors.textTertiary.withValues(alpha: 0.35)
        : selected
        ? Colors.white
        : isToday
        ? AppColors.primary
        : weekend
        ? AppColors.errorDark.withValues(alpha: 0.8)
        : AppColors.textPrimary;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.appBarMid, AppColors.primaryDark],
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${date!.day}',
                  style: AppTypography.metric(
                    fontSize: 14.5,
                    color: fg,
                    fontWeight: selected || isToday
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
                if (isToday)
                  Positioned(
                    bottom: 5,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.secondaryLight
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
