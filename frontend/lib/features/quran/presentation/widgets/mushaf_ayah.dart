import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../models/ayah.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';

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

/// One ayah rendered as flowing, justified mushaf text, closed by a gold
/// ayah rosette. Words are individually coloured so recitation progress and
/// mistakes can be shown in place, without breaking the line flow the way
/// per-word boxes would.
class MushafAyah extends StatefulWidget {
  final Ayah ayah;
  final double fontSize;

  /// Verdict per word index. Missing entries fall back to [WordMark.pending].
  final Map<int, WordMark> marks;
  final bool showTranslation;
  final VoidCallback? onTap;

  /// Reading rather than practising: words with no verdict are drawn in full
  /// ink. Off (the default) they rest in the softer "not heard yet" tone,
  /// which is what recitation and results need.
  final bool readingMode;

  /// How many leading words form the Basmala, to set on their own centred
  /// line. The bundled text opens ayah 1 of most surahs with it; splitting it
  /// out is purely visual -- word indices, and so live highlighting and
  /// verdicts, are unchanged.
  final int leadingCenteredWords;

  /// An optional transliteration line under the ayah.
  final String? transliteration;

  /// Word indices that carry a Tajweed rule the reader asked to see, drawn as
  /// a soft tint -- deliberately unlike the underlines that mark mistakes, so
  /// "this word has a ghunnah" can never be read as "you got this wrong".
  final Set<int> referenceWords;
  final Color? referenceColor;

  /// Whether this ayah is the one a Qari is reciting right now.
  final bool playing;

  /// Long-press on a single word, with its index inside this ayah.
  ///
  /// Long-press rather than tap because tap already means "show the
  /// translation" here. Taking that gesture over would break a documented
  /// behaviour to add a new one.
  final void Function(int wordIndex)? onWordLongPress;

  const MushafAyah({
    super.key,
    required this.ayah,
    required this.fontSize,
    this.marks = const {},
    this.showTranslation = false,
    this.onTap,
    this.readingMode = false,
    this.leadingCenteredWords = 0,
    this.transliteration,
    this.referenceWords = const {},
    this.referenceColor,
    this.playing = false,
    this.onWordLongPress,
  });

  @override
  State<MushafAyah> createState() => _MushafAyahState();
}

/// Stateful to own the gesture recognizers and the colour tween.
///
/// Recognizers are disposables that register with the gesture arena, so they
/// are owned by the State and rebuilt only when the word count or the
/// callback changes -- never inside `build`.
class _MushafAyahState extends State<MushafAyah> with SingleTickerProviderStateMixin {
  /// Words do not snap from one tone to the next. A verdict arriving mid
  /// recitation used to repaint a word in one frame, which read as a flicker
  /// rather than as progress. This tween carries each changed word from the
  /// colour it was actually showing to its new one.
  ///
  /// The animation is decoration only. `widget.marks` is the truth and is
  /// applied the moment it arrives.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  Map<int, Color> _fadeFrom = const {};
  List<LongPressGestureRecognizer> _wordRecognizers = const [];

  @override
  void initState() {
    super.initState();
    _fade.value = 1.0;
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(MushafAyah oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onWordLongPress != widget.onWordLongPress ||
        oldWidget.ayah.arabicText != widget.ayah.arabicText) {
      _syncRecognizers();
    }
    _startFadeIfChanged(oldWidget);
  }

