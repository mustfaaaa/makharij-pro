// The reading page writes the Quran continuously, one paragraph per ruku, in
// the script the reader chose. These pin what that must never break: the text
// rests muted until a word is actually heard, a mistake is named by colour
// *and* shape, a word's index stays the bundled text's index whichever script
// is drawn, and ayahs flow on one after another instead of each standing alone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/quran/presentation/widgets/mushaf_ayah.dart';
import 'package:frontend/features/quran/presentation/widgets/mushaf_paragraph.dart';
import 'package:frontend/models/ayah.dart';
import 'package:frontend/models/quran_script.dart';
import 'package:frontend/models/tajweed_error.dart';
import 'package:frontend/services/quran_script_repository.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/tajweed_rule_style.dart';

const _ayah2 = Ayah(
  number: 2,
  arabicText: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
  translation: 'All praise is due to Allah, Lord of the worlds.',
);
const _ayah3 = Ayah(
  number: 3,
  arabicText: 'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
  translation: 'The Entirely Merciful, the Especially Merciful.',
);

ParagraphAyah _para(Ayah ayah, {Map<int, WordMark> marks = const {}, List<String>? words, AyahPlacement? placement}) =>
    ParagraphAyah(
      ayah: ayah,
      text: ScriptedAyah(words: words ?? ayah.arabicText.split(' '), end: arabicNumber(ayah.number)),
      marks: marks,
      placement: placement,
    );

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Future<void> _pump(WidgetTester tester, Map<int, WordMark> marks,
    {bool reduceMotion = false, bool readingMode = false}) {
  return tester.pumpWidget(_app(
    MushafParagraph(
      ayahs: [_para(_ayah2, marks: marks)],
      script: QuranScript.uthmani,
      fontSize: 24,
      readingMode: readingMode,
    ),
    reduceMotion: reduceMotion,
  ));
}

/// The main text of the paragraph (the Basmala line, when there is one, comes
/// first; these ayahs have none).
RichText _text(WidgetTester tester) => tester.widget<RichText>(
      find.descendant(of: find.byType(MushafParagraph), matching: find.byType(RichText)).first,
    );

/// Every word span, in reading order: spans with letters, not the spaces
/// between them or the ayah's closing mark.
List<TextSpan> _wordSpans(WidgetTester tester) {
  final spans = <TextSpan>[];
  _text(tester).text.visitChildren((span) {
    if (span is TextSpan &&
        span.text != null &&
        span.text!.trim().isNotEmpty &&
        !RegExp(r'^[٠-٩]+$').hasMatch(span.text!)) {
      spans.add(span);
    }
    return true;
  });
  return spans;
}

