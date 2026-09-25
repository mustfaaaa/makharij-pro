import 'package:flutter/material.dart';

import '../../../../models/tajweed_error.dart';
import '../../../../shared/ui/ornaments.dart';

/// Arabic-Indic digits, so ayah numbers read the way they do in a printed
/// mushaf rather than as Latin numerals.
String arabicNumber(int value) => arabicIndicDigits(value);

/// How a word should be painted in the mushaf text.
enum WordTone {
  /// Not yet recited. In reading mode this is simply the text, in full ink;
  /// during practice it is the softened "not heard yet" tone.
  pending,

  /// Confirmed as recited by the live analysis while the user speaks.
  recited,

  /// A mistake, from the finished analysis. Never used during recording:
  /// a half-decoded word must not be accused of anything.
  flagged,
}

/// One word's verdict as the page draws it.
///
/// A flagged word carries the rule it broke, so the page can say *which*
/// mistake it was rather than only that there was one. [rule] is null while
/// reciting (the live cursor reports progress, never mistakes) and for a
/// flagged word whose rule a newer server sent under a name this build
/// doesn't know.
class WordMark {
  final WordTone tone;
  final TajweedErrorType? rule;

  const WordMark(this.tone, {this.rule});

  static const pending = WordMark(WordTone.pending);
  static const recited = WordMark(WordTone.recited);
}

/// The illuminated plate above a surah's text: "Surah" and its name in a double gold
/// rule over a faint star lattice, with a one-line summary.
///
/// No Basmala here on purpose. The bundled Quran text already opens every
/// surah's ayah 1 with it (At-Tawbah excepted), so printing one would show it
/// twice -- and the second copy would carry no recitation highlighting.
class MushafSurahHeader extends StatelessWidget {
  final String nameArabic;
  final String subtitle;
  const MushafSurahHeader({
    super.key,
    required this.nameArabic,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SurahCartouche(nameArabic: 'سُورَةُ $nameArabic', subtitle: subtitle);
  }
}
