import 'package:flutter/material.dart';

import '../models/quran_script.dart';
import 'app_colors.dart';

/// Three bundled families, two roles each (see DESIGN.md):
///
///  * **Figtree** -- interface text. Open humanist shapes that sit beside
///    Naskh without competing with it, and real tabular figures for timers.
///  * **Amiri** -- display, in both scripts: screen titles, surah names,
///    headlines. Its Latin is a classical book face, so a heading in English
///    and a surah name in Arabic read as one voice.
///  * **The Quran** -- in the King Fahd Complex's own faces, and nothing else
///    in them. The reader writes it in the script the user chose (see
///    [quranScript]); everywhere else Quran text is shown in KFGQPC HAFS
///    Uthmanic Script ([quran]), which covers every codepoint of the bundled
///    Uthmani text.
///
/// All are declared in pubspec.yaml and bundled, never fetched: the Quran has
/// to render in its own face on a first launch with no connection.
abstract class AppTypography {
  static const String ui = 'Figtree';
  static const String display = 'Amiri';
  static const String quranFamily = 'QuranUthmani';

  /// Fallbacks for glyphs a family lacks (Arabic inside a Figtree string, a
  /// Latin digit inside a Quran face).
  static const List<String> _uiFallback = ['Amiri', 'Roboto', 'sans-serif'];
  static const List<String> _arabicFallback = ['AmiriQuran', 'Amiri', 'Figtree'];

  static TextStyle _ui(double size, FontWeight weight, double height, Color color, {double spacing = 0}) =>
      TextStyle(
        fontFamily: ui,
        fontFamilyFallback: _uiFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );

  static TextStyle _display(double size, double height, Color color, {double spacing = 0}) => TextStyle(
        fontFamily: display,
        fontFamilyFallback: const ['Figtree'],
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: height,
        letterSpacing: spacing,
        color: color,
      );

  /// The interface scale. Display and headline roles are Amiri; everything a
  /// user operates or scans is Figtree. Heights never drop below 1.1 -- tight
  /// leading on large text clips descenders.
  static TextTheme get uiTextTheme => TextTheme(
        displayLarge: _display(36, 1.15, AppColors.textPrimary, spacing: -0.4),
        displayMedium: _display(31, 1.15, AppColors.textPrimary, spacing: -0.3),
        displaySmall: _display(27, 1.18, AppColors.textPrimary, spacing: -0.2),
        headlineLarge: _display(28, 1.2, AppColors.textPrimary, spacing: -0.2),
        headlineMedium: _display(25, 1.2, AppColors.textPrimary, spacing: -0.2),
        headlineSmall: _display(22, 1.25, AppColors.textPrimary, spacing: -0.1),
        titleLarge: _ui(18, FontWeight.w600, 1.3, AppColors.textPrimary, spacing: -0.1),
        titleMedium: _ui(16, FontWeight.w600, 1.35, AppColors.textPrimary),
        titleSmall: _ui(14, FontWeight.w600, 1.35, AppColors.textPrimary),
        bodyLarge: _ui(16, FontWeight.w400, 1.55, AppColors.textPrimary),
        bodyMedium: _ui(14.5, FontWeight.w400, 1.5, AppColors.textSecondary),
        bodySmall: _ui(12.5, FontWeight.w400, 1.45, AppColors.textMuted),
        labelLarge: _ui(14.5, FontWeight.w600, 1.2, AppColors.textPrimary, spacing: 0.1),
        labelMedium: _ui(12.5, FontWeight.w600, 1.25, AppColors.textSecondary),
        labelSmall: _ui(11.5, FontWeight.w500, 1.25, AppColors.textMuted, spacing: 0.1),
      );

  /// Quran text. Default 28 with 2.15 line-height: the stacked Uthmani marks
  /// need the room above and below.
  static TextStyle quran({double fontSize = 28, Color? color, double height = 2.15}) => TextStyle(
        fontFamily: quranFamily,
        fontFamilyFallback: _arabicFallback,
        fontSize: fontSize,
        height: height,
        color: color ?? AppColors.textPrimary,
      );

  /// Quran text written in [script] -- only for text that came from that
  /// script's own encoding (QuranScriptRepository). The size is scaled so both
  /// scripts read at the same size for the same setting.
  static TextStyle quranScript(QuranScript script, {double fontSize = 28, Color? color, double? height}) => TextStyle(
        fontFamily: script.fontFamily,
        fontFamilyFallback: _arabicFallback,
        fontSize: fontSize * script.sizeScale,
        height: height ?? script.lineHeight,
        color: color ?? AppColors.textPrimary,
      );

  /// Kept for existing call sites: every one of them is Quran text.
  static TextStyle arabicVerse({double fontSize = 28, Color? color, double height = 2.15}) =>
      quran(fontSize: fontSize, color: color, height: height);

  /// Arabic interface text -- surah names, examples in a list -- in Amiri.
  static TextStyle arabicWord({double fontSize = 22, Color? color, FontWeight weight = FontWeight.w400}) => TextStyle(
        fontFamily: display,
        fontFamilyFallback: const ['QuranUthmani', 'AmiriQuran', 'Figtree'],
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.5,
        color: color ?? AppColors.textPrimary,
      );

  /// Large Amiri display in either script, for heroes and cartouches.
  static TextStyle displayText({double fontSize = 30, Color? color, double height = 1.2}) =>
      _display(fontSize, height, color ?? AppColors.textPrimary, spacing: fontSize >= 28 ? -0.3 : -0.1);

  /// Tabular figures for timers, counts and anything that ticks.
  static TextStyle numeric({double fontSize = 28, FontWeight weight = FontWeight.w600, Color? color}) =>
      _ui(fontSize, weight, 1.15, color ?? AppColors.textPrimary)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
