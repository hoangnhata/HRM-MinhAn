import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Thang bán kính ánh xạ từ component theme của web.
///
/// Các tên cũ (`xs`…`xl`, `brXs`…`brXl`) được giữ nguyên để mọi màn hình hiện
/// tại tiếp tục biên dịch. Token theo ngữ nghĩa giúp component mới không phải
/// tự chọn radius và tránh lỗi nhân radius như khi dùng số trong MUI `sx`.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double pill = 999;

  static const double chipSmall = 7;
  static const double chip = 8;
  static const double control = 10;
  static const double base = 12;
  static const double paper = 14;
  static const double card = 16;
  static const double dialog = 18;
  static const double bottomSheet = 22;
  static const double snackbar = 12;

  static BorderRadius get brXs => BorderRadius.circular(xs);
  static BorderRadius get brSm => BorderRadius.circular(sm);
  static BorderRadius get brMd => BorderRadius.circular(md);
  static BorderRadius get brLg => BorderRadius.circular(lg);
  static BorderRadius get brXl => BorderRadius.circular(xl);
  static BorderRadius get brPill => BorderRadius.circular(pill);

  static BorderRadius get brChipSmall => BorderRadius.circular(chipSmall);
  static BorderRadius get brChip => BorderRadius.circular(chip);
  static BorderRadius get brControl => BorderRadius.circular(control);
  static BorderRadius get brBase => BorderRadius.circular(base);
  static BorderRadius get brPaper => BorderRadius.circular(paper);
  static BorderRadius get brCard => BorderRadius.circular(card);
  static BorderRadius get brDialog => BorderRadius.circular(dialog);
  static BorderRadius get brBottomSheet => BorderRadius.circular(bottomSheet);
  static BorderRadius get brSnackbar => BorderRadius.circular(snackbar);
}

/// Thang khoảng cách 4pt, với nhịp chính 8pt giống `theme.spacing = 8` của web.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Gutter chuẩn cho màn hình điện thoại.
  static const double page = 16;
  static const double pageWide = 24;

  /// Kích thước chạm tối thiểu theo Material/WCAG cho control tương tác.
  static const double minTouchTarget = 48;
  static const double compactTouchTarget = 44;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: page);
}

/// Elevation mô phỏng các box-shadow chính trong `frontend/src/theme.ts`.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.04),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.03),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.035),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get lifted => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.13),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get overlay => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.16),
      blurRadius: 56,
      offset: const Offset(0, 24),
    ),
  ];

  static List<BoxShadow> get nav => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  static List<BoxShadow> get appBar => [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.15),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get button => [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.16),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.20),
      blurRadius: 16,
      offset: const Offset(0, 7),
    ),
  ];

  static List<BoxShadow> tinted(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.18),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
}

class AppGradients {
  AppGradients._();

  /// Khớp panel gradient web: dark → main → #0a7a76.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primaryDark,
      AppColors.primary,
      AppColors.brandGradientEnd,
    ],
    stops: [0.0, 0.42, 1.0],
  );

  /// Khớp AppBar web: dark → main (58%) → #10918A.
  static const LinearGradient appBar = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primaryDark, AppColors.primary, AppColors.appBarMid],
    stops: [0.0, 0.58, 1.0],
  );

  static const LinearGradient brandSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryLight],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.secondaryDark, AppColors.secondaryLight],
  );

  static LinearGradient tint(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
  );
}
