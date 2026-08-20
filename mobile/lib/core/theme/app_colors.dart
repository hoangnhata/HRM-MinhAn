import 'package:flutter/material.dart';

/// Bảng màu dùng chung với web (`frontend/src/theme.ts`).
///
/// Các màu `*Light`/`*Dark` là màu semantic chính thức từ web. Những màu có
/// alpha bên dưới mô phỏng trực tiếp `alpha(...)` trong MUI để trạng thái hover,
/// selected, focus và disabled có cùng độ tương phản trên cả hai nền tảng.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF087A75);
  static const Color primaryLight = Color(0xFF4BA9A2);
  static const Color primaryDark = Color(0xFF045B57);
  static const Color primaryContrast = Color(0xFFFFFFFF);

  /// Điểm cuối gradient AppBar của web.
  static const Color appBarMid = Color(0xFF10918A);

  /// Điểm cuối gradient ở màn hình đăng nhập của web.
  static const Color brandGradientEnd = Color(0xFF0A7A76);

  /// Container được pha từ primary 10.5% trên nền trắng (MUI selected state).
  static const Color primaryContainer = Color(0xFFE5F1F1);

  static const Color secondary = Color(0xFFB98716);
  static const Color secondaryLight = Color(0xFFE6C76E);
  static const Color secondaryDark = Color(0xFF89630D);
  static const Color secondaryContrast = Color(0xFF251B05);
  static const Color secondaryContainer = Color(0xFFF8F2E8);

  static const Color error = Color(0xFFC33B4A);
  static const Color errorLight = Color(0xFFFDEBED);
  static const Color errorDark = Color(0xFF952D39);
  static const Color errorText = Color(0xFF8C2A36);

  static const Color success = Color(0xFF17835F);
  static const Color successLight = Color(0xFFE4F7EF);
  static const Color successDark = Color(0xFF0F6247);

  static const Color warning = Color(0xFFB96B00);
  static const Color warningLight = Color(0xFFFFF3DE);
  static const Color warningDark = Color(0xFF8D5100);
  static const Color warningText = Color(0xFF744200);

  static const Color info = Color(0xFF2574C8);
  static const Color infoLight = Color(0xFFE8F2FF);
  static const Color infoDark = Color(0xFF15549A);

  static const Color background = Color(0xFFEEF4F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7FBFA);
  static const Color surfaceMuted = Color(0xFFEEF4F3);
  static const Color surfaceHigh = Color(0xFFE4EEEC);
  static const Color surfaceHighest = Color(0xFFD9E6E4);

  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF5C697C);

  /// Màu chữ phụ cấp ba, dùng cho hint/icon không mang thông tin chính.
  static const Color textTertiary = Color(0xFF8792A4);

  /// `alpha(#172033, 0.09)` — divider/card border mặc định trên web.
  static const Color divider = Color(0x17172033);
  static const Color borderSoft = Color(0x17172033);

  /// `alpha(#172033, 0.16)` — outlined button và control border.
  static const Color border = Color(0x29172033);

  /// `alpha(#172033, 0.15)` — viền input mặc định.
  static const Color inputBorder = Color(0x26172033);

  static const Color outline = Color(0x735C697C);
  static const Color tooltip = Color(0xFF263244);

  static const Color actionHover = Color(0x0E087A75);
  static const Color actionSelected = Color(0x1B087A75);
  static const Color actionFocus = Color(0x26087A75);
  static const Color actionDisabled = Color(0x47172033);
  static const Color actionDisabledBackground = Color(0x14172033);

  static const Color driveBrandBg = Color(0xFFF1F7F6);

  static const List<Color> appBarGradient = [primaryDark, primary, appBarMid];

  static const List<Color> chartPalette = [
    Color(0xFF0F766E),
    Color(0xFF0369A1),
    Color(0xFF7C3AED),
    Color(0xFFBE185D),
    Color(0xFFB45309),
    secondary,
    info,
  ];

  static Color statusColor(String key) {
    switch (key.trim().toLowerCase()) {
      case 'success':
      case 'approved':
      case 'active':
      case 'working':
        return success;
      case 'error':
      case 'rejected':
      case 'cancelled':
        return error;
      case 'warning':
      case 'pending':
      case 'probation':
        return warning;
      case 'info':
      case 'intern':
        return info;
      default:
        return textSecondary;
    }
  }
}
