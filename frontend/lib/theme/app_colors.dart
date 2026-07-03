import 'package:flutter/material.dart';

/// Central, brightness-aware palette. Widgets reference `AppColors.x`
/// directly; switching [brightness] (driven by the theme toggle) makes every
/// reference resolve to its light or dark value on the next rebuild — that's
/// what makes dark mode actually take effect across the app.
///
/// Because these are getters (not `const`), they can't be used inside `const`
/// expressions — that's intentional so colours can change at runtime.
abstract class AppColors {
  static Brightness brightness = Brightness.light;
  static bool get _d => brightness == Brightness.dark;

  // Brand — green
  static Color get primary => _d ? const Color(0xFF52BE8E) : const Color(0xFF1F6E4E);
  static Color get primaryDark => _d ? const Color(0xFF2E8B62) : const Color(0xFF15503A);
  static Color get primaryLight => _d ? const Color(0xFF6FCBA1) : const Color(0xFF3E9370);
  static Color get primarySurface => _d ? const Color(0xFF16261E) : const Color(0xFFE6F0EA);

  // Accent — gold
  static Color get accent => _d ? const Color(0xFFD9B84A) : const Color(0xFFC9A227);
  static Color get accentLight => _d ? const Color(0xFFE8D48A) : const Color(0xFFE8D48A);
  static Color get accentSurface => _d ? const Color(0xFF2A2416) : const Color(0xFFF7EFD6);

  // Neutrals — warm cream (light) / warm charcoal (dark)
  static Color get background => _d ? const Color(0xFF15120C) : const Color(0xFFF6EFE1);
  static Color get cream => _d ? const Color(0xFF1B1710) : const Color(0xFFF1E7D3);
  static Color get creamDark => _d ? const Color(0xFF120F0A) : const Color(0xFFE8DBC2);
  static Color get surface => _d ? const Color(0xFF211C14) : const Color(0xFFFFFDF8);
  static Color get surfaceAlt => _d ? const Color(0xFF2A2418) : const Color(0xFFF0E9DA);
  static Color get border => _d ? const Color(0xFF3A3325) : const Color(0xFFE3D9C4);
  static Color get divider => _d ? const Color(0xFF2E2819) : const Color(0xFFEBE2D1);

  // Text
  static Color get textPrimary => _d ? const Color(0xFFF2ECDD) : const Color(0xFF1C2321);
  static Color get textSecondary => _d ? const Color(0xFFBBB4A2) : const Color(0xFF5B6360);
  static Color get textMuted => _d ? const Color(0xFF8C8573) : const Color(0xFF8A9088);
  static Color get textOnPrimary => const Color(0xFFFFFFFF);
  static Color get textOnAccent => _d ? const Color(0xFF1C2321) : const Color(0xFF1C2321);

  // Semantic (consistent across modes)
  static Color get success => const Color(0xFF2E9B5C);
  static Color get warning => const Color(0xFFCE8A1B);
  static Color get error => const Color(0xFFC24444);
  static Color get info => const Color(0xFF3B7DBF);

  // Tajweed error highlight
  static Color get errorHighlight => const Color(0xFFE86A6A);
  static Color get errorHighlightBg => _d ? const Color(0xFF3A2020) : const Color(0xFFFBE7E7);

  // Score bands
  static Color get scoreExcellent => const Color(0xFF2E9B5C);
  static Color get scoreGood => const Color(0xFF7CA83B);
  static Color get scoreAverage => const Color(0xFFCE8A1B);
  static Color get scorePoor => const Color(0xFFC24444);
}
