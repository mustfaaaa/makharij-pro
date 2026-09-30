import 'tajweed_error.dart';

/// Real, evidence-based per-word result from POST /api/v1/sessions/analyze_word_level
/// (Gate 1+2, see makharij_audit) -- the phoneme model's actual recognized
/// output for this word, with its real timestamps, diffed against the ayah's
/// canonical phoneme sequence. Unlike the old simulated preview, every field
/// here traces back to a measurement: [startSec]/[endSec] from the recognizer's
/// own token timings, [errorType]/[explanation] from which Tajweed feature the
/// phoneme diff actually broke.
class WordVerdict {
  /// The surah this word is in. Null from a server that analyses one surah per
  /// recording and so never says: the word is then in the session's own surah.
  final int? surahNumber;
  final int ayahNumber;

  /// Index of this word within its own ayah (not within the whole surah).
  final int wordIndex;
  final String word;
  final double startSec;
  final double endSec;
  final double distance;
  final double confidence;

  /// False when the recording never reached this word -- the user stopped
  /// earlier. Not a mistake, and never scored as one.
  final bool recited;
  final bool flagged;

  /// Whether the backend considers this reliable enough to affect progress
  /// statistics. A generic pronunciation mismatch can still be shown for the
  /// learner to review without being counted as a confirmed mistake.
  final String reviewStatus;
  final bool countsTowardScore;
  final Map<String, dynamic>? durationEvidence;
  final int evidenceCount;

  /// Which Tajweed rule the mistake belongs to, and a sentence explaining it.
  /// Both null when the word was recited correctly or wasn't reached.
  final TajweedErrorType? errorType;
  final String? explanation;

  const WordVerdict({
    this.surahNumber,
    required this.ayahNumber,
    required this.wordIndex,
    required this.word,
    required this.startSec,
    required this.endSec,
    required this.distance,
    required this.confidence,
    required this.recited,
    required this.flagged,
    this.reviewStatus = 'confirmed_error',
    this.countsTowardScore = true,
    this.durationEvidence,
    this.evidenceCount = 0,
    this.errorType,
    this.explanation,
  });

  factory WordVerdict.fromJson(Map<String, dynamic> json) {
    return WordVerdict(
      surahNumber: json['surah_number'] as int?,
      ayahNumber: json['ayah_number'] as int? ?? 1,
      wordIndex: json['word_index'] as int? ?? 0,
      word: json['word'] as String,
      startSec: (json['start_sec'] as num).toDouble(),
      endSec: (json['end_sec'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      // Older servers don't send `recited`; treat their words as recited so
      // the response still renders rather than coming back entirely greyed out.
      recited: json['recited'] as bool? ?? true,
      flagged: json['flagged'] as bool,
      reviewStatus:
          json['review_status'] as String? ??
          ((json['flagged'] as bool? ?? false) ? 'confirmed_error' : 'correct'),
      countsTowardScore: json['counts_toward_score'] as bool? ?? true,
      durationEvidence: (json['duration_evidence'] as Map?)
          ?.cast<String, dynamic>(),
      evidenceCount: json['evidence_count'] as int? ?? 0,
      errorType: tajweedErrorTypeFromId(json['error_type'] as String?),
      explanation: json['explanation'] as String?,
    );
  }
}
