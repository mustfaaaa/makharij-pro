// A recitation span becomes an analysis request in exactly one place. These
// pin what that request asks the backend for -- where the recitation begins,
// and how far it may run, across surahs -- how long the app waits for it, and
// that the reached position the backend returns is read back, since "Continue
// from here" starts from it.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/quran_position.dart';
import 'package:frontend/models/recitation_span.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/session_service.dart';

/// Records the analysis request instead of sending it, and answers with a
/// response shaped like the real endpoint's.
class _RecordingClient implements ApiClient {
  final Map<String, dynamic> response;
  _RecordingClient(this.response);

  String? path;
  Map<String, String>? fields;
  Duration? timeout;

  @override
  Future<Map<String, dynamic>> postAudio(
    String path,
    Uint8List audioBytes, {
    Map<String, String> fields = const {},
    bool authRequired = true,
    Duration? timeout,
  }) async {
    this.path = path;
    this.fields = fields;
    this.timeout = timeout;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _response({Map<String, dynamic> extra = const {}}) => {
      'session_id': 'session-1',
      'surah_number': 2,
      'from_ayah': 57,
      'to_ayah': 286,
      'reached_ayah': 58,
      'reached_word_index': 3,
      'total_words': 40,
      'words_recited': 2,
      'accuracy_score': 0.5,
      'words': [
        {
          'ayah_number': 57,
          'word_index': 0,
          'word': 'وَظَلَّلْنَا',
          'start_sec': 0.1,
          'end_sec': 0.9,
          'distance': 0.0,
          'confidence': 1.0,
          'recited': true,
          'flagged': false,
        },
        {
          'ayah_number': 57,
          'word_index': 1,
          'word': 'عَلَيْكُمُ',
          'start_sec': 0.9,
          'end_sec': 1.4,
          'distance': 2.0,
          'confidence': 0.6,
          'recited': true,
          'flagged': true,
          'error_type': 'madd',
          'explanation': 'Short.',
        },
      ],
      ...extra,
    };

void main() {
  final audio = Uint8List(3200);

  group('what the analysis is asked for', () {
    test('an open recitation may run on through the surahs after it', () {
      expect(analysisFields(RecitationSpan.inSurah(2, fromAyah: 57)), {
        'surah_number': '2',
        'from_ayah': '57',
        'end_surah': '114',
      });
    });

    test('a fixed range sends where it stops', () {
      expect(analysisFields(RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 60)), {
        'surah_number': '2',
        'from_ayah': '57',
        'end_surah': '2',
        'to_ayah': '60',
      });
    });

    test('a range ending in a later surah says which', () {
      expect(
        analysisFields(const RecitationSpan(start: QuranPosition(2, 280), end: QuranPosition(3, 5))),
        {'surah_number': '2', 'from_ayah': '280', 'end_surah': '3', 'to_ayah': '5'},
      );
    });

    test('the upload sends exactly those fields', () async {
      final client = _RecordingClient(_response());
      final span = RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 286);
      await ApiSessionService(client).generateSessionResult(span, audio);

      expect(client.path, '/api/v1/sessions/analyze_word_level');
      expect(client.fields, {...analysisFields(span), 'qari_id': 'abdurrahmaan_as_sudais'});
    });
  });

  group('how long the app waits', () {
    test('a short recitation keeps the two minutes it always had', () {
      expect(uploadTimeoutFor(const Duration(seconds: 40)), greaterThanOrEqualTo(const Duration(minutes: 2)));
      expect(uploadTimeoutFor(const Duration(seconds: 40)), lessThan(const Duration(minutes: 3)));
    });

    test('a juz-length recitation is given time for its upload and analysis', () {
      expect(uploadTimeoutFor(const Duration(minutes: 45)), greaterThan(const Duration(minutes: 15)));
      expect(finishTimeoutFor(const Duration(minutes: 45)), greaterThan(const Duration(minutes: 5)));
    });

    test('the upload is sent with the timeout its length calls for', () async {
      final client = _RecordingClient(_response());
      await ApiSessionService(client).generateSessionResult(
        RecitationSpan.inSurah(2, fromAyah: 57),
        audio,
        durationRecorded: const Duration(minutes: 20),
      );
      expect(client.timeout, uploadTimeoutFor(const Duration(minutes: 20)));
    });
  });

  group('reading the answer', () {
    test('the reached word comes back as a position in the recording\'s surah', () async {
      final result = await ApiSessionService(_RecordingClient(_response()))
          .generateSessionResult(RecitationSpan.inSurah(2, fromAyah: 57), audio);

      expect(result.surahNumber, 2);
      expect(result.reached, const QuranPosition(2, 58, word: 3));
      expect(result.endSurah, isNull);
      expect(result.wordVerdicts!.map((v) => v.surahNumber), [null, null]);
      expect(result.errors.single.ayahNumber, 57);
    });

    test('a server that names surahs is believed', () async {
      final result = await ApiSessionService(
        _RecordingClient(_response(extra: {'reached_surah': 3, 'reached_ayah': 2, 'end_surah': 3})),
      ).generateSessionResult(RecitationSpan.inSurah(2, fromAyah: 280), audio);

      expect(result.reached, const QuranPosition(3, 2, word: 3));
      expect(result.endSurah, 3);
    });

    test('nothing recited means nothing reached', () async {
      final result = await ApiSessionService(
        _RecordingClient(_response(extra: {'reached_ayah': null, 'reached_word_index': null})),
      ).generateSessionResult(RecitationSpan.inSurah(2, fromAyah: 57), audio);

      expect(result.reached, isNull);
    });

    test('a result judged on the live socket reads exactly as an uploaded one', () async {
      final span = RecitationSpan.inSurah(2, fromAyah: 57);
      final uploaded = await ApiSessionService(_RecordingClient(_response())).generateSessionResult(span, audio);
      final service = ApiSessionService(_RecordingClient(_response()));
      final adopted = service.adoptAnalysis(span, _response(), audio);

      expect(adopted.id, uploaded.id);
      expect(adopted.reached, uploaded.reached);
      expect(adopted.accuracyScore, uploaded.accuracyScore);
      expect(adopted.errors.map((e) => e.word), uploaded.errors.map((e) => e.word));
      // Kept, like an uploaded one, for the feedback screen to open without a refetch.
      expect(await service.getSessionById('session-1'), same(adopted));
    });
  });
}
