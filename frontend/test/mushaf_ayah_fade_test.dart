// A verdict arriving mid-recitation used to repaint a word in a single frame.
// With several words settling at once that read as the page twitching rather
// than as progress, so the colour now travels from what the word was showing to
// what it becomes.
//
// What matters here is that it *travels*: a snap and a tween look identical if
// you only ever check the start and the end, so these check the middle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/quran/presentation/widgets/mushaf_ayah.dart';
import 'package:frontend/models/ayah.dart';
import 'package:frontend/theme/app_colors.dart';

const _ayah = Ayah(
  number: 1,
  arabicText: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
  translation: 'Say, He is Allah, One.',
);

List<TextStyle?> _wordStyles(WidgetTester tester) {
  final styles = <TextStyle?>[];
  final richText = tester.widget<RichText>(find.byType(RichText).first);
  richText.text.visitChildren((span) {
    if (span is TextSpan && (span.text ?? '').trim().isNotEmpty) {
      styles.add(span.style);
    }
    return true;
  });
  return styles;
}

Color? _colorOf(WidgetTester tester, int index) => _wordStyles(tester)[index]?.color;

Future<void> _pump(WidgetTester tester, Map<int, WordMark> marks,
    {bool reduceMotion = false}) {
  return tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: MushafAyah(ayah: _ayah, fontSize: 24, marks: marks),
      ),
    ),
  ));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a newly recited word travels to its colour instead of snapping',
      (tester) async {
    await _pump(tester, const {});
    final resting = _colorOf(tester, 0);
    expect(resting, AppColors.verseResting);

    await _pump(tester, const {0: WordMark.recited});
    await tester.pump();                                   // start the tween
    await tester.pump(const Duration(milliseconds: 120));  // partway

    final midway = _colorOf(tester, 0);
    expect(midway, isNot(resting),
        reason: 'the word should have begun moving');
    expect(midway, isNot(AppColors.textPrimary),
        reason: 'it should not have arrived yet -- that would be a snap');

    await tester.pumpAndSettle();
    expect(_colorOf(tester, 0), AppColors.textPrimary);
  });

  testWidgets('words nobody has reached do not animate', (tester) async {
    await _pump(tester, const {});
    await _pump(tester, const {0: WordMark.recited});
    await tester.pump(const Duration(milliseconds: 120));

    // Word 1 was never marked, so it has nothing to travel to and must sit
    // still while its neighbour changes.
    expect(_colorOf(tester, 1), AppColors.verseResting);
  });

  testWidgets('reduced motion lands on the final colour immediately',
      (tester) async {
    await _pump(tester, const {}, reduceMotion: true);
    await _pump(tester, const {0: WordMark.recited}, reduceMotion: true);
    await tester.pump();

    expect(_colorOf(tester, 0), AppColors.textPrimary,
        reason: 'someone who asked for less motion gets the answer, not a tween');
  });

  testWidgets('the verdict is applied even if the tween never finishes',
      (tester) async {
    // Correctness must not depend on an animation completing: a second verdict
    // can interrupt the first, and the mark is the truth either way.
    await _pump(tester, const {});
    await _pump(tester, const {0: WordMark.recited});
    await tester.pump(const Duration(milliseconds: 60));
    await _pump(tester, {0: const WordMark(WordTone.flagged, rule: null)});
    await tester.pumpAndSettle();

    expect(_colorOf(tester, 0), AppColors.errorHighlight);
  });
}
