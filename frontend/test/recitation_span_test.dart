// A recitation is a place to begin and a direction, not a box around one ayah.
// These pin the order of positions across surahs, what a span covers, and
// where "Continue from here" picks up after a recording stops.
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/quran_position.dart';
import 'package:frontend/models/recitation_span.dart';

void main() {
  group('QuranPosition', () {
    test('orders by surah, then ayah, then word', () {
      expect(const QuranPosition(2, 286) < const QuranPosition(3, 1), isTrue);
      expect(const QuranPosition(2, 57) < const QuranPosition(2, 58), isTrue);
      expect(const QuranPosition(2, 57, word: 3) > const QuranPosition(2, 57), isTrue);
      expect(const QuranPosition(3, 1).compareTo(const QuranPosition(3, 1)), 0);
    });

    test('ayahStart drops the word', () {
      expect(const QuranPosition(2, 57, word: 4).ayahStart, const QuranPosition(2, 57));
    });
  });

  group('RecitationSpan', () {
    test('an open span covers its start and everything after it', () {
      final span = RecitationSpan.inSurah(2, fromAyah: 57);
      expect(span.isOpenEnded, isTrue);
      expect(span.containsAyah(2, 56), isFalse);
      expect(span.containsAyah(2, 57), isTrue);
      expect(span.containsAyah(2, 286), isTrue);
      // The span itself does not end at the surah; the request built from it
      // does, for as long as the backend analyses one surah per recording.
      expect(span.containsAyah(3, 1), isTrue);
    });

    test('a fixed range covers exactly its ayahs', () {
      final span = RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 60);
      expect(span.containsAyah(2, 56), isFalse);
      expect(span.containsAyah(2, 57), isTrue);
      expect(span.containsAyah(2, 60), isTrue);
      expect(span.containsAyah(2, 61), isFalse);
      expect(span.containsAyah(3, 1), isFalse);
    });

    test('moving the start keeps an end still ahead of it, and drops one behind it', () {
      final span = RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 60);
      expect(span.startingAt(const QuranPosition(2, 58)).end, const QuranPosition(2, 60));
      expect(span.startingAt(const QuranPosition(2, 60)).end, const QuranPosition(2, 60));
      expect(span.startingAt(const QuranPosition(2, 61)).end, isNull);
    });
  });

  group('resumeAfter', () {
    const words = ['قَالَ', 'رَبِّ', 'ٱغْفِرْ', 'لِى'];

    test('a finished ayah continues at the next one', () {
      expect(
        RecitationSpan.resumeAfter(const QuranPosition(2, 60, word: 3), reachedAyahWords: words, ayahsInSurah: 286),
        const QuranPosition(2, 61),
      );
    });

    test('an ayah stopped part-way is begun again, from its first word', () {
      expect(
        RecitationSpan.resumeAfter(const QuranPosition(2, 60, word: 1), reachedAyahWords: words, ayahsInSurah: 286),
        const QuranPosition(2, 60),
      );
    });

    test('a silent waqf sign after the last spoken word does not hold the ayah open', () {
      const withWaqf = ['قَالَ', 'رَبِّ', 'ۖ'];
      expect(
        RecitationSpan.resumeAfter(const QuranPosition(2, 60, word: 1), reachedAyahWords: withWaqf, ayahsInSurah: 286),
        const QuranPosition(2, 61),
      );
    });

    test('the last ayah of a surah continues into the next surah', () {
      expect(
        RecitationSpan.resumeAfter(const QuranPosition(2, 286, word: 3), reachedAyahWords: words, ayahsInSurah: 286),
        const QuranPosition(3, 1),
      );
    });

    test('the last spoken word of an ayah passes over silent signs written after it', () {
      expect(RecitationSpan.lastSpokenWord(words), 3);
      expect(RecitationSpan.lastSpokenWord(const ['قَالَ', 'رَبِّ', 'ۖ']), 1);
      expect(RecitationSpan.lastSpokenWord(const ['قَالَ']), 0);
    });

    test('there is nothing to continue to after the last ayah of the Quran', () {
      expect(
        RecitationSpan.resumeAfter(const QuranPosition(114, 6, word: 3), reachedAyahWords: words, ayahsInSurah: 6),
        isNull,
      );
    });
  });
}
