import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../dummy/dummy_surahs.dart';
import '../models/ayah.dart';
import '../models/surah.dart';
import 'api_client.dart';
import 'quran_text_repository.dart';

abstract class SurahService {
  Future<List<Surah>> getSurahs();
  Future<Surah> getSurahByNumber(int number);
  Future<Surah> toggleBookmark(int number);

  /// The real Uthmani Arabic text + translation for every ayah of [number],
  /// loaded from the bundled Quran asset (all 114 surahs).
  Future<List<Ayah>> getAyahs(int number);
}

/// Serves the real, complete 114-surah list (names/meanings/ayah counts are
/// accurate reference data) plus real per-user state merged in: lastScore
/// from actual session history (/api/v1/sessions) and isBookmarked from the
/// same Firestore user document TajweedRuleService/UserService use.
class AssetSurahService implements SurahService {
  // Lazy getters, not eager fields: getAyahs() (the only method the Quran
  // text test suite exercises) never touches Firebase, and evaluating
  // FirebaseAuth.instance at construction time would crash there since no
  // Firebase app is initialized in a plain `flutter test` environment.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final ApiClient _client = const ApiClient();

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  Future<Set<int>> _bookmarkedNumbers() async {
    final doc = _doc;
    if (doc == null) return const {};
    final snapshot = await doc.get();
    final list = (snapshot.data()?['bookmarkedSurahs'] as List?)?.cast<int>() ?? const [];
    return list.toSet();
  }

  Future<Map<int, double>> _lastScoresBySurah() async {
    if (_auth.currentUser == null) return const {};
    try {
      final json = await _client.get('/api/v1/sessions');
      final sessions = (json['sessions'] as List).cast<Map<String, dynamic>>();
      // Sessions are ordered newest-first, so the first one seen per surah is the latest.
      final scores = <int, double>{};
      for (final s in sessions) {
        final number = s['surahNumber'] as int?;
        if (number == null || scores.containsKey(number)) continue;
        final accuracy = s['accuracyScore'] as num?;
        if (accuracy != null) scores[number] = accuracy.toDouble() * 100;
      }
      return scores;
    } catch (_) {
      return const {};
    }
  }

  Future<List<Surah>> _surahsWithRealState() async {
    final bookmarked = await _bookmarkedNumbers();
    final scores = await _lastScoresBySurah();
    return dummySurahs
        .map((s) => s.copyWith(isBookmarked: bookmarked.contains(s.number), lastScore: scores[s.number]))
        .toList();
  }

  @override
  Future<List<Surah>> getSurahs() => _surahsWithRealState();

  @override
  Future<Surah> getSurahByNumber(int number) async {
    final surahs = await _surahsWithRealState();
    return surahs.firstWhere((s) => s.number == number, orElse: () => surahs.first);
  }

  @override
  Future<Surah> toggleBookmark(int number) async {
    final doc = _doc;
    final surahs = await _surahsWithRealState();
    final current = surahs.firstWhere((s) => s.number == number, orElse: () => surahs.first);
    if (doc == null) return current;
    final nowBookmarked = !current.isBookmarked;
    await doc.set({
      'bookmarkedSurahs': nowBookmarked ? FieldValue.arrayUnion([number]) : FieldValue.arrayRemove([number]),
    }, SetOptions(merge: true));
    return current.copyWith(isBookmarked: nowBookmarked);
  }

  @override
  Future<List<Ayah>> getAyahs(int number) => QuranTextRepository.instance.ayahsForSurah(number);
}
