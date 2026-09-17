import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/reattempt_outcome.dart';

/// FR-8/BR-5's response, as the results screen has to read it.
///
/// The distinction worth pinning is `notReached` against `stillWrong`. They
/// arrive in the same shape and mean opposite things: one is "you said it, it
/// was still off", the other is "the recording never got there". Collapsing
/// them would make the app tell someone they recited a word wrongly when the
/// microphone simply missed them -- the exact failure this feature exists to
/// give people a way out of.
void main() {
  group('ReattemptOutcome.fromJson', () {
    test('a word that came back right', () {
      final outcome = ReattemptOutcome.fromJson({
        'session_id': 'abc',
        'corrected': [
          {'ayahNumber': 2, 'wordIndex': 3, 'word': 'ٱلرَّحْمَٰنِ'}
        ],
        'still_wrong': [],
        'not_reached': [],
        'words_correct': 6,
        'words_recited': 7,
        'accuracy_score': 0.8571,
      });

      expect(outcome.corrected.single.wordIndex, 3);
      expect(outcome.corrected.single.word, 'ٱلرَّحْمَٰنِ');
      expect(outcome.allCorrected, isTrue);
      // The backend sends a 0-1 proportion; the screen shows a percentage.
      expect(outcome.accuracyScore, closeTo(85.71, 0.01));
      expect(outcome.wordsCorrect, 6);
    });

    test('a word that is still wrong carries the new attempt\'s rule', () {
      final outcome = ReattemptOutcome.fromJson({
        'corrected': [],
        'still_wrong': [
          {'ayahNumber': 1, 'wordIndex': 0, 'word': 'قُلْ', 'errorType': 'shaddah'}
        ],
        'not_reached': [],
        'accuracy_score': 0.5,
      });

      expect(outcome.stillWrong.single.errorType, 'shaddah');
      expect(outcome.allCorrected, isFalse);
    });

    test('a word the retake never reached is not a wrong word', () {
      final outcome = ReattemptOutcome.fromJson({
        'corrected': [],
        'still_wrong': [],
        'not_reached': [
          {'ayahNumber': 1, 'wordIndex': 4}
        ],
        'accuracy_score': 0.5,
      });

      expect(outcome.notReached, hasLength(1));
      expect(outcome.stillWrong, isEmpty);
      expect(outcome.allCorrected, isFalse,
          reason: 'nothing was corrected, so the screen must not claim success');
      // No verdict was produced for it, so there is no word text to show.
      expect(outcome.notReached.single.word, isNull);
    });

    test('correcting one word while another stays wrong is not all-corrected', () {
      final outcome = ReattemptOutcome.fromJson({
        'corrected': [
          {'ayahNumber': 1, 'wordIndex': 0, 'word': 'قُلْ'}
        ],
        'still_wrong': [
          {'ayahNumber': 1, 'wordIndex': 2, 'word': 'ٱللَّهُ', 'errorType': 'madd'}
        ],
        'not_reached': [],
        'accuracy_score': 0.66,
      });

      expect(outcome.allCorrected, isFalse);
      expect(outcome.only, isNull, reason: 'two words, so no single subject');
    });

    test('a single-word retake exposes its one word whatever the outcome', () {
      for (final key in ['corrected', 'still_wrong', 'not_reached']) {
        final outcome = ReattemptOutcome.fromJson({
          'corrected': const [],
          'still_wrong': const [],
          'not_reached': const [],
          key: [
            {'ayahNumber': 3, 'wordIndex': 1}
          ],
          'accuracy_score': 0.5,
        });
        expect(outcome.only?.wordIndex, 1, reason: 'for $key');
        expect(outcome.only?.ayahNumber, 3, reason: 'for $key');
      }
    });

    test('integer-valued accuracy still parses as a double', () {
      final outcome = ReattemptOutcome.fromJson({
        'corrected': const [],
        'still_wrong': const [],
        'not_reached': const [],
        'accuracy_score': 1,
      });
      expect(outcome.accuracyScore, 100.0);
    });

    test('missing lists from an older server do not throw', () {
      final outcome = ReattemptOutcome.fromJson({'session_id': 'abc'});

      expect(outcome.corrected, isEmpty);
      expect(outcome.stillWrong, isEmpty);
      expect(outcome.notReached, isEmpty);
      expect(outcome.accuracyScore, 0);
      expect(outcome.allCorrected, isFalse);
    });
  });
}
