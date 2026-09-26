import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/record.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/quran_position.dart';
import '../../../../models/recitation_span.dart';
import '../../../../models/session_result.dart';
import '../../../../services/live_recitation_channel.dart';
import '../../../../services/quran_text_repository.dart';
import '../../../../services/service_locator.dart';
import '../../../../services/session_service.dart' show finishTimeoutFor;
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

  /// What the current recording covers, as it was when recording began.
  RecitationSpan? _recording;

  /// The last recording, kept until it has been judged: a failed analysis can
  /// then be tried again without reciting the whole passage again. Retry used
  /// to call stopAndProcess a second time, on a buffer already emptied, and
  /// could only ever report "Recording failed".
  Uint8List? _unjudged;
  Duration _unjudgedLength = Duration.zero;

  /// Counts recordings being judged. One that was cancelled -- the reciter
  /// left the wait -- must not come back later and show its result, or be
  /// uploaded once the socket it was waiting on has closed.
  int _run = 0;

  /// Whether the last recording failed to be judged and can be tried again.
  bool get canRetryAnalysis => _unjudged != null && _recording != null;

  /// Opens [surahNumber] for reading and recitation, beginning at [span]'s
  /// start (ayah 1 when not given).
  Future<void> beginSession(int surahNumber, {RecitationSpan? span}) async {
    emit(RecitationState(
      status: RecitationStatus.idle,
      surahNumber: surahNumber,
      span: span ?? RecitationSpan(start: QuranPosition(surahNumber, 1)),
    ));
    final ayahs = await QuranTextRepository.instance.ayahsForSurah(surahNumber);
    // Guard against a stale response if the surah changed again while awaiting.
    if (state.surahNumber == surahNumber) {
      emit(state.copyWith(ayahs: ayahs));
    }
  }

  Future<void> startListening() async {
    final span = state.recordingSpan;
    if (state.surahNumber == null || span == null) return;
    _recording = span;
    _unjudged = null;

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
    final connected = await live.connect(span: span);
    if (connected) {
      _live = live;
      _positionSubscription = live.positions.listen((p) {
        emit(state.copyWith(livePosition: p));
      });
      _verdictSubscription = live.verdicts.listen((v) {
        // Each message holds only the words that just settled, so this merges
        // into the ayah rather than replacing it -- otherwise the second batch
        // of an ayah would wipe the marks the first one put there.
        final key = (v.surah, v.ayah);
        final existing = state.liveVerdicts[key];
        final merged = existing == null
            ? v
            : LiveAyahVerdicts(
                surah: v.surah,
                ayah: v.ayah,
                correctByWord: {...existing.correctByWord, ...v.correctByWord},
                ruleByWord: {...existing.ruleByWord, ...v.ruleByWord},
              );
        emit(state.copyWith(
          liveVerdicts: {...state.liveVerdicts, key: merged},
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

  /// Stops recording and has the recitation judged.
  ///
  /// The live socket has decoded all of it by now, so when it is still up and
  /// its server offers it, the recitation is judged there -- with its progress
  /// measured as it goes -- instead of being uploaded to be decoded a second
  /// time. For a juz that is the difference between an 85 MB upload with a
  /// two-minute decode, and the alignment alone. Anything short of a result
  /// from the socket falls back to the upload, exactly as before.
  Future<void> stopAndProcess() async {
    final span = _recording ?? state.recordingSpan;
    if (state.surahNumber == null || span == null) return;
    final run = ++_run;

    await _recorder.stop();
    inputLevels.value = const [];
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    // Nothing more to follow on the page.
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _verdictSubscription?.cancel();
    _verdictSubscription = null;

    final duration = _recordingStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_recordingStartedAt!);
    _recordingStartedAt = null;

    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty) {
      await _closeLive();
      emit(state.copyWith(status: RecitationStatus.error, errorMessage: 'Recording failed — please try again.'));
      return;
    }

    // The model needs enough audio to say anything meaningful about Tajweed
    // rules -- without this, stopping almost immediately still produced a
    // full scored result from essentially nothing.
    if (duration.inMilliseconds < 1500) {
      await _closeLive();
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: 'Recording was too short — recite a bit more before stopping.',
      ));
      return;
    }

    _unjudged = pcm;
    _unjudgedLength = duration;
    emit(state.copyWith(
      status: RecitationStatus.processing,
      recordedDuration: duration,
      clearAnalysisProgress: true,
    ));

    final live = _live;
    if (live != null && live.canFinish) {
      final progress = live.analysisProgress.listen((fraction) {
        if (run == _run) emit(state.copyWith(analysisProgress: fraction));
      });
      final json = await live.finish(timeout: finishTimeoutFor(duration));
      await progress.cancel();
      if (run != _run) return;
      if (json != null) {
        SessionResult? result;
        try {
          result = Services.session.adoptAnalysis(span, json, pcm, durationRecorded: duration);
        } catch (_) {
          // An answer this app cannot read: the upload below gets one it can.
        }
        if (result != null) {
          await _closeLive();
          _unjudged = null;
          emit(state.copyWith(status: RecitationStatus.result, result: result));
          return;
        }
      }
    }
    await _closeLive();
    if (run != _run) return;
    emit(state.copyWith(clearAnalysisProgress: true));
    await _upload(span, run);
  }

  /// Tries again to have the last recording judged, after it failed.
  Future<void> retryAnalysis() async {
    final span = _recording;
    if (_unjudged == null || span == null) return;
    final run = ++_run;
    emit(state.copyWith(status: RecitationStatus.processing, clearAnalysisProgress: true));
    await _upload(span, run);
  }

  Future<void> _upload(RecitationSpan span, int run) async {
    final pcm = _unjudged;
    if (pcm == null) return;
    try {
      final result = await Services.session.generateSessionResult(
        span,
        pcm,
        durationRecorded: _unjudgedLength,
      );
      if (run != _run) return;
      _unjudged = null;
      emit(state.copyWith(status: RecitationStatus.result, result: result));
    } on AppException catch (e) {
      if (run != _run) return;
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

  bool _extending = false;

  /// Runs the page on into the surah after the last one it shows -- when the
  /// reader scrolls past its end, or the reciter recites past it.
  Future<void> extendPassage() async {
    final opened = state.surahNumber;
    final passage = state.passage;
    if (opened == null || passage.isEmpty || _extending) return;
    final next = passage.last.surah + 1;
    if (next > 114) return;
    _extending = true;
    try {
      final ayahs = await QuranTextRepository.instance.ayahsForSurah(next);
      // Still the same page, and nothing else extended it meanwhile.
      if (state.surahNumber == opened && state.passage.last.surah + 1 == next) {
        emit(state.copyWith(following: [...state.following, PassageSurah(next, ayahs)]));
      }
    } finally {
      _extending = false;
    }
  }

  /// Sets where the next recording begins, and where it stops for a fixed
  /// practice range. Only between recordings: a recording already under way
  /// was started from its own span, and the live cursor is counting from it.
  ///
  /// Kept inside the text the page shows: the start in one of its surahs, and
  /// a fixed end in that same surah.
  void setSpan(RecitationSpan span) {
    if (state.surahNumber == null || state.status == RecitationStatus.listening) return;
    final passage = state.passage;
    final section = passage.where((p) => p.surah == span.start.surah).firstOrNull ?? passage.first;
    final last = section.ayahs.isEmpty ? span.start.ayah : section.ayahs.last.number;
    final from = section.surah == span.start.surah ? span.start.ayah.clamp(1, last) : 1;
    final end = span.end;
    final to = end != null && end.surah == section.surah ? end.ayah.clamp(from, last) : null;
    emit(state.copyWith(span: RecitationSpan.inSurah(section.surah, fromAyah: from, toAyah: to)));
  }

  void reset() {
    // Whatever was being judged is no longer wanted; the socket closing also
    // tells its server not to store it.
    _run++;
    _unjudged = null;
    unawaited(_closeLive());
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
