import 'package:equatable/equatable.dart';

import '../../../../models/ayah.dart';
import '../../../../models/session_result.dart';
import '../../../../services/live_recitation_channel.dart';

enum RecitationStatus { idle, listening, processing, result, error }

class RecitationState extends Equatable {
  final RecitationStatus status;
  final int? surahNumber;
  final List<Ayah> ayahs;

  /// The ayahs the user chose to practise. Defaults to the whole surah; a
  /// 286-ayah surah is not something anyone recites in one go, so the reading
  /// page lets them narrow it.
  final int fromAyah;
  final int? toAyah;
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

  /// What the analyser made of the ayahs already finished, keyed by ayah
  /// number, arriving while the reciter is still going.
  ///
  /// Separate from [livePosition] because it means something different: the
  /// position is immediate and never accuses, these may flag mistakes but
  /// trail about an ayah behind. And separate from [result], which judges the
  /// whole recording and is the verdict that finally stands.
  final Map<int, LiveAyahVerdicts> liveVerdicts;

  const RecitationState({
    this.status = RecitationStatus.idle,
    this.surahNumber,
    this.ayahs = const [],
    this.fromAyah = 1,
    this.toAyah,
    this.result,
    this.errorMessage,
    this.liveConnected = false,
    this.livePosition,
    this.liveVerdicts = const {},
  });

  /// How many words of the surah have been recited so far, live. 0 before the
  /// reciter has said anything the recognizer could place.
  int get liveWordsRecited => livePosition == null ? 0 : livePosition!.globalIndex + 1;

  /// The ayahs currently selected for practice.
  List<Ayah> get selectedAyahs => ayahs
      .where((a) => a.number >= fromAyah && (toAyah == null || a.number <= toAyah!))
      .toList();

  bool get isWholeSurah =>
      fromAyah == 1 && (toAyah == null || ayahs.isEmpty || toAyah == ayahs.last.number);

  RecitationState copyWith({
    RecitationStatus? status,
    int? surahNumber,
    List<Ayah>? ayahs,
    int? fromAyah,
    int? toAyah,
    SessionResult? result,
    String? errorMessage,
    bool? liveConnected,
    LivePosition? livePosition,
    Map<int, LiveAyahVerdicts>? liveVerdicts,
    bool clearLivePosition = false,
    bool clearToAyah = false,
  }) {
    return RecitationState(
      status: status ?? this.status,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahs: ayahs ?? this.ayahs,
      fromAyah: fromAyah ?? this.fromAyah,
      toAyah: clearToAyah ? null : (toAyah ?? this.toAyah),
      result: result ?? this.result,
      errorMessage: errorMessage,
      liveConnected: liveConnected ?? this.liveConnected,
      livePosition: clearLivePosition ? null : (livePosition ?? this.livePosition),
      // Cleared alongside the position: both belong to one recitation, and
      // carrying last time's verdicts into a new one would mark words the
      // reciter has not said yet.
      liveVerdicts: clearLivePosition ? const {} : (liveVerdicts ?? this.liveVerdicts),
    );
  }

  @override
  List<Object?> get props => [
        status,
        surahNumber,
        ayahs,
        fromAyah,
        toAyah,
        result,
        errorMessage,
        liveConnected,
        livePosition?.globalIndex,
        // Words, not ayahs: verdicts arrive a few words at a time and merge
        // into an ayah already present, so counting ayahs would leave the state
        // looking unchanged and the page would never repaint them.
        liveVerdicts.values.fold<int>(0, (n, v) => n + v.correctByWord.length),
      ];
}
