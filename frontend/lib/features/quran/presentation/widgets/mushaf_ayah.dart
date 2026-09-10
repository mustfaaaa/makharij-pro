import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../models/ayah.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/tajweed_rule_style.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// Arabic-Indic digits, so ayah numbers read the way they do in a printed
/// mushaf rather than as Latin numerals.
String arabicNumber(int value) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return value.toString().split('').map((d) => digits[int.parse(d)]).join();
}

/// How a word should be painted in the mushaf text.
enum WordTone {
  /// Not yet recited — the resting state of the whole page.
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

/// One ayah rendered as flowing, justified mushaf text, closed by a gold
/// ayah-number medallion. Words are individually coloured so recitation
/// progress and mistakes can be shown in place, without breaking the line
/// flow the way per-word boxes would.
class MushafAyah extends StatefulWidget {
  final Ayah ayah;
  final double fontSize;

  /// Verdict per word index. Missing entries fall back to [WordMark.pending].
  final Map<int, WordMark> marks;
  final bool showTranslation;
  final VoidCallback? onTap;

  /// Long-press on a single word, with its index inside this ayah.
  ///
  /// Long-press rather than tap because tap already means "show the
  /// translation" here, and the reading page tells the user so. Taking that
  /// gesture over would break a documented behaviour to add a new one.
  final void Function(int wordIndex)? onWordLongPress;

  const MushafAyah({
    super.key,
    required this.ayah,
    required this.fontSize,
    this.marks = const {},
    this.showTranslation = false,
    this.onTap,
    this.onWordLongPress,
  });

  @override
  State<MushafAyah> createState() => _MushafAyahState();
}

/// Stateful only to own the tap recognizer.
///
/// [TapGestureRecognizer] is a disposable: it registers with the gesture
/// arena and holds a callback. It used to be constructed inline in `build`,
/// so every rebuild leaked one per ayah -- and on the reading page, where a
/// per-second recording timer rebuilt the whole surah, that was hundreds of
/// live recognizers a minute for a long surah.
class _MushafAyahState extends State<MushafAyah> {
  /// One long-press recognizer per word. Like the tap recognizer before it,
  /// these are disposables that register with the gesture arena, so they are
  /// owned by the State and rebuilt only when the word count or the callback
  /// actually changes -- never inside `build`.
  List<LongPressGestureRecognizer> _wordRecognizers = const [];

  @override
  void initState() {
    super.initState();
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(MushafAyah oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onWordLongPress != widget.onWordLongPress ||
        oldWidget.ayah.arabicText != widget.ayah.arabicText) {
      _syncRecognizers();
    }
  }

  void _syncRecognizers() {
    for (final recognizer in _wordRecognizers) {
      recognizer.dispose();
    }
    final handler = widget.onWordLongPress;
    if (handler == null) {
      _wordRecognizers = const [];
      return;
    }
    final wordCount = widget.ayah.arabicText.split(' ').length;
    _wordRecognizers = [
      for (var i = 0; i < wordCount; i++)
        LongPressGestureRecognizer()..onLongPress = () => handler(i),
    ];
  }

  @override
  void dispose() {
    for (final recognizer in _wordRecognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  /// The rule's own colour when a word is flagged, so the page distinguishes a
  /// short madd from a missed ghunnah instead of painting both the same red.
  Color _colorFor(WordMark mark) {
    switch (mark.tone) {
      case WordTone.pending:
        // Its own token, not `textMuted`: this is the resting state of the
        // whole mushaf page, so it carries the full 4.5:1 text requirement
        // even though its job is to look quiet.
        return AppColors.verseResting;
      case WordTone.recited:
        return AppColors.textPrimary;
      case WordTone.flagged:
        return mark.rule == null
            ? AppColors.errorHighlight
            : TajweedRuleStyle.color(mark.rule!);
    }
  }

  /// Colour plus, for a flagged word, the underline whose shape names the
  /// rule. The shape is what keeps this readable without colour.
  TextStyle _styleFor(WordMark mark) {
    final base = AppTypography.arabicVerse(
      fontSize: widget.fontSize,
      color: _colorFor(mark),
      height: 2.1,
    );
    final rule = mark.rule;
    if (mark.tone != WordTone.flagged || rule == null) return base;
    return base.copyWith(
      decoration: TajweedRuleStyle.decoration(rule),
      decorationStyle: TajweedRuleStyle.decorationStyle(rule),
      decorationColor: TajweedRuleStyle.color(rule),
      decorationThickness: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.ayah.arabicText.split(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            // Ayah-level tap lives here rather than on the spans: each word
            // span can hold only one recognizer, and that slot is now the
            // long-press. A tap that no word claims falls through to this.
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Text.rich(
            TextSpan(children: [
              for (var i = 0; i < words.length; i++)
                TextSpan(
                  text: i == words.length - 1 ? words[i] : '${words[i]} ',
                  style: _styleFor(widget.marks[i] ?? WordMark.pending),
                  recognizer: i < _wordRecognizers.length ? _wordRecognizers[i] : null,
                ),
              const TextSpan(text: ' '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _AyahMedallion(number: widget.ayah.number, size: widget.fontSize * 1.15),
              ),
            ]),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            ),
          ),
          if (widget.showTranslation)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                widget.ayah.translation,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// The gold circle carrying the ayah number, in place of a printed ۝ — drawn
/// rather than typed so it looks the same in every font the app might fall
/// back to.
class _AyahMedallion extends StatelessWidget {
  final int number;
  final double size;
  const _AyahMedallion({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySurface,
        border: Border.all(color: AppColors.primary, width: 1.2),
      ),
      child: Text(
        arabicNumber(number),
        textDirection: TextDirection.rtl,
        style: AppTypography.arabicWord(
          fontSize: size * 0.46,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// The decorative plate above a surah's text: its name and a one-line summary.
///
/// No Basmala here on purpose. The bundled Quran text already opens every
/// surah's ayah 1 with it (At-Tawbah excepted), so printing one would show it
/// twice — and the second copy would carry no recitation highlighting, since
/// only the real ayah text is scored.
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            'سُورَةُ $nameArabic',
            textDirection: TextDirection.rtl,
            style: AppTypography.arabicVerse(
              fontSize: 30,
              color: AppColors.primaryDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
