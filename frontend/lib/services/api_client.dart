import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';
import 'api_config.dart';

/// Thin HTTP helper shared by the real (non-dummy) service implementations.
/// Not a full REST client abstraction -- our API surface is small enough
/// that a generic get/postMultipart pair covers every endpoint.
class ApiClient {
  const ApiClient();

  /// Ordinary calls: small JSON over a local network. Long enough for a busy
  /// server, short enough that a wrong address is reported rather than waited
  /// out -- without one, a request to an unreachable host sits on the system's
  /// own TCP timeout, which is over a minute.
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// A recitation: the upload plus the model's pass over the audio.
  static const Duration _analysisTimeout = Duration(seconds: 120);

  /// Reference audio for one word. A miss here is not worth waiting on.
  static const Duration _mediaTimeout = Duration(seconds: 25);

  /// Refreshing the sign-in token talks to Firebase, not to our server, so it
  /// gets its own bound: otherwise a bad connection stalls before the request
  /// is even built.
  static const Duration _tokenTimeout = Duration(seconds: 8);

  Future<Map<String, String>> _authHeader({required bool required}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (required) throw const AppException('You need to be signed in for this.');
      return {};
    }
    final String? token;
    try {
      token = await user.getIdToken().timeout(_tokenTimeout);
    } catch (_) {
      throw const AppException('Could not confirm your sign-in. Check your connection and try again.');
    }
    if (token == null) throw const AppException('You need to be signed in for this.');
    return {'Authorization': 'Bearer $token'};
  }

  /// Sends a request under a time limit, and when the server could not be
  /// reached at all, searches for its address once and sends it again.
  ///
  /// [idempotent] decides whether that second attempt is safe. A GET may
  /// always be repeated. A write is only repeated when the search moved the
  /// app to a different address, which means the first attempt never reached a
  /// server at all -- otherwise a recitation whose reply was merely lost would
  /// be analysed and saved twice.
  Future<T> _send<T>(
    Future<T> Function(String base) attempt, {
    required bool idempotent,
    Duration timeout = _requestTimeout,
  }) async {
    // Nothing is sent until the address has been settled (or the startup
    // budget has run out), so no screen fires at a guess. The extra bound is
    // for a caller that reaches this before startup ran at all: waiting is a
    // courtesy, never a place to hang.
    await ApiConfig.ready.timeout(const Duration(seconds: 3), onTimeout: () {});
    final first = ApiConfig.baseUrl;
    try {
      return await attempt(first).timeout(timeout);
    } catch (e) {
      if (e is AppException) rethrow;
      final timedOut = e is TimeoutException;
      final found = await ApiConfig.ensureReachable();
      final moved = found && ApiConfig.baseUrl != first;
      if (idempotent ? found : moved) {
        try {
          return await attempt(ApiConfig.baseUrl).timeout(timeout);
        } catch (e2) {
          if (e2 is AppException) rethrow;
          throw AppException(e2 is TimeoutException ? _tooSlow : _unreachable);
        }
      }
      throw AppException(timedOut ? _tooSlow : _unreachable);
    }
  }

  static String get _unreachable => ApiConfig.isConfigurable
      ? 'Could not reach the server at ${ApiConfig.baseUrl}. Check that the backend is running, then set its address in Settings, under Developer.'
      : 'Could not reach the server. Check your connection and try again.';

  static String get _tooSlow => ApiConfig.isConfigurable
      ? 'The server at ${ApiConfig.baseUrl} did not answer in time. Check that it is running and on this network.'
      : 'The server did not answer in time. Try again in a moment.';

  Future<Map<String, dynamic>> get(String path, {bool authRequired = true}) async {
    final headers = await _authHeader(required: authRequired);
    final response = await _send(
      (base) => http.get(Uri.parse('$base$path'), headers: headers),
      idempotent: true,
    );
    return _decode(response);
  }

  /// [audioBytes] is uploaded as the multipart field named "audio". [fields]
  /// become additional form fields (e.g. surah_number, from_ayah).
  ///
  /// Bytes rather than a file path deliberately: the recorder captures raw PCM
  /// to memory so it can be streamed to the live-analysis socket at the same
  /// time, and the same samples are then wrapped as a WAV here. That also
  /// removes the web special case -- there is no `blob:` URL to re-fetch,
  /// because nothing was ever written to a file.
  Future<Map<String, dynamic>> postAudio(
    String path,
    Uint8List audioBytes, {
    Map<String, String> fields = const {},
    bool authRequired = true,
  }) async {
    final headers = await _authHeader(required: authRequired);
    final streamed = await _send(
      (base) {
        // A MultipartRequest cannot be sent twice, so each attempt builds its own.
        final request = http.MultipartRequest('POST', Uri.parse('$base$path'))
          ..headers.addAll(headers)
          ..fields.addAll(fields)
          ..files.add(http.MultipartFile.fromBytes('audio', audioBytes, filename: 'recitation.wav'));
        return request.send();
      },
      idempotent: false,
      timeout: _analysisTimeout,
    );
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  /// Posts form fields with no body of its own -- small "record this fact"
  /// calls, where a multipart envelope would be all overhead.
  Future<Map<String, dynamic>> postForm(
    String path, {
    Map<String, String> fields = const {},
    bool authRequired = true,
  }) async {
    final headers = await _authHeader(required: authRequired);
    final response = await _send(
      (base) => http.post(Uri.parse('$base$path'), headers: headers, body: fields),
      idempotent: false,
    );
    return _decode(response);
  }

  /// A JSON body, for endpoints that take structure rather than form fields
  /// (Rattil's assistant takes a message plus the conversation so far).
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    final headers = {
      ...await _authHeader(required: authRequired),
      'Content-Type': 'application/json',
    };
    final response = await _send(
      (base) => http.post(Uri.parse('$base$path'), headers: headers, body: jsonEncode(body)),
      idempotent: false,
      // Rattil's assistant answers through Google, which takes a few seconds.
      timeout: const Duration(seconds: 45),
    );
    return _decode(response);
  }

  /// Fetches a binary body (reference audio). Returns null rather than
  /// throwing: playing a Qari's word is a convenience layered on the results
  /// screen, and the 15 surahs with reference audio are a real, current limit
  /// -- a 404 here is expected, not a failure worth surfacing.
  Future<Uint8List?> getBytes(String path, {bool authRequired = false}) async {
    try {
      final headers = await _authHeader(required: authRequired);
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: headers).timeout(_mediaTimeout);
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] != null) detail = decoded['detail'].toString();
      } catch (_) {
        // Non-JSON error body -- fall back to the raw text already assigned above.
      }
      // The server answered, so this is not a connection problem: say which
      // kind of answer it was when it has nothing useful of its own to say.
      if (detail.trim().isEmpty) {
        detail = switch (status) {
          401 || 403 => 'Your sign-in was not accepted. Sign in again.',
          404 => 'That is not available on the server.',
          >= 500 => 'The server ran into a problem with this request.',
          _ => 'The server rejected this request.',
        };
      }
      throw AppException(detail, statusCode: status);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
