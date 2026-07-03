import '../dummy/dummy_surahs.dart';
import '../models/surah.dart';

abstract class SurahService {
  Future<List<Surah>> getSurahs();
  Future<Surah> getSurahByNumber(int number);
  Future<Surah> toggleBookmark(int number);
}

/// Serves the static dummy Surah list behind a simulated network delay.
/// Swap for an HTTP/Firestore-backed implementation once the backend lands.
class DummySurahService implements SurahService {
  final List<Surah> _surahs = List.of(dummySurahs);

  @override
  Future<List<Surah>> getSurahs() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return List.unmodifiable(_surahs);
  }

  @override
  Future<Surah> getSurahByNumber(int number) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _surahs.firstWhere((s) => s.number == number, orElse: () => _surahs.first);
  }

  @override
  Future<Surah> toggleBookmark(int number) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _surahs.indexWhere((s) => s.number == number);
    if (index == -1) return _surahs.first;
    final current = _surahs[index];
    final updated = Surah(
      number: current.number,
      nameArabic: current.nameArabic,
      nameEnglish: current.nameEnglish,
      meaning: current.meaning,
      ayahCount: current.ayahCount,
      revelationPlace: current.revelationPlace,
      lastScore: current.lastScore,
      isBookmarked: !current.isBookmarked,
    );
    _surahs[index] = updated;
    return updated;
  }
}
