import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract class AppTheme {
  /// Single source of truth for the app's ThemeData ("Illuminated Parchment",
  /// see DESIGN.md). Every component that ships with Material is themed here,
  /// so screens get the look without restyling widgets one by one.
  static ThemeData build() {
    final textTheme = AppTypography.uiTextTheme;
    final dark = AppColors.brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E4D3B),
      brightness: AppColors.brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.onPrimarySurface,
      secondary: AppColors.goldInk,
      onSecondary: AppColors.textOnAccent,
      secondaryContainer: AppColors.goldWash,
      onSecondaryContainer: AppColors.goldInk,
      tertiary: AppColors.emerald,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surfaceAlt,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.container,
      surfaceContainerHighest: AppColors.container,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: AppColors.textOnAccent,
      errorContainer: AppColors.errorLight,
      onErrorContainer: AppColors.error,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.textOnInverse,
      shadow: AppColors.cardShadow,
      surfaceTint: Colors.transparent,
    );

    final controlShape = RoundedRectangleBorder(borderRadius: AppRadii.mdRadius);
    const controlPadding = EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14);
    const controlSize = Size(64, 52);
    final label = textTheme.labelLarge;

    final filledStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(controlSize),
      padding: const WidgetStatePropertyAll(controlPadding),
      shape: WidgetStatePropertyAll(controlShape),
      textStyle: WidgetStatePropertyAll(label),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled)
          ? AppColors.container
          : AppColors.primary),
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled)
          ? AppColors.textMuted
          : AppColors.textOnPrimary),
      overlayColor: WidgetStatePropertyAll(AppColors.textOnPrimary.withValues(alpha: 0.10)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: AppColors.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      fontFamily: AppTypography.ui,
      dividerColor: AppColors.divider,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(color: AppColors.textSecondary, size: 22),
      // Platform transitions everywhere: the Cupertino route keeps the iOS
      // edge-swipe back gesture, and FadeForwards is Material's own motion.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.sm,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
        shape: Border(bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0))),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgRadius,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(controlSize),
          padding: const WidgetStatePropertyAll(controlPadding),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(label),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.disabled) ? AppColors.textMuted : AppColors.textPrimary),
          side: WidgetStateProperty.resolveWith((s) => BorderSide(
                color: s.contains(WidgetState.disabled) ? AppColors.border : AppColors.borderStrong,
              )),
          overlayColor: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.06)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(label),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.disabled) ? AppColors.textMuted : AppColors.primaryDark),
          overlayColor: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.08)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
          overlayColor: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 15),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.primaryDark),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.borderStrong)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.borderStrong)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: AppRadii.mdRadius, borderSide: BorderSide(color: AppColors.error, width: 2)),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySurface,
        disabledColor: AppColors.container,
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.onPrimarySurface),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
        side: BorderSide(color: AppColors.border),
        checkmarkColor: AppColors.onPrimarySurface,
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.primarySurface : AppColors.surface),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.onPrimarySurface : AppColors.textSecondary),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.textOnPrimary : AppColors.borderStrong),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.container),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.borderStrong),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.container,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        activeTickMarkColor: AppColors.textOnPrimary,
        inactiveTickMarkColor: AppColors.borderStrong,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.container,
        circularTrackColor: AppColors.container,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        dragHandleSize: const Size(36, 4),
        modalBarrierColor: AppColors.photoScrim.withValues(alpha: dark ? 0.6 : 0.36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
        barrierColor: AppColors.photoScrim.withValues(alpha: dark ? 0.6 : 0.36),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.xlRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textOnInverse),
        actionTextColor: dark ? AppColors.onPrimarySurface : const Color(0xFFBFE0CC),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: AppRadii.smRadius),
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.textOnInverse),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySurface,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 12,
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? AppColors.onPrimarySurface : AppColors.textSecondary);
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primary,
      ),
      dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    );
  }

  /// A block that rests on the page. Hairline plus the softest shadow in
  /// light mode; a hairline alone in dark mode, where the surface itself is
  /// lighter than the ground.
  static BoxDecoration cardDecoration({double radius = AppRadii.lg}) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.sm,
    );
  }
}
