import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/audio/wav_encoder.dart';
import '../../../../theme/app_colors.dart';

/// Plays back the exact slice of the user's own recording that a flagged word
/// was spoken in.
///
/// Being told "the elongation was too short" is of limited use if you cannot
/// hear what you actually said. The word's start/end come from the recognizer's
/// own token timestamps, so this plays precisely the audio the verdict was
/// formed from.
///
/// The slice is cut out of the raw PCM and given its own WAV header rather than
/// seeking a full-recording player and stopping on a timer: at word length
/// (often under half a second) a timer race is audible, and an exact buffer
/// simply cannot drift.
class WordPlaybackButton extends StatefulWidget {
  /// Raw 16 kHz mono PCM16 of the whole recitation.
  final Uint8List pcm;
  final double startSec;
  final double endSec;
  final String label;

  const WordPlaybackButton({
    super.key,
    required this.pcm,
    required this.startSec,
    required this.endSec,
    this.label = 'Hear yourself',
  });

  @override
  State<WordPlaybackButton> createState() => _WordPlaybackButtonState();
}

class _WordPlaybackButtonState extends State<WordPlaybackButton> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Uint8List? _slice() => pcmSlice(widget.pcm, widget.startSec, widget.endSec);

  Future<void> _play() async {
    final slice = _slice();
    if (slice == null) return;

    setState(() => _playing = true);
    try {
      await _player.play(BytesSource(pcm16ToWav(slice)));
      await _player.onPlayerComplete.first;
    } catch (_) {
      // Playback is a convenience; a device that refuses it must not break the
      // results screen.
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_slice() == null) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: _playing ? null : _play,
      icon: Icon(_playing ? Icons.graphic_eq_rounded : Icons.play_circle_outline_rounded, size: 18),
      label: Text(_playing ? 'Playing…' : widget.label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
