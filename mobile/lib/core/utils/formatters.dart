import 'package:intl/intl.dart';

/// Cac ham dinh dang chung — dong bo cach hien thi ngay/tien/so voi web
/// (dd/MM/yyyy, phan tram nghin bang dau cham, VND).
class AppFormat {
  AppFormat._();

  static final DateFormat _dateVi = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeVi = DateFormat('HH:mm dd/MM/yyyy');
  static final DateFormat _timeVi = DateFormat('HH:mm');
  static final DateFormat _monthVi = DateFormat('MM/yyyy');
  static final NumberFormat _currency = NumberFormat.decimalPattern('vi_VN');

  static String date(DateTime? d) => d == null ? '—' : _dateVi.format(d);

  static String dateTime(DateTime? d) =>
      d == null ? '—' : _dateTimeVi.format(d);

  static String time(DateTime? d) => d == null ? '—' : _timeVi.format(d);

  static String month(DateTime? d) => d == null ? '—' : _monthVi.format(d);

  static const List<String> _weekdaysVi = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// "Thứ Hai"
  static String weekday(DateTime d) => _weekdaysVi[d.weekday - 1];

  /// "Thứ Ba, 09/08/2026" — dùng ở header các trang chính.
  static String longDateVi(DateTime d) =>
      '${_weekdaysVi[d.weekday - 1]}, ${_dateVi.format(d)}';

  /// "Tháng 8/2026" — nhãn tháng dạng chữ.
  static String monthLabelVi(DateTime d) => 'Tháng ${d.month}/${d.year}';

  /// Số công/giờ: bỏ ".0" cho số nguyên, giữ 1 chữ số thập phân khi cần.
  static String compactNumber(num? value) {
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// Điểm chấm — giữ tối đa 2 chữ số thập phân, bỏ số 0 thừa (1,75 · 0,5 · 8).
  /// Không dùng [compactNumber] cho điểm: nó làm tròn 1 chữ số (1,75 → 1,8).
  static String score(num? value) {
    if (value == null) return '—';
    var s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  /// Công tháng — đồng bộ web `formatWorkUnits` (luôn 2 chữ số thập phân).
  static String workUnits(num? value, {bool suffix = false}) {
    if (value == null) return '—';
    final s = _normalizeWorkUnits(value.toDouble())
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    return suffix ? '$s công' : s;
  }

  /// Đồng bộ web `normalizeWorkUnits`: công gần bội số 1/3 được làm tròn về 1/3.
  static double _normalizeWorkUnits(double n) {
    if (!n.isFinite || n == 0) return 0;
    final thirds = (n * 3).round();
    if ((n * 3 - thirds).abs() < 0.05) return thirds / 3;
    return n;
  }

  /// Tiền tệ dạng gọn: 12,5 tr / 950 ng — dùng trong thẻ thống kê hẹp.
  static String currencyCompact(num? value) {
    if (value == null) return '—';
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} tỷ';
    }
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} tr';
    }
    if (abs >= 1000) {
      return '${(value / 1000).round()} nghìn';
    }
    return value.toString();
  }

  static String currency(num? value, {String suffix = ' đ'}) {
    if (value == null) return '—';
    return '${_currency.format(value)}$suffix';
  }

  static String number(num? value, {int decimals = 0}) {
    if (value == null) return '—';
    final fmt = NumberFormat.decimalPattern('vi_VN');
    fmt.maximumFractionDigits = decimals;
    return fmt.format(value);
  }

  /// Thâm niên / năm công tác — đồng bộ web `formatYears` (tối đa 2 chữ số thập phân).
  static String years(num? value) {
    if (value == null) return '—';
    var s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  static DateTime? tryParseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String relativeFromNow(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return date(d);
  }

  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
