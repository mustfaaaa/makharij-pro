import '../models/ayah.dart';

/// Placeholder ayahs for Al-Fatihah, used across recitation/result screens.
final List<Ayah> dummyFatihahAyahs = [
  const Ayah(number: 1, arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', translation: 'In the name of Allah, the Most Gracious, the Most Merciful.'),
  const Ayah(number: 2, arabicText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ', translation: 'All praise is due to Allah, Lord of the worlds.', errorWordIndexes: [1]),
  const Ayah(number: 3, arabicText: 'الرَّحْمَٰنِ الرَّحِيمِ', translation: 'The Most Gracious, the Most Merciful.'),
  const Ayah(number: 4, arabicText: 'مَالِكِ يَوْمِ الدِّينِ', translation: 'Master of the Day of Judgment.', errorWordIndexes: [0]),
  const Ayah(number: 5, arabicText: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', translation: 'It is You we worship and You we ask for help.'),
  const Ayah(number: 6, arabicText: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ', translation: 'Guide us to the straight path.'),
  const Ayah(number: 7, arabicText: 'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ', translation: 'The path of those upon whom You have bestowed favor, not of those who have evoked anger or of those who are astray.'),
];
