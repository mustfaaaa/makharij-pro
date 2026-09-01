import 'tajweed_error.dart';

/// Real, evidence-based per-word result from POST /api/v1/sessions/analyze_word_level
/// (Gate 1+2, see makharij_audit) -- the phoneme model's actual recognized
/// output for this word, with its real timestamps, diffed against the ayah's
/// canonical phoneme sequence. Unlike the old simulated preview, every field
/// here traces back to a measurement: [startSec]/[endSec] from the recognizer's
/// own token timings, [errorType]/[explanation] from which Tajweed feature the
/// phoneme diff actually broke.
class WordVerdict {
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

  /// Which Tajweed rule the mistake belongs to, and a sentence explaining it.
  /// Both null when the word was recited correctly or wasn't reached.
  final TajweedErrorType? errorType;
  final String? explanation;

  const WordVerdict({
    required this.ayahNumber,
    required this.wordIndex,
    required this.word,
    required this.startSec,
    required this.endSec,
    required this.distance,
    required this.confidence,
    required this.recited,
    required this.flagged,
    this.errorType,
    this.explanation,
  });

  factory WordVerdict.fromJson(Map<String, dynamic> json) {
    return WordVerdict(
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
      errorType: tajweedErrorTypeFromId(json['error_type'] as String?),
      explanation: json['explanation'] as String?,
    );
  }
}
