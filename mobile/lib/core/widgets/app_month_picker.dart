import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

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

  @override
  Widget build(BuildContext context) {
    final years = _years();
    if (!years.contains(_year)) _year = widget.year;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brSheetTop,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.brPill,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            style: AppTypography.style(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          // Nhiều năm thì cho cuộn ngang; ít năm thì chia đều bề ngang.
          if (years.length <= 4)
            Row(
              children: [
                for (final y in years) ...[
                  if (y != years.first) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: _MonthPickChip(
                        label: '$y',
                        selected: y == _year,
                        onTap: () => setState(() => _year = y),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(
                  width: 84,
                  child: _MonthPickChip(
                    label: '${years[i]}',
                    selected: years[i] == _year,
                    onTap: () => setState(() => _year = years[i]),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              for (var m = 1; m <= 12; m++)
                _MonthPickChip(
                  label: 'Tháng $m',
                  selected: _year == widget.year && m == widget.month,
                  current: _year == _now.year && m == _now.month,
                  disabled: !widget.allowFuture && _isFuture(_year, m),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, (_year, m));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthPickChip extends StatelessWidget {
  const _MonthPickChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.current = false,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Tháng hiện tại — viền mảnh để nhận ra khi chưa được chọn.
  final bool current;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (selected) {
      background = AppColors.primary;
      foreground = Colors.white;
    } else if (disabled) {
      background = AppColors.surfaceMuted.withValues(alpha: 0.55);
      foreground = AppColors.textTertiary.withValues(alpha: 0.6);
    } else {
      background = AppColors.surfaceMuted;
      foreground = AppColors.textPrimary;
    }

    return Semantics(
      button: !disabled,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: AppRadius.brMd,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: current && !selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
