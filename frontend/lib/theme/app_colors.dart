import 'package:flutter/material.dart';

/// Central color palette. Calm, minimal, Islamic-modern: green primary,
/// gold accent, off-white surfaces.
abstract class AppColors {
  // Brand
  static const Color primary = Color(0xFF1F6E4E);
  static const Color primaryDark = Color(0xFF15503A);
  static const Color primaryLight = Color(0xFF3E9370);
  static const Color primarySurface = Color(0xFFE6F0EA);

  static const Color accent = Color(0xFFC9A227);
  static const Color accentLight = Color(0xFFE8D48A);
  static const Color accentSurface = Color(0xFFF7EFD6);

  // Neutrals — warm cream / beige palette
  static const Color background = Color(0xFFF6EFE1); // warm cream base
  static const Color cream = Color(0xFFF1E7D3); // deeper beige for immersive/full screens
  static const Color creamDark = Color(0xFFE8DBC2); // beige used behind cream for depth
  static const Color surface = Color(0xFFFFFDF8); // near-white card, warmed slightly
  static const Color surfaceAlt = Color(0xFFF0E9DA);
  static const Color border = Color(0xFFE3D9C4);
  static const Color divider = Color(0xFFEBE2D1);

  // Text
  static const Color textPrimary = Color(0xFF1C2321);
  static const Color textSecondary = Color(0xFF5B6360);
  static const Color textMuted = Color(0xFF8A9088);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF1C2321);

  // Semantic
  static const Color success = Color(0xFF2E9B5C);
  static const Color warning = Color(0xFFCE8A1B);
  static const Color error = Color(0xFFC24444);
  static const Color info = Color(0xFF3B7DBF);

  // Tajweed error highlight (used to mark mispronounced words)
  static const Color errorHighlight = Color(0xFFE86A6A);
  static const Color errorHighlightBg = Color(0xFFFBE7E7);

  // Score bands
  static const Color scoreExcellent = Color(0xFF2E9B5C);
  static const Color scoreGood = Color(0xFF7CA83B);
  static const Color scoreAverage = Color(0xFFCE8A1B);
  static const Color scorePoor = Color(0xFFC24444);

  // Dark theme (minimal, refined later)
  static const Color darkBackground = Color(0xFF11150F);
  static const Color darkSurface = Color(0xFF1A1F17);
  static const Color darkTextPrimary = Color(0xFFEDEEE9);
}
