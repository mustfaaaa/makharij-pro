import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../models/ayah.dart';
import '../../../../models/quran_script.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../services/quran_script_repository.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';
import 'mushaf_ayah.dart';

/// One ayah as a [MushafParagraph] writes it.
class ParagraphAyah {
  /// The bundled text's ayah: its word indices are the ones [marks],
  /// [referenceWords] and the callbacks use, whichever script is drawn.
  final Ayah ayah;

  /// How each of those words is written in the chosen script.
  final ScriptedAyah text;

  /// Where the ayah sits among the rukus, for the ruku mark and for screen
  /// readers. Null only in tests.
  final AyahPlacement? placement;

  /// How many leading words are the Basmala the bundled text opens ayah 1
  /// with. They are set on their own centred line above the paragraph.
  final int leadingCenteredWords;

  /// Verdict per word index. Missing entries fall back to [WordMark.pending].
  final Map<int, WordMark> marks;

  /// Words carrying a Tajweed rule the reader asked to see -- a soft tint,
  /// deliberately unlike the underline of a mistake.
  final Set<int> referenceWords;

  const ParagraphAyah({
    required this.ayah,
    required this.text,
    this.placement,
    this.leadingCenteredWords = 0,
    this.marks = const {},
    this.referenceWords = const {},
  });
}

/// [ayahs] (consecutive, from [surah]) grouped the way the mushaf paragraphs
/// them: a paragraph closes where a ruku does, or where [ayahs] runs out.
/// Needs QuranScriptRepository loaded; before that, every ayah stands alone.
///
/// Each ayah in [breakBefore] also opens a new paragraph, so the page can set
/// something between the lines there -- where a recitation begins, or where a
/// juz does -- without breaking into the text.
List<List<Ayah>> paragraphsByRuku(int surah, List<Ayah> ayahs, {Set<int> breakBefore = const {}}) {
  final repo = QuranScriptRepository.instance;
  final paragraphs = <List<Ayah>>[];
  var current = <Ayah>[];
  for (final ayah in ayahs) {
    if (current.isNotEmpty && breakBefore.contains(ayah.number)) {
      paragraphs.add(current);
      current = [];
    }
    current.add(ayah);
    if (repo.placement(surah, ayah.number)?.endsRuku ?? true) {
      paragraphs.add(current);
      current = [];
    }
  }
  if (current.isNotEmpty) paragraphs.add(current);
  return paragraphs;
}

/// How many leading words of [ayah] are the Basmala the bundled text prefixes
/// to ayah 1 of every surah but Al-Fatihah (where it *is* ayah 1) and
/// At-Tawbah (which has none). Mirrors the backend's basmala_prefix_len.
int basmalaWordsIn(int surah, Ayah ayah) =>
    (ayah.number == 1 && surah != 1 && surah != 9 && ayah.arabicText.split(' ').length > 4) ? 4 : 0;

/// A translation or transliteration shown under the paragraph for one ayah.
class AyahNote {
  final int ayah;
  final String? transliteration;
  final String? translation;
  const AyahNote({required this.ayah, this.transliteration, this.translation});
}

/// A run of ayahs written continuously, as a printed mushaf writes them: one
/// ayah follows the last on the same line, each closed by its own mark.
///
/// The reader gives it one ruku at a time. Rukus are the mushaf's own
/// paragraphs, and keeping each one a single piece of text is what lets a
/// 286-ayah surah scroll smoothly instead of laying out six thousand words at
/// once.
///
/// Gestures are resolved on the laid-out text rather than on each word: tap
/// anywhere on an ayah for [onAyahTap], hold a word for [onWordLongPress]. A
/// span holds only one recognizer, and hundreds of recognizers per paragraph
/// would cost more than one hit test.
class MushafParagraph extends StatefulWidget {
  final List<ParagraphAyah> ayahs;
  final QuranScript script;
  final double fontSize;

  /// Reading rather than practising: words with no verdict are drawn in full
  /// ink. Off, they rest in the softer "not heard yet" tone.
  final bool readingMode;

  final Color? referenceColor;

