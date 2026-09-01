import 'dart:math';
import 'dart:typed_data';

import '../core/audio/wav_encoder.dart';
import '../dummy/dummy_sessions.dart';
import '../dummy/dummy_surahs.dart';
import '../models/ayah.dart';
import '../models/session_result.dart';
import '../models/tajweed_error.dart';
import '../models/word_verdict.dart';
import 'api_client.dart';
import 'quran_text_repository.dart';

/// Default reference Qari, sent for analytics only -- the phoneme model
/// compares against the ayah's canonical phoneme sequence, not a specific
/// reciter's audio. Matches the backend's own default.
const _defaultQariId = 'abdurrahmaan_as_sudais';

abstract class SessionService {
  Future<List<SessionResult>> getSessions();
  Future<SessionResult> getSessionById(String id);

  /// Analyzes a just-recorded recitation of [surahNumber], ayahs [fromAyah] to
  /// [toAyah] (the whole surah when [toAyah] is null).
  ///
  /// [audioPcm] is raw 16 kHz mono PCM16 straight from the recorder: it gets a
  /// WAV header for upload, and is kept on the result so the user can play back
  /// individual words. [DummySessionService] accepts but ignores it.
  Future<SessionResult> generateSessionResult(
    int surahNumber,
    Uint8List audioPcm, {
    int fromAyah = 1,
    int? toAyah,
    Duration durationRecorded = Duration.zero,
  });
}

/// Word-highlighting preview data for [DummySessionService] only -- it has no
/// backend and therefore no real analysis to show. [ApiSessionService] builds
/// its errors from real word verdicts instead (see [_errorsFromVerdicts]).
List<TajweedError> _generatePreviewErrors(double accuracyScore, Random random, List<Ayah> ayahs) {
  final allWords = ayahs.expand((a) => a.arabicText.split(' ').map((w) => (word: w, ayah: a.number))).toList();
  if (allWords.isEmpty) return const [];
  final errorCount = accuracyScore >= 90 ? random.nextInt(2) : 1 + random.nextInt(3);
  allWords.shuffle(random);
  const types = TajweedErrorType.values;
  return allWords.take(errorCount).map((w) {
    final type = types[random.nextInt(types.length)];
    return TajweedError(word: w.word, ayahNumber: w.ayah, type: type, explanation: _explanationFor(type));
  }).toList();
}

/// Real, measured mistakes -- one entry per flagged word, carrying the
/// backend's own explanation of which Tajweed feature the phoneme diff broke.
List<TajweedError> _errorsFromVerdicts(List<WordVerdict> verdicts) {
  return verdicts
      .where((v) => v.recited && v.flagged)
      .map((v) => TajweedError(
            word: v.word,
            ayahNumber: v.ayahNumber,
            type: v.errorType ?? TajweedErrorType.makhraj,
            explanation: v.explanation ?? 'This word did not match the expected pronunciation.',
          ))
      .toList();
}

/// The same mistakes, read back from a stored session. History keeps the
/// mistakes rather than every word, so a past session shows exactly what went
/// wrong -- it used to come back empty and claim a flawless recitation.
List<TajweedError> _errorsFromStored(List<dynamic> stored) {
  return stored.cast<Map<String, dynamic>>().map((m) {
    return TajweedError(
      word: m['word'] as String? ?? '',
      ayahNumber: m['ayahNumber'] as int? ?? 0,
      type: tajweedErrorTypeFromId(m['errorType'] as String?) ?? TajweedErrorType.makhraj,
      explanation: m['explanation'] as String? ?? '',
    );
  }).toList();
}

/// Ten hasanah per Arabic letter recited (diacritics excluded), per the
/// hadith (Tirmidhi 2910). Counted over the words the user actually recited,
/// so stopping halfway through a surah doesn't credit the whole thing.
int _hasanahForVerdicts(List<WordVerdict> verdicts) =>
    verdicts.where((v) => v.recited).fold<int>(0, (sum, v) => sum + _countArabicLetters(v.word)) * 10;

int _hasanahForAyahs(List<Ayah> ayahs) =>
    ayahs.fold<int>(0, (sum, ayah) => sum + _countArabicLetters(ayah.arabicText)) * 10;

int _countArabicLetters(String text) {
  // Strip Arabic combining diacritics (harakat) so only base letters are
  // counted: U+0610-061A, U+064B-065F, U+0670, U+06D6-06ED, plus spaces.
  final buffer = StringBuffer();
  for (final code in text.runes) {
    final isDiacritic = (code >= 0x0610 && code <= 0x061A) ||
        (code >= 0x064B && code <= 0x065F) ||
        code == 0x0670 ||
        (code >= 0x06D6 && code <= 0x06ED) ||
        code == 0x0020;
    if (!isDiacritic) buffer.writeCharCode(code);
  }
  return buffer.length;
}

String _explanationFor(TajweedErrorType type) {
  switch (type) {
    case TajweedErrorType.makhraj:
      return 'The articulation point of this letter was slightly off target.';
    case TajweedErrorType.ghunnah:
      return 'The nasal sound (ghunnah) was too short — hold it for a full two counts.';
    case TajweedErrorType.shaddah:
      return 'The doubled letter was not emphasized enough.';
    case TajweedErrorType.madd:
      return 'The elongation was shorter than the required count.';
    case TajweedErrorType.skipped:
      return 'This word was not recited.';
  }
}

