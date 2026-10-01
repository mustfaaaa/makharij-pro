/// The traditional Indo-Pak names used for the thirty Quran paras.
///
/// These are display names, not a value derived from the first ayah in the
/// bundled Madinah division. A few traditional para names begin immediately
/// before the corresponding Madinah juz boundary, so deriving them from the
/// current boundary produces the wrong label.
class JuzName {
  final int number;
  final String transliteration;
  final String arabic;

  const JuzName(this.number, this.transliteration, this.arabic);
}

const juzNames = <JuzName>[
  JuzName(1, 'Alif Laam Meem', 'الٓمٓ'),
  JuzName(2, 'Sayaqool', 'سَيَقُولُ'),
  JuzName(3, 'Tilkal Rusul', 'تِلْكَ ٱلرُّسُلُ'),
  JuzName(4, 'Lan Tanaaloo', 'لَن تَنَالُوا۟'),
  JuzName(5, 'Wal Mohsanat', 'وَٱلْمُحْصَنَٰتُ'),
  JuzName(6, 'La Yuhibbullah', 'لَا يُحِبُّ ٱللَّهُ'),
  JuzName(7, "Wa Iza Sami'u", 'وَإِذَا سَمِعُوا۟'),
  JuzName(8, 'Wa Lau Annana', 'وَلَوْ أَنَّنَا'),
  JuzName(9, "Qalal Mala'u", 'قَالَ ٱلْمَلَأُ'),
  JuzName(10, "Wa'lamu", 'وَٱعْلَمُوٓا۟'),
  JuzName(11, "Ya'tazirun", 'يَعْتَذِرُونَ'),
  JuzName(12, 'Wa Ma Min Daabbah', 'وَمَا مِن دَآبَّةٍ'),
  JuzName(13, "Wa Ma Ubarri'u", 'وَمَآ أُبَرِّئُ'),
  JuzName(14, 'Rubama', 'رُّبَمَا'),
  JuzName(15, 'Subhanallazi', 'سُبْحَٰنَ ٱلَّذِى'),
  JuzName(16, 'Qala Alam', 'قَالَ أَلَمْ'),
  JuzName(17, 'Iqtaraba', 'ٱقْتَرَبَ لِلنَّاسِ'),
  JuzName(18, 'Qad Aflaha', 'قَدْ أَفْلَحَ'),
  JuzName(19, 'Wa Qalallazina', 'وَقَالَ ٱلَّذِينَ'),
  JuzName(20, 'Amman Khalaqa', 'أَمَّنْ خَلَقَ'),
  JuzName(21, 'Utlu Ma Uhiya', 'ٱتْلُ مَآ أُوحِىَ'),
  JuzName(22, 'Wa Man Yaqnut', 'وَمَن يَقْنُتْ'),
  JuzName(23, 'Wa Ma Liya', 'وَمَا لِىَ'),
  JuzName(24, 'Faman Azlamu', 'فَمَنْ أَظْلَمُ'),
  JuzName(25, 'Ilayhi Yuraddu', 'إِلَيْهِ يُرَدُّ'),
  JuzName(26, 'Ha Meem', 'حمٓ'),
  JuzName(27, 'Qala Fama Khatbukum', 'قَالَ فَمَا خَطْبُكُمْ'),
  JuzName(28, 'Qad Sami Allah', 'قَدْ سَمِعَ ٱللَّهُ'),
  JuzName(29, 'Tabarakallazi', 'تَبَٰرَكَ ٱلَّذِى'),
  JuzName(30, "Amma Yatasa'alun", 'عَمَّ يَتَسَآءَلُونَ'),
];

JuzName juzName(int number) {
  if (number < 1 || number > juzNames.length) {
    throw RangeError.range(number, 1, juzNames.length, 'number');
  }
  return juzNames[number - 1];
}
