import 'package:equatable/equatable.dart';

import '../../../../models/ayah.dart';
import '../../../../models/recitation_span.dart';
import '../../../../models/session_result.dart';
import '../../../../services/live_recitation_channel.dart';

enum RecitationStatus { idle, listening, processing, result, error }

/// One surah of the text the reading page shows, and its ayahs.
class PassageSurah {
  final int surah;
  final List<Ayah> ayahs;
  const PassageSurah(this.surah, this.ayahs);
}

class RecitationState extends Equatable {
  final RecitationStatus status;

  /// The surah whose text is loaded, all of it: the reading page shows the
  /// whole surah whatever part of it is being recited.
  final int? surahNumber;
  final List<Ayah> ayahs;

  /// The surahs after [surahNumber] the page has run on into, in order -- as
  /// the reader scrolls past the end of one, or the reciter recites past it.
  final List<PassageSurah> following;

  /// What the next (or current) recording covers: where the reciter begins,
  /// and, for fixed practice, where they stop. Null before a surah is opened.
  ///
  /// It used to be a from/to pair that also decided what the page showed, so
  /// choosing ayah 57 hid ayahs 1-56. The page now always shows the surah and
  /// only marks where recitation begins; this says what gets recorded.
  final RecitationSpan? span;
  final SessionResult? result;
  final String? errorMessage;

  /// Whether the live analysis socket is actually connected. False means the
  /// recitation still records and still gets scored at the end, but no words
  /// will light up while reciting -- the page must say so rather than sitting
  /// there looking broken.
  final bool liveConnected;

  /// Where the reciter has reached, updated live while recording. Null before
  /// the first word is recognized, and whenever no recitation is in progress.
  /// This is a progress signal only -- it never says anything about mistakes.
  final LivePosition? livePosition;

  /// What the analyser made of the ayahs already finished, keyed by
  /// (surah, ayah), arriving while the reciter is still going.
  ///
  /// Separate from [livePosition] because it means something different: the
  /// position is immediate and never accuses, these may flag mistakes but
  /// trail about an ayah behind. And separate from [result], which judges the
  /// whole recording and is the verdict that finally stands.
  final Map<(int, int), LiveAyahVerdicts> liveVerdicts;

  /// While the recitation is being judged: how much of it the server has
  /// judged so far, 0..1, as the server measures it. Null when there is no
  /// such measure -- the recording is being uploaded, whose progress this
  /// cannot see -- and the wait is then shown without a number.
  final double? analysisProgress;

  /// How long the recording being judged is, to say how far through it the
  /// judging has got.
  final Duration? recordedDuration;

  const RecitationState({
    this.status = RecitationStatus.idle,
    this.surahNumber,
    this.ayahs = const [],
    this.following = const [],
    this.span,
    this.result,
    this.errorMessage,
    this.liveConnected = false,
    this.livePosition,
    this.liveVerdicts = const {},
    this.analysisProgress,
    this.recordedDuration,
  });

  /// How many words of the session have been recited so far, live, counted
  /// from its first word. 0 before the reciter has said anything the
  /// recognizer could place.
  int get liveWordsRecited => livePosition == null ? 0 : livePosition!.globalIndex + 1;

  /// The ayah recitation begins at, within [surahNumber].
  int get fromAyah => span?.start.ayah ?? 1;

  /// The last ayah a fixed practice range covers, within [surahNumber]. Null
  /// when the recitation runs on from [fromAyah].
  int? get toAyah {
    final end = span?.end;
    return end != null && end.surah == surahNumber ? end.ayah : null;
  }

  /// What a recording made from the reading page covers: its span, as it is.
  /// A recitation left open is followed on into the surahs after this one --
  /// the page runs on into them as the reciter does.
  RecitationSpan? get recordingSpan => span;

  /// Everything the page shows: this surah, then the ones it has run on into.
  List<PassageSurah> get passage => [
        if (surahNumber != null) PassageSurah(surahNumber!, ayahs),
        ...following,
      ];

