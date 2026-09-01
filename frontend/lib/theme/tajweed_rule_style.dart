import 'package:flutter/material.dart';

import '../models/tajweed_error.dart';
import 'app_colors.dart';

/// How each Tajweed rule marks a word it was broken on.
///
/// Two signals, never one. Colour alone would fail the readers who most need
/// this: roughly one man in twelve cannot separate the red/green end of the
/// palette, and the app is read one-handed in whatever light the reciter
/// happens to be sitting in. So every rule also gets an underline whose
/// *shape* carries the same meaning, and which survives greyscale, a dimmed
/// screen, and a printed screenshot.
///
/// The shapes are chosen to echo the mistake rather than to be merely
/// different from each other:
///
/// | rule    | underline | why |
/// |---------|-----------|-----|
/// | madd    | dashed    | a long stroke — the elongation that was cut short |
/// | ghunnah | wavy      | the nasal hum |
/// | shaddah | double    | the letter that should have sounded twice |
/// | makhraj | dotted    | an unsteady letter, off its articulation point |
/// | skipped | struck through | a word that was never said |
abstract class TajweedRuleStyle {
  static Color color(TajweedErrorType type) {
    switch (type) {
      case TajweedErrorType.madd:
        return AppColors.ruleMadd;
      case TajweedErrorType.ghunnah:
        return AppColors.ruleGhunnah;
      case TajweedErrorType.shaddah:
        return AppColors.ruleShaddah;
      case TajweedErrorType.makhraj:
        return AppColors.ruleMakhraj;
      case TajweedErrorType.skipped:
        return AppColors.ruleSkipped;
    }
  }

  static TextDecoration decoration(TajweedErrorType type) =>
      type == TajweedErrorType.skipped ? TextDecoration.lineThrough : TextDecoration.underline;

  static TextDecorationStyle decorationStyle(TajweedErrorType type) {
    switch (type) {
      case TajweedErrorType.madd:
        return TextDecorationStyle.dashed;
      case TajweedErrorType.ghunnah:
        return TextDecorationStyle.wavy;
      case TajweedErrorType.shaddah:
        return TextDecorationStyle.double;
      case TajweedErrorType.makhraj:
        return TextDecorationStyle.dotted;
      case TajweedErrorType.skipped:
        return TextDecorationStyle.solid;
    }
  }

  /// A one-word hint at what the underline means, for the legend.
  static String shapeHint(TajweedErrorType type) {
    switch (type) {
      case TajweedErrorType.madd:
        return 'dashed';
      case TajweedErrorType.ghunnah:
        return 'wavy';
      case TajweedErrorType.shaddah:
        return 'double';
      case TajweedErrorType.makhraj:
        return 'dotted';
      case TajweedErrorType.skipped:
        return 'struck out';
    }
  }
}
