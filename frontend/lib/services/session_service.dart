import 'dart:math';

import '../dummy/dummy_ayahs.dart';
import '../dummy/dummy_sessions.dart';
import '../dummy/dummy_surahs.dart';
import '../models/session_result.dart';
import '../models/tajweed_error.dart';

abstract class SessionService {
  Future<List<SessionResult>> getSessions();
  Future<SessionResult> getSessionById(String id);

  /// Simulates the backend returning a freshly analyzed recitation result —
  /// score and flagged words are randomly generated each call, standing in
  /// for the real MFCC/TensorFlow inference pipeline (Phase 12).
  Future<SessionResult> generateSessionResult(int surahNumber);
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
  Future<SessionResult> generateSessionResult(int surahNumber) async {
    await Future.delayed(const Duration(milliseconds: 2200));

    final surah = dummySurahs.firstWhere((s) => s.number == surahNumber, orElse: () => dummySurahs.first);
    final score = 62 + _random.nextInt(37).toDouble(); // 62–98

    final allWords = dummyFatihahAyahs.expand((a) => a.arabicText.split(' ').map((w) => (word: w, ayah: a.number))).toList();
    final errorCount = score >= 90 ? _random.nextInt(2) : 1 + _random.nextInt(3);
    allWords.shuffle(_random);
    final types = TajweedErrorType.values;
    final errors = allWords.take(errorCount).map((w) {
      final type = types[_random.nextInt(types.length)];
      return TajweedError(word: w.word, ayahNumber: w.ayah, type: type, explanation: _explanationFor(type));
    }).toList();

    final result = SessionResult(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      surahName: surah.nameEnglish,
      surahNumber: surah.number,
      dateTime: DateTime.now(),
      accuracyScore: score,
      duration: Duration(minutes: 1 + _random.nextInt(6), seconds: _random.nextInt(60)),
      errors: errors,
    );
    _sessions.insert(0, result);
    return result;
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
    }
  }
}
