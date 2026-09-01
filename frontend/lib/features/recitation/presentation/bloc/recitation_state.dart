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
      ];
}
