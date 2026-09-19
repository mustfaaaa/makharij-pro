import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/record.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../services/live_recitation_channel.dart';
import '../../../../services/quran_text_repository.dart';
import '../../../../services/service_locator.dart';
import 'recitation_state.dart';

/// The model expects 16 kHz mono; capturing at that rate avoids a resample on
/// both the live socket and the final upload.
const _sampleRate = 16000;

/// Owns the Idle -> Listening -> Processing -> Result state machine for a
/// single recitation session, including the actual microphone capture
/// (FR-1) that [startListening]/[stopAndProcess] drive.
///
/// Capture is a raw PCM *stream* rather than a recorded file, so the same
/// samples can do two jobs at once: they are forwarded to the live analysis
/// socket (which drives word-by-word highlighting while the user recites) and
/// accumulated in memory to be wrapped as a WAV and uploaded for the
/// authoritative analysis when recording stops.
class RecitationCubit extends Cubit<RecitationState> {
  RecitationCubit() : super(const RecitationState());

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _pcm = BytesBuilder(copy: false);

  /// How loud the microphone is right now, as a short history (oldest first,
  /// each 0..1), measured from the same PCM chunks that are recorded and
  /// streamed. It drives the recording ring and waveform, so what the reciter
  /// sees is their own voice arriving -- not a decorative animation.
  ///
  /// A [ValueNotifier] rather than Bloc state on purpose: it changes many
  /// times a second, and putting it in [RecitationState] would rebuild every
  /// listener of the recitation flow on every audio chunk.
  final ValueNotifier<List<double>> inputLevels = ValueNotifier(const []);
  static const _levelHistory = 48;

  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<LivePosition>? _positionSubscription;
  StreamSubscription<LiveAyahVerdicts>? _verdictSubscription;
  LiveRecitationChannel? _live;
  DateTime? _recordingStartedAt;

  Future<void> beginSession(int surahNumber) async {
    emit(RecitationState(status: RecitationStatus.idle, surahNumber: surahNumber));
    final ayahs = await QuranTextRepository.instance.ayahsForSurah(surahNumber);
    // Guard against a stale response if the surah changed again while awaiting.
    if (state.surahNumber == surahNumber) {
      emit(state.copyWith(ayahs: ayahs));
    }
  }

  Future<void> startListening() async {
    final surahNumber = state.surahNumber;
    if (surahNumber == null) return;

    if (!await _recorder.hasPermission()) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: 'Microphone permission is required to record your recitation.',
      ));
      return;
    }

    _pcm.clear();

    // Best-effort: if the live socket can't be reached the recitation still
    // records and still gets analyzed, only the live highlight is missing.
    final live = LiveRecitationChannel();
    final connected = await live.connect(surahNumber: surahNumber, fromAyah: state.fromAyah);
    if (connected) {
      _live = live;
      _positionSubscription = live.positions.listen((p) {
        emit(state.copyWith(livePosition: p));
      });
      _verdictSubscription = live.verdicts.listen((v) {
        // Each message holds only the words that just settled, so this merges
        // into the ayah rather than replacing it -- otherwise the second batch
        // of an ayah would wipe the marks the first one put there.
        final existing = state.liveVerdicts[v.ayah];
        final merged = existing == null
            ? v
            : LiveAyahVerdicts(
                ayah: v.ayah,
                correctByWord: {...existing.correctByWord, ...v.correctByWord},
                ruleByWord: {...existing.ruleByWord, ...v.ruleByWord},
              );
        emit(state.copyWith(
          liveVerdicts: {...state.liveVerdicts, v.ayah: merged},
        ));
      });
    } else {
      await live.close();
    }

    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    ));
    inputLevels.value = const [];
    _audioSubscription = stream.listen((chunk) {
      _pcm.add(chunk);
      _live?.sendAudio(chunk);
      _pushLevel(chunk);
    });

    _recordingStartedAt = DateTime.now();
    emit(state.copyWith(
      status: RecitationStatus.listening,
      liveConnected: connected,
      clearLivePosition: true,
    ));
  }

  /// RMS of one little-endian PCM16 chunk, mapped from -60..0 dBFS to 0..1.
  void _pushLevel(Uint8List chunk) {
    if (chunk.length < 2) return;
    final samples = chunk.buffer.asByteData(chunk.offsetInBytes, chunk.lengthInBytes);
    var sum = 0.0;
    final n = chunk.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final v = samples.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    final rms = math.sqrt(sum / n);
    final db = rms <= 0 ? -60.0 : 20 * math.log(rms) / math.ln10;
    final level = ((db + 60) / 60).clamp(0.0, 1.0);
    final history = [...inputLevels.value, level];
    inputLevels.value =
        history.length > _levelHistory ? history.sublist(history.length - _levelHistory) : history;
  }

  Future<void> stopAndProcess() async {
    final surahNumber = state.surahNumber;
    if (surahNumber == null) return;

    await _recorder.stop();
    inputLevels.value = const [];
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _closeLive();

    final duration = _recordingStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_recordingStartedAt!);
    _recordingStartedAt = null;

    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty) {
      emit(state.copyWith(status: RecitationStatus.error, errorMessage: 'Recording failed — please try again.'));
      return;
    }

    // The model needs enough audio to say anything meaningful about Tajweed
    // rules -- without this, stopping almost immediately still produced a
    // full scored result from essentially nothing.
    if (duration.inMilliseconds < 1500) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: 'Recording was too short — recite a bit more before stopping.',
      ));
      return;
    }

    emit(state.copyWith(status: RecitationStatus.processing));
    try {
      final result = await Services.session.generateSessionResult(
        surahNumber,
        pcm,
        fromAyah: state.fromAyah,
        toAyah: state.toAyah,
        durationRecorded: duration,
      );
      emit(state.copyWith(status: RecitationStatus.result, result: result));
    } on AppException catch (e) {
      emit(state.copyWith(status: RecitationStatus.error, errorMessage: e.message));
    }
  }

  /// Abandons an in-flight recording without analyzing it (the user navigated
  /// away). Leaves the microphone and socket released.
  Future<void> cancelListening() async {
    if (state.status != RecitationStatus.listening) return;
    await _recorder.stop();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _closeLive();
    _pcm.clear();
    _recordingStartedAt = null;
    inputLevels.value = const [];
    emit(state.copyWith(status: RecitationStatus.idle, clearLivePosition: true));
  }

  Future<void> _closeLive() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _verdictSubscription?.cancel();
    _verdictSubscription = null;
    await _live?.close();
    _live = null;
  }

  /// Narrows what gets recited and scored. A null [toAyah] means "to the end
  /// of the surah", so it has to be cleared explicitly rather than ignored.
  void setAyahRange({int fromAyah = 1, int? toAyah}) {
    emit(state.copyWith(fromAyah: fromAyah, toAyah: toAyah, clearToAyah: toAyah == null));
  }

  void reset() {
    emit(const RecitationState());
  }

  @override
  Future<void> close() {
    _audioSubscription?.cancel();
    _positionSubscription?.cancel();
    _verdictSubscription?.cancel();
    _live?.close();
    _recorder.dispose();
    inputLevels.dispose();
    return super.close();
  }
}
