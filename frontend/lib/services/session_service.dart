import 'dart:math';
import 'dart:typed_data';

import '../core/audio/wav_encoder.dart';
import '../dummy/dummy_sessions.dart';
import '../dummy/dummy_surahs.dart';
import '../models/ayah.dart';
import '../models/quran_position.dart';
import '../models/reattempt_outcome.dart';
import '../models/recitation_span.dart';
import '../models/session_result.dart';
import '../models/tajweed_error.dart';
import '../models/word_verdict.dart';
import 'api_client.dart';
import 'server_cache.dart';
import 'quran_text_repository.dart';

/// Default reference Qari, sent for analytics only -- the phoneme model
/// compares against the ayah's canonical phoneme sequence, not a specific
/// reciter's audio. Matches the backend's own default.
const _defaultQariId = 'abdurrahmaan_as_sudais';

/// The form fields that ask the analysis endpoint for [span]: where the
/// recitation begins, and how far it may run -- to [span]'s end, or, left
/// open, on through the surahs after it for as long as the recording goes.
/// The one place a span becomes a request; the live socket's handshake says
/// the same thing in the same terms.
Map<String, String> analysisFields(RecitationSpan span) {
  final end = span.end;
  return {
    'surah_number': span.start.surah.toString(),
    'from_ayah': span.start.ayah.toString(),
    'end_surah': (end?.surah ?? 114).toString(),
    if (end != null) 'to_ayah': end.ayah.toString(),
  };
}

/// How long uploading a recording of [length] and having it analysed may
/// take before the app gives up on it: the usual two minutes, plus a share of
/// the recording's own length. A 16 kHz WAV is about 1.9 MB a minute, which a
/// slow phone connection uploads in roughly a quarter of the time it took to
/// recite; the server decodes and aligns it in under a tenth (measured: 18
/// minutes of Al-Baqarah in 71 s). So a full juz of about 45 minutes gets
/// some 18 minutes, and a two-minute recitation the two minutes it always had.
Duration uploadTimeoutFor(Duration length) => const Duration(minutes: 2) + length * 0.35;

/// How long the live socket may take to judge a recitation it has already
/// decoded: only the alignment is left, which runs at about a fiftieth of the
/// recording's length (18 minutes aligned in 19 s).
Duration finishTimeoutFor(Duration length) => const Duration(minutes: 1) + length * 0.2;

/// A [SessionResult] from the analysis response -- the same shape whether the
/// recording was uploaded or judged on the live socket.
SessionResult resultFromAnalysis(
  RecitationSpan span,
  Map<String, dynamic> json,
  Uint8List audioPcm, {
  Duration durationRecorded = Duration.zero,
}) {
  final surahNumber = json['surah_number'] as int? ?? span.start.surah;
  final surah = dummySurahs.firstWhere((s) => s.number == surahNumber, orElse: () => dummySurahs.first);
  final words = (json['words'] as List).cast<Map<String, dynamic>>();
  final wordVerdicts = words.map(WordVerdict.fromJson).toList();
  final recited = wordVerdicts.where((v) => v.recited).toList();
  final ayah = json['reached_ayah'] as int?;

  return SessionResult(
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
    fromAyah: json['from_ayah'] as int? ?? span.start.ayah,
    toAyah: json['to_ayah'] as int? ?? span.end?.ayah,
    endSurah: json['end_surah'] as int?,
    // The last word the analysis placed the reciter on. A server analysing
    // one surah per recording does not send `reached_surah`: that surah it is.
    reached: ayah == null
        ? null
        : QuranPosition(
            json['reached_surah'] as int? ?? surahNumber,
            ayah,
            word: json['reached_word_index'] as int? ?? 0,
          ),
  );
}

abstract class SessionService {
  Future<List<SessionResult>> getSessions();
  Future<SessionResult> getSessionById(String id);

  /// Analyzes a just-recorded recitation that began at [span]'s start and ran
  /// on from there (to its end, for a fixed practice range).
  ///
  /// [audioPcm] is raw 16 kHz mono PCM16 straight from the recorder: it gets a
  /// WAV header for upload, and is kept on the result so the user can play back
  /// individual words. [DummySessionService] accepts but ignores it.
  Future<SessionResult> generateSessionResult(
    RecitationSpan span,
    Uint8List audioPcm, {
    Duration durationRecorded = Duration.zero,
  });

