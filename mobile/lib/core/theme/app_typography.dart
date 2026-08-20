import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography Inter dùng xuyên suốt web và mobile.
///
/// Scale giữ nhịp chữ cô đọng của web nhưng tăng vùng đọc/tương tác phù hợp
/// điện thoại. Inter hỗ trợ đầy đủ tiếng Việt; số KPI dùng tabular figures để
/// không bị xê dịch khi dữ liệu thay đổi.
class AppTypography {
  AppTypography._();

  static const List<FontFeature> _textFeatures = [
    FontFeature.enable('kern'),
    FontFeature.enable('cv02'),
    FontFeature.enable('cv03'),
    FontFeature.enable('cv04'),
    FontFeature.enable('cv11'),
  ];

  static const List<FontFeature> _numericFeatures = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
    FontFeature.enable('kern'),
  ];

  /// Style gốc — mọi TextStyle trong app nên đi qua đây để đồng bộ font.
  static TextStyle style({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    bool tabular = false,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? _numericFeatures : _textFeatures,
    );
  }

  /// Số liệu KPI / chart — tương đương `fontFeatureSettings: "tnum"` của web.
  static TextStyle metric({
    double fontSize = 24,
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final tracking = fontSize >= 28
        ? -0.6
        : fontSize >= 22
        ? -0.4
        : fontSize >= 16
        ? -0.25
        : -0.1;
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.1,
      letterSpacing: tracking,
      fontFeatures: _numericFeatures,
    );
  }

  /// Số phụ trong legend / hàng chi tiết — nhẹ, dễ quét.
  static TextStyle metricMuted({
    double fontSize = 12,
    Color color = AppColors.textSecondary,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.25,
      letterSpacing: -0.1,
      fontFeatures: _numericFeatures,
    );
  }

  /// Nhãn phụ dưới số / chú thích.
  static TextStyle caption({
    Color color = AppColors.textSecondary,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return style(
      fontSize: 12,
      fontWeight: fontWeight,
      color: color,
      height: 1.5,
      letterSpacing: 0.12,
    );
  }

  /// Tiêu đề section trên mobile.
  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) {
    return style(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.45,
      letterSpacing: -0.24,
    );
  }

  /// Tiêu đề trang / header lớn trên nền brand.
  static TextStyle pageTitle({Color color = AppColors.textPrimary}) {
    return style(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.2,
      letterSpacing: -0.84,
    );
  }

  /// Tiêu đề hàng danh sách / thẻ.
  static TextStyle listTitle({Color color = AppColors.textPrimary}) {
    return style(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.4,
      letterSpacing: -0.14,
    );
  }

  /// Mô tả phụ dưới tiêu đề hàng.
  static TextStyle listSubtitle({Color color = AppColors.textSecondary}) {
    return style(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.55,
      letterSpacing: -0.08,
    );
  }

  /// Body đọc thoải mái với dấu tiếng Việt.
  static TextStyle body({
    double fontSize = 15,
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.65,
      letterSpacing: -0.16,
    );
  }

  /// Nhãn uppercase nhỏ dùng cho overline/eyebrow giống PageHeader web.
  static TextStyle overline({Color color = AppColors.primaryDark}) {
    return style(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.5,
      letterSpacing: 0.88,
    );
  }

  static TextTheme textTheme(TextTheme base) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: style(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.12,
        color: AppColors.textPrimary,
        height: 1.15,
      ),
      displayMedium: style(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.84,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      displaySmall: style(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.65,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      headlineLarge: style(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.72,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      headlineMedium: style(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.55,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      headlineSmall: style(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      titleLarge: style(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.36,
        color: AppColors.textPrimary,
        height: 1.35,
      ),
      titleMedium: style(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.15,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      titleSmall: style(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.08,
        color: AppColors.textSecondary,
        height: 1.45,
      ),
      bodyLarge: style(
        fontSize: 15,
        height: 1.65,
        letterSpacing: -0.16,
        color: AppColors.textPrimary,
      ),
      bodyMedium: style(
        fontSize: 13,
        height: 1.55,
        letterSpacing: -0.08,
        color: AppColors.textPrimary,
      ),
      bodySmall: style(
        fontSize: 12,
        height: 1.5,
        letterSpacing: 0.12,
        color: AppColors.textSecondary,
      ),
      labelLarge: style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.17,
        height: 1.35,
      ),
      labelMedium: style(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: -0.08,
        height: 1.35,
      ),
      labelSmall: style(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: AppColors.textTertiary,
        height: 1.3,
      ),
    );
  }
}
