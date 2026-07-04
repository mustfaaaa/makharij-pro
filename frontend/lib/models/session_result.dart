import 'tajweed_error.dart';

class SessionResult {
  final String id;
  final String surahName;
  final int surahNumber;
  final DateTime dateTime;
  final double accuracyScore;
  final Duration duration;
  final List<TajweedError> errors;

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
    this.hasanahEarned = 0,
  });
}