  /// The ayah a Qari is reciting now.
  final int? playingAyah;

  /// Ayahs the page is pointing at -- one whose translation sheet is open --
  /// tinted so the reader can see which ayah it belongs to.
  final Set<int> selectedAyahs;

  final List<AyahNote> notes;

  final void Function(int ayah)? onAyahTap;
  final void Function(int ayah, int wordIndex)? onWordLongPress;

  const MushafParagraph({
    super.key,
    required this.ayahs,
    required this.script,
    required this.fontSize,
    this.readingMode = false,
    this.referenceColor,
    this.playingAyah,
    this.selectedAyahs = const {},
    this.notes = const [],
    this.onAyahTap,
    this.onWordLongPress,
  });

  @override
  State<MushafParagraph> createState() => MushafParagraphState();
}

/// Where one word, or an ayah's closing mark ([word] == -1), sits in the text.
class _Range {
  final int start;
  final int end;
  final int ayah;
  final int word;
  const _Range(this.start, this.end, this.ayah, this.word);
}

class _Spans {
  final List<InlineSpan> spans = [];
  final List<_Range> ranges = [];
  int _offset = 0;

  void add(InlineSpan span, {int? ayah, int? word}) {
    final length = span is TextSpan ? (span.text?.length ?? 0) : 1;
    if (ayah != null && word != null) ranges.add(_Range(_offset, _offset + length, ayah, word));
    spans.add(span);
    _offset += length;
  }
}

class MushafParagraphState extends State<MushafParagraph> with SingleTickerProviderStateMixin {
  final _mainKey = GlobalKey();
  final _basmalaKey = GlobalKey();
  List<_Range> _mainRanges = const [];
  List<_Range> _basmalaRanges = const [];

  /// Words do not snap from one tone to the next: a verdict arriving mid
  /// recitation carries each changed word from the colour it was showing to
  /// its new one. Decoration only -- `widget.ayahs[].marks` is the truth.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..value = 1.0;
  Map<int, Color> _fadeFrom = const {};

  static int _key(int ayah, int word) => ayah * 1000 + word;

  @override
  void didUpdateWidget(MushafParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = {for (final a in oldWidget.ayahs) a.ayah.number: a};
    final changed = <int, Color>{};
    for (final a in widget.ayahs) {
      final previous = before[a.ayah.number];
      if (previous == null) continue;
      for (var i = 0; i < a.text.words.length; i++) {
        final from = _target(previous.marks[i] ?? WordMark.pending, oldWidget.readingMode);
        final to = _target(a.marks[i] ?? WordMark.pending, widget.readingMode);
        if (from != to) changed[_key(a.ayah.number, i)] = _painted(previous, i, oldWidget.readingMode);
      }
    }
    if (changed.isEmpty) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _fadeFrom = const {};
      _fade.value = 1.0;
      return;
    }
    _fadeFrom = changed;
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  // ── Scrolling support ─────────────────────────────────────────────────────

