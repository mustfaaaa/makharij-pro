// Verifies the real, complete Quran text (114 surahs / 6236 ayahs) that
// replaced the old Al-Fatihah-only dummy data actually loads correctly and
// is genuinely per-surah -- the exact bug being fixed here was every surah
// silently reusing Al-Fatihah's ayahs regardless of which one was selected.
//
// Deliberately avoids hand-typed Arabic string literals for exact-match
// assertions: combining-mark ordering (e.g. shadda+fatha vs fatha+shadda)
// can render identically while being byte-different, so a manually-typed
// comparison string can silently fail to match real source text even when
// it looks correct. Instead this test independently re-decodes the same
// JSON asset the repository loads and compares against that, which proves
// the repository's parsing is faithful without embedding any retyped text.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/dummy/dummy_surahs.dart';
import 'package:frontend/services/quran_text_repository.dart';
import 'package:frontend/services/surah_service.dart';

Future<Map<String, dynamic>> _loadRawAsset() async {
  final raw = await rootBundle.loadString('assets/quran/quran_full.json');
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuranTextRepository', () {
    test('loads all 114 surahs totalling 6236 ayahs', () async {
      final repo = QuranTextRepository.instance;
      var total = 0;
      for (var n = 1; n <= 114; n++) {
        final ayahs = await repo.ayahsForSurah(n);
        expect(ayahs, isNotEmpty, reason: 'surah $n has no ayahs');
        total += ayahs.length;
      }
      expect(total, 6236);
    });

    test('every surah\'s ayah count matches the known Surah metadata', () async {
      final repo = QuranTextRepository.instance;
      for (final surah in dummySurahs) {
        final ayahs = await repo.ayahsForSurah(surah.number);
        expect(
          ayahs.length,
          surah.ayahCount,
          reason: 'surah ${surah.number} (${surah.nameEnglish}) expected ${surah.ayahCount} ayahs, got ${ayahs.length}',
        );
      }
    });

    test('parsed output is byte-faithful to the source asset for every surah', () async {
      final rawDecoded = await _loadRawAsset();
      final rawSurahs = (rawDecoded['surahs'] as List).cast<Map<String, dynamic>>();

      for (final rawSurah in rawSurahs) {
        final number = rawSurah['number'] as int;
        final rawAyahs = (rawSurah['ayahs'] as List).cast<Map<String, dynamic>>();
        final parsedAyahs = await QuranTextRepository.instance.ayahsForSurah(number);

        expect(parsedAyahs.length, rawAyahs.length, reason: 'surah $number ayah count mismatch');
        for (var i = 0; i < rawAyahs.length; i++) {
          expect(parsedAyahs[i].number, rawAyahs[i]['number']);
          expect(parsedAyahs[i].arabicText, rawAyahs[i]['arabicText'], reason: 'surah $number ayah $i arabicText mismatch');
          expect(parsedAyahs[i].translation, rawAyahs[i]['translation'], reason: 'surah $number ayah $i translation mismatch');
        }
      }
    });

    test('different surahs have genuinely different text (not all reusing Al-Fatihah)', () async {
      final repo = QuranTextRepository.instance;
      final fatihah = await repo.ayahsForSurah(1);
      for (final n in [2, 55, 108, 112, 113, 114]) {
        final ayahs = await repo.ayahsForSurah(n);
        expect(ayahs.first.arabicText, isNot(fatihah.first.arabicText), reason: 'surah $n is reusing Al-Fatihah\'s text');
        expect(ayahs.length, isNot(fatihah.length), reason: 'surah $n suspiciously has Al-Fatihah\'s ayah count too');
      }
    });

    test('At-Tawbah (9) is the one surah with no Bismillah prefix', () async {
      final ayahs = await QuranTextRepository.instance.ayahsForSurah(9);
      // Every other surah's ayah 1 starts with the Bismillah (بِسْمِ); 9 does not.
      expect(ayahs.first.arabicText.startsWith('بِسْمِ'), isFalse);
      for (final n in [1, 2, 55, 108, 112, 113, 114]) {
        final other = await QuranTextRepository.instance.ayahsForSurah(n);
        expect(other.first.arabicText.startsWith('بِسْمِ'), isTrue, reason: 'surah $n should start with the Bismillah');
      }
    });

    test('every ayah has non-empty Arabic text and translation', () async {
      for (var n = 1; n <= 114; n++) {
        final ayahs = await QuranTextRepository.instance.ayahsForSurah(n);
        for (final a in ayahs) {
          expect(a.arabicText.trim(), isNotEmpty, reason: 'surah $n ayah ${a.number} has empty Arabic text');
          expect(a.translation.trim(), isNotEmpty, reason: 'surah $n ayah ${a.number} has empty translation');
        }
      }
    });

    test('unknown surah number returns an empty list rather than throwing', () async {
      final ayahs = await QuranTextRepository.instance.ayahsForSurah(999);
      expect(ayahs, isEmpty);
    });
  });

  group('AssetSurahService.getAyahs', () {
    test('delegates to the real repository, not dummy data', () async {
      final SurahService service = AssetSurahService();
      final direct = await QuranTextRepository.instance.ayahsForSurah(108);
      final viaService = await service.getAyahs(108);
      expect(viaService.length, direct.length);
      expect(viaService.first.arabicText, direct.first.arabicText);
    });
  });
}
