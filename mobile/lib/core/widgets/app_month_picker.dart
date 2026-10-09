import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'tinted_card_backdrop.dart';

/// Sheet chọn tháng dùng chung — hàng năm ở trên, lưới 12 tháng ở dưới.
///
/// Đây là mẫu của màn Bảng công theo khoa; mọi màn có chọn tháng (báo cáo,
/// đánh giá QTKT, nâng bậc lương, bảng công cá nhân) dùng chung hàm này để
/// không còn mỗi nơi một kiểu picker.
///
/// Trả về `(year, month)` khi người dùng chạm một tháng, `null` khi đóng sheet.
/// Mặc định không cho chọn tháng tương lai ([allowFuture] = false); màn nào
/// nhìn về phía trước (nâng bậc lương) bật [allowFuture] và [yearsForward].
Future<(int, int)?> showAppMonthPicker(
  BuildContext context, {
  required int year,
  required int month,
  String title = 'Chọn tháng',
  int yearsBack = 2,
  int yearsForward = 0,
  bool allowFuture = false,
}) {
  return showModalBottomSheet<(int, int)>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MonthPickerSheet(
      year: year,
      month: month,
      title: title,
      yearsBack: yearsBack,
      yearsForward: yearsForward,
      allowFuture: allowFuture,
    ),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.year,
    required this.month,
    required this.title,
    required this.yearsBack,
    required this.yearsForward,
    required this.allowFuture,
  });

  final int year;
  final int month;
  final String title;
  final int yearsBack;
  final int yearsForward;
  final bool allowFuture;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.year;
  final DateTime _now = DateTime.now();

  bool _isFuture(int year, int month) =>
      year > _now.year || (year == _now.year && month > _now.month);

  List<int> _years() {
    var first = _now.year - widget.yearsBack;
    var last = _now.year + widget.yearsForward;
    // Luôn chứa năm đang xem để chip năm hiện tại không biến mất.
    if (widget.year < first) first = widget.year;
    if (widget.year > last) last = widget.year;
    return [for (var y = first; y <= last; y++) y];
  }

  void _pick(int year, int month) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, (year, month));
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final years = _years();
    if (!years.contains(_year)) _year = widget.year;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final viewingCurrent =
        widget.year == _now.year && widget.month == _now.month;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brSheetTop,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.brPill,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // ── Đầu sheet ─────────────────────────────────────────────────
          Row(
            children: [
              const TintedIconTile(
                icon: Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 38,
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
                        letterSpacing: -0.3,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đang xem tháng ${_two(widget.month)}/${widget.year}',
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Năm: rãnh lõm + ô trắng nổi ───────────────────────────────
          _YearTrack(
            years: years,
            selected: _year,
            onSelect: (y) {
              HapticFeedback.selectionClick();
              setState(() => _year = y);
            },
          ),
          const SizedBox(height: 14),
          // ── Lưới 12 tháng ─────────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.75,
            children: [
              for (var m = 1; m <= 12; m++)
                _MonthCell(
                  label: 'Tháng $m',
                  selected: _year == widget.year && m == widget.month,
                  current: _year == _now.year && m == _now.month,
                  disabled: !widget.allowFuture && _isFuture(_year, m),
                  onTap: () => _pick(_year, m),
                ),
            ],
          ),
          if (!viewingCurrent) ...[
            const SizedBox(height: 14),
            _CurrentMonthButton(
              label: 'Về tháng hiện tại · ${_two(_now.month)}/${_now.year}',
              onTap: () => _pick(_now.year, _now.month),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hàng năm: rãnh lõm nhạt, năm đang chọn là ô trắng nổi chữ teal.
class _YearTrack extends StatelessWidget {
  const _YearTrack({
    required this.years,
    required this.selected,
    required this.onSelect,
  });

  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(int y) => _YearItem(
      label: '$y',
      selected: y == selected,
      onTap: () => onSelect(y),
    );

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.7),
        borderRadius: AppRadius.brMd,
      ),
      // Nhiều năm thì cho cuộn ngang; ít năm thì chia đều bề ngang.
      child: years.length <= 4
          ? Row(children: [for (final y in years) Expanded(child: item(y))])
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: years.length,
              itemBuilder: (_, i) => SizedBox(width: 84, child: item(years[i])),
            ),
    );
  }
}

class _YearItem extends StatelessWidget {
  const _YearItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Năm $label',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md - 3),
            boxShadow: selected ? AppShadows.soft : null,
          ),
          child: Text(
            label,
            style: AppTypography.metric(
              fontSize: 14,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô tháng: chọn = gradient brand nổi; tháng hiện tại = viền teal + chấm;
/// tháng tương lai bị khoá = mờ.
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.onTap,
    this.current = false,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool current;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? Colors.white
        : disabled
        ? AppColors.textTertiary.withValues(alpha: 0.55)
        : AppColors.textPrimary;
    final BoxBorder border = selected
        ? Border.all(color: Colors.transparent)
        : Border.all(
            color: current
                ? AppColors.primary.withValues(alpha: 0.45)
                : disabled
                ? AppColors.borderSoft.withValues(alpha: 0.5)
                : AppColors.borderSoft,
            width: current ? 1.4 : 1,
          );

    return Semantics(
      button: !disabled,
      selected: selected,
      label: current ? '$label, tháng hiện tại' : label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: AppRadius.brMd,
          child: Ink(
            decoration: BoxDecoration(
              gradient: selected ? AppGradients.brand : null,
              color: selected
                  ? null
                  : disabled
                  ? AppColors.surfaceAlt.withValues(alpha: 0.6)
                  : AppColors.surfaceAlt,
              borderRadius: AppRadius.brMd,
              border: border,
              boxShadow: selected ? AppShadows.tinted(AppColors.primary) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: AppTypography.uppercaseHeight,
                    color: foreground,
                  ),
                ),
                if (current)
                  Positioned(
                    bottom: 6,
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
                if (disabled)
                  Positioned(
                    top: 5,
                    right: 6,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 10,
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
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

/// Nút về nhanh tháng hiện tại ở đáy sheet.
class _CurrentMonthButton extends StatelessWidget {
  const _CurrentMonthButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        color: AppColors.primary.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.today_rounded,
                  size: 17,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTypography.style(
                    fontSize: 13,
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
