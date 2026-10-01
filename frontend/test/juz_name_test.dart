import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/quran/presentation/widgets/juz_list.dart';
import 'package:frontend/models/juz_name.dart';
import 'package:frontend/services/juz_division.dart';

void main() {
  test('all thirty traditional para names are present in order', () {
    expect(juzNames.length, 30);
    expect(
      juzNames.map((name) => name.number),
      List.generate(30, (i) => i + 1),
    );

    expect(juzName(1).transliteration, 'Alif Laam Meem');
    expect(juzName(4).arabic, 'لَن تَنَالُوا۟');
    expect(juzName(11).arabic, 'يَعْتَذِرُونَ');
    expect(juzName(21).transliteration, 'Utlu Ma Uhiya');
    expect(juzName(30).arabic, 'عَمَّ يَتَسَآءَلُونَ');
  });

  test('invalid juz numbers are rejected', () {
    expect(() => juzName(0), throwsRangeError);
    expect(() => juzName(31), throwsRangeError);
  });

  testWidgets(
    'juz row shows the traditional name without repeating its number',
    (tester) async {
      await tester.runAsync(() async => JuzDivision.load());
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CustomScrollView(slivers: [JuzSliverList()])),
        ),
      );
      await tester.pump();

      expect(find.text('Alif Laam Meem'), findsOneWidget);
      expect(find.text('الٓمٓ'), findsOneWidget);
      expect(find.text('Juz 1'), findsNothing);
    },
  );
}