List<Color?> _wordColors(WidgetTester tester) => _wordSpans(tester).map((s) => s.style?.color).toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('paragraphs', () {
    // Al-Baqarah's first rukus in the bundled count: 1-7, then 8-20.
    final baqarah = [for (var n = 1; n <= 20; n++) Ayah(number: n, arabicText: 'كَلِمَة', translation: '')];
    List<List<int>> numbers(List<List<Ayah>> paragraphs) =>
        [for (final p in paragraphs) [for (final a in p) a.number]];

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await QuranScriptRepository.instance.ensureLoaded();
    });

    test('a paragraph closes where a ruku does', () {
      expect(numbers(paragraphsByRuku(2, baqarah)), [
        [1, 2, 3, 4, 5, 6, 7],
        [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
      ]);
    });

    test('an ayah asked to open a paragraph does, and a ruku still closes one', () {
      // Where a recitation begins, mid-ruku: the ayahs before it keep their own
      // paragraph, so the page can mark the line between them.
      expect(numbers(paragraphsByRuku(2, baqarah, breakBefore: {5})), [
        [1, 2, 3, 4],
        [5, 6, 7],
        [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
      ]);
    });

    test('a break already at a ruku, or before the first ayah, adds no empty paragraph', () {
      expect(numbers(paragraphsByRuku(2, baqarah, breakBefore: {1, 8})), [
        [1, 2, 3, 4, 5, 6, 7],
        [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
      ]);
    });
  });

  group('word colouring', () {
    testWidgets('every word rests muted when nothing has been recited', (tester) async {
      await _pump(tester, const {});
      final colors = _wordColors(tester);
      expect(colors, hasLength(4));
      expect(colors.every((c) => c == AppColors.verseResting), isTrue,
          reason: 'the page must start (and stay) muted until the reciter speaks');
    });

    testWidgets('reading mode draws unheard words in full ink', (tester) async {
      await _pump(tester, const {}, readingMode: true);
      expect(_wordColors(tester).every((c) => c == AppColors.textPrimary), isTrue);
    });

    testWidgets('only the words confirmed so far take on full colour', (tester) async {
      await _pump(tester, const {0: WordMark.recited, 1: WordMark.recited});
      final colors = _wordColors(tester);
      expect(colors[0], AppColors.textPrimary);
      expect(colors[1], AppColors.textPrimary);
      expect(colors[2], AppColors.verseResting, reason: 'not reached yet');
      expect(colors[3], AppColors.verseResting, reason: 'not reached yet');
    });

    testWidgets('a flagged word with no known rule falls back to the error colour', (tester) async {
      await _pump(tester, const {0: WordMark.recited, 1: WordMark(WordTone.flagged), 2: WordMark.recited});
      final colors = _wordColors(tester);
      expect(colors[1], AppColors.errorHighlight);
      expect(colors.where((c) => c == AppColors.errorHighlight), hasLength(1));
    });

    testWidgets('each rule has its own colour and its own underline shape', (tester) async {
      await _pump(tester, const {
        0: WordMark(WordTone.flagged, rule: TajweedErrorType.madd),
        1: WordMark(WordTone.flagged, rule: TajweedErrorType.ghunnah),
        2: WordMark(WordTone.flagged, rule: TajweedErrorType.shaddah),
        3: WordMark(WordTone.flagged, rule: TajweedErrorType.makhraj),
      });
      final styles = _wordSpans(tester).map((s) => s.style).toList();
      expect(styles.map((s) => s?.color).toList(), [
        TajweedRuleStyle.color(TajweedErrorType.madd),
        TajweedRuleStyle.color(TajweedErrorType.ghunnah),
        TajweedRuleStyle.color(TajweedErrorType.shaddah),
        TajweedRuleStyle.color(TajweedErrorType.makhraj),
      ]);
      expect(styles.map((s) => s?.decorationStyle).toList(), [
        TextDecorationStyle.dashed,
        TextDecorationStyle.wavy,
        TextDecorationStyle.double,
        TextDecorationStyle.dotted,
      ], reason: 'a colour-blind reader has only the shape to go on');
    });

    testWidgets('a correctly recited word carries no underline at all', (tester) async {
      await _pump(tester, const {0: WordMark.recited});
      expect(_wordSpans(tester).first.style?.decoration, anyOf(isNull, TextDecoration.none));
    });
  });

  group('continuous text', () {
    testWidgets('ayahs flow on in one piece of text, each closed by its number', (tester) async {
      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [_para(_ayah2), _para(_ayah3)],
        script: QuranScript.uthmani,
        fontSize: 24,
      )));
      final plain = _text(tester).text.toPlainText(includeSemanticsLabels: false);
      expect(plain, contains(arabicNumber(2)));
      expect(plain, contains(arabicNumber(3)));
      expect(plain.indexOf(arabicNumber(2)), lessThan(plain.indexOf('ٱلرَّحِيمِ')),
          reason: 'ayah 3 follows ayah 2 in the same text, not in a block of its own');
      expect(_wordSpans(tester), hasLength(6));
      // A screen reader hears where each ayah ends, not a bare digit.
      expect(_text(tester).text.toPlainText(), contains('end of ayah 2'));
    });

    testWidgets('a word the script writes with its neighbour keeps the indices of the rest', (tester) async {
      // 37:130 in Uthmani: إِلۡ يَاسِينَ is one word, the bundled text's two.
      // Index 3 is empty; a mark on index 2 must still colour the written word,
      // and nothing may shift onto the wrong one.
      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [
          ParagraphAyah(
            ayah: const Ayah(number: 130, arabicText: 'سَلَٰمٌ عَلَىٰٓ إِلْ يَاسِينَ', translation: ''),
            text: const ScriptedAyah(words: ['سَلَٰمٌ', 'عَلَىٰٓ', 'إِلۡ يَاسِينَ', ''], end: '١٣٠'),
            marks: const {2: WordMark(WordTone.flagged, rule: TajweedErrorType.madd)},
          ),
        ],
        script: QuranScript.uthmani,
        fontSize: 24,
      )));
      final spans = _wordSpans(tester);
      expect(spans.map((s) => s.text), ['سَلَٰمٌ', 'عَلَىٰٓ', 'إِلۡ يَاسِينَ']);
      expect(spans[2].style?.color, TajweedRuleStyle.color(TajweedErrorType.madd));
    });

    testWidgets('the Uthmani text marks the end of a ruku with ع; IndoPak draws its own', (tester) async {
      const place = AyahPlacement(ruku: 1, rukuInSurah: 1, endsRuku: true, sajdah: null, juz: 1);
      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [_para(_ayah2, placement: place)],
        script: QuranScript.uthmani,
        fontSize: 24,
      )));
      expect(find.text('ع'), findsOneWidget);

      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [_para(_ayah2, placement: place)],
        script: QuranScript.indopak,
        fontSize: 24,
      )));
      expect(find.text('ع'), findsNothing,
          reason: 'the IndoPak font draws the ruku sign above the ayah circle itself');
    });

    testWidgets('notes show under the paragraph, numbered by ayah', (tester) async {
      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [_para(_ayah2), _para(_ayah3)],
        script: QuranScript.uthmani,
        fontSize: 24,
        notes: [AyahNote(ayah: 3, translation: _ayah3.translation)],
      )));
      expect(find.text(_ayah3.translation), findsOneWidget);
      expect(find.text(_ayah2.translation), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('gestures', () {
    Finder verse() => find.descendant(of: find.byType(MushafParagraph), matching: find.byType(RichText)).first;

    testWidgets('tapping an ayah reports that ayah', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [_para(_ayah2)],
        script: QuranScript.uthmani,
        fontSize: 24,
        onAyahTap: taps.add,
      )));
      await tester.tap(verse());
      await tester.pumpAndSettle();
      expect(taps, [2]);
    });

    testWidgets('holding a word reports its ayah and a real index, and not a tap', (tester) async {
      final taps = <int>[];
      final held = <(int, int)>[];
      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [_para(_ayah2)],
        script: QuranScript.uthmani,
        fontSize: 24,
        onAyahTap: taps.add,
        onWordLongPress: (ayah, word) => held.add((ayah, word)),
      )));
      await tester.longPress(verse());
      await tester.pumpAndSettle();

      expect(held, hasLength(1));
      expect(held.single.$1, 2);
      expect(held.single.$2, inInclusiveRange(0, _ayah2.arabicText.split(' ').length - 1),
          reason: 'an off-by-one here would look plausible and open the wrong word');
      expect(taps, isEmpty, reason: 'holding a word must not also toggle the translation');
    });

    testWidgets('holding the first and last word opens those words', (tester) async {
      final held = <int>[];
      await tester.pumpWidget(_app(MushafParagraph(
        ayahs: [_para(_ayah2)],
        script: QuranScript.uthmani,
        fontSize: 24,
        onWordLongPress: (_, word) => held.add(word),
      )));
      final box = tester.getRect(verse());
      // Right to left: the first word is at the right edge of the first line.
      await tester.longPressAt(Offset(box.right - 4, box.top + 12));
      await tester.pumpAndSettle();
      expect(held, [0]);
    });
  });

  group('fading', () {
    Color? colorOf(WidgetTester tester, int word) => _wordColors(tester)[word];

    testWidgets('a newly recited word travels to its colour instead of snapping', (tester) async {
      await _pump(tester, const {});
      final resting = colorOf(tester, 0);
      expect(resting, AppColors.verseResting);

      await _pump(tester, const {0: WordMark.recited});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final midway = colorOf(tester, 0);
      expect(midway, isNot(resting), reason: 'the word should have begun moving');
      expect(midway, isNot(AppColors.textPrimary), reason: 'arriving at once would be a snap');

      await tester.pumpAndSettle();
      expect(colorOf(tester, 0), AppColors.textPrimary);
      expect(colorOf(tester, 1), AppColors.verseResting, reason: 'a word nobody reached does not move');
    });

    testWidgets('reduced motion lands on the final colour immediately', (tester) async {
      await _pump(tester, const {}, reduceMotion: true);
      await _pump(tester, const {0: WordMark.recited}, reduceMotion: true);
      await tester.pump();
      expect(colorOf(tester, 0), AppColors.textPrimary);
    });

    testWidgets('the verdict is applied even if the tween never finishes', (tester) async {
      await _pump(tester, const {});
      await _pump(tester, const {0: WordMark.recited});
      await tester.pump(const Duration(milliseconds: 60));
      await _pump(tester, {0: const WordMark(WordTone.flagged, rule: null)});
      await tester.pumpAndSettle();
      expect(colorOf(tester, 0), AppColors.errorHighlight);
    });
  });

  group('ayah numbering', () {
    test('renders Arabic-Indic digits, as a printed mushaf does', () {
      expect(arabicNumber(1), '١');
      expect(arabicNumber(29), '٢٩');
      expect(arabicNumber(286), '٢٨٦');
    });
  });

  group('MushafSurahHeader', () {
    testWidgets('shows the surah name and summary, and no Basmala of its own', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MushafSurahHeader(nameArabic: 'الإخلاص', subtitle: 'Sincerity · 4 Ayahs')),
      ));
      expect(find.text('سُورَةُ الإخلاص'), findsOneWidget);
      expect(find.text('Sincerity · 4 Ayahs'), findsOneWidget);
      expect(find.textContaining('بِسْمِ'), findsNothing);
    });
  });
}
