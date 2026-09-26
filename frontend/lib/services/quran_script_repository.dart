import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../models/quran_script.dart';

/// One ayah written in one script.
///
/// [words] runs parallel to the bundled text's words -- entry i is how word i
/// of `Ayah.arabicText.split(' ')` is written in this script. That is what lets
/// live highlighting, verdicts and long-press keep using the indices the
/// recitation analysis reports, whichever script is on screen. An entry is
/// empty where the script has nothing of its own to draw there: a waqf sign
/// the script writes inside the word before it, or the second half of a word
/// the script writes as one (إِلۡ يَاسِينَ, 37:130).
class ScriptedAyah {
  final List<String> words;

  /// The ayah's closing mark as the script's font draws it: the ayah number in
  /// its circle, and for IndoPak the sign above it -- the ruku (ع), the sajda,
  /// or a waqf sign that falls at the ayah's end.
  final String end;

  const ScriptedAyah({required this.words, required this.end});
}

/// Where an ayah sits in the mushaf's divisions. The same in both scripts.
class AyahPlacement {
  /// Ruku number across the whole Quran, in the IndoPak count (558).
  final int ruku;

  /// Ruku number within the surah, from 1.
  final int rukuInSurah;

  /// Whether this ayah closes its ruku.
  final bool endsRuku;

  /// Sajda number (1-14) when this is a sajda ayah.
  final int? sajdah;

  final int juz;

  const AyahPlacement({
    required this.ruku,
    required this.rukuInSurah,
    required this.endsRuku,
    required this.sajdah,
    required this.juz,
  });
}

/// The Quran in the reader's two scripts, from `assets/quran/quran_scripts.json`
/// (built by ml/tools/build_quran_scripts.py from the quran.com API).
///
/// A companion to QuranTextRepository, not a replacement: that text is the one
/// the analysis indexes words by, and it does not change. This one only says
/// how each of those words is *written* in Uthmani or IndoPak, with each
/// script's own waqf, sajda and ruku marks, and where the rukus fall.
class QuranScriptRepository {
  QuranScriptRepository._();
  static final QuranScriptRepository instance = QuranScriptRepository._();

  static const _asset = 'assets/quran/quran_scripts.json';
  static const _separator = '|';

  List<List<Map<String, dynamic>>>? _surahs;
  Future<void>? _loading;
  final Map<(int, int, QuranScript), ScriptedAyah> _ayahs = {};

  bool get isLoaded => _surahs != null;

  /// Loads the asset once. Every lookup below is synchronous afterwards, so a
  /// page that awaited this can build without a future per ayah.
  Future<void> ensureLoaded() {
    if (_surahs != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString(_asset);
    _surahs = await compute(_decode, raw);
  }

  static List<List<Map<String, dynamic>>> _decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final surah in json['surahs'] as List)
        [for (final ayah in surah as List) ayah as Map<String, dynamic>],
    ];
  }

  /// How many ayahs [surah] has -- 0 before [ensureLoaded] has finished, or
  /// for a surah number outside 1..114.
  int ayahCount(int surah) {
    final surahs = _surahs;
    if (surahs == null || surah < 1 || surah > surahs.length) return 0;
    return surahs[surah - 1].length;
  }

  Map<String, dynamic>? _raw(int surah, int ayah) {
    final surahs = _surahs;
    if (surahs == null || surah < 1 || surah > surahs.length) return null;
    final ayahs = surahs[surah - 1];
    if (ayah < 1 || ayah > ayahs.length) return null;
    return ayahs[ayah - 1];
  }

  /// The ayah in [script], or null before [ensureLoaded] has finished.
  ScriptedAyah? ayah(int surah, int ayah, QuranScript script) {
    final cached = _ayahs[(surah, ayah, script)];
    if (cached != null) return cached;
    final raw = _raw(surah, ayah);
    if (raw == null) return null;
    final isUthmani = script == QuranScript.uthmani;
    final scripted = ScriptedAyah(
      words: (raw[isUthmani ? 'u' : 'n'] as String).split(_separator),
      end: raw[isUthmani ? 'ue' : 'ne'] as String,
    );
    return _ayahs[(surah, ayah, script)] = scripted;
  }

  /// Word [index] of the ayah in [script] -- null when not loaded, and empty
  /// where the script writes that word together with the one before it.
  String? word(int surah, int ayah, int index, QuranScript script) {
    final words = this.ayah(surah, ayah, script)?.words;
    if (words == null || index < 0 || index >= words.length) return null;
    return words[index];
  }

  AyahPlacement? placement(int surah, int ayah) {
    final raw = _raw(surah, ayah);
    if (raw == null) return null;
    final ruku = raw['r'] as int;
    final first = _raw(surah, 1)!['r'] as int;
    final next = _raw(surah, ayah + 1);
    return AyahPlacement(
      ruku: ruku,
      rukuInSurah: ruku - first + 1,
      endsRuku: next == null || next['r'] != ruku,
      sajdah: raw['s'] as int?,
      juz: raw['j'] as int,
    );
  }
}
