// The Uthmani and IndoPak texts are drawn over the bundled text's word
// indices: live highlighting, verdicts and long-press all address words by
// their position in quran_full.json. If the two ever disagreed in length for
// an ayah, a mark would land on the wrong word -- silently, and only in one
// script. These check every ayah of the Quran rather than a sample.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/quran_script.dart';
import 'package:frontend/services/quran_script_repository.dart';
import 'package:frontend/services/quran_text_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = QuranScriptRepository.instance;
  setUpAll(repo.ensureLoaded);

  test('every ayah in both scripts runs parallel to the bundled text', () async {
    var ayahs = 0;
    for (var surah = 1; surah <= 114; surah++) {
      for (final ayah in await QuranTextRepository.instance.ayahsForSurah(surah)) {
        final words = ayah.arabicText.split(' ').length;
        for (final script in QuranScript.values) {
          final scripted = repo.ayah(surah, ayah.number, script);
          expect(scripted, isNotNull, reason: '$surah:${ayah.number} missing in ${script.name}');
          expect(scripted!.words.length, words,
              reason: '$surah:${ayah.number} in ${script.name} would put marks on the wrong words');
        }
        ayahs++;
      }
    }
    expect(ayahs, 6236);
  });

  test('every ayah closes with its own number, in both scripts', () {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    String arabic(int n) => n.toString().split('').map((d) => digits[int.parse(d)]).join();
    for (var surah = 1; surah <= 114; surah++) {
      for (var ayah = 1; repo.placement(surah, ayah) != null; ayah++) {
        for (final script in QuranScript.values) {
          expect(repo.ayah(surah, ayah, script)!.end, startsWith(arabic(ayah)), reason: '$surah:$ayah ${script.name}');
        }
      }
    }
  });

  test('rukus and sajdas are where the IndoPak mushaf has them', () async {
    final raw = jsonDecode(await rootBundle.loadString('assets/quran/quran_scripts.json')) as Map<String, dynamic>;
    var rukuEnds = 0;
    final sajdas = <String>[];
    final surahs = raw['surahs'] as List;
    for (var surah = 1; surah <= surahs.length; surah++) {
      for (var ayah = 1; ayah <= (surahs[surah - 1] as List).length; ayah++) {
        final place = repo.placement(surah, ayah)!;
        if (place.endsRuku) rukuEnds++;
        if (place.sajdah != null) sajdas.add('$surah:$ayah');
      }
    }
    expect(rukuEnds, 558);
    expect(sajdas, hasLength(14));
    expect(sajdas, containsAll(['7:206', '13:15', '32:15', '41:38', '53:62', '96:19']));
    // The last ayah of a surah always closes its ruku.
    expect(repo.placement(2, 286)!.endsRuku, isTrue);
    expect(repo.placement(1, 7)!.endsRuku, isTrue);
    expect(repo.placement(2, 7)!.endsRuku, isTrue);
    expect(repo.placement(2, 6)!.endsRuku, isFalse);
    expect(repo.placement(2, 8)!.rukuInSurah, 2);
  });

  test('the ayah 1 Basmala is written in the script, never left empty', () {
    for (final script in QuranScript.values) {
      final words = repo.ayah(2, 1, script)!.words;
      expect(words.take(4).every((w) => w.isNotEmpty), isTrue, reason: script.name);
      expect(words.take(4).toList(), repo.ayah(1, 1, script)!.words, reason: script.name);
    }
  });

  test('At-Tawbah opens with no Basmala in either script', () async {
    final tawbah = (await QuranTextRepository.instance.ayahsForSurah(9)).first;
    for (final script in QuranScript.values) {
      expect(repo.ayah(9, 1, script)!.words.length, tawbah.arabicText.split(' ').length);
      expect(repo.ayah(9, 1, script)!.words.first, isNot(repo.ayah(1, 1, script)!.words.first));
    }
  });
}
