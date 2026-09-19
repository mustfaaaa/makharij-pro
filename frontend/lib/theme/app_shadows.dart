import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation tiers. The app is flat by default -- things sit on parchment and
/// are separated by space and hairlines -- so these are for the few things
/// that genuinely float: the practice dock, the mini-player, a raised hero
/// block overlapping a photograph.
///
/// All of them resolve through [AppColors.cardShadow], which is transparent
/// in dark mode: there, elevation is a lighter surface, never a shadow.
abstract class AppShadows {
  /// Barely lifted: a chip or row that must separate from a photo.
  static List<BoxShadow> get sm => [
        BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 1)),
      ];

  /// A block resting on the page.
  static List<BoxShadow> get md => [
        BoxShadow(color: AppColors.cardShadow, blurRadius: 18, offset: const Offset(0, 6)),
      ];

  /// Floating chrome: the dock, the mini-player, a block overlapping a hero.
  static List<BoxShadow> get lg => [
        BoxShadow(color: AppColors.cardShadow, blurRadius: 28, offset: const Offset(0, 10)),
        BoxShadow(color: AppColors.cardShadow, blurRadius: 4, offset: const Offset(0, 1)),
      ];

  /// A soft green halo under the record button, so it reads as the one live
  /// control on the page. Nothing in dark mode.
  static List<BoxShadow> get brandGlow => [
        BoxShadow(
          color: AppColors.brightness == Brightness.dark
              ? const Color(0x00000000)
              : AppColors.primary.withValues(alpha: 0.28),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];
}
