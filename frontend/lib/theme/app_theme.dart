import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract class AppTheme {
  /// Builds the theme for the current [AppColors.brightness]. The app root
  /// sets the brightness before calling this, so one builder serves both
  /// light and the dark "Tahajjud" mode.
  static ThemeData build() {
    final isDark = AppColors.brightness == Brightness.dark;
    final textTheme = AppTypography.uiTextTheme;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: AppColors.brightness,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: AppColors.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      dividerColor: AppColors.divider,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdRadius,
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.error)),
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
        side: BorderSide.none,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.lgRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceAlt : AppColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.textPrimary : AppColors.textOnPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smRadius),
      ),
      dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    );
  }
}