  /// The result of a recitation the server already judged and stored -- the
  /// live socket's answer to "finish", which has the same shape as the upload
  /// endpoint's. Read exactly as [generateSessionResult] reads that one.
  SessionResult adoptAnalysis(
    RecitationSpan span,
    Map<String, dynamic> json,
    Uint8List audioPcm, {
    Duration durationRecorded = Duration.zero,
  });

  /// Records the reciter's own verdict on a word the analysis flagged --
  /// `agreed: false` meaning "I said this correctly". [surahNumber] is the
  /// word's surah, for a recitation that ran on past the one it began in.
  Future<void> recordWordFeedback({
    required String sessionId,
    required int ayahNumber,
    required int wordIndex,
    required bool agreed,
    int? surahNumber,
  });

  /// Re-recites a flagged word (FR-8/BR-5) and returns what changed.
  ///
  /// Only words the session already flagged can change, so this can lower the
  /// number of mistakes but never raise it -- trying again is safe.
  ///
  /// [wordIndex] null re-attempts every flagged word in [ayahNumber].
  Future<ReattemptOutcome> reattempt({
    required String sessionId,
    required int surahNumber,
    required int ayahNumber,
    int? wordIndex,
    required Uint8List audioPcm,
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
            explanation: v.explanation ?? 'This word sounded different from what was expected.',
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
      return 'This letter sounded slightly off its articulation point — listen back.';
    case TajweedErrorType.ghunnah:
      return 'The nasal hum (ghunnah) sounded shorter than the two counts expected.';
    case TajweedErrorType.shaddah:
      return 'This letter should sound doubled (shaddah) — listen back and check.';
    case TajweedErrorType.madd:
      return 'The elongation sounded shorter than the count expected here.';
    case TajweedErrorType.skipped:
      return 'This word wasn’t picked up — did you recite it?';
  }
}

class DummySessionService implements SessionService {
  final List<SessionResult> _sessions = List.of(dummySessions);
  final _random = Random();

  /// Nothing to record against: this implementation's sessions are generated,
  /// not stored, so there is no document for the verdict to attach to.
  @override
  Future<void> recordWordFeedback({
    required String sessionId,
    required int ayahNumber,
    required int wordIndex,
    required bool agreed,
    int? surahNumber,
  }) async {}

  /// Never reached: this implementation has no backend, so the live socket
  /// never connects and there is no server result to adopt.
  @override
  SessionResult adoptAnalysis(
    RecitationSpan span,
    Map<String, dynamic> json,
    Uint8List audioPcm, {
    Duration durationRecorded = Duration.zero,
  }) =>
      resultFromAnalysis(span, json, audioPcm, durationRecorded: durationRecorded);

