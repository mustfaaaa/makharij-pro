import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../services/api_client.dart';
import '../../../../shared/ui/action_styles.dart';

/// Plays a reference Qari saying the same word the reciter was marked on.
///
/// Being told an elongation was short is worth far more beside the sound of it
/// done properly, and it is what turns a verdict into something the reciter can
/// check rather than take on trust. Paired with "Hear yourself", the screen
/// stops arguing and simply shows both.
///
/// Reference audio covers 15 surahs (Al-Fatihah and 101-114) -- the recordings
/// the repository actually holds. Elsewhere the backend returns 404 and this
/// button quietly removes itself rather than offering something that will fail.
class ReferencePlaybackButton extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;
  final int wordIndex;
  final String qariId;

  const ReferencePlaybackButton({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.wordIndex,
    this.qariId = 'abdurrahmaan_as_sudais',
  });

  @override
  State<ReferencePlaybackButton> createState() => _ReferencePlaybackButtonState();
}

class _ReferencePlaybackButtonState extends State<ReferencePlaybackButton> {
  final AudioPlayer _player = AudioPlayer();
  static const _client = ApiClient();

  Uint8List? _audio;
  bool _loading = false;
  bool _playing = false;
  bool _unavailable = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    setState(() => _playing = true);

    // Fetched on first press, not on build: a results screen can list a dozen
    // flagged words, and pre-loading a clip for each would be a dozen requests
    // for audio the reciter may never ask to hear.
    if (_audio == null) {
      setState(() => _loading = true);
      final bytes = await _client.getBytes(
        '/api/v1/rattil/word?surah=${widget.surahNumber}&ayah=${widget.ayahNumber}'
        '&word_index=${widget.wordIndex}&qari_id=${widget.qariId}',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _audio = bytes;
        _unavailable = bytes == null;
      });
      if (bytes == null) {
        setState(() => _playing = false);
        return;
      }
    }

    try {
      await _player.play(BytesSource(_audio!));
      await _player.onPlayerComplete.first;
    } catch (_) {
      // Playback is a convenience; a device that refuses it must not break the
      // results screen.
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Once we know there is no reference for this ayah, stop offering it.
    if (_unavailable) return const SizedBox.shrink();

    final label = _loading ? 'Loading…' : (_playing ? 'Playing…' : 'Hear the Qari');
    return TextButton.icon(
      onPressed: _playing || _loading ? null : _play,
      icon: Icon(
        _playing ? Icons.graphic_eq_rounded : Icons.record_voice_over_outlined,
        size: 18,
      ),
      label: Text(label),
      style: ActionStyles.listen,
    );
  }
}
