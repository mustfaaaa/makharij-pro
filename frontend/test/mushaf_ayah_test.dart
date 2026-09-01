// The reading page's core promise: the text rests in muted ink, stays muted
// when recording starts, and a word only takes on full colour once the live
// analysis confirms it was actually recited. These tests pin that, since it is
// the difference between showing the reciter their own progress and playing an
// animation at them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/quran/presentation/widgets/mushaf_ayah.dart';
import 'package:frontend/models/ayah.dart';
import 'package:frontend/models/tajweed_error.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/tajweed_rule_style.dart';

const _ayah = Ayah(
  number: 2,
  arabicText: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
  translation: 'All praise is due to Allah, Lord of the worlds.',
);

/// The style each word span was painted with, in reading order.
List<TextStyle?> _wordStyles(WidgetTester tester) {
  final richText = tester.widget<RichText>(find.byType(RichText).first);
  final styles = <TextStyle?>[];
  richText.text.visitChildren((span) {
    if (span is TextSpan && span.text != null && span.text!.trim().isNotEmpty) {
      styles.add(span.style);
    }
    return true;
  });
  return styles;
}

List<Color?> _wordColors(WidgetTester tester) =>
    _wordStyles(tester).map((s) => s?.color).toList();

Future<void> _pump(WidgetTester tester, Map<int, WordMark> marks) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MushafAyah(ayah: _ayah, fontSize: 24, marks: marks),
    ),
  ));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('MushafAyah word colouring', () {
    testWidgets('every word rests muted when nothing has been recited', (tester) async {
      await _pump(tester, const {});
      final colors = _wordColors(tester);

      expect(colors, hasLength(4));
      expect(colors.every((c) => c == AppColors.textMuted), isTrue,
          reason: 'the page must start (and stay) grey until the reciter speaks');
    });

    testWidgets('only the words confirmed so far take on full colour', (tester) async {
      await _pump(tester, const {0: WordMark.recited, 1: WordMark.recited});
      final colors = _wordColors(tester);

      expect(colors[0], AppColors.textPrimary);
      expect(colors[1], AppColors.textPrimary);
      expect(colors[2], AppColors.textMuted, reason: 'not reached yet');
      expect(colors[3], AppColors.textMuted, reason: 'not reached yet');
    });

    testWidgets('a flagged word with no known rule falls back to the error colour',
        (tester) async {
      await _pump(tester, const {
        0: WordMark.recited,
        1: WordMark(WordTone.flagged),
        2: WordMark.recited,
      });
      final colors = _wordColors(tester);

      expect(colors[1], AppColors.errorHighlight);
      expect(colors.where((c) => c == AppColors.errorHighlight), hasLength(1));
    });

    testWidgets('each rule paints its word in its own colour, not one shared red',
        (tester) async {
      await _pump(tester, const {
        0: WordMark(WordTone.flagged, rule: TajweedErrorType.madd),
        1: WordMark(WordTone.flagged, rule: TajweedErrorType.ghunnah),
        2: WordMark(WordTone.flagged, rule: TajweedErrorType.shaddah),
        3: WordMark(WordTone.flagged, rule: TajweedErrorType.makhraj),
      });
      final colors = _wordColors(tester).take(4).toList();

      expect(colors[0], TajweedRuleStyle.color(TajweedErrorType.madd));
      expect(colors[1], TajweedRuleStyle.color(TajweedErrorType.ghunnah));
      expect(colors[2], TajweedRuleStyle.color(TajweedErrorType.shaddah));
      expect(colors[3], TajweedRuleStyle.color(TajweedErrorType.makhraj));
      expect(colors.toSet(), hasLength(4), reason: 'the four rules must be distinguishable');
    });

    testWidgets('the rule is also carried by the underline, so colour is never the only signal',
        (tester) async {
      await _pump(tester, const {
        0: WordMark(WordTone.flagged, rule: TajweedErrorType.madd),
        1: WordMark(WordTone.flagged, rule: TajweedErrorType.ghunnah),
        2: WordMark(WordTone.flagged, rule: TajweedErrorType.shaddah),
        3: WordMark(WordTone.flagged, rule: TajweedErrorType.makhraj),
      });
      final styles = _wordStyles(tester).take(4).toList();

      expect(styles.map((s) => s?.decorationStyle).toSet(), hasLength(4),
          reason: 'a colour-blind reader has only the shape to go on');
      expect(styles[0]?.decorationStyle, TextDecorationStyle.dashed);
      expect(styles[1]?.decorationStyle, TextDecorationStyle.wavy);
      expect(styles[2]?.decorationStyle, TextDecorationStyle.double);
      expect(styles[3]?.decorationStyle, TextDecorationStyle.dotted);
    });

    testWidgets('a correctly recited word carries no underline at all', (tester) async {
      await _pump(tester, const {0: WordMark.recited});
      expect(_wordStyles(tester).first?.decoration, anyOf(isNull, TextDecoration.none));
    });

    testWidgets('translation is hidden until the ayah is tapped', (tester) async {
      await _pump(tester, const {});
      expect(find.text(_ayah.translation), findsNothing);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MushafAyah(ayah: _ayah, fontSize: 24, showTranslation: true),
        ),
      ));
      expect(find.text(_ayah.translation), findsOneWidget);
    });
  });

  group('ayah numbering', () {
    test('renders Arabic-Indic digits, as a printed mushaf does', () {
      expect(arabicNumber(1), '١');
      expect(arabicNumber(7), '٧');
      expect(arabicNumber(29), '٢٩');
      expect(arabicNumber(286), '٢٨٦');
    });
  });

  group('MushafSurahHeader', () {
    testWidgets('shows the surah name and summary, and no Basmala of its own',
        (tester) async {
      // The bundled Quran text already opens ayah 1 with the Basmala, so a
      // second one here would be a duplicate the analysis never scores.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MushafSurahHeader(nameArabic: 'الإخلاص', subtitle: 'Sincerity · 4 Ayahs'),
        ),
      ));

      expect(find.text('سُورَةُ الإخلاص'), findsOneWidget);
      expect(find.text('Sincerity · 4 Ayahs'), findsOneWidget);
      expect(find.textContaining('بِسْمِ'), findsNothing);
    });
  });
}
