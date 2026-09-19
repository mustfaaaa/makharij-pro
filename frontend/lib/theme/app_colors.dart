import 'package:flutter/material.dart';

/// Central, brightness-aware palette: "Illuminated Parchment" (see DESIGN.md
/// at the repository root, which is the design contract for these values).
///
/// Parchment and ivory are the ground, charcoal is the ink, deep green is the
/// brand and the primary action, and bronze gold is *illumination only* --
/// ayah markers, the surah cartouche, the recording ring, hasanah and
/// milestones. Colour inside the Quran text always means a Tajweed rule.
///
/// Widgets read `AppColors.x` directly; flipping [brightness] makes every
/// reference resolve to its light or dark value on the next rebuild. These
/// are getters, not `const`, so they can change at runtime.
///
/// ## Contrast contract
///
/// Every value is measured, not eyeballed, and `test/theme_contrast_test.dart`
/// asserts it:
///
///   * anything used as **text** clears 4.5:1 against [background] and
///     [surface] in both themes;
///   * anything that **identifies a control** -- field outlines, unselected
///     chip boundaries -- clears the 3:1 non-text minimum: [borderStrong];
///   * decorative hairlines ([border], [divider]) and ornament strokes
///     ([gold]) are exempt from text contrast but still visible.
///
/// Dark mode is its own palette rather than an inversion: a green-black
/// ground, ivory ink, lighter surfaces for elevation instead of shadows, and
/// accents lifted so they stay legible without glowing.
abstract class AppColors {
  static Brightness brightness = Brightness.light;
  static bool get _d => brightness == Brightness.dark;

  // ── Brand: deep green ─────────────────────────────────────────────────────
  /// The primary action and the brand. A deep forest green by day (ivory text
  /// on it measures 9.40:1); a lifted, muted emerald by night with dark text
  /// on it (8.22:1), so filled buttons read as lit rather than as holes.
  static Color get primary => _d ? const Color(0xFF8CC4A6) : const Color(0xFF1E4D3B);

  /// One step lighter than [primary]. Kept for the handful of places that
  /// paired two brand tones; there are no brand gradients any more.
  static Color get primaryLight => _d ? const Color(0xFFA3D1B8) : const Color(0xFF2A6149);

  /// Muted emerald wash: selected rows, tonal chips, the nav indicator.
  static Color get primarySurface => _d ? const Color(0xFF1E3A2E) : const Color(0xFFDFEAE1);

  /// Brand colour used as *text or icon* on a light surface -- links, the
  /// selected tab, small emphasis. The same green as [primary]: at 8.63:1 on
  /// parchment it is already an ink.
  static Color get primaryDark => _d ? const Color(0xFF8CC4A6) : const Color(0xFF1E4D3B);

  /// Ink on [primarySurface].
  static Color get onPrimarySurface => _d ? const Color(0xFFCFE6D8) : const Color(0xFF163B2D);

  /// Muted emerald for non-text accents: progress fills, the Quran map.
  static Color get emerald => _d ? const Color(0xFF6FAF8F) : const Color(0xFF3F7A61);

  // ── Illumination: bronze gold ─────────────────────────────────────────────
  /// Ornament strokes only -- ayah markers, cartouche rules, the recording
  /// ring. 3.16:1 on parchment: enough to read as a line, never used as text.
  static Color get gold => _d ? const Color(0xFFCDAA66) : const Color(0xFFA9823F);

  /// Bronze used as text (hasanah, milestones, small labels).
  static Color get goldInk => _d ? const Color(0xFFD9BA7C) : const Color(0xFF7A5A1C);

  /// The fill inside an ayah marker or a hasanah chip.
  static Color get goldWash => _d ? const Color(0xFF2A2517) : const Color(0xFFF2E7CE);

  /// Legacy name for the bronze *ink*: charts and small text.
  static Color get accent => goldInk;

  /// Legacy name for the bronze *ornament* tone.
  static Color get accentLight => gold;
  static Color get accentSurface => goldWash;

  // ── Neutrals: parchment (light) / night (dark) ────────────────────────────
  static Color get background => _d ? const Color(0xFF0F1311) : const Color(0xFFF7F2E8);
  static Color get cream => _d ? const Color(0xFF131815) : const Color(0xFFF3EDE1);
  static Color get creamDark => _d ? const Color(0xFF0B0E0C) : const Color(0xFFEAE2D3);
  static Color get surface => _d ? const Color(0xFF151A17) : const Color(0xFFFFFCF5);

  /// Sunken: text fields, grouped rows, the search box.
  static Color get surfaceAlt => _d ? const Color(0xFF0B0E0C) : const Color(0xFFEFE8DA);

  /// Selected and tonal fills.
  static Color get container => _d ? const Color(0xFF1F2622) : const Color(0xFFE6DDCB);

  /// Floating chrome: the practice dock, the mini-player. In dark mode
  /// elevation is a lighter surface, never a shadow.
  static Color get raised => _d ? const Color(0xFF242C28) : const Color(0xFFFFFCF5);

  /// Decorative hairline. Exempt from 3:1, but visible.
  static Color get border => _d ? const Color(0xFF2F3833) : const Color(0xFFDDD3C0);
  static Color get divider => _d ? const Color(0xFF2A322D) : const Color(0xFFE3DACA);

  /// The boundary of an actual control. Meets the 3:1 non-text minimum.
  static Color get borderStrong => _d ? const Color(0xFF6C766F) : const Color(0xFF857D6E);

  // ── Text ─────────────────────────────────────────────────────────────────
  static Color get textPrimary => _d ? const Color(0xFFECE7DC) : const Color(0xFF1D211F);
  static Color get textSecondary => _d ? const Color(0xFFB8B4A8) : const Color(0xFF4F5550);

