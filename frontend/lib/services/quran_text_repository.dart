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
