class Surah {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final String meaning;
  final int ayahCount;
  final String revelationPlace;
  final double? lastScore;
  final bool isBookmarked;

  const Surah({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.meaning,
    required this.ayahCount,
    required this.revelationPlace,
    this.lastScore,
    this.isBookmarked = false,
  });
}
