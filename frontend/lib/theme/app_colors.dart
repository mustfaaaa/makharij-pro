import 'package:flutter/material.dart';

/// Central colour palette — gold/cream Islamic-modern theme.
abstract class AppColors {
  // ── Brand: Muted Gold ─────────────────────────────────────────────────────
  static const Color primary        = Color(0xFFC2A366); // main gold
  static const Color primaryDark    = Color(0xFFB08F4F); // deeper gold
  static const Color primaryLight   = Color(0xFFD4B87A); // lighter gold
  static const Color primarySurface = Color(0xFFF7EDD6); // very light gold wash

  static const Color accent        = Color(0xFFC9A227); // warm amber accent
  static const Color accentLight   = Color(0xFFE8D48A);
  static const Color accentSurface = Color(0xFFF7EFD6);

  // ── Neutrals: warm cream/parchment ────────────────────────────────────────
  static const Color background  = Color(0xFFFBF8F3); // warm cream base
  static const Color cream       = Color(0xFFF5F0E8); // deeper cream
  static const Color creamDark   = Color(0xFFEDE5D5);
  static const Color surface     = Color(0xFFFFFFFF); // white card
  static const Color surfaceAlt  = Color(0xFFF7F3EC);
  static const Color border      = Color(0xFFEDE8DE);
  static const Color divider     = Color(0xFFEDE8DE);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF2D2A26);
  static const Color textSecondary = Color(0xFF8A8378);
  static const Color textMuted     = Color(0xFFADA89F);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent  = Color(0xFF2D2A26);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF00875A);
  static const Color successLight = Color(0xFFE6F4EF);
  static const Color warning      = Color(0xFFCE8A1B);
  static const Color error        = Color(0xFFD9383A);
  static const Color errorLight   = Color(0xFFFCEAEA);
  static const Color info         = Color(0xFF3B7DBF);

  // ── Tajweed highlight ─────────────────────────────────────────────────────
  static const Color errorHighlight   = Color(0xFFD9383A);
  static const Color errorHighlightBg = Color(0xFFFCEAEA);

  // ── Score bands ───────────────────────────────────────────────────────────
  static const Color scoreExcellent = Color(0xFF00875A);
  static const Color scoreGood      = Color(0xFF7CA83B);
  static const Color scoreAverage   = Color(0xFFCE8A1B);
  static const Color scorePoor      = Color(0xFFD9383A);

  // ── Dark (stub) ───────────────────────────────────────────────────────────
  static const Color darkBackground  = Color(0xFF1A1610);
  static const Color darkSurface     = Color(0xFF252018);
  static const Color darkTextPrimary = Color(0xFFEDEBE5);

  // ── Shadow ───────────────────────────────────────────────────────────────
  static const Color cardShadow = Color(0x08000000);
}