  /// The laid-out text holding [ayah] and the rect where it begins, so the
  /// page can bring that exact line into view. Null before layout.
  ({RenderBox box, Rect rect})? locate(int ayah) {
    for (final (key, ranges) in [(_basmalaKey, _basmalaRanges), (_mainKey, _mainRanges)]) {
      final paragraph = key.currentContext?.findRenderObject();
      if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
      for (final r in ranges) {
        if (r.ayah != ayah) continue;
        final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: r.start, extentOffset: r.end));
        if (boxes.isEmpty) continue;
        return (box: paragraph, rect: boxes.first.toRect());
      }
    }
    return null;
  }

  /// The ayah written at [global] (a point on screen), for remembering where
  /// the reader stopped. Points above or below the text clamp to its first or
  /// last ayah.
  int? ayahAt(Offset global) {
    final paragraph = _mainKey.currentContext?.findRenderObject();
    if (paragraph is! RenderParagraph || !paragraph.hasSize || _mainRanges.isEmpty) return null;
    final local = paragraph.globalToLocal(global);
    if (local.dy <= 0) return _mainRanges.first.ayah;
    if (local.dy >= paragraph.size.height) return _mainRanges.last.ayah;
    final offset = paragraph
        .getPositionForOffset(Offset(local.dx.clamp(0, paragraph.size.width), local.dy))
        .offset;
    for (final r in _mainRanges) {
      if (offset < r.end) return r.ayah;
    }
    return _mainRanges.last.ayah;
  }

  // ── Gestures ──────────────────────────────────────────────────────────────

  /// The word or ayah mark under [global] in the text behind [key], or null
  /// when the touch landed on empty space between lines or past the text.
  _Range? _hit(GlobalKey key, List<_Range> ranges, Offset global) {
    final paragraph = key.currentContext?.findRenderObject();
    if (paragraph is! RenderParagraph) return null;
    final local = paragraph.globalToLocal(global);
    final offset = paragraph.getPositionForOffset(local).offset;
    // A caret sits between characters, so the touched one is on either side.
    for (final r in ranges) {
      if (r.start > offset || r.end < offset) continue;
      final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: r.start, extentOffset: r.end));
      if (boxes.any((b) => b.toRect().inflate(6).contains(local))) return r;
    }
    return null;
  }

  Widget _touchable(GlobalKey key, List<_Range> Function() ranges, Widget text) {
    final tap = widget.onAyahTap;
    final hold = widget.onWordLongPress;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: tap == null
          ? null
          : (details) {
              final hit = _hit(key, ranges(), details.globalPosition);
              if (hit != null) tap(hit.ayah);
            },
      onLongPressStart: hold == null
          ? null
          : (details) {
              final hit = _hit(key, ranges(), details.globalPosition);
              if (hit != null && hit.word >= 0) hold(hit.ayah, hit.word);
            },
      child: text,
    );
  }

  // ── Colour ────────────────────────────────────────────────────────────────

  Color _target(WordMark mark, bool reading) {
    switch (mark.tone) {
      case WordTone.pending:
        return reading ? AppColors.textPrimary : AppColors.verseResting;
      case WordTone.recited:
        return AppColors.textPrimary;
      case WordTone.flagged:
        return mark.rule == null ? AppColors.errorHighlight : TajweedRuleStyle.color(mark.rule!);
    }
  }

  Color _painted(ParagraphAyah a, int word, bool reading) {
    final target = _target(a.marks[word] ?? WordMark.pending, reading);
    final from = _fadeFrom[_key(a.ayah.number, word)];
    if (from == null || _fade.isCompleted) return target;
    return Color.lerp(from, target, Curves.easeOut.transform(_fade.value)) ?? target;
  }

  /// The tint behind an ayah the page is pointing at: the one a Qari is
  /// reciting, or one whose note is open.
  Color? _ayahTint(int ayah) {
    if (ayah == widget.playingAyah) return AppColors.goldWash.withValues(alpha: 0.9);
    if (widget.selectedAyahs.contains(ayah)) return AppColors.goldWash.withValues(alpha: 0.55);
    return null;
  }

  /// The start-of-hizb-quarter sign (۞) or the sajda sign (۩) standing on its
  /// own: illumination, not a word.
  static bool _isOrnament(String text) => text.runes.every((r) => r == 0x06DE || r == 0x06E9);

  TextStyle _base({Color? color, Color? background}) => AppTypography.quranScript(
        widget.script,
        fontSize: widget.fontSize,
        color: color,
      ).copyWith(backgroundColor: background);

  TextStyle _wordStyle(ParagraphAyah a, int i, {required bool tinted}) {
    final mark = a.marks[i] ?? WordMark.pending;
    final word = a.text.words[i];
    final tint = tinted ? _ayahTint(a.ayah.number) : null;
    if (_isOrnament(word)) return _base(color: AppColors.goldInk, background: tint);

    var style = _base(color: _painted(a, i, widget.readingMode), background: tint);
    if (a.referenceWords.contains(i) && mark.tone != WordTone.flagged) {
      style = style.copyWith(backgroundColor: (widget.referenceColor ?? AppColors.gold).withValues(alpha: 0.16));
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

  String? _wordSemantics(String word, WordMark mark) => mark.tone == WordTone.flagged
      ? '$word, needs attention${mark.rule == null ? '' : ': ${mark.rule!.label}'}'
      : null;

  String _endSemantics(ParagraphAyah a) {
    final place = a.placement;
    return [
      'end of ayah ${a.ayah.number}',
      if (place?.sajdah != null) 'place of sajdah',
      if (place != null && place.endsRuku) 'end of ruku ${place.rukuInSurah}',
    ].join(', ');
  }

  // ── Building ──────────────────────────────────────────────────────────────

  /// [tinted] is false for the Basmala line: it opens the surah rather than
  /// belonging to ayah 1, and the Qari's recording of ayah 1 does not say it,
  /// so it never lights up with that ayah.
  void _writeWords(_Spans out, ParagraphAyah a, int from, int to, {bool tinted = true}) {
    final tint = tinted ? _ayahTint(a.ayah.number) : null;
    for (var i = from; i < to; i++) {
      final word = a.text.words[i];
      if (word.isEmpty) continue;
      final mark = a.marks[i] ?? WordMark.pending;
      out.add(
        TextSpan(text: word, style: _wordStyle(a, i, tinted: tinted), semanticsLabel: _wordSemantics(word, mark)),
        ayah: a.ayah.number,
        word: i,
      );
      out.add(TextSpan(text: ' ', style: _base(background: tint)));
    }
  }

  void _writeEnd(_Spans out, ParagraphAyah a) {
    out.add(
      TextSpan(
        text: a.text.end,
        style: _base(color: AppColors.goldInk, background: _ayahTint(a.ayah.number)),
        semanticsLabel: _endSemantics(a),
      ),
      ayah: a.ayah.number,
      word: -1,
    );
    // The IndoPak font draws the ruku sign above the ayah circle itself. The
    // Madinah mushaf does not mark rukus at all, so the Uthmani text gets the
    // same ع, small and in gold, where the ruku ends.
    if (widget.script == QuranScript.uthmani && (a.placement?.endsRuku ?? false)) {
      out.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'ع',
              style: AppTypography.quranScript(
                QuranScript.uthmani,
                fontSize: widget.fontSize * 0.6,
                color: AppColors.goldInk,
                height: 1.0,
              ),
            ),
          ),
        ),
      ));
    }
    out.add(TextSpan(text: ' ', style: _base()));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final first = widget.ayahs.first;
    final lead = first.leadingCenteredWords.clamp(0, first.text.words.length);

    final text = AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final basmala = _Spans();
        if (lead > 0) _writeWords(basmala, first, 0, lead, tinted: false);
        final main = _Spans();
        for (final a in widget.ayahs) {
          _writeWords(main, a, identical(a, first) ? lead : 0, a.text.words.length);
          _writeEnd(main, a);
        }
        _basmalaRanges = basmala.ranges;
        _mainRanges = main.ranges;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lead > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _touchable(
                  _basmalaKey,
                  () => _basmalaRanges,
                  Text.rich(
                    TextSpan(children: basmala.spans),
                    key: _basmalaKey,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            _touchable(
              _mainKey,
              () => _mainRanges,
              Text.rich(
                TextSpan(children: main.spans),
                key: _mainKey,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
              ),
            ),
          ],
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text,
          AnimatedSize(
            duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: widget.notes.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final note in widget.notes)
                          _Note(note: note, textTheme: textTheme, numbered: widget.ayahs.length > 1),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final AyahNote note;
  final TextTheme textTheme;

  /// Whether to say which ayah this is: needed when the paragraph holds
  /// several, redundant when the note sits right under its only ayah.
  final bool numbered;
  const _Note({required this.note, required this.textTheme, required this.numbered});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (numbered)
            SizedBox(
              width: 32,
              child: Text(
                '${note.ayah}',
                style: textTheme.labelMedium?.copyWith(color: AppColors.goldInk),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.transliteration != null && note.transliteration!.isNotEmpty)
                  Text(
                    note.transliteration!,
                    style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, height: 1.55),
                  ),
                if (note.translation != null)
                  Text(
                    note.translation!,
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.6),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
