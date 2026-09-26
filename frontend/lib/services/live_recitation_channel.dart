import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/recitation_span.dart';
import 'api_config.dart';

/// Where the reciter currently is, as reported by the live analysis socket.
class LivePosition {
  /// The surah the word is in. A server that follows one surah per recording
  /// does not send it; the channel fills in the surah it asked about.
  final int surah;
  final int ayah;

  /// Index of the word within its own ayah.
  final int wordIndex;

  /// Index of the word counted from the first word of the recitation — what
  /// the reading page uses to decide how much of the text has been recited.
  final int globalIndex;

  const LivePosition({
    required this.surah,
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
  final int surah;
  final int ayah;

  /// Word index within the ayah -> was it recited correctly.
  final Map<int, bool> correctByWord;

  /// Word index -> the rule the analyser named, for the words it flagged.
  final Map<int, String> ruleByWord;

  const LiveAyahVerdicts({
    required this.surah,
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
/// That analysis can come from here too. When recording stops, [finish] asks
/// the server to judge the whole recitation from the stream it has already
/// decoded, reporting its progress as it goes — so a long recitation is not
/// uploaded and decoded a second time. It returns null whenever that is not
/// possible (the server cannot, or the socket dropped along the way), and the
/// recording is then uploaded as before.
///
/// If the socket fails to connect, or drops mid-recitation, recording carries
/// on unaffected and only the live feedback is lost.
class LiveRecitationChannel {
  /// The defaults are the app's own sign-in, backend address and socket; tests
  /// supply their own.
  LiveRecitationChannel({
    Future<String?> Function()? idToken,
    Future<Uri> Function()? endpoint,
    WebSocketChannel Function(Uri uri)? open,
  })  : _idToken = idToken ?? _firebaseIdToken,
        _endpoint = endpoint ?? _streamEndpoint,
        _open = open ?? WebSocketChannel.connect;

  final Future<String?> Function() _idToken;
  final Future<Uri> Function() _endpoint;
  final WebSocketChannel Function(Uri uri) _open;

  static Future<String?> _firebaseIdToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken().timeout(const Duration(seconds: 5));

  static Future<Uri> _streamEndpoint() async {
    await ApiConfig.ready;
    final base = ApiConfig.baseUrl;
    return Uri.parse('$base/api/v1/sessions/stream').replace(scheme: base.startsWith('https') ? 'wss' : 'ws');
  }

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  final _positions = StreamController<LivePosition>.broadcast();
  final _verdicts = StreamController<LiveAyahVerdicts>.broadcast();
  final _analysisProgress = StreamController<double>.broadcast();

  /// Word positions as the reciter reaches them. Always moves forward.
  Stream<LivePosition> get positions => _positions.stream;

  /// Per-ayah verdicts, trailing the position by about one ayah.
  Stream<LiveAyahVerdicts> get verdicts => _verdicts.stream;

  /// After [finish]: how much of the recitation the server has judged, 0..1.
  /// Measured on the server as it goes, never estimated here.
  Stream<double> get analysisProgress => _analysisProgress.stream;

  bool get isConnected => _channel != null && !_closed;

  /// Whether this server judges the recitation itself on [finish]. It says so
  /// in its first message; one that does not gets the recording uploaded.
  bool get canFinish => isConnected && _serverFinishes;
  bool _serverFinishes = false;

  Completer<Map<String, dynamic>?>? _finished;

  /// The surah this channel follows, for messages that do not name one.
  int _surah = 1;

  /// Returns true when the socket is up and the server accepted the handshake.
  /// Never throws — a failed connection just means no live highlighting.
  ///
  /// The handshake names where the recitation begins and how far it may run:
  /// to [span]'s end, or — left open — on through the surahs after it.
  Future<bool> connect({required RecitationSpan span}) async {
    _surah = span.start.surah;
    try {
      // Live highlighting is a bonus on top of the recording, so every step
      // here is bounded: a slow socket must never delay the microphone.
      final token = await _idToken();
      if (token == null) return false;

      final channel = _open(await _endpoint());
      await channel.ready.timeout(const Duration(seconds: 5));
      _channel = channel;

      final end = span.end;
      channel.sink.add(jsonEncode({
        'token': token,
        'surah_number': span.start.surah,
        'from_ayah': span.start.ayah,
        'end_surah': end?.surah ?? 114,
        if (end != null) 'to_ayah': end.ayah,
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

  /// Asks the server to judge the recitation it has streamed, and waits for
  /// the result: the same response `POST /sessions/analyze_word_level` gives,
  /// already stored as a session. Null when that cannot happen — the server
  /// does not offer it, the socket drops, the server reports an error, or
  /// [timeout] passes — so the caller can upload the recording instead.
  Future<Map<String, dynamic>?> finish({required Duration timeout}) async {
    if (!canFinish) return null;
    final done = _finished = Completer<Map<String, dynamic>?>();
    try {
      _channel!.sink.add(jsonEncode({'type': 'finish'}));
    } catch (_) {
      _teardown();
      return null;
    }
    return done.future.timeout(timeout, onTimeout: () => null);
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
      case 'ready':
        _serverFinishes = message['finish'] == true;
      case 'progress':
        _positions.add(LivePosition(
          surah: message['surah'] as int? ?? _surah,
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
            surah: message['surah'] as int? ?? _surah,
            ayah: message['ayah'] as int,
            correctByWord: correct,
            ruleByWord: rules,
          ));
        }
      case 'analysis_progress':
        final fraction = (message['fraction'] as num?)?.toDouble();
        if (fraction != null && !_analysisProgress.isClosed) {
          _analysisProgress.add(fraction.clamp(0.0, 1.0));
        }
      case 'result':
        _completeFinish(Map<String, dynamic>.of(message)..remove('type'));
      case 'error':
        // Before [finish] an error carries nothing the page needs; after it,
        // the server could not judge the recitation, and the upload will.
        _completeFinish(null);
      default:
        return;
    }
  }

  void _completeFinish(Map<String, dynamic>? result) {
    final done = _finished;
    if (done != null && !done.isCompleted) done.complete(result);
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
    await _analysisProgress.close();
  }

  void _teardown() {
    _closed = true;
    // Whoever is waiting on [finish] learns now rather than at its timeout.
    _completeFinish(null);
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
