import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Theme tổng thể đồng bộ với web: teal + vàng, bề mặt sáng và chữ Inter.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryContrast,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryContrast,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.secondaryContrast,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.infoLight,
      onTertiaryContainer: AppColors.infoDark,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorLight,
      onErrorContainer: AppColors.errorDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceDim: AppColors.surfaceHighest,
      surfaceBright: AppColors.surface,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surfaceAlt,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHighest,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.outline,
      outlineVariant: AppColors.divider,
      shadow: AppColors.textPrimary,
      scrim: AppColors.textPrimary,
      inverseSurface: AppColors.tooltip,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.primaryLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.style().fontFamily,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = AppTypography.textTheme(base.textTheme);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.brControl,
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      primaryIconTheme: const IconThemeData(color: Colors.white, size: 22),
      dividerColor: AppColors.divider,
      disabledColor: AppColors.actionDisabled,
      focusColor: AppColors.actionFocus,
      hoverColor: AppColors.actionHover,
      highlightColor: AppColors.actionSelected,
      splashColor: AppColors.actionHover,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.12),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.20),
        selectionHandleColor: AppColors.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        scrolledUnderElevation: 0,
        shadowColor: AppColors.primaryDark.withValues(alpha: 0.15),
        centerTitle: false,
        toolbarHeight: 56,
        titleSpacing: AppSpacing.page,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTypography.style(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.34,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brCard,
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceAlt,
        disabledColor: AppColors.actionDisabledBackground,
        selectedColor: AppColors.actionSelected,
        secondarySelectedColor: AppColors.actionSelected,
        checkmarkColor: AppColors.primary,
        deleteIconColor: AppColors.textSecondary,
        labelStyle: AppTypography.style(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.06,
        ),
        secondaryLabelStyle: AppTypography.style(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brChip),
        side: const BorderSide(color: AppColors.divider),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hoverColor: AppColors.actionHover,
        focusColor: AppColors.actionFocus,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        border: inputBorder(AppColors.inputBorder),
        enabledBorder: inputBorder(AppColors.inputBorder),
        focusedBorder: inputBorder(AppColors.primary, 2),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 2),
        disabledBorder: inputBorder(AppColors.borderSoft),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        labelStyle: AppTypography.style(
          fontSize: 14,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: AppTypography.style(
          fontSize: 14,
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: AppTypography.style(
          fontSize: 14,
          color: AppColors.textTertiary,
        ),
        helperStyle: AppTypography.caption(color: AppColors.textTertiary),
        errorStyle: AppTypography.style(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.error,
          height: 1.45,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.minTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brControl),
              tapTargetSize: MaterialTapTargetSize.padded,
              animationDuration: AppDurations.fast,
              textStyle: AppTypography.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.17,
                height: 1.35,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.actionDisabledBackground;
                }
                if (states.contains(WidgetState.pressed)) {
                  return AppColors.primaryDark;
                }
                return AppColors.primary;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.disabled)
                    ? AppColors.actionDisabled
                    : Colors.white;
              }),
              overlayColor: WidgetStatePropertyAll(
                Colors.white.withValues(alpha: 0.10),
              ),
              shadowColor: WidgetStatePropertyAll(
                AppColors.primaryDark.withValues(alpha: 0.24),
              ),
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled) ||
                    states.contains(WidgetState.pressed)) {
                  return 0;
                }
                if (states.contains(WidgetState.hovered)) return 3;
                return 2;
              }),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.actionDisabledBackground,
              disabledForegroundColor: AppColors.actionDisabled,
              minimumSize: const Size(0, AppSpacing.minTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brControl),
              tapTargetSize: MaterialTapTargetSize.padded,
              animationDuration: AppDurations.fast,
              elevation: 2,
              shadowColor: AppColors.primaryDark.withValues(alpha: 0.24),
              textStyle: AppTypography.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.17,
                height: 1.35,
              ),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                Colors.white.withValues(alpha: 0.10),
              ),
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled) ||
                    states.contains(WidgetState.pressed)) {
                  return 0;
                }
                if (states.contains(WidgetState.hovered)) return 3;
                return 2;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.minTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brControl),
              tapTargetSize: MaterialTapTargetSize.padded,
              animationDuration: AppDurations.fast,
              textStyle: AppTypography.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.17,
                height: 1.35,
              ),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.disabled)
                    ? AppColors.actionDisabled
                    : AppColors.primary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered)) {
                  return AppColors.actionHover;
                }
                return Colors.transparent;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                return BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? AppColors.borderSoft
                      : AppColors.border,
                );
              }),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.actionDisabled,
              minimumSize: const Size(0, AppSpacing.minTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brControl),
              tapTargetSize: MaterialTapTargetSize.padded,
              animationDuration: AppDurations.fast,
              textStyle: AppTypography.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.17,
                height: 1.35,
              ),
            ).copyWith(
              overlayColor: const WidgetStatePropertyAll(AppColors.actionHover),
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          disabledForegroundColor: AppColors.actionDisabled,
          minimumSize: const Size.square(AppSpacing.minTouchTarget),
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brControl),
          highlightColor: AppColors.actionSelected,
          hoverColor: AppColors.actionHover,
          focusColor: AppColors.actionFocus,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 1,
        splashColor: Colors.white.withValues(alpha: 0.10),
        extendedTextStyle: AppTypography.style(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brCard),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        minLeadingWidth: 40,
        horizontalTitleGap: 12,
        titleTextStyle: AppTypography.style(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.14,
        ),
        subtitleTextStyle: AppTypography.style(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.55,
          letterSpacing: -0.08,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brControl),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.10),
        height: 68,
        indicatorColor: AppColors.actionSelected,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: AppRadius.brControl,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.style(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 2,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.16),
        barrierColor: AppColors.textPrimary.withValues(alpha: 0.42),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        clipBehavior: Clip.antiAlias,
        // Tránh chỉ maxWidth — dễ gây ConstrainedBox size MISSING khi hit-test.
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brDialog,
          side: const BorderSide(color: AppColors.borderSoft),
        ),
        iconColor: AppColors.primary,
        titleTextStyle: AppTypography.style(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.36,
          height: 1.35,
        ),
        contentTextStyle: AppTypography.body(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        modalElevation: 24,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.16),
        modalBarrierColor: AppColors.textPrimary.withValues(alpha: 0.42),
        showDragHandle: true,
        dragHandleColor: AppColors.textTertiary,
        dragHandleSize: const Size(36, 4),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 640),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 12,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSnackbar),
        backgroundColor: AppColors.tooltip,
        actionTextColor: AppColors.secondaryLight,
        disabledActionTextColor: AppColors.actionDisabled,
        showCloseIcon: true,
        closeIconColor: Colors.white,
        actionOverflowThreshold: 0.45,
        dismissDirection: DismissDirection.down,
        contentTextStyle: AppTypography.style(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.actionSelected,
        linearMinHeight: 7,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: AppColors.surface,
        borderRadius: AppRadius.brPill,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.divider,
        dividerHeight: 1,
        overlayColor: const WidgetStatePropertyAll(AppColors.actionHover),
        labelStyle: AppTypography.style(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.14,
        ),
        unselectedLabelStyle: AppTypography.style(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.textTertiary
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.actionDisabledBackground
              : states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textTertiary.withValues(alpha: 0.45),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : AppColors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brXs),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.actionDisabledBackground;
          }
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.actionDisabled;
          }
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondary;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.13),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brBase,
          side: const BorderSide(color: AppColors.divider),
        ),
        textStyle: AppTypography.style(
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.tooltip,
          borderRadius: AppRadius.brChip,
          boxShadow: AppShadows.lifted,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.all(8),
        verticalOffset: 16,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 3),
        textStyle: AppTypography.style(
          color: Colors.white,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.065),
        ),
        headingTextStyle: AppTypography.style(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary.withValues(alpha: 0.76),
        ),
        dataTextStyle: AppTypography.style(
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.55,
        ),
        dividerThickness: 1,
        headingRowHeight: 48,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        horizontalMargin: 16,
        columnSpacing: 20,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.secondary,
        textColor: AppColors.secondaryContrast,
        textStyle: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryContrast,
          height: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
        dividerColor: AppColors.borderSoft,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textTertiary.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.primary),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.primary.withValues(alpha: 0.1);
        }),
        todayBorder: const BorderSide(color: AppColors.primary),
        rangeSelectionBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brDialog),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        hourMinuteColor: AppColors.primary.withValues(alpha: 0.1),
        hourMinuteTextColor: AppColors.primaryDark,
        dialHandColor: AppColors.primary,
        dialBackgroundColor: AppColors.surfaceMuted,
        dialTextColor: AppColors.textPrimary,
        entryModeIconColor: AppColors.primary,
        dayPeriodColor: AppColors.primary.withValues(alpha: 0.12),
        dayPeriodTextColor: AppColors.primaryDark,
        helpTextStyle: AppTypography.style(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
