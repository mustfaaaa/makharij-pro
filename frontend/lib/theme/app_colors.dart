import 'package:flutter/material.dart';

/// Central, brightness-aware colour palette — gold/cream Islamic-modern
/// theme (light) with a warm "night parchment" dark variant. Widgets read
/// `AppColors.x` directly; flipping [brightness] (driven by the Settings
/// toggle) makes every reference resolve to its light or dark value on the
/// next rebuild — that's what makes dark mode actually take effect.
///
/// Because these are getters (not `const`), they can't be used inside
/// `const` expressions — that's intentional so colours can change at runtime.
///
/// ## Contrast contract
///
/// Every value here is measured, not eyeballed. The light palette used to
/// fail WCAG AA nearly everywhere — body text at 3.75:1, the primary button
/// label at 2.41:1, the resting mushaf page at 2.23:1 — so the rule is now:
///
///   * anything used as **text** clears 4.5:1 against every surface it is
///     drawn on (`surface`, `background`, `surfaceAlt`, `cream`, and
///     `primarySurface` for the gold inks);
///   * anything that **identifies a control** — input outlines, unselected
///     chip boundaries — clears the 3:1 non-text minimum: that's
///     [borderStrong];
///   * a purely decorative hairline ([border], [divider]) is exempt from
///     3:1, but is still lifted far enough to actually be seen.
///
/// Where one hue had to serve as both a fill and as text it is split in two:
/// the brand hue keeps its saturation for fills, and a darker sibling carries
/// the text role. Darkening the shared value instead would have turned the
/// brand gold to brown.
abstract class AppColors {
  static Brightness brightness = Brightness.light;
  static bool get _d => brightness == Brightness.dark;

  // ── Brand: Muted Gold ─────────────────────────────────────────────────────
  // [primary] and [primaryLight] are FILL colours — buttons, gradients, the
  // mic, the Ask-AI circle. They stay bright gold on purpose. Content drawn
  // on top of them is dark ink (see [textOnPrimary]), never white: white on
  // this gold measures 2.41:1, which is why every CTA in the app used to fail.
  static Color get primary => _d ? const Color(0xFFD9B876) : const Color(0xFFC2A366);
  static Color get primaryLight => _d ? const Color(0xFFE6CC94) : const Color(0xFFD4B87A);
  static Color get primarySurface => _d ? const Color(0xFF2E2818) : const Color(0xFFF7EDD6);

  /// The gold **ink**: gold used as text or as a small icon on a light
  /// surface. Deliberately far darker than [primary] — 5.31:1 on white and
  /// 4.56:1 on [primarySurface], so a gold chip label reads against its own
  /// background. Don't use it as a large fill; use [primary] for that.
  static Color get primaryDark => _d ? const Color(0xFFC2A366) : const Color(0xFF806839);

  /// Accent gold. Darkened in light mode because its only jobs are text and
  /// thin chart strokes — at `#C9A227` the progress line sat at 2.42:1
  /// against its card, below even the 3:1 non-text floor.
  static Color get accent => _d ? const Color(0xFFE0BD4A) : const Color(0xFF846A19);
  static Color get accentLight => _d ? const Color(0xFFE8D48A) : const Color(0xFFBE9A34);
  static Color get accentSurface => _d ? const Color(0xFF2E2818) : const Color(0xFFF7EFD6);

  // ── Neutrals: warm cream/parchment (light) / warm charcoal (dark) ─────────
  static Color get background => _d ? const Color(0xFF17130E) : const Color(0xFFFBF8F3);
  static Color get cream => _d ? const Color(0xFF1D1811) : const Color(0xFFF5F0E8);
  static Color get creamDark => _d ? const Color(0xFF120F0A) : const Color(0xFFEDE5D5);
  static Color get surface => _d ? const Color(0xFF221D15) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt => _d ? const Color(0xFF2A2419) : const Color(0xFFF7F3EC);

  /// Decorative hairline around cards. Not a control boundary, so 1.4.11's
  /// 3:1 doesn't apply — but the old values sat at 1.15:1, which is no border
  /// at all. Lifted to roughly 1.5:1: visible, still soft.
  static Color get border => _d ? const Color(0xFF453D2D) : const Color(0xFFDCD5C7);
  static Color get divider => _d ? const Color(0xFF423A29) : const Color(0xFFDCD5C7);

  /// The boundary of an actual control — text field outlines, unselected
  /// chips, checkbox edges. Meets the 3:1 non-text minimum, so the control's
  /// shape is identifiable without relying on its fill.
  static Color get borderStrong => _d ? const Color(0xFF7E7051) : const Color(0xFF8F8A80);

  // ── Text ─────────────────────────────────────────────────────────────────
  static Color get textPrimary => _d ? const Color(0xFFF2ECDE) : const Color(0xFF2D2A26);
  static Color get textSecondary => _d ? const Color(0xFFBAB0A0) : const Color(0xFF6B655C);
  static Color get textMuted => _d ? const Color(0xFF9A9082) : const Color(0xFF706D67);

  /// Ink for content sitting on a gold fill ([primary], [primaryLight], and
  /// the gold gradients). Dark, not white — see the note on [primary].
  static Color get textOnPrimary => const Color(0xFF2D2A26);
  static Color get textOnAccent => const Color(0xFF2D2A26);

  /// Ink for content on an **inverted** surface — the snackbar, whose
  /// background is [textPrimary] and so flips with the theme. This used to be
  /// hardcoded white, which in dark mode put white text on a cream snackbar
  /// at 1.18:1.
  static Color get textOnInverse => _d ? const Color(0xFF221D15) : const Color(0xFFFBF8F3);

