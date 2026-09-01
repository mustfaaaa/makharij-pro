import 'dart:typed_data';

import 'tajweed_error.dart';
import 'word_verdict.dart';

class SessionResult {
  final String id;
  final String surahName;
  final int surahNumber;
  final DateTime dateTime;

  /// Share of the words actually recited that were pronounced correctly.
  /// Read it together with [wordsRecited]: reciting three words perfectly and
  /// stopping is 100% accurate and almost no coverage.
  final double accuracyScore;
  final Duration duration;

  /// The mistakes to explain in writing, one per flagged word. Derived from
  /// [wordVerdicts] for real backend sessions; only [DummySessionService]
  /// (which has no backend at all) still fills this with a simulation, and
  /// result_screen.dart labels that case a preview.
  final List<TajweedError> errors;

  /// Real, evidence-based per-word results from POST .../analyze_word_level
  /// (phoneme recognition diffed against the ayah's canonical phoneme
  /// sequence), covering the whole ayah range. Null only when the phoneme model
  /// isn't loaded server-side, or for a session loaded from history (which
  /// stores the mistakes, not every word).
  final List<WordVerdict>? wordVerdicts;

  /// How much of the requested range was covered: [wordsRecited] of
  /// [totalWords]. Without these the accuracy percentage is unreadable.
  final int wordsRecited;
  final int totalWords;

  /// The recitation itself, as recorded (16 kHz mono PCM16, no WAV header).
  /// Kept so the user can hear the word they were marked down on -- being told
  /// an elongation was short is not much use if you can't hear your own. Null
  /// for sessions loaded from history: audio is never uploaded or stored.
  final Uint8List? audioPcm;

  /// Hasanah earned for the letters recited this session (ten per letter,
  /// per the hadith behind the app's hasanah counter).
  final int hasanahEarned;

  const SessionResult({
    required this.id,
    required this.surahName,
    required this.surahNumber,
    required this.dateTime,
    required this.accuracyScore,
    required this.duration,
    required this.errors,
    this.wordVerdicts,
    this.wordsRecited = 0,
    this.totalWords = 0,
    this.audioPcm,
    this.hasanahEarned = 0,
  });
}
