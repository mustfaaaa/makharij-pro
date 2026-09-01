// The recorder captures headerless PCM so the same samples can feed the live
// analysis socket, then this wraps them for upload. If the header is wrong the
// backend decodes silence (or nothing) and every recitation scores zero, so
// the field layout is worth pinning exactly.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/audio/wav_encoder.dart';

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));

void main() {
  group('pcm16ToWav', () {
    final pcm = Uint8List.fromList(List.generate(320, (i) => i % 256));

    test('writes a RIFF/WAVE header of the standard 44 bytes', () {
      final wav = pcm16ToWav(pcm);

      expect(wav.length, 44 + pcm.length);
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_ascii(wav, 12, 4), 'fmt ');
      expect(_ascii(wav, 36, 4), 'data');
    });

    test('declares 16 kHz mono 16-bit, which is what the model expects', () {
      final view = ByteData.sublistView(pcm16ToWav(pcm));

      expect(view.getUint16(20, Endian.little), 1, reason: 'format = PCM');
      expect(view.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(view.getUint32(24, Endian.little), 16000, reason: 'sample rate');
      expect(view.getUint32(28, Endian.little), 32000, reason: 'byte rate = 16000 * 1 * 2');
      expect(view.getUint16(32, Endian.little), 2, reason: 'block align');
      expect(view.getUint16(34, Endian.little), 16, reason: 'bits per sample');
    });

    test('sizes both length fields against the actual payload', () {
      final view = ByteData.sublistView(pcm16ToWav(pcm));

      expect(view.getUint32(4, Endian.little), 36 + pcm.length);
      expect(view.getUint32(40, Endian.little), pcm.length);
    });

    test('copies the samples through byte for byte', () {
      final wav = pcm16ToWav(pcm);
      expect(wav.sublist(44), pcm);
    });

    test('handles an empty recording without producing a malformed file', () {
      final wav = pcm16ToWav(Uint8List(0));
      final view = ByteData.sublistView(wav);

      expect(wav.length, 44);
      expect(view.getUint32(40, Endian.little), 0);
    });
  });

  group('pcmSlice', () {
    // 4 seconds of recording, each byte distinguishable by position.
    final pcm = Uint8List.fromList(
      List.generate(kPcmBytesPerSecond * 4, (i) => i % 251),
    );

    test('cuts the word out with a little padding on each side', () {
      final slice = pcmSlice(pcm, 1.0, 1.5, paddingSec: 0.1)!;

      // 0.9s .. 1.6s = 0.7s of audio.
      expect(slice.length, (0.7 * kPcmBytesPerSecond).round());
      expect(slice[0], pcm[(0.9 * kPcmBytesPerSecond).round()]);
    });

    test('always starts and ends on a whole PCM16 sample', () {
      // Timings that land mid-sample: an odd byte offset shifts every sample
      // and the clip plays back as noise rather than as speech.
      for (final start in [0.30001, 0.500031, 1.7000123]) {
        final slice = pcmSlice(pcm, start, start + 0.4)!;
        expect(slice.length.isEven, isTrue, reason: 'slice must hold whole samples');
      }
    });

    test('clamps to the recording instead of reading past its end', () {
      final slice = pcmSlice(pcm, 3.9, 4.5)!;
      expect(slice.length, lessThanOrEqualTo(pcm.length));
      expect(slice.last, pcm.last);
    });

    test('a word right at the start is not cut short by the padding', () {
      final slice = pcmSlice(pcm, 0.0, 0.4)!;
      expect(slice[0], pcm[0]);
    });

    test('returns null rather than playing something inaudibly short', () {
      expect(pcmSlice(pcm, 1.0, 1.01, paddingSec: 0.0), isNull);
      expect(pcmSlice(pcm, 1.0, 1.0), isNull);
      expect(pcmSlice(pcm, 2.0, 1.0), isNull);
    });

    test('a slice is playable as a WAV of its own', () {
      final slice = pcmSlice(pcm, 1.0, 1.3)!;
      final wav = pcm16ToWav(slice);
      final view = ByteData.sublistView(wav);

      expect(view.getUint32(40, Endian.little), slice.length);
      expect(view.getUint32(24, Endian.little), 16000);
    });
  });
}