  /// Quiet text. Clears 4.5:1 on background and surface only -- never set it
  /// on [container] or [surfaceAlt].
  static Color get textMuted => _d ? const Color(0xFF959488) : const Color(0xFF626963);

  /// Ink on a [primary] fill.
  static Color get textOnPrimary => _d ? const Color(0xFF0D241A) : const Color(0xFFFFFCF5);
  static Color get textOnAccent => _d ? const Color(0xFF151A17) : const Color(0xFFFFFCF5);

  /// Ink on an inverted surface (the snackbar, whose ground is [textPrimary]).
  static Color get textOnInverse => _d ? const Color(0xFF151A17) : const Color(0xFFF7F2E8);

  /// Ink on a deep-green brand panel ([successSurface], [brandCardGradient]).
  static Color get textOnBrandCard => const Color(0xFFFFFCF5);

  /// Deep-green panel behind ivory text. Flat: the stops are one tone apart,
  /// only enough to keep a large panel from looking printed.
  static List<Color> get brandCardGradient =>
      _d ? const [Color(0xFF1E3A2E), Color(0xFF18302A)] : const [Color(0xFF1E4D3B), Color(0xFF193F31)];

  /// Small brand controls used to take a gold sweep. They are flat now.
  static List<Color> get brandControlGradient => [primary, primary];

  // ── Semantic ──────────────────────────────────────────────────────────────
  static Color get success => _d ? const Color(0xFF6CC596) : const Color(0xFF2A7248);
  static Color get successLight => _d ? const Color(0xFF15291F) : const Color(0xFFE2EEE5);
  static Color get warning => _d ? const Color(0xFFE0A94F) : const Color(0xFF8A5A0B);
  static Color get error => _d ? const Color(0xFFF08A80) : const Color(0xFFB3261E);
  static Color get errorLight => _d ? const Color(0xFF2E1B19) : const Color(0xFFF8E6E3);
  static Color get info => _d ? const Color(0xFF86B4F0) : const Color(0xFF2A5C9E);

  /// Deep-green brand panel.
  static Color get successSurface => _d ? const Color(0xFF1E3A2E) : const Color(0xFF1E4D3B);

  // ── Tajweed highlight ─────────────────────────────────────────────────────
  static Color get errorHighlight => _d ? const Color(0xFFF08A80) : const Color(0xFFB3261E);
  static Color get errorHighlightBg => _d ? const Color(0xFF2E1B19) : const Color(0xFFF8E6E3);

  // ── Tajweed rules ─────────────────────────────────────────────────────────
  // One colour per rule, in the conventional hue families of Tajweed
  // mushafs, each paired with an underline shape (see TajweedRuleStyle) so
  // colour is never the only signal. All are verse *text*, so all clear 4.5:1.
  //
  // Madd is a red-orange so it cannot be mistaken for bronze ornament; Ghunnah
  // is jade rather than green so it never reads as the brand; Shaddah leans
  // crimson to stay apart from Madd.
  static Color get ruleMadd => _d ? const Color(0xFFE68A4F) : const Color(0xFFA84E14);
  static Color get ruleGhunnah => _d ? const Color(0xFF4FC3B5) : const Color(0xFF0F6B63);
  static Color get ruleShaddah => _d ? const Color(0xFFEE7F9C) : const Color(0xFFA3284A);
  static Color get ruleMakhraj => _d ? const Color(0xFF86B4F0) : const Color(0xFF2A5C9E);
  static Color get ruleSkipped => _d ? const Color(0xFF959488) : const Color(0xFF626963);

  /// An un-recited word *during practice*. Reading mode shows the Quran in
  /// full ink; only once recording starts do the words not yet heard soften to
  /// this, and ink back in as the recogniser places them. It is still text, so
  /// it keeps the full 4.5:1.
  static Color get verseResting => _d ? const Color(0xFF959488) : const Color(0xFF626963);

  // ── Score bands ───────────────────────────────────────────────────────────
  static Color get scoreExcellent => success;
  static Color get scoreGood => _d ? const Color(0xFFA9C97A) : const Color(0xFF4E6B22);
  static Color get scoreAverage => warning;
  static Color get scorePoor => error;

  // ── Dark (legacy stub names -- kept for any remaining references) ────────
  static Color get darkBackground => const Color(0xFF0F1311);
  static Color get darkSurface => const Color(0xFF151A17);
  static Color get darkTextPrimary => const Color(0xFFECE7DC);

  // ── Shadow ───────────────────────────────────────────────────────────────
  /// A soft, green-tinted shadow for the few things that float in light mode.
  /// Transparent in dark mode, where elevation is a lighter surface instead.
  static Color get cardShadow => _d ? const Color(0x00000000) : const Color(0x141B2A22);

  // ── Frosted panels over photography ──────────────────────────────────────
  static Color get glassSurface => _d ? const Color(0xB3151A17) : const Color(0xB3FFFCF5);
  static Color get glassBorder => _d ? const Color(0x1FFFFFFF) : const Color(0x99FFFFFF);

  /// A panel carrying body text over a photograph. Dense enough that
  /// secondary text keeps 4.5:1 over a mid-tone image.
  static Color get glassSurfaceStrong => _d ? const Color(0xE0151A17) : const Color(0xE6FFFCF5);

  /// The scrim colour laid over photography so text on it reads: a deep
  /// green-black, not a flat grey, so photos sit inside the palette.
  static Color get photoScrim => const Color(0xFF0B1410);

  /// Ivory ink for text set directly on a scrimmed photograph.
  static Color get textOnPhoto => const Color(0xFFFBF7EE);
  static Color get textOnPhotoSecondary => const Color(0xFFDCD5C6);
}
