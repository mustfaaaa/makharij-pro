// The two pieces Rattil AI gained for FR-16 and "follow along": the reciter
// picker, and the ayah shown while it is recited.
//
// The screen itself cannot be pumped here -- its player constructs an
// AudioPlayer, which needs a platform -- so these are tested on their own. What
// they pin is layout under pressure (a narrow phone, the longest ayah in the
// Quran at the largest text size) and the picker's behaviour; Flutter's test
// binding fails a test on any overflow, so "no exception" is the assertion.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/app/cubit/verse_text_size_cubit.dart';
import 'package:frontend/features/ask_ai/presentation/widgets/rattil_widgets.dart';
import 'package:frontend/models/qari.dart';
import 'package:frontend/services/quran_text_repository.dart';

const _short = [1, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114];
final _qaris = [
  Qari(
    qariId: 'abdurrahmaan_as_sudais',
    nameEnglish: 'Abdul Rahman As-Sudais',
    nameArabic: 'عبد الرحمن السديس',
    availableSurahs: [for (var i = 1; i <= 114; i++) i],
  ),
  const Qari(qariId: 'alafasy', nameEnglish: 'Mishary Rashid Alafasy', nameArabic: 'مشاري راشد العفاسي', availableSurahs: _short),
  const Qari(qariId: 'yasser_ad_dussary', nameEnglish: 'Yasser Al-Dosari', nameArabic: 'ياسر الدوسري', availableSurahs: _short),
];

Widget _frame(Widget child, {double width = 360, VerseTextSizeCubit? cubit}) => BlocProvider(
      create: (_) => cubit ?? VerseTextSizeCubit(),
      child: MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('QariPicker', () {
    testWidgets('one pill per reciter, named the way people say it, with their coverage', (tester) async {
      await tester.pumpWidget(_frame(QariPicker(qaris: _qaris, selected: _qaris.first, totalSurahs: 114, onPick: (_) {})));

      expect(find.text('Sudais'), findsOneWidget);
      expect(find.text('Alafasy'), findsOneWidget);
      expect(find.text('Dosari'), findsOneWidget);
      expect(find.text('Whole Quran'), findsOneWidget);
      expect(find.text('15 surahs'), findsNWidgets(2));
    });

    testWidgets('tapping a pill picks that reciter', (tester) async {
      Qari? picked;
      await tester.pumpWidget(_frame(QariPicker(qaris: _qaris, selected: _qaris.first, totalSurahs: 114, onPick: (q) => picked = q)));

      await tester.tap(find.text('Alafasy'));
      await tester.pumpAndSettle();
      expect(picked?.qariId, 'alafasy');
    });

    testWidgets('screen readers hear who is selected and what they have', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_frame(QariPicker(qaris: _qaris, selected: _qaris[1], totalSurahs: 114, onPick: (_) {})));

      final selected = tester.getSemantics(find.bySemanticsLabel(RegExp('Mishary Rashid Alafasy')));
      expect(selected.label, contains('15 surahs'));
      expect(selected, isSemantics(isButton: true, isSelected: true));
      final other = tester.getSemantics(find.bySemanticsLabel(RegExp('Abdul Rahman As-Sudais')));
      expect(other, isSemantics(isButton: true, isSelected: false));
      handle.dispose();
    });

    testWidgets('fits a 320-wide phone without overflowing', (tester) async {
      await tester.pumpWidget(_frame(QariPicker(qaris: _qaris, selected: _qaris.first, totalSurahs: 114, onPick: (_) {}), width: 320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('every pill is at least 48 tall -- a real touch target', (tester) async {
      await tester.pumpWidget(_frame(QariPicker(qaris: _qaris, selected: _qaris.first, totalSurahs: 114, onPick: (_) {})));
      for (final name in ['Sudais', 'Alafasy', 'Dosari']) {
        final pill = find.ancestor(of: find.text(name), matching: find.byType(AnimatedContainer));
        expect(tester.getSize(pill).height, greaterThanOrEqualTo(48), reason: name);
      }
    });
  });

  group('RattilAyahText', () {
    testWidgets('shows the Arabic and its translation', (tester) async {
      await tester.pumpWidget(_frame(const RattilAyahText(arabic: 'نص', translation: 'A translation')));
      expect(find.text('نص'), findsOneWidget);
      expect(find.text('A translation'), findsOneWidget);
    });

    testWidgets('the longest ayah, at the largest size, on a narrow phone, stays inside the card', (tester) async {
      final ayahs = await tester.runAsync(() => QuranTextRepository.instance.ayahsForSurah(2));
      final longest = ayahs!.firstWhere((a) => a.number == 282);
      final cubit = VerseTextSizeCubit();
      await cubit.setSize(VerseTextSize.large);

      await tester.pumpWidget(_frame(
        RattilAyahText(arabic: longest.arabicText, translation: longest.translation),
        width: 320,
        cubit: cubit,
      ));
      expect(tester.takeException(), isNull);
      // Capped, and scrollable within the cap rather than growing the card.
      expect(tester.getSize(find.byType(RattilAyahText)).height, lessThanOrEqualTo(260));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('the Arabic is laid out right to left', (tester) async {
      await tester.pumpWidget(_frame(const RattilAyahText(arabic: 'نص', translation: 't')));
      final arabic = tester.widget<Text>(find.text('نص'));
      expect(arabic.textDirection, TextDirection.rtl);
    });
  });
}
