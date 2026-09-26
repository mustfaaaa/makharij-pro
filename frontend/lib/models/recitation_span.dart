import '../services/quran_text_repository.dart';
import 'quran_position.dart';

/// What one recording covers: where the reciter begins, and how far on it is
/// followed.
///
/// A span is a *starting point with a direction*, not a box around one ayah.
/// Choosing ayah 57 means "I begin at 57 and read on", so a reciter who carries
/// on to 58, 59, 60 is followed and scored on each of them. [end] exists for
/// deliberate practice of a fixed passage ("practise ayah 12"); without it the
/// span is open-ended.
///
/// The backend analyses one surah per recording for now, so an open span is
/// followed to the end of the surah it starts in. The span itself does not say
/// so -- that limit belongs to the request, and lives where the request is
/// built (SessionService, LiveRecitationChannel) so it can be lifted there.
class RecitationSpan {
  final QuranPosition start;

  /// The last ayah the session covers, inclusive. Null: onward from [start].
  final QuranPosition? end;

  const RecitationSpan({required this.start, this.end});

  /// A span from ayah [fromAyah] of [surah], to [toAyah] when given.
  factory RecitationSpan.inSurah(int surah, {int fromAyah = 1, int? toAyah}) => RecitationSpan(
        start: QuranPosition(surah, fromAyah),
        end: toAyah == null ? null : QuranPosition(surah, toAyah),
      );

  bool get isOpenEnded => end == null;

  /// Whether ayah [ayah] of [surah] belongs to this recitation.
  bool containsAyah(int surah, int ayah) {
    final at = QuranPosition(surah, ayah);
    if (at < start.ayahStart) return false;
    final last = end;
    return last == null || at <= last.ayahStart;
  }

  /// The same end, from a new start -- dropped if the start has moved past it,
  /// since a range that ends before it begins covers nothing.
  RecitationSpan startingAt(QuranPosition newStart) {
    final last = end;
    return RecitationSpan(start: newStart, end: last != null && last.ayahStart >= newStart.ayahStart ? last : null);
  }

  /// Where to begin the next recitation after one that reached [reached].
  ///
  /// [reachedAyahWords] are the words of the reached ayah as the bundled text
  /// splits them, and [ayahsInSurah] how many ayahs its surah has.
  ///
  /// A reciter who finished the ayah goes on to the next one, crossing into the
  /// next surah after the last. One who stopped part-way through an ayah goes
  /// back to its beginning: the analysis starts at an ayah's first word, and a
  /// start mid-ayah would score the words before it as never recited. Null
  /// once the reached ayah closes the Quran.
  static QuranPosition? resumeAfter(
    QuranPosition reached, {
    required List<String> reachedAyahWords,
    required int ayahsInSurah,
    int lastSurah = 114,
  }) {
    if (reached.word < lastSpokenWord(reachedAyahWords)) return reached.ayahStart;
    if (reached.ayah < ayahsInSurah) return QuranPosition(reached.surah, reached.ayah + 1);
    if (reached.surah < lastSurah) return QuranPosition(reached.surah + 1, 1);
    return null;
  }

  /// The index of an ayah's last word that is said aloud. A waqf sign or the
  /// hizb ornament is written as a word of its own and carries no sound, so
  /// an ayah is finished with only those left after its last spoken word --
  /// and the live cursor never lands on one.
  static int lastSpokenWord(List<String> ayahWords) {
    var last = ayahWords.length - 1;
    while (last > 0 && ayahWords[last].runes.every(QuranTextRepository.isMark)) {
      last--;
    }
    return last;
  }

  @override
  bool operator ==(Object other) => other is RecitationSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'RecitationSpan($start → ${end ?? 'onward'})';
}
