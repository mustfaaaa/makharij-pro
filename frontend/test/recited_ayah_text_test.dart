// What Rattil shows beside a Qari's recording of an ayah.
//
// The text asset prefixes the Basmala to ayah 1 of almost every surah; the
// per-ayah recordings do not contain it (checked by decoding them). So for the
// words on screen to match the words being recited, ayah 1 must lose that
// prefix -- except in Al-Fatihah, where the Basmala is the ayah itself.
//
// Like quran_text_repository_test.dart, this never types Arabic by hand: a
// retyped string can look identical to the asset and differ byte for byte, so
// every expectation here is built from the asset's own text.
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/services/quran_text_repository.dart';

/// The letters (and spaces) of Arabic text, without its diacritics.
String _letters(String s) =>
    String.fromCharCodes(s.runes.where((r) => !QuranTextRepository.isMark(r)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = QuranTextRepository.instance;

  test('the Basmala is read from Al-Fatihah 1:1', () async {
    final fatihah = await repo.ayahsForSurah(1);
    expect(await repo.basmala(), fatihah.first.arabicText);
    expect(await repo.basmala(), isNotEmpty);
  });

  test('Al-Fatihah keeps it: there the Basmala is ayah 1', () async {
    final basmala = await repo.basmala();
    final first = (await repo.ayahsForSurah(1)).first;
    expect(QuranTextRepository.asRecited(1, first, basmala), first.arabicText);
  });

  test('every other surah\'s ayah 1 loses the Basmala, and only the Basmala', () async {
    final basmala = await repo.basmala();
    final basmalaLetters = _letters(basmala);
    var removed = 0;
    for (var surah = 2; surah <= 114; surah++) {
      final first = (await repo.ayahsForSurah(surah)).first;
      final shown = QuranTextRepository.asRecited(surah, first, basmala);

      expect(_letters(shown).startsWith(basmalaLetters), isFalse,
          reason: 'surah $surah still opens with the Basmala');
      expect(shown, isNotEmpty, reason: 'surah $surah lost its whole first ayah');
      if (shown != first.arabicText) {
        removed++;
        // What went is the Basmala's letters, nothing more.
        final taken = first.arabicText.substring(0, first.arabicText.length - shown.length);
        expect(_letters(taken).trim(), basmalaLetters.trim(), reason: 'surah $surah');
        expect(first.arabicText.endsWith(shown), isTrue, reason: 'surah $surah');
      }
    }
    // Every surah but At-Tawbah carries it -- including At-Tin and Al-Qadr,
    // whose Basmala is spelled with an extra shadda and was missed by an
    // exact match.
    expect(removed, 112);
  });

  test('At-Tawbah is left alone: it has no Basmala', () async {
    final basmala = await repo.basmala();
    final first = (await repo.ayahsForSurah(9)).first;
    expect(QuranTextRepository.asRecited(9, first, basmala), first.arabicText);
  });

  test('ayat after the first are never touched', () async {
    final basmala = await repo.basmala();
    for (final surah in [1, 2, 18, 112]) {
      final ayahs = await repo.ayahsForSurah(surah);
      for (final ayah in ayahs.skip(1)) {
        expect(QuranTextRepository.asRecited(surah, ayah, basmala), ayah.arabicText);
      }
    }
  });

  test('with no Basmala known, the text is shown unchanged', () async {
    final first = (await repo.ayahsForSurah(2)).first;
    expect(QuranTextRepository.asRecited(2, first, ''), first.arabicText);
  });
}
