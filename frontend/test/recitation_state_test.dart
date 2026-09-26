// The reading page shows a whole surah; the recitation covers part of it.
// These pin which ayahs belong to the recitation for each kind of span, and
// that the from/to getters older screens read still say the same thing.
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/recitation/presentation/bloc/recitation_state.dart';
import 'package:frontend/models/ayah.dart';
import 'package:frontend/models/quran_position.dart';
import 'package:frontend/models/recitation_span.dart';

void main() {
  final baqarah = [for (var n = 1; n <= 286; n++) Ayah(number: n, arabicText: 'كَلِمَة', translation: '')];

  RecitationState stateWith(RecitationSpan span) =>
      RecitationState(surahNumber: 2, ayahs: baqarah, span: span);

  test('beginning at an ayah covers it and every ayah after it, and none before', () {
    final state = stateWith(RecitationSpan.inSurah(2, fromAyah: 57));
    expect(state.sessionAyahs.first.number, 57);
    expect(state.sessionAyahs.last.number, 286);
    expect(state.sessionAyahs.length, 230);
    expect(state.fromAyah, 57);
    expect(state.toAyah, isNull);
    expect(state.passageLabel, 'From ayah 57');
  });

  test('a fixed range covers exactly its ayahs', () {
    final state = stateWith(RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 60));
    expect(state.sessionAyahs.map((a) => a.number), [57, 58, 59, 60]);
    expect(state.toAyah, 60);
    expect(state.passageLabel, 'Ayahs 57–60');
  });

  test('labels: an open recitation is "from" an ayah, since it runs on past the surah', () {
    expect(stateWith(RecitationSpan.inSurah(2)).passageLabel, 'From ayah 1');
    expect(stateWith(RecitationSpan.inSurah(2, toAyah: 286)).passageLabel, 'Whole surah');
    expect(stateWith(RecitationSpan.inSurah(2, fromAyah: 12, toAyah: 12)).passageLabel, 'Ayah 12');
    expect(stateWith(RecitationSpan.inSurah(3, fromAyah: 5)).passageLabel, 'From 3:5');
  });

  test('an end in a later surah reads, inside this one, as running to its end', () {
    final state = stateWith(const RecitationSpan(start: QuranPosition(2, 280), end: QuranPosition(3, 5)));
    expect(state.toAyah, isNull);
    expect(state.sessionAyahs.map((a) => a.number), [280, 281, 282, 283, 284, 285, 286]);
  });

  test('a recording from the page is followed as far as the reciter goes', () {
    // Left open it runs on into Aal-E-Imran and beyond: the page runs on
    // into them too.
    expect(stateWith(RecitationSpan.inSurah(2, fromAyah: 57)).recordingSpan, RecitationSpan.inSurah(2, fromAyah: 57));
    // A fixed range is kept as it is.
    expect(stateWith(RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 60)).recordingSpan,
        RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 60));
  });

  group('a passage that runs on into the next surah', () {
    final imran = [for (var n = 1; n <= 200; n++) Ayah(number: n, arabicText: 'كَلِمَة كَلِمَة', translation: '')];
    RecitationState running(RecitationSpan span) => RecitationState(
          surahNumber: 2,
          ayahs: baqarah,
          following: [PassageSurah(3, imran)],
          span: span,
        );

    test('the page holds both surahs, in order', () {
      final state = running(RecitationSpan.inSurah(2, fromAyah: 280));
      expect(state.passage.map((p) => p.surah), [2, 3]);
      expect(state.ayahsOf(3), same(imran));
      expect(state.ayahsOf(4), isEmpty);
    });

    test('an open recitation runs from its start through every surah shown', () {
      final positions = running(RecitationSpan.inSurah(2, fromAyah: 280)).sessionPositions;
      expect(positions.first.$1, 2);
      expect(positions.first.$2.number, 280);
      expect(positions.where((p) => p.$1 == 2).length, 7);
      expect(positions.where((p) => p.$1 == 3).length, 200);
      expect(positions.last.$1, 3);
    });

    test('a recitation begun in the later surah covers only that surah from there', () {
      final positions = running(RecitationSpan.inSurah(3, fromAyah: 5)).sessionPositions;
      expect(positions.every((p) => p.$1 == 3), isTrue);
      expect(positions.first.$2.number, 5);
    });

    test('a fixed range stays in its surah', () {
      final positions = running(RecitationSpan.inSurah(2, fromAyah: 284, toAyah: 285)).sessionPositions;
      expect(positions.map((p) => (p.$1, p.$2.number)), [(2, 284), (2, 285)]);
    });
  });

  test('before a surah is opened there is no span, and nothing is narrowed', () {
    const state = RecitationState();
    expect(state.fromAyah, 1);
    expect(state.toAyah, isNull);
    expect(state.sessionAyahs, isEmpty);
  });
}
