import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';

/// Where the reciter currently is, as reported by the live analysis socket.
class LivePosition {
  final int ayah;

  /// Index of the word within its own ayah.
  final int wordIndex;

  /// Index of the word within the whole surah — what the reading page uses to
  /// decide how much of the text has been recited so far.
  final int globalIndex;

  const LivePosition({
    required this.ayah,
    required this.wordIndex,
    required this.globalIndex,
  });
}

/// Verdicts for some words of one ayah, sent while the reciter is still going.
///
/// The server sends these only for words the reciter is already several words
/// past: a word judged the moment it ends has no following text to settle
/// against and reads as a mistake that is not there. The lag is the point.
///
/// A message carries only the words that have *just* settled, so these merge
/// into what is already held for the ayah rather than replacing it.
class LiveAyahVerdicts {
  final int ayah;

  /// Word index within the ayah -> was it recited correctly.
  final Map<int, bool> correctByWord;

  /// Word index -> the rule the analyser named, for the words it flagged.
  final Map<int, String> ruleByWord;

  const LiveAyahVerdicts({
    required this.ayah,
    required this.correctByWord,
    required this.ruleByWord,
  });
}

/// Streams microphone audio to the backend while the user recites, reports
/// which word they have reached so the reading page can light words up as they
/// are spoken, and — a whole ayah behind that — what the analyser made of the
/// ayahs already finished.
///
/// The two signals are deliberately different in kind. The *position* is
/// immediate and approximate and never says anything is wrong. The *verdicts*
/// are slower and may flag mistakes, because by the time they are sent the
/// audio they judge is complete. Neither is authoritative: the full-recording
/// analysis when recording stops is what the results screen shows.
///
/// If the socket fails to connect, or drops mid-recitation, recording carries
/// on unaffected and only the live feedback is lost.
class LiveRecitationChannel {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  final _positions = StreamController<LivePosition>.broadcast();
  final _verdicts = StreamController<LiveAyahVerdicts>.broadcast();

  /// Word positions as the reciter reaches them. Always moves forward.
  Stream<LivePosition> get positions => _positions.stream;

  /// Per-ayah verdicts, trailing the position by about one ayah.
  Stream<LiveAyahVerdicts> get verdicts => _verdicts.stream;

  bool get isConnected => _channel != null && !_closed;

  /// Returns true when the socket is up and the server accepted the handshake.
  /// Never throws — a failed connection just means no live highlighting.
  Future<bool> connect({required int surahNumber, int fromAyah = 1}) async {
    try {
      // Live highlighting is a bonus on top of the recording, so every step
      // here is bounded: a slow socket must never delay the microphone.
      final token = await FirebaseAuth.instance.currentUser
          ?.getIdToken()
          .timeout(const Duration(seconds: 5));
      if (token == null) return false;

      await ApiConfig.ready;
      final base = ApiConfig.baseUrl;
      final uri = Uri.parse('$base/api/v1/sessions/stream')
          .replace(scheme: base.startsWith('https') ? 'wss' : 'ws');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 5));
      _channel = channel;

      channel.sink.add(jsonEncode({
        'token': token,
        'surah_number': surahNumber,
        'from_ayah': fromAyah,
      }));

      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _teardown(),
        onDone: _teardown,
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      _teardown();
      return false;
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (message['type']) {
      case 'progress':
        _positions.add(LivePosition(
          ayah: message['ayah'] as int,
          wordIndex: message['word_index'] as int,
          globalIndex: message['global_index'] as int,
        ));
      case 'ayah_result':
        final words = (message['words'] as List?) ?? const [];
        final correct = <int, bool>{};
        final rules = <int, String>{};
        for (final w in words.cast<Map<String, dynamic>>()) {
          final index = w['word_index'] as int?;
          if (index == null) continue;
          final ok = w['correct'] as bool? ?? true;
          correct[index] = ok;
          final rule = w['error_type'] as String?;
          if (!ok && rule != null && rule.isNotEmpty) rules[index] = rule;
        }
        if (correct.isNotEmpty) {
          _verdicts.add(LiveAyahVerdicts(
            ayah: message['ayah'] as int,
            correctByWord: correct,
            ruleByWord: rules,
          ));
        }
      default:
        return; // 'ready' and 'error' carry nothing the page needs
    }
  }

  /// Forwards one chunk of 16-bit PCM straight from the recorder.
  void sendAudio(Uint8List chunk) {
    if (_channel == null || _closed) return;
    try {
      _channel!.sink.add(chunk);
    } catch (_) {
      _teardown(); // the socket died mid-recitation; recording continues
    }
  }

  Future<void> close() async {
    if (_channel != null && !_closed) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'stop'}));
      } catch (_) {
        // Nothing to do -- we're closing anyway.
      }
    }
    _teardown();
    await _positions.close();
    await _verdicts.close();
  }

  void _teardown() {
    _closed = true;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {
      // Already closed.
    }
    _channel = null;
  }
}