  /// Ink for content on a saturated brand card ([successSurface] and
  /// [brandCardGradient]), where white is the correct choice and clears 4.5:1.
  static Color get textOnBrandCard => const Color(0xFFFFFFFF);

  /// The gold hero panel behind white text — the Profile header and the
  /// Progress "Overall Accuracy" card.
  ///
  /// The old stops ran `primaryLight` -> `#8B6914`, so white text sat at
  /// 1.92:1 at the light end of the sweep and only reached 5.09:1 at the
  /// dark end. These are a deep antique gold at both ends (4.87:1 and
  /// 6.93:1), so the label stays readable wherever it falls on the gradient.
  static List<Color> get brandCardGradient =>
      _d ? const [Color(0xFF7A5F26), Color(0xFF5C4820)] : const [Color(0xFF8A6D2F), Color(0xFF6F5622)];

  /// The gold sweep on a small brand control — the mic, the Ask-AI circle,
  /// the send button, a user chat bubble. Pairs with [textOnPrimary].
  ///
  /// Deliberately a *narrow* sweep. These used to run
  /// `primaryLight -> primaryDark`, and once `primaryDark` became the ink
  /// gold that span was wide enough that neither white nor dark ink could
  /// clear 4.5:1 at both ends. Keeping both stops in the bright golds means
  /// the dark ink reads across the whole gradient (7.44:1 and 5.93:1).
  static List<Color> get brandControlGradient => [primaryLight, primary];

  // ── Semantic ──────────────────────────────────────────────────────────────
  static Color get success => _d ? const Color(0xFF3FAE7F) : const Color(0xFF007E54);
  static Color get successLight => _d ? const Color(0xFF1B2E24) : const Color(0xFFE6F4EF);
  static Color get warning => _d ? const Color(0xFFCE8A1B) : const Color(0xFF956413);
  static Color get error => _d ? const Color(0xFFE36160) : const Color(0xFFCC3436);
  static Color get errorLight => _d ? const Color(0xFF2E1C1B) : const Color(0xFFFCEAEA);
  static Color get info => _d ? const Color(0xFF6BA6DE) : const Color(0xFF3570AC);

  /// Full-bleed green brand card — "Today's goal" on Home, the summary panel
  /// on Progress. Was a hardcoded `#1F6E4E` on three screens with no dark
  /// variant, so it stayed a bright daylight green on a night-parchment page.
  static Color get successSurface => _d ? const Color(0xFF17513A) : const Color(0xFF1F6E4E);

  // ── Tajweed highlight ─────────────────────────────────────────────────────
  static Color get errorHighlight => _d ? const Color(0xFFE36160) : const Color(0xFFCC3436);
  static Color get errorHighlightBg => _d ? const Color(0xFF2E1C1B) : const Color(0xFFFCEAEA);

  // ── Tajweed rules ─────────────────────────────────────────────────────────
  // One signature colour per rule, so a flagged word says *which* rule it
  // broke rather than only that something was wrong.
  //
  // These are deliberately four separate hues. The previous set drew Madd,
  // Ghunnah and Shaddah from primary/accent/warning -- #C2A366, #C9A227 and
  // #CE8A1B -- which are the same gold to the eye at verse size, so three of
  // the four rules were indistinguishable on the page.
  //
  // Colour is never the only signal: see TajweedRuleStyle, which pairs each
  // of these with an underline shape that carries the same meaning for
  // colour-blind readers and in greyscale.
  //
  // Every one of these is verse *text*, so all four clear 4.5:1 -- Madd and
  // Skipped were darkened in light mode to get there.
  static Color get ruleMadd => _d ? const Color(0xFFD9A25C) : const Color(0xFF966328);
  static Color get ruleGhunnah => _d ? const Color(0xFF5CBF95) : const Color(0xFF2C7856);
  static Color get ruleShaddah => _d ? const Color(0xFFE0836A) : const Color(0xFFA6462F);
  static Color get ruleMakhraj => _d ? const Color(0xFF7FAEE0) : const Color(0xFF3B6EA8);
  static Color get ruleSkipped => _d ? const Color(0xFF948A7A) : const Color(0xFF726D66);

  /// The resting colour of an un-recited word on the mushaf page. This is the
  /// app's primary reading surface, so it carries the full 4.5:1 text
  /// requirement even though its job is to look quiet — at the old
  /// `textMuted` it rendered the entire Quran at 2.23:1.
  static Color get verseResting => _d ? const Color(0xFF9A9082) : const Color(0xFF706D67);

  // ── Score bands ───────────────────────────────────────────────────────────
  static Color get scoreExcellent => _d ? const Color(0xFF3FAE7F) : const Color(0xFF007E54);
  static Color get scoreGood => _d ? const Color(0xFF7CA83B) : const Color(0xFF547328);
  static Color get scoreAverage => _d ? const Color(0xFFCE8A1B) : const Color(0xFF956413);
  static Color get scorePoor => _d ? const Color(0xFFE36160) : const Color(0xFFCC3436);

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

  /// A frosted panel carrying **body text** over a photograph — the "Last
  /// Read" strip on the Quran tab. Denser than [glassSurface] because at 0x99
  /// the composite only gives secondary text about 3.5:1 over a mid-tone
  /// photo; at this opacity it reaches 4.67:1. Unlike the raw white it
  /// replaces, it flips to parchment in dark mode.
  static Color get glassSurfaceStrong => _d ? const Color(0xD12A2419) : const Color(0xD1FFFFFF);
}
