import '../models/surah.dart';

/// Static placeholder Surah list. Subset only — real dataset comes with
/// backend integration in a later phase.
final List<Surah> dummySurahs = [
  const Surah(number: 1, nameArabic: 'الفاتحة', nameEnglish: 'Al-Fatihah', meaning: 'The Opening', ayahCount: 7, revelationPlace: 'Makkah', lastScore: 92, isBookmarked: true),
  const Surah(number: 2, nameArabic: 'البقرة', nameEnglish: 'Al-Baqarah', meaning: 'The Cow', ayahCount: 286, revelationPlace: 'Madinah', lastScore: 78),
  const Surah(number: 18, nameArabic: 'الكهف', nameEnglish: 'Al-Kahf', meaning: 'The Cave', ayahCount: 110, revelationPlace: 'Makkah', lastScore: 85, isBookmarked: true),
  const Surah(number: 36, nameArabic: 'يس', nameEnglish: 'Ya-Sin', meaning: 'Ya Sin', ayahCount: 83, revelationPlace: 'Makkah', lastScore: 88),
  const Surah(number: 55, nameArabic: 'الرحمن', nameEnglish: 'Ar-Rahman', meaning: 'The Beneficent', ayahCount: 78, revelationPlace: 'Madinah'),
  const Surah(number: 56, nameArabic: 'الواقعة', nameEnglish: 'Al-Waqi\'ah', meaning: 'The Inevitable', ayahCount: 96, revelationPlace: 'Makkah'),
  const Surah(number: 67, nameArabic: 'الملك', nameEnglish: 'Al-Mulk', meaning: 'The Sovereignty', ayahCount: 30, revelationPlace: 'Makkah', lastScore: 95),
  const Surah(number: 112, nameArabic: 'الإخلاص', nameEnglish: 'Al-Ikhlas', meaning: 'The Sincerity', ayahCount: 4, revelationPlace: 'Makkah', lastScore: 97),
  const Surah(number: 113, nameArabic: 'الفلق', nameEnglish: 'Al-Falaq', meaning: 'The Daybreak', ayahCount: 5, revelationPlace: 'Makkah'),
  const Surah(number: 114, nameArabic: 'الناس', nameEnglish: 'An-Nas', meaning: 'Mankind', ayahCount: 6, revelationPlace: 'Makkah', lastScore: 90),
];
