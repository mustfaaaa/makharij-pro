import 'dart:typed_data';

/// Wraps raw PCM samples in a WAV container.
///
/// The recorder streams headerless 16-bit PCM (that is what the live analysis
/// socket needs), but the backend's final analysis decodes a real audio file.
/// Rather than recording twice, the same captured samples get a 44-byte RIFF
/// header bolted on here and are uploaded as a normal .wav.
Uint8List pcm16ToWav(
  Uint8List pcm, {
  int sampleRate = 16000,
  int channels = 1,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;

  final header = ByteData(44);
  void writeAscii(int offset, String tag) {
    for (var i = 0; i < tag.length; i++) {
      header.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little); // chunk size
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  header.setUint16(20, 1, Endian.little); // format = PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  final out = Uint8List(44 + pcm.length);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, out.length, pcm);
  return out;
}


/// 16 kHz mono PCM16: two bytes per sample.
const int kPcmBytesPerSecond = 16000 * 2;

/// Cuts the slice of a recording between [startSec] and [endSec], with a little
/// [paddingSec] on each side.
///
/// Word timings mark where sound was *detected*, not where the word began and
/// ended to the ear, so a bare cut sounds clipped and a very short word can be
/// nearly inaudible; the padding fixes both.
///
/// Returns null when the result would be too short to hear, or when the
/// timings fall outside the audio.
Uint8List? pcmSlice(
  Uint8List pcm,
  double startSec,
  double endSec, {
  double paddingSec = 0.12,
  double minLengthSec = 0.05,
}) {
  if (endSec <= startSec) return null;

  var start = ((startSec - paddingSec) * kPcmBytesPerSecond).round();
  var end = ((endSec + paddingSec) * kPcmBytesPerSecond).round();
  start = start.clamp(0, pcm.length);
  end = end.clamp(0, pcm.length);

  // Samples are two bytes wide. An odd offset shifts every sample by a byte,
  // which does not sound like a slightly different clip -- it plays as noise.
  if (start.isOdd) start -= 1;
  if (end.isOdd) end += 1;
  start = start.clamp(0, pcm.length);
  end = end.clamp(start, pcm.length);

  if (end - start < (minLengthSec * kPcmBytesPerSecond).round()) return null;
  return Uint8List.sublistView(pcm, start, end);
}
