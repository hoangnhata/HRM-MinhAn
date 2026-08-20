/// Cac ham kiem tra dau vao don gian cho form — thong bao tieng Viet.
class Validators {
  Validators._();

  static String? required(String? value, {String label = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) return '$label không được để trống';
    return null;
  }

  static String? minLength(String? value, int length, {String label = 'Giá trị'}) {
    if (value == null || value.length < length) {
      return '$label phải có ít nhất $length ký tự';
    }
    return null;
  }

  /// Cho phép để trống; chỉ báo lỗi khi có nhập mà sai định dạng.
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(text);
    return ok ? null : 'Email không đúng định dạng';
  }

  /// Số điện thoại Việt Nam: 9–11 chữ số, cho phép khoảng trắng và dấu chấm.
  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[\s.\-()]'), '');
    final ok = RegExp(r'^\+?\d{9,11}$').hasMatch(digits);
    return ok ? null : 'Số điện thoại không hợp lệ';
  }

  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (value) {
      for (final v in validators) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
