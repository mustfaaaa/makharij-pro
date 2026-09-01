// Verifies WordVerdict.fromJson matches the real shape returned by
// POST /api/v1/sessions/analyze_word_level (see backend/app/routers/sessions.py's
// analyze_word_level response and PhonemeAnalysisService.WordPhonemeResult).
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/tajweed_error.dart';
import 'package:frontend/models/word_verdict.dart';

void main() {
  group('WordVerdict.fromJson', () {
    test('parses a real-shaped flagged word correctly', () {
      final verdict = WordVerdict.fromJson({
        'word': 'الرحيم',
        'start_sec': 1.234,
        'end_sec': 1.876,
        'distance': 0.72,
        'confidence': 0.28,
        'flagged': true,
      });

      expect(verdict.word, 'الرحيم');
      expect(verdict.startSec, 1.234);
      expect(verdict.endSec, 1.876);
      expect(verdict.distance, 0.72);
      expect(verdict.confidence, 0.28);
      expect(verdict.flagged, isTrue);
    });

    test('parses a non-flagged word correctly', () {
      final verdict = WordVerdict.fromJson({
        'word': 'بسم',
        'start_sec': 0.0,
        'end_sec': 0.4,
        'distance': 0.05,
        'confidence': 0.95,
        'flagged': false,
      });

      expect(verdict.flagged, isFalse);
      expect(verdict.confidence, greaterThan(verdict.distance));
    });

    test('integer-valued JSON numbers (e.g. distance: 0) still parse as double', () {
      // JSON doesn't distinguish 0 from 0.0 -- Dart's json.decode can hand
      // back an int where a double is expected, which a naive `as double`
      // cast would crash on.
      final verdict = WordVerdict.fromJson({
        'word': 'الله',
        'start_sec': 0,
        'end_sec': 1,
        'distance': 0,
        'confidence': 1,
        'flagged': false,
      });

      expect(verdict.startSec, 0.0);
      expect(verdict.confidence, 1.0);
    });

    test('parses the ayah-range fields the whole-surah response adds', () {
      final verdict = WordVerdict.fromJson({
        'ayah_number': 5,
        'word_index': 3,
        'word': 'نستعين',
        'start_sec': 12.1,
        'end_sec': 13.4,
        'distance': 3,
        'confidence': 0.62,
        'recited': true,
        'flagged': true,
        'error_type': 'madd',
        'explanation': 'The elongation was too short.',
      });

      expect(verdict.ayahNumber, 5);
      expect(verdict.wordIndex, 3);
      expect(verdict.recited, isTrue);
      expect(verdict.errorType, TajweedErrorType.madd);
      expect(verdict.explanation, 'The elongation was too short.');
    });

    test('a word the recording never reached is not treated as a mistake', () {
      final verdict = WordVerdict.fromJson({
        'ayah_number': 7,
        'word_index': 0,
        'word': 'صراط',
        'start_sec': 0,
        'end_sec': 0,
        'distance': 0,
        'confidence': 0,
        'recited': false,
        'flagged': false,
        'error_type': null,
        'explanation': null,
      });

      expect(verdict.recited, isFalse);
      expect(verdict.flagged, isFalse);
      expect(verdict.errorType, isNull);
    });

    test('an unknown error_type from a newer server does not throw', () {
      final verdict = WordVerdict.fromJson({
        'word': 'الله',
        'start_sec': 0,
        'end_sec': 1,
        'distance': 1,
        'confidence': 0.5,
        'flagged': true,
        'error_type': 'qalqalah',
      });

      expect(verdict.errorType, isNull);
      expect(verdict.flagged, isTrue);
    });

    test('omitted `recited` (older server) defaults to recited', () {
      final verdict = WordVerdict.fromJson({
        'word': 'بسم',
        'start_sec': 0,
        'end_sec': 1,
        'distance': 0,
        'confidence': 1,
        'flagged': false,
      });

      expect(verdict.recited, isTrue);
    });
  });
}
