/// Thrown by the service layer. Dummy implementations never actually throw
/// today, but every screen already handles this so swapping in real HTTP/
/// Firebase-backed services later requires no UI changes.
///
/// [statusCode] is null for non-HTTP failures (e.g. network errors) and for
/// call sites that construct this directly rather than via ApiClient's
/// response decoding -- only check it where a caller genuinely needs to
/// distinguish, e.g. a 404 ("not available yet") from other failures.
class AppException implements Exception {
  final String message;
  final int? statusCode;
  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
