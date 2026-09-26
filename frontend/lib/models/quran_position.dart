/// A place in the Quran, in mushaf order: a surah, an ayah in it, and
/// optionally a word in that ayah.
///
/// Navigation and recitation both address the text this way, rather than by
/// an ayah number that only means something inside one surah. A Juz begins
/// mid-surah and runs into the next one, and a reciter can do the same, so a
/// bare ayah number cannot say where either of them is.
///
/// [word] indexes the bundled text's words (`Ayah.arabicText.split(' ')`), the
/// same indices the analysis reports. Navigation leaves it at 0.
class QuranPosition implements Comparable<QuranPosition> {
  final int surah;
  final int ayah;
  final int word;

  const QuranPosition(this.surah, this.ayah, {this.word = 0});

  /// The same ayah, at its first word.
  QuranPosition get ayahStart => word == 0 ? this : QuranPosition(surah, ayah);

  @override
  int compareTo(QuranPosition other) {
    if (surah != other.surah) return surah.compareTo(other.surah);
    if (ayah != other.ayah) return ayah.compareTo(other.ayah);
    return word.compareTo(other.word);
  }

  bool operator <(QuranPosition other) => compareTo(other) < 0;
  bool operator <=(QuranPosition other) => compareTo(other) <= 0;
  bool operator >(QuranPosition other) => compareTo(other) > 0;
  bool operator >=(QuranPosition other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is QuranPosition && other.surah == surah && other.ayah == ayah && other.word == word;

  @override
  int get hashCode => Object.hash(surah, ayah, word);

  @override
  String toString() => word == 0 ? '$surah:$ayah' : '$surah:$ayah#$word';
}
