import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../models/after_clip.dart';
import '../../models/qari.dart';

/// Playback speeds offered wherever a Qari plays. 0.75 and 1.0 are what
/// Rattil's typed commands have always used ("slower", "normal speed"); 1.25
/// is the "fast" option, for revision.
enum QariSpeed {
  slow(0.75, 'Slow'),
  normal(1.0, 'Normal'),
  fast(1.25, 'Fast');

  final double rate;
  final String label;
  const QariSpeed(this.rate, this.label);
}

/// Plays one reference recitation -- a list of per-ayah clips from
/// `/api/v1/rattil/recitation` -- with the same "after this clip" modes as
/// Rattil's player (stop, play on, repeat the ayah) and three speeds.
///
/// A [ChangeNotifier] so a docked mini-player and the page it sits on (which
/// highlights the ayah being recited) can both listen to one source of truth.
class QariPlayerController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  RecitationResult? _recitation;
  int _index = 0;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  QariSpeed _speed = QariSpeed.normal;
  AfterClip _afterClip = AfterClip.continueOn;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// Set while stopping on purpose: some platforms deliver a completion event
  /// for a stop we asked for, which would look exactly like a clip ending.
  bool _stoppingOurselves = false;
  bool _disposed = false;

  QariPlayerController() {
    _completeSub = _player.onPlayerComplete.listen((_) => _onClipEnded());
    _positionSub = _player.onPositionChanged.listen((p) {
      _position = p;
      _notify();
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      _duration = d;
      _notify();
    });
  }

  RecitationResult? get recitation => _recitation;
  bool get hasRecitation => _recitation != null && _recitation!.clips.isNotEmpty;
  int get index => _index;
  bool get playing => _playing;
  bool get loading => _loading;
  String? get error => _error;
  QariSpeed get speed => _speed;
  AfterClip get afterClip => _afterClip;

  /// The ayah number now playing, or null when nothing is loaded.
  int? get currentAyah => hasRecitation ? _recitation!.clips[_index].ayah : null;

  /// Real playback progress through the current clip, 0..1.
  double get clipProgress {
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads a fetched recitation and starts it from its first clip (or from
  /// the clip for [startAyah]).
  Future<void> start(RecitationResult recitation, {int? startAyah}) async {
    _recitation = recitation;
    _error = null;
    final i = startAyah == null ? 0 : recitation.clips.indexWhere((c) => c.ayah == startAyah);
    _index = i < 0 ? 0 : i;
    await _playCurrent();
  }

  void setLoading(bool value, {String? error}) {
    _loading = value;
    _error = error;
    _notify();
  }

  Future<void> _playCurrent() async {
    final r = _recitation;
    if (r == null || r.clips.isEmpty) return;
    _position = Duration.zero;
    _duration = Duration.zero;
    _stoppingOurselves = true;
    await _player.stop();
    _stoppingOurselves = false;
    await _player.setPlaybackRate(_speed.rate);
    try {
      await _player.play(UrlSource(r.clips[_index].url));
      _playing = true;
      _error = null;
    } catch (_) {
      _playing = false;
      _error = 'This recitation could not be played. Check your connection.';
    }
    _notify();
  }

  Future<void> _onClipEnded() async {
    if (_disposed || _stoppingOurselves) return;
    final r = _recitation;
    if (r == null) return;
    switch (_afterClip) {
      case AfterClip.repeatOne:
        await _playCurrent();
      case AfterClip.continueOn:
        if (_index < r.clips.length - 1) {
          _index += 1;
          await _playCurrent();
        } else {
          _playing = false;
          _notify();
        }
      case AfterClip.stop:
        _playing = false;
        _notify();
    }
  }

  Future<void> toggle() async {
    if (!hasRecitation) return;
    if (_playing) {
      await _player.pause();
      _playing = false;
      _notify();
      return;
    }
    if (_position > Duration.zero && _position < _duration) {
      await _player.resume();
      _playing = true;
      _notify();
      return;
    }
    await _playCurrent();
  }

  Future<void> next() async {
    final r = _recitation;
    if (r == null || _index >= r.clips.length - 1) return;
    _index += 1;
    await _playCurrent();
  }

  Future<void> previous() async {
    if (!hasRecitation || _index == 0) return;
    _index -= 1;
    await _playCurrent();
  }

  Future<void> setSpeed(QariSpeed speed) async {
    _speed = speed;
    if (_playing) await _player.setPlaybackRate(speed.rate);
    _notify();
  }

  void setAfterClip(AfterClip mode) {
    _afterClip = mode;
    _notify();
  }

  /// Stops playback and forgets the recitation, closing any mini-player.
  Future<void> close() async {
    _stoppingOurselves = true;
    await _player.stop();
    _stoppingOurselves = false;
    _playing = false;
    _recitation = null;
    _error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _completeSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
