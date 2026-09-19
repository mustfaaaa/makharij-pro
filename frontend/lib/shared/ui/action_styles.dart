import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Pill-shaped actions used where a word is reviewed: listening, retrying,
/// disagreeing. One shape and height for all of them, so the row reads as a
/// set rather than four unrelated links.
abstract class ActionStyles {
  static ButtonStyle pill({required Color background, required Color foreground}) => TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground.withValues(alpha: 0.7),
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Figtree', fontSize: 14, fontWeight: FontWeight.w600),
      );

  /// Listening: tonal, on the emerald wash.
  static ButtonStyle get listen =>
      pill(background: AppColors.primarySurface, foreground: AppColors.onPrimarySurface);

  /// A quiet action with no fill.
  static ButtonStyle get quiet => TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Figtree', fontSize: 14, fontWeight: FontWeight.w600),
      );
}