  /// Begin a tween for the words whose painted colour just changed: a new
  /// verdict, or the page moving between reading and practice.
  void _startFadeIfChanged(MushafAyah old) {
    final changed = <int, Color>{};
    final count = widget.ayah.arabicText.split(' ').length;
    for (var i = 0; i < count; i++) {
      final before = _targetColor(old.marks[i] ?? WordMark.pending, old.readingMode);
      final after = _targetColor(widget.marks[i] ?? WordMark.pending, widget.readingMode);
      if (before == after) continue;
      changed[i] = _paintedColorFor(i, old.marks, old.readingMode);
    }
    if (changed.isEmpty) return;

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      setState(() => _fadeFrom = const {});
      _fade.value = 1.0;
      return;
    }
    setState(() => _fadeFrom = changed);
    _fade.forward(from: 0);
  }

  Color _paintedColorFor(int index, Map<int, WordMark> marks, bool reading) {
    final target = _targetColor(marks[index] ?? WordMark.pending, reading);
    final from = _fadeFrom[index];
    if (from == null || _fade.isCompleted) return target;
    return Color.lerp(from, target, Curves.easeOut.transform(_fade.value)) ?? target;
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
      for (var i = 0; i < wordCount; i++) LongPressGestureRecognizer()..onLongPress = () => handler(i),
    ];
  }

  @override
  void dispose() {
    _fade.dispose();
    for (final recognizer in _wordRecognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  /// The rule's own colour when a word is flagged, so the page distinguishes a
  /// short madd from a missed ghunnah instead of painting both the same red.
  Color _targetColor(WordMark mark, bool reading) {
    switch (mark.tone) {
      case WordTone.pending:
        // Full ink when simply reading. During practice, the words not heard
        // yet soften to their own token -- still a full 4.5:1 text colour.
        return reading ? AppColors.textPrimary : AppColors.verseResting;
      case WordTone.recited:
        return AppColors.textPrimary;
      case WordTone.flagged:
        return mark.rule == null ? AppColors.errorHighlight : TajweedRuleStyle.color(mark.rule!);
    }
  }

  /// Colour plus, for a flagged word, the underline whose shape names the
  /// rule. The shape is what keeps this readable without colour.
  TextStyle _styleFor(WordMark mark, int index) {
    var style = AppTypography.quran(
      fontSize: widget.fontSize,
      color: _paintedColorFor(index, widget.marks, widget.readingMode),
      height: 2.15,
    );
    if (widget.referenceWords.contains(index) && mark.tone != WordTone.flagged) {
      final tint = widget.referenceColor ?? AppColors.gold;
      style = style.copyWith(backgroundColor: tint.withValues(alpha: 0.16));
    }
    final rule = mark.rule;
    if (mark.tone != WordTone.flagged || rule == null) return style;
    return style.copyWith(
      decoration: TajweedRuleStyle.decoration(rule),
      decorationStyle: TajweedRuleStyle.decorationStyle(rule),
      decorationColor: TajweedRuleStyle.color(rule),
      decorationThickness: 2,
    );
  }

  String? _semanticsFor(String word, WordMark mark) {
    switch (mark.tone) {
      case WordTone.flagged:
        return '$word, needs attention${mark.rule == null ? '' : ': ${mark.rule!.label}'}';
      case WordTone.recited:
      case WordTone.pending:
        return null;
    }
  }

  InlineSpan _wordSpan(List<String> words, int i, {required bool last}) {
    final mark = widget.marks[i] ?? WordMark.pending;
    return TextSpan(
      text: last ? words[i] : '${words[i]} ',
      style: _styleFor(mark, i),
      semanticsLabel: _semanticsFor(words[i], mark),
      recognizer: i < _wordRecognizers.length ? _wordRecognizers[i] : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.ayah.arabicText.split(' ');
    final lead = widget.leadingCenteredWords.clamp(0, words.length - 1);
    final textTheme = Theme.of(context).textTheme;

    final verse = AnimatedBuilder(
      animation: _fade,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              for (var i = lead; i < words.length; i++) _wordSpan(words, i, last: i == words.length - 1),
              const TextSpan(text: ' '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Semantics(
                  label: 'end of ayah ${widget.ayah.number}',
                  child: AyahMarker(number: widget.ayah.number, size: widget.fontSize * 1.18),
                ),
              ),
            ]),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );

    // The Basmala on its own centred line above the ayah it opens. Same spans,
    // same indices, same recognizers: only the layout differs.
    final basmala = lead == 0
        ? null
        : AnimatedBuilder(
            animation: _fade,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text.rich(
                TextSpan(children: [
                  for (var i = 0; i < lead; i++) _wordSpan(words, i, last: i == lead - 1),
                ]),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
            ),
          );

    return AnimatedContainer(
      duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: widget.playing ? 10 : 0, vertical: widget.playing ? 4 : 0),
      margin: const EdgeInsets.only(bottom: AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: widget.playing ? AppColors.goldWash.withValues(alpha: 0.75) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?basmala,
          GestureDetector(
            // Ayah-level tap lives here rather than on the spans: each word
            // span can hold only one recognizer, and that slot is the
            // long-press. A tap that no word claims falls through to this.
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: verse,
          ),
          if (widget.transliteration != null && widget.transliteration!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.transliteration!,
                style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, height: 1.55),
              ),
            ),
          AnimatedSize(
            duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: widget.showTranslation
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      widget.ayah.translation,
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.6),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
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
