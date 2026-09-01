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
import 'package:frontend/theme/app_colors.dart';

const _ayah = Ayah(
  number: 2,
  arabicText: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
  translation: 'All praise is due to Allah, Lord of the worlds.',
);

/// Colour each word span was painted with, in reading order.
List<Color?> _wordColors(WidgetTester tester) {
  final richText = tester.widget<RichText>(find.byType(RichText).first);
  final colors = <Color?>[];
  richText.text.visitChildren((span) {
    if (span is TextSpan && span.text != null && span.text!.trim().isNotEmpty) {
      colors.add(span.style?.color);
    }
    return true;
  });
  return colors;
}

Future<void> _pump(WidgetTester tester, Map<int, WordTone> tones) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MushafAyah(ayah: _ayah, fontSize: 24, tones: tones),
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
      await _pump(tester, const {0: WordTone.recited, 1: WordTone.recited});
      final colors = _wordColors(tester);

      expect(colors[0], AppColors.textPrimary);
      expect(colors[1], AppColors.textPrimary);
      expect(colors[2], AppColors.textMuted, reason: 'not reached yet');
      expect(colors[3], AppColors.textMuted, reason: 'not reached yet');
    });

    testWidgets('a flagged word is the only thing painted in the error colour', (tester) async {
      await _pump(tester, const {
        0: WordTone.recited,
        1: WordTone.flagged,
        2: WordTone.recited,
      });
      final colors = _wordColors(tester);

      expect(colors[1], AppColors.errorHighlight);
      expect(colors.where((c) => c == AppColors.errorHighlight), hasLength(1));
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
