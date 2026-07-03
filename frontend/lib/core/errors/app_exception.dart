/// Thrown by the service layer. Dummy implementations never actually throw
/// today, but every screen already handles this so swapping in real HTTP/
/// Firebase-backed services later requires no UI changes.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}
