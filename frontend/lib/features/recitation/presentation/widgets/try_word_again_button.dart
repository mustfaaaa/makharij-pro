import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../../models/reattempt_outcome.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/action_styles.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

/// The model expects 16 kHz mono, matching the main recorder.
const _sampleRate = 16000;

/// Long enough for one word with a breath either side; short enough that a
/// forgotten recording stops on its own rather than running until the screen
/// is closed.
const _maxTake = Duration(seconds: 8);

/// FR-8/BR-5: another go at one word the analysis flagged.
///
/// This sits beside "I said it right", and the pair is deliberate. One says
/// *the app was wrong*; this one says *let me show you*. The reciter should
/// never have to pick the first just because the second is unavailable.
///
/// Trying again cannot cost anything. The backend only lets words that were
/// already flagged change, so a retake can lower the session's mistake count
/// and never raise it -- if this take is worse than the last, nothing happens.
/// That is not politeness, it is what makes the button safe to press: at a
/// measured 41.9% false-alarm rate, the person being asked to prove themselves
/// is often right.
class TryWordAgainButton extends StatefulWidget {
  final String? sessionId;
  final int surahNumber;
  final int ayahNumber;
  final int wordIndex;

  /// Called when the retake settled the word, so the results screen can stop
  /// showing it as a mistake.
  final VoidCallback? onCorrected;

  const TryWordAgainButton({
    super.key,
    required this.sessionId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.wordIndex,
    this.onCorrected,
  });

  @override
  State<TryWordAgainButton> createState() => _TryWordAgainButtonState();
}

enum _Phase { idle, recording, sending, done }

class _TryWordAgainButtonState extends State<TryWordAgainButton> {
  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  Timer? _limit;

  _Phase _phase = _Phase.idle;
  String? _message;
  bool _corrected = false;

  @override
  void dispose() {
    _limit?.cancel();
    _subscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        setState(() => _message = 'Microphone permission is needed to try again.');
      }
      return;
    }
    _pcm.clear();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    ));
    _subscription = stream.listen(_pcm.add);
    // Stops itself, so a take left running does not silently become a
    // minute-long upload.
    _limit = Timer(_maxTake, _stopAndSend);
    if (mounted) setState(() => _phase = _Phase.recording);
  }

  Future<void> _stopAndSend() async {
    _limit?.cancel();
    _limit = null;
    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;

    final pcm = _pcm.takeBytes();
    final sessionId = widget.sessionId;
    // Half a second of PCM16 at 16 kHz. Below this there is nothing to hear,
    // and sending it would return a verdict drawn from silence.
    if (pcm.length < _sampleRate || sessionId == null) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _message = 'That was too short to hear. Recite the whole word, then tap when done.';
        });
      }
      return;
    }

    if (mounted) setState(() => _phase = _Phase.sending);
    try {
      final outcome = await Services.session.reattempt(
        sessionId: sessionId,
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
        wordIndex: widget.wordIndex,
        audioPcm: pcm,
      );
      if (!mounted) return;
      setState(() {
        _corrected = outcome.corrected.isNotEmpty;
        _phase = _corrected ? _Phase.done : _Phase.idle;
        _message = _outcomeMessage(outcome);
      });
      if (_corrected) widget.onCorrected?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _message = "That take could not be sent. Check your connection and try again.";
      });
    }
  }

  String _outcomeMessage(ReattemptOutcome outcome) {
    if (outcome.corrected.isNotEmpty) return 'That sounded right. The flag is cleared.';
    if (outcome.notReached.isNotEmpty) {
      // Not a verdict. Saying "still wrong" here would be the app inventing a
      // judgement out of a word it never heard.
      return "That take didn't reach the word — try once more.";
    }
    return 'Not quite yet. Listen to the Qari, then try once more.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessionId == null) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final label = switch (_phase) {
      _Phase.idle => 'Try this word',
      _Phase.recording => 'Tap when done',
      _Phase.sending => 'Checking…',
      _Phase.done => 'Cleared',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: switch (_phase) {
            _Phase.idle => _start,
            _Phase.recording => _stopAndSend,
            _ => null,
          },
          icon: Icon(
            switch (_phase) {
              _Phase.recording => Icons.stop_circle_outlined,
              _Phase.done => Icons.check_circle_outline,
              _ => Icons.mic_none,
            },
            size: 18,
          ),
          label: Text(label),
          style: switch (_phase) {
            _Phase.recording => ActionStyles.pill(background: AppColors.error, foreground: AppColors.textOnAccent),
            _Phase.sending => ActionStyles.pill(background: AppColors.container, foreground: AppColors.textSecondary),
            _Phase.done => ActionStyles.pill(background: AppColors.successLight, foreground: AppColors.success),
            _ => ActionStyles.pill(background: AppColors.primary, foreground: AppColors.textOnPrimary),
          },
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: AppSpacing.xs),
            child: Text(
              _message!,
              style: text.bodySmall?.copyWith(
                color: _corrected ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
