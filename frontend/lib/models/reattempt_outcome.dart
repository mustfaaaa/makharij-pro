/// What came back from re-reciting a word the analysis flagged (FR-8/BR-5).
///
/// Three outcomes, and the screen has to tell them apart, because they call for
/// different things to be said:
///
///   * [corrected]    — the retake was clean. Say so, and stop flagging it.
///   * [stillWrong]   — heard, still not right. The explanation is the *new*
///                      take's, not the old one's.
///   * [notReached]   — the recording never got to the word. Not a verdict at
///                      all, and telling someone they were wrong when the mic
///                      simply missed them is the failure this app already has
///                      too much of.
class ReattemptOutcome {
  final List<ReattemptWord> corrected;
  final List<ReattemptWord> stillWrong;
  final List<ReattemptWord> notReached;

  /// Recomputed over the original attempt's word count, so it is comparable
  /// with the score the results screen was already showing.
  final double accuracyScore;
  final int wordsCorrect;
  final int wordsRecited;

  const ReattemptOutcome({
    required this.corrected,
    required this.stillWrong,
    required this.notReached,
    required this.accuracyScore,
    required this.wordsCorrect,
    required this.wordsRecited,
  });

  /// True when every word this retake was asked about is now right.
  bool get allCorrected => corrected.isNotEmpty && stillWrong.isEmpty && notReached.isEmpty;

  /// The single word this retake was about, when it was about one word.
  ReattemptWord? get only {
    final all = [...corrected, ...stillWrong, ...notReached];
    return all.length == 1 ? all.first : null;
  }

  static List<ReattemptWord> _words(dynamic raw) => (raw as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(ReattemptWord.fromJson)
      .toList();

  factory ReattemptOutcome.fromJson(Map<String, dynamic> json) => ReattemptOutcome(
        corrected: _words(json['corrected']),
        stillWrong: _words(json['still_wrong']),
        notReached: _words(json['not_reached']),
        accuracyScore: ((json['accuracy_score'] as num?) ?? 0).toDouble() * 100,
        wordsCorrect: (json['words_correct'] as int?) ?? 0,
        wordsRecited: (json['words_recited'] as int?) ?? 0,
      );
}

class ReattemptWord {
  final int ayahNumber;
  final int wordIndex;

  /// Absent on `not_reached`: the backend has no new verdict to name a word
  /// from, only the coordinates it was asked about.
  final String? word;
  final String? errorType;

  const ReattemptWord({
    required this.ayahNumber,
    required this.wordIndex,
    this.word,
    this.errorType,
  });

  factory ReattemptWord.fromJson(Map<String, dynamic> json) => ReattemptWord(
        ayahNumber: (json['ayahNumber'] as int?) ?? 0,
        wordIndex: (json['wordIndex'] as int?) ?? 0,
        word: json['word'] as String?,
        errorType: json['errorType'] as String?,
      );
}
