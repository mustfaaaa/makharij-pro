import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The three elevation tiers the app is allowed to use.
///
/// Screens had drifted to nine different blur radii (8, 10, 12, 14, 16, 18,
/// 20, 22) declared inline, against a single `AppTheme.cardDecoration` that
/// only four call sites actually used. Cards on adjacent screens sat at
/// visibly different heights for no reason.
///
/// These are getters, not `const`, because [AppColors.cardShadow] resolves
/// per theme — a dark page needs a deeper shadow, since there is no border
/// contrast to lean on.
abstract class AppShadows {
  /// Chips, small pills, list rows — barely lifted.
  static List<BoxShadow> get sm => [
        BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
      ];

  /// The default card. Most surfaces in the app want this one.
  static List<BoxShadow> get md => [
        BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4)),
      ];

  /// Floating chrome that sits above the page: the frosted bottom nav, the
  /// raised Ask-AI circle, the recording pill.
  static List<BoxShadow> get lg => [
        BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: const Offset(0, 6)),
      ];

  /// A gold glow under an interactive brand element (the mic, the Ask-AI
  /// circle). Tinted rather than neutral, so it reads as the control's own
  /// light rather than as depth.
  static List<BoxShadow> get brandGlow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.40),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}
