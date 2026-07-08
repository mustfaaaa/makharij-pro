import 'package:flutter/material.dart';

/// Central, brightness-aware colour palette — gold/cream Islamic-modern
/// theme (light) with a warm "night parchment" dark variant. Widgets read
/// `AppColors.x` directly; flipping [brightness] (driven by the Settings
/// toggle) makes every reference resolve to its light or dark value on the
/// next rebuild — that's what makes dark mode actually take effect.
///
/// Because these are getters (not `const`), they can't be used inside
/// `const` expressions — that's intentional so colours can change at runtime.
abstract class AppColors {
  static Brightness brightness = Brightness.light;
  static bool get _d => brightness == Brightness.dark;

  // ── Brand: Muted Gold ─────────────────────────────────────────────────────
  static Color get primary => _d ? const Color(0xFFD9B876) : const Color(0xFFC2A366);
  static Color get primaryDark => _d ? const Color(0xFFC2A366) : const Color(0xFFB08F4F);
  static Color get primaryLight => _d ? const Color(0xFFE6CC94) : const Color(0xFFD4B87A);
  static Color get primarySurface => _d ? const Color(0xFF2E2818) : const Color(0xFFF7EDD6);

  static Color get accent => _d ? const Color(0xFFE0BD4A) : const Color(0xFFC9A227);
  static Color get accentLight => const Color(0xFFE8D48A);
  static Color get accentSurface => _d ? const Color(0xFF2E2818) : const Color(0xFFF7EFD6);

  // ── Neutrals: warm cream/parchment (light) / warm charcoal (dark) ─────────
  static Color get background => _d ? const Color(0xFF17130E) : const Color(0xFFFBF8F3);
  static Color get cream => _d ? const Color(0xFF1D1811) : const Color(0xFFF5F0E8);
  static Color get creamDark => _d ? const Color(0xFF120F0A) : const Color(0xFFEDE5D5);
  static Color get surface => _d ? const Color(0xFF221D15) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt => _d ? const Color(0xFF2A2419) : const Color(0xFFF7F3EC);
  static Color get border => _d ? const Color(0xFF3A331F) : const Color(0xFFEDE8DE);
  static Color get divider => _d ? const Color(0xFF352E1C) : const Color(0xFFEDE8DE);

  // ── Text ─────────────────────────────────────────────────────────────────
  static Color get textPrimary => _d ? const Color(0xFFF2ECDE) : const Color(0xFF2D2A26);
  static Color get textSecondary => _d ? const Color(0xFFBAB0A0) : const Color(0xFF8A8378);
  static Color get textMuted => _d ? const Color(0xFF8A8172) : const Color(0xFFADA89F);
  static Color get textOnPrimary => const Color(0xFFFFFFFF);
  static Color get textOnAccent => const Color(0xFF2D2A26);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static Color get success => _d ? const Color(0xFF3FAE7F) : const Color(0xFF00875A);
  static Color get successLight => _d ? const Color(0xFF1B2E24) : const Color(0xFFE6F4EF);
  static Color get warning => const Color(0xFFCE8A1B);
  static Color get error => _d ? const Color(0xFFE0605F) : const Color(0xFFD9383A);
  static Color get errorLight => _d ? const Color(0xFF2E1C1B) : const Color(0xFFFCEAEA);
  static Color get info => const Color(0xFF3B7DBF);

  // ── Tajweed highlight ─────────────────────────────────────────────────────
  static Color get errorHighlight => _d ? const Color(0xFFE0605F) : const Color(0xFFD9383A);
  static Color get errorHighlightBg => _d ? const Color(0xFF2E1C1B) : const Color(0xFFFCEAEA);

  // ── Score bands ───────────────────────────────────────────────────────────
  static Color get scoreExcellent => _d ? const Color(0xFF3FAE7F) : const Color(0xFF00875A);
  static Color get scoreGood => const Color(0xFF7CA83B);
  static Color get scoreAverage => const Color(0xFFCE8A1B);
  static Color get scorePoor => _d ? const Color(0xFFE0605F) : const Color(0xFFD9383A);

  // ── Dark (legacy stub names — kept for any remaining references) ─────────
  static Color get darkBackground => const Color(0xFF17130E);
  static Color get darkSurface => const Color(0xFF221D15);
  static Color get darkTextPrimary => const Color(0xFFF2ECDE);

  // ── Shadow ───────────────────────────────────────────────────────────────
  // Soft, still subtle — enough to lift cards off the cream background without
  // looking heavy. Dark mode leans on a deeper shadow since there's no border
  // contrast to rely on.
  static Color get cardShadow => _d ? const Color(0x40000000) : const Color(0x14100A00);

  // ── Liquid glass (frosted bars) ──────────────────────────────────────────
  static Color get glassSurface => _d ? const Color(0x992A2419) : const Color(0x99FFFFFF);
  static Color get glassBorder => _d ? const Color(0x1FFFFFFF) : const Color(0xB3FFFFFF);
}