  /// The ayahs of [surah], if the page has them.
  List<Ayah> ayahsOf(int surah) {
    for (final p in passage) {
      if (p.surah == surah) return p.ayahs;
    }
    return const [];
  }

  /// The recitation's ayahs across the passage, in reading order, each with
  /// its surah -- the words the live cursor counts from the recitation's start.
  List<(int, Ayah)> get sessionPositions {
    final s = span;
    return [
      for (final p in passage)
        for (final a in p.ayahs)
          if (s == null || s.containsAyah(p.surah, a.number)) (p.surah, a),
    ];
  }

  /// The loaded ayahs of [surahNumber] that belong to the recitation -- what
  /// is recorded, followed and scored, as opposed to everything shown.
  List<Ayah> get sessionAyahs {
    final s = span;
    final surah = surahNumber;
    if (s == null || surah == null) return ayahs;
    return ayahs.where((a) => s.containsAyah(surah, a.number)).toList();
  }

  bool get isWholeSurah =>
      fromAyah == 1 && (toAyah == null || ayahs.isEmpty || toAyah == ayahs.last.number);

  /// The recitation's passage in a few words, for the dock and the wait.
  ///
  /// Left open, a recitation is followed on past the end of its surah, so it
  /// is "from" an ayah; stopping at the surah's last ayah is the whole surah.
  String get passageLabel {
    final s = span;
    final start = s?.start;
    if (start != null && start.surah != surahNumber) {
      // Begun in a surah the page ran on into.
      final end = s!.end;
      return end == null ? 'From ${start.surah}:${start.ayah}' : '${start.surah}:${start.ayah}–${end.ayah}';
    }
    final to = toAyah;
    if (to == null) return 'From ayah $fromAyah';
    if (fromAyah == 1 && ayahs.isNotEmpty && to == ayahs.last.number) return 'Whole surah';
    return to == fromAyah ? 'Ayah $fromAyah' : 'Ayahs $fromAyah–$to';
  }

  RecitationState copyWith({
    RecitationStatus? status,
    int? surahNumber,
    List<Ayah>? ayahs,
    List<PassageSurah>? following,
    RecitationSpan? span,
    SessionResult? result,
    String? errorMessage,
    bool? liveConnected,
    LivePosition? livePosition,
    Map<(int, int), LiveAyahVerdicts>? liveVerdicts,
    bool clearLivePosition = false,
    double? analysisProgress,
    Duration? recordedDuration,
    bool clearAnalysisProgress = false,
  }) {
    return RecitationState(
      status: status ?? this.status,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahs: ayahs ?? this.ayahs,
      following: following ?? this.following,
      span: span ?? this.span,
      result: result ?? this.result,
      errorMessage: errorMessage,
      liveConnected: liveConnected ?? this.liveConnected,
      livePosition: clearLivePosition ? null : (livePosition ?? this.livePosition),
      // Cleared alongside the position: both belong to one recitation, and
      // carrying last time's verdicts into a new one would mark words the
      // reciter has not said yet.
      liveVerdicts: clearLivePosition ? const {} : (liveVerdicts ?? this.liveVerdicts),
      analysisProgress: clearAnalysisProgress ? null : (analysisProgress ?? this.analysisProgress),
      recordedDuration: recordedDuration ?? this.recordedDuration,
    );
  }

  @override
  List<Object?> get props => [
        status,
        surahNumber,
        ayahs,
        following.length,
        span,
        result,
        errorMessage,
        liveConnected,
        livePosition?.globalIndex,
        // Words, not ayahs: verdicts arrive a few words at a time and merge
        // into an ayah already present, so counting ayahs would leave the state
        // looking unchanged and the page would never repaint them.
        liveVerdicts.values.fold<int>(0, (n, v) => n + v.correctByWord.length),
        analysisProgress,
        recordedDuration,
      ];
}