  /// Same reason: there is no stored session to re-score. Reports the word as
  /// corrected so the flow can be walked through without a backend, and says
  /// nothing about accuracy, which it cannot know.
  @override
  Future<ReattemptOutcome> reattempt({
    required String sessionId,
    required int surahNumber,
    required int ayahNumber,
    int? wordIndex,
    required Uint8List audioPcm,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return ReattemptOutcome(
      corrected: [ReattemptWord(ayahNumber: ayahNumber, wordIndex: wordIndex ?? 0)],
      stillWrong: const [],
      notReached: const [],
      accuracyScore: 0,
      wordsCorrect: 0,
      wordsRecited: 0,
    );
  }

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
    RecitationSpan span,
    Uint8List audioPcm, {
    Duration durationRecorded = Duration.zero,
  }) async {
    await Future.delayed(const Duration(milliseconds: 2200));
    final surahNumber = span.start.surah;

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

  /// The history, briefly cached. Opening the app asks for it three times at
  /// once -- the home screen's "continue your recitation", the progress
  /// glance, and the recent list -- and each one used to be its own round trip
  /// to the server. Requests that arrive while one is in flight share it, and
  /// the answer is reused for a few seconds; writing a session or a re-attempt
  /// clears it, so nothing shows a stale history after a recitation.
  static const _historyTtl = Duration(seconds: 20);
  Future<List<SessionResult>>? _inFlightHistory;
  List<SessionResult>? _history;
  DateTime? _historyAt;

  @override
  Future<List<SessionResult>> getSessions() {
    final cached = _history;
    final at = _historyAt;
    if (cached != null && at != null && DateTime.now().difference(at) < _historyTtl) {
      return Future.value(cached);
    }
    var request = _inFlightHistory;
    if (request == null) {
      request = _fetchSessions();
      _inFlightHistory = request;
      // See CachedValue: the shared request always keeps a listener.
      request.then((_) {}, onError: (_) {}).whenComplete(() => _inFlightHistory = null);
    }
    return request;
  }

  Future<List<SessionResult>> _fetchSessions() async {
    final json = await _client.get('/api/v1/sessions');
    final sessions = (json['sessions'] as List).cast<Map<String, dynamic>>();
    final parsed = sessions.map(_sessionFromHistoryJson).toList();
    _history = parsed;
    _historyAt = DateTime.now();
    return parsed;
  }

  /// Called after anything that changes the stored history: this device just
  /// wrote a recitation, so every screen's cached numbers are out of date.
  void _forgetHistory() {
    _history = null;
    _historyAt = null;
    ServerCache.invalidate();
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
    RecitationSpan span,
    Uint8List audioPcm, {
    Duration durationRecorded = Duration.zero,
  }) async {
    final json = await _client.postAudio(
      '/api/v1/sessions/analyze_word_level',
      pcm16ToWav(audioPcm),
      fields: {...analysisFields(span), 'qari_id': _defaultQariId},
      timeout: uploadTimeoutFor(durationRecorded),
    );
    return adoptAnalysis(span, json, audioPcm, durationRecorded: durationRecorded);
  }

  @override
  SessionResult adoptAnalysis(
    RecitationSpan span,
    Map<String, dynamic> json,
    Uint8List audioPcm, {
    Duration durationRecorded = Duration.zero,
  }) {
    final result = resultFromAnalysis(span, json, audioPcm, durationRecorded: durationRecorded);
    _lastResult = result;
    _forgetHistory();
    return result;
  }

  /// Records that the reciter disagrees with one flagged word.
  ///
  /// The detector wrongly flags roughly two correct recitations in five
  /// (ml/eval/README.md), so this is not an escape hatch for a rare bug -- it is
  /// the honest response to a known limit, and the only source of per-word
  /// judgement on real learner audio that exists.
  @override
  Future<void> recordWordFeedback({
    required String sessionId,
    required int ayahNumber,
    required int wordIndex,
    required bool agreed,
    int? surahNumber,
  }) async {
    await _client.postForm(
      '/api/v1/sessions/$sessionId/word-feedback',
      fields: {
        'ayah_number': ayahNumber.toString(),
        'word_index': wordIndex.toString(),
        'agreed': agreed.toString(),
        if (surahNumber != null) 'surah_number': surahNumber.toString(),
      },
    );
  }

  /// FR-8/BR-5: another go at a word the analysis flagged.
  ///
  /// The backend only lets already-flagged words change, so a retake can
  /// improve the session's score and never worsen it. That asymmetry is the
  /// point: with a measured 41.9% false-alarm rate, a reciter who is told they
  /// were wrong is often right, and asking them to prove it must not be a
  /// gamble.
  @override
  Future<ReattemptOutcome> reattempt({
    required String sessionId,
    required int surahNumber,
    required int ayahNumber,
    int? wordIndex,
    required Uint8List audioPcm,
  }) async {
    final json = await _client.postAudio(
      '/api/v1/sessions/$sessionId/reattempt',
      pcm16ToWav(audioPcm),
      fields: {
        'surah_number': surahNumber.toString(),
        'ayah_number': ayahNumber.toString(),
        if (wordIndex != null) 'word_index': wordIndex.toString(),
      },
    );
    _forgetHistory();
    return ReattemptOutcome.fromJson(json);
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
      fromAyah: json['fromAyah'] as int?,
      toAyah: json['toAyah'] as int?,
      endSurah: json['endSurah'] as int?,
    );
  }
}
