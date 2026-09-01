import 'dart:async';
import 'dart:typed_data';

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

  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<LivePosition>? _positionSubscription;
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
    } else {
      await live.close();
    }

    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    ));
    _audioSubscription = stream.listen((chunk) {
      _pcm.add(chunk);
      _live?.sendAudio(chunk);
    });

    _recordingStartedAt = DateTime.now();
    emit(state.copyWith(
      status: RecitationStatus.listening,
      liveConnected: connected,
      clearLivePosition: true,
    ));
  }

  Future<void> stopAndProcess() async {
    final surahNumber = state.surahNumber;
    if (surahNumber == null) return;

    await _recorder.stop();
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
    emit(state.copyWith(status: RecitationStatus.idle, clearLivePosition: true));
  }

  Future<void> _closeLive() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
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
    _live?.close();
    _recorder.dispose();
    return super.close();
  }
}