class DummySessionService implements SessionService {
  final List<SessionResult> _sessions = List.of(dummySessions);
  final _random = Random();

  @override
  Future<List<SessionResult>> getSessions() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return List.unmodifiable(_sessions.reversed);
  }

  @override
  Future<SessionResult> getSessionById(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _sessions.firstWhere((s) => s.id == id, orElse: () => _sessions.first);
  }

  @override
  Future<SessionResult> generateSessionResult(
    int surahNumber,
    Uint8List audioPcm, {
    int fromAyah = 1,
    int? toAyah,
    Duration durationRecorded = Duration.zero,
  }) async {
    await Future.delayed(const Duration(milliseconds: 2200));

    final surah = dummySurahs.firstWhere((s) => s.number == surahNumber, orElse: () => dummySurahs.first);
    final ayahs = await QuranTextRepository.instance.ayahsForSurah(surahNumber);
    final score = 62 + _random.nextInt(37).toDouble(); // 62–98

    final result = SessionResult(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      surahName: surah.nameEnglish,
      surahNumber: surah.number,
      dateTime: DateTime.now(),
      accuracyScore: score,
      duration: Duration(minutes: 1 + _random.nextInt(6), seconds: _random.nextInt(60)),
      errors: _generatePreviewErrors(score, _random, ayahs),
      hasanahEarned: _hasanahForAyahs(ayahs),
    );
    _sessions.insert(0, result);
    return result;
  }
}

/// Real backend-backed implementation.
///
/// One upload, not two: the word-level endpoint now both analyzes and stores
/// the session, so the same audio no longer goes up twice (once for a
/// whole-clip rule classifier whose verdicts were too coarse to show, once for
/// the per-word analysis that the score actually comes from).
class ApiSessionService implements SessionService {
  final ApiClient _client;
  ApiSessionService([ApiClient client = const ApiClient()]) : _client = client;

  /// The most recently analyzed session, kept so the detailed-feedback screen
  /// can show its per-word verdicts and play its audio back without a refetch.
  SessionResult? _lastResult;

  @override
  Future<List<SessionResult>> getSessions() async {
    final json = await _client.get('/api/v1/sessions');
    final sessions = (json['sessions'] as List).cast<Map<String, dynamic>>();
    return sessions.map(_sessionFromHistoryJson).toList();
  }

  @override
  Future<SessionResult> getSessionById(String id) async {
    final cached = _lastResult;
    if (cached != null && cached.id == id) return cached;
    // No single-session-by-id endpoint yet -- history is small enough for
    // now that fetching the list and finding it client-side is fine.
    final sessions = await getSessions();
    return sessions.firstWhere((s) => s.id == id, orElse: () => sessions.first);
  }

  @override
  Future<SessionResult> generateSessionResult(
    int surahNumber,
    Uint8List audioPcm, {
    int fromAyah = 1,
    int? toAyah,
    Duration durationRecorded = Duration.zero,
  }) async {
    final surah = dummySurahs.firstWhere((s) => s.number == surahNumber, orElse: () => dummySurahs.first);
    final json = await _client.postAudio(
      '/api/v1/sessions/analyze_word_level',
      pcm16ToWav(audioPcm),
      fields: {
        'surah_number': surahNumber.toString(),
        'from_ayah': fromAyah.toString(),
        if (toAyah != null) 'to_ayah': toAyah.toString(),
        'qari_id': _defaultQariId,
      },
    );

    final words = (json['words'] as List).cast<Map<String, dynamic>>();
    final wordVerdicts = words.map(WordVerdict.fromJson).toList();
    final recited = wordVerdicts.where((v) => v.recited).toList();

    final result = SessionResult(
      id: json['session_id'] as String,
      surahName: surah.nameEnglish,
      surahNumber: surah.number,
      dateTime: DateTime.now(),
      accuracyScore: (json['accuracy_score'] as num).toDouble() * 100,
      duration: durationRecorded,
      errors: _errorsFromVerdicts(wordVerdicts),
      wordVerdicts: wordVerdicts,
      wordsRecited: json['words_recited'] as int? ?? recited.length,
      totalWords: json['total_words'] as int? ?? wordVerdicts.length,
      audioPcm: audioPcm,
      hasanahEarned: _hasanahForVerdicts(recited),
    );
    _lastResult = result;
    return result;
  }

  SessionResult _sessionFromHistoryJson(Map<String, dynamic> json) {
    final surahNumber = json['surahNumber'] as int? ?? 1;
    final surah = dummySurahs.firstWhere((s) => s.number == surahNumber, orElse: () => dummySurahs.first);
    final createdAt = json['createdAt'] as String?;

    return SessionResult(
      id: json['session_id'] as String,
      surahName: surah.nameEnglish,
      surahNumber: surahNumber,
      dateTime: createdAt == null ? DateTime.now() : (DateTime.tryParse(createdAt) ?? DateTime.now()),
      accuracyScore: (json['accuracyScore'] as num? ?? 0).toDouble() * 100,
      duration: Duration.zero, // not persisted server-side yet
      errors: _errorsFromStored(json['mistakes'] as List? ?? const []),
      wordsRecited: json['wordsRecited'] as int? ?? 0,
      totalWords: json['totalWords'] as int? ?? 0,
    );
  }
}
