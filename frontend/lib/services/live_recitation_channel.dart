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

/// Streams microphone audio to the backend while the user recites and reports
/// which word they have reached, so the reading page can light words up as
/// they are actually spoken.
///
/// This is a *progress* signal only. It never reports mistakes: a word that is
/// still half-decoded would produce a false accusation, so correct/incorrect
/// verdicts come solely from the full-recording analysis once recording stops.
/// If the socket fails to connect, or drops mid-recitation, recording carries
/// on unaffected and only the live highlight is lost.
class LiveRecitationChannel {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  final _positions = StreamController<LivePosition>.broadcast();

  /// Word positions as the reciter reaches them. Always moves forward.
  Stream<LivePosition> get positions => _positions.stream;

  bool get isConnected => _channel != null && !_closed;

  /// Returns true when the socket is up and the server accepted the handshake.
  /// Never throws — a failed connection just means no live highlighting.
  Future<bool> connect({required int surahNumber, int fromAyah = 1}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;

      final uri = Uri.parse('$kApiBaseUrl/api/v1/sessions/stream')
          .replace(scheme: kApiBaseUrl.startsWith('https') ? 'wss' : 'ws');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
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
    if (message['type'] != 'progress') return;
    _positions.add(LivePosition(
      ayah: message['ayah'] as int,
      wordIndex: message['word_index'] as int,
      globalIndex: message['global_index'] as int,
    ));
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
