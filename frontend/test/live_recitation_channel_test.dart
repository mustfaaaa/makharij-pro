// The live socket follows the reciter and, when they stop, can return the
// judged recitation itself. These drive the channel against a scripted server
// to pin the handshake it sends, and that "finish" gives the server's result
// when there is one -- and null, promptly, whenever there is not, so the app
// uploads the recording instead of waiting out a timeout.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:frontend/models/recitation_span.dart';
import 'package:frontend/services/live_recitation_channel.dart';

class _Sink implements WebSocketSink {
  final sent = <dynamic>[];
  bool closed = false;

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future close([int? closeCode, String? closeReason]) async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A socket whose server side the test scripts.
class _Socket implements WebSocketChannel {
  final server = StreamController<dynamic>();
  final _sink = _Sink();

  List<Map<String, dynamic>> get sentJson =>
      [for (final m in _sink.sent) if (m is String) jsonDecode(m) as Map<String, dynamic>];

  void say(Map<String, dynamic> message) => server.add(jsonEncode(message));

  @override
  Stream<dynamic> get stream => server.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(LiveRecitationChannel, _Socket)> _connected(RecitationSpan span) async {
  final socket = _Socket();
  final channel = LiveRecitationChannel(
    idToken: () async => 'token',
    endpoint: () async => Uri.parse('ws://server/api/v1/sessions/stream'),
    open: (_) => socket,
  );
  expect(await channel.connect(span: span), isTrue);
  return (channel, socket);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('the handshake names where the recitation begins and how far it may run', () async {
    final (_, open) = await _connected(RecitationSpan.inSurah(2, fromAyah: 57));
    expect(open.sentJson.first, {'token': 'token', 'surah_number': 2, 'from_ayah': 57, 'end_surah': 114});

    final (_, closed) = await _connected(RecitationSpan.inSurah(2, fromAyah: 57, toAyah: 286));
    expect(closed.sentJson.first,
        {'token': 'token', 'surah_number': 2, 'from_ayah': 57, 'end_surah': 2, 'to_ayah': 286});
  });

  test('positions say which surah they are in, and fall back to the one asked about', () async {
    final (channel, socket) = await _connected(RecitationSpan.inSurah(2, fromAyah: 286));
    final seen = <(int, int)>[];
    channel.positions.listen((p) => seen.add((p.surah, p.ayah)));
    socket.say({'type': 'progress', 'ayah': 286, 'word_index': 0, 'global_index': 0});
    socket.say({'type': 'progress', 'surah': 3, 'ayah': 1, 'word_index': 4, 'global_index': 60});
    await _settle();
    expect(seen, [(2, 286), (3, 1)]);
  });

  test('finish returns the server\'s judged recitation, with its progress on the way', () async {
    final (channel, socket) = await _connected(RecitationSpan.inSurah(2, fromAyah: 57));
    socket.say({'type': 'ready', 'surah_number': 2, 'total_words': 10, 'finish': true});
    await _settle();
    expect(channel.canFinish, isTrue);

    final progress = <double>[];
    channel.analysisProgress.listen(progress.add);
    final result = channel.finish(timeout: const Duration(seconds: 5));
    await _settle();
    expect(socket.sentJson.last, {'type': 'finish'});

    socket.say({'type': 'analysis_progress', 'fraction': 0.4});
    socket.say({'type': 'analysis_progress', 'fraction': 1.0});
    socket.say({'type': 'result', 'session_id': 'session-9', 'words': []});
    expect(await result, {'session_id': 'session-9', 'words': []});
    expect(progress, [0.4, 1.0]);
  });

  test('a server that does not offer it is not asked', () async {
    final (channel, socket) = await _connected(RecitationSpan.inSurah(2, fromAyah: 57));
    socket.say({'type': 'ready', 'surah_number': 2, 'total_words': 10});
    await _settle();
    expect(channel.canFinish, isFalse);
    expect(await channel.finish(timeout: const Duration(seconds: 5)), isNull);
    expect(socket.sentJson.where((m) => m['type'] == 'finish'), isEmpty);
  });

  test('a socket that closes before the result gives up at once, not at the timeout', () async {
    final (channel, socket) = await _connected(RecitationSpan.inSurah(2, fromAyah: 57));
    socket.say({'type': 'ready', 'finish': true});
    await _settle();
    final result = channel.finish(timeout: const Duration(minutes: 10));
    await _settle();
    await socket.server.close();
    expect(await result.timeout(const Duration(seconds: 2)), isNull);
  });

  test('a server that could not judge it says so, and the upload takes over', () async {
    final (channel, socket) = await _connected(RecitationSpan.inSurah(2, fromAyah: 57));
    socket.say({'type': 'ready', 'finish': true});
    await _settle();
    final result = channel.finish(timeout: const Duration(seconds: 5));
    await _settle();
    socket.say({'type': 'error', 'detail': 'Could not analyze audio'});
    expect(await result, isNull);
  });
}
