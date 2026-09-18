import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/ayah.dart';

/// Loads and caches the complete Quran text (Uthmani Arabic + Saheeh
/// International translation, all 114 surahs / 6236 ayahs) bundled as a JSON
/// asset. Replaces the Al-Fatihah-only dummy ayahs that were previously
/// reused for every surah across the recitation, listening, result, and
/// surah-details screens.
///
/// A standalone class (rather than living on [SurahService]) so both
/// `surah_service.dart` and `session_service.dart` can depend on it directly
/// without creating a circular import between those two files.
class QuranTextRepository {
  QuranTextRepository._();
  static final QuranTextRepository instance = QuranTextRepository._();

  Map<int, List<Ayah>>? _bySurah;
  Future<Map<int, List<Ayah>>>? _loading;

  Future<List<Ayah>> ayahsForSurah(int surahNumber) async {
    final map = await _ensureLoaded();
    return map[surahNumber] ?? const [];
  }

  /// The Basmala exactly as this asset writes it -- read from Al-Fatihah 1:1
  /// rather than typed, because a hand-typed Arabic string can differ from the
  /// asset's byte for byte while looking identical.
  Future<String> basmala() async {
    final fatihah = await ayahsForSurah(1);
    return fatihah.isEmpty ? '' : fatihah.first.arabicText;
  }

  /// An ayah's text as a per-ayah Qari recording of it is actually recited.
  ///
  /// This asset prefixes the Basmala to ayah 1 of every surah -- apart from
  /// At-Tawbah, which has none, and Al-Fatihah, where the Basmala *is* ayah 1.
  /// The reciters' per-ayah recordings do not: decoding ayah 1 of Al-Baqarah,
  /// Al-Kahf, At-Tawbah and Al-Ikhlas with the production recogniser found no
  /// Basmala in any of them, for any of the three reciters. Shown unchanged,
  /// the words on screen would open with a phrase the reciter never says.
  ///
  /// Matched on letters, not bytes: At-Tin and Al-Qadr write the Basmala's
  /// first letter with an extra shadda (بِّسْمِ), so an exact prefix match
  /// missed them and left the Basmala on screen for exactly those two surahs.
  static String asRecited(int surah, Ayah ayah, String basmala) {
    final text = ayah.arabicText;
    if (surah == 1 || ayah.number != 1 || basmala.isEmpty) return text;
    final end = _endOfPrefixByLetters(text, basmala);
    if (end < 0) return text;
    return String.fromCharCodes(text.runes.skip(end)).trimLeft();
  }

  /// Arabic diacritics and Quranic annotation marks -- everything that is not
  /// a letter or a space.
  static bool isMark(int rune) =>
      (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || (rune >= 0x06D6 && rune <= 0x06ED);

  /// Where [prefix] ends in [text] when only letters are compared, as a rune
  /// index -- or -1 if [text] does not begin with those letters.
  static int _endOfPrefixByLetters(String text, String prefix) {
    final wanted = prefix.runes.where((r) => !isMark(r)).toList();
    final runes = text.runes.toList();
    var i = 0;
    var j = 0;
    while (i < runes.length && j < wanted.length) {
      if (isMark(runes[i])) {
        i++;
        continue;
      }
      if (runes[i] != wanted[j]) return -1;
      i++;
      j++;
    }
    if (j < wanted.length) return -1;
    // The marks on the prefix's last letter belong to it.
    while (i < runes.length && isMark(runes[i])) {
      i++;
    }
    return i;
  }

  Future<Map<int, List<Ayah>>> _ensureLoaded() {
    final loaded = _bySurah;
    if (loaded != null) return Future.value(loaded);
    return _loading ??= _load();
  }

  Future<Map<int, List<Ayah>>> _load() async {
    final raw = await rootBundle.loadString('assets/quran/quran_full.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final surahsJson = decoded['surahs'] as List;

    final map = <int, List<Ayah>>{};
    for (final entry in surahsJson) {
      final surahJson = entry as Map<String, dynamic>;
      final number = surahJson['number'] as int;
      final ayahsJson = surahJson['ayahs'] as List;
      map[number] = ayahsJson.map((a) => Ayah.fromJson(a as Map<String, dynamic>)).toList();
    }
    _bySurah = map;
    return map;
  }
}
