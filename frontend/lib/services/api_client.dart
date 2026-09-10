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

  Future<Map<String, String>> _authHeader({required bool required}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (required) throw const AppException('You need to be signed in for this.');
      return {};
    }
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> get(String path, {bool authRequired = true}) async {
    final headers = await _authHeader(required: authRequired);
    final http.Response response;
    try {
      response = await http.get(Uri.parse('$kApiBaseUrl$path'), headers: headers);
    } catch (_) {
      throw const AppException('Could not reach the server. Check your connection and try again.');
    }
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
    final audioFile = http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: 'recitation.wav',
    );
    final request = http.MultipartRequest('POST', Uri.parse('$kApiBaseUrl$path'))
      ..headers.addAll(headers)
      ..fields.addAll(fields)
      ..files.add(audioFile);

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send();
    } catch (_) {
      throw const AppException('Could not reach the server. Check your connection and try again.');
    }
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
    final http.Response response;
    try {
      response = await http.post(Uri.parse('$kApiBaseUrl$path'), headers: headers, body: fields);
    } catch (_) {
      throw const AppException('Could not reach the server. Check your connection and try again.');
    }
    return _decode(response);
  }

  /// Fetches a binary body (reference audio). Returns null rather than
  /// throwing: playing a Qari's word is a convenience layered on the results
  /// screen, and the 15 surahs with reference audio are a real, current limit
  /// -- a 404 here is expected, not a failure worth surfacing.
  Future<Uint8List?> getBytes(String path, {bool authRequired = false}) async {
    try {
      final headers = await _authHeader(required: authRequired);
      final response = await http.get(Uri.parse('$kApiBaseUrl$path'), headers: headers);
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] != null) detail = decoded['detail'].toString();
      } catch (_) {
        // Non-JSON error body -- fall back to the raw text already assigned above.
      }
      throw AppException(detail, statusCode: response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
