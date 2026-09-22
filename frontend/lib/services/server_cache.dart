/// One place for "the server's answer is still good".
///
/// Several screens ask for the same derived data at the same moment -- the home
/// screen, the progress tab and the statistics page all want the session
/// history and the progress summary -- and each used to be its own request.
/// Services cache their answer for [ttl] and share a request already in flight.
///
/// The cache is only ever a few seconds old, and anything this device writes
/// (a recitation, a re-attempt) calls [invalidate] straight away, so a fresh
/// recitation never reads back as the old numbers.
library;

class ServerCache {
  ServerCache._();

  static const Duration ttl = Duration(seconds: 20);

  static final List<void Function()> _listeners = [];

  /// Registers a service's "forget what you cached" callback.
  static void onInvalidate(void Function() forget) => _listeners.add(forget);

  /// Called after a write that changes what the server would now answer.
  static void invalidate() {
    for (final forget in _listeners) {
      forget();
    }
  }
}

/// A value fetched from the server, kept for [ServerCache.ttl], with callers
/// that arrive mid-flight sharing the one request.
class CachedValue<T> {
  final Future<T> Function() _fetch;
  Future<T>? _inFlight;
  T? _value;
  DateTime? _at;

  CachedValue(this._fetch) {
    ServerCache.onInvalidate(forget);
  }

  Future<T> get() {
    final value = _value;
    final at = _at;
    if (value != null && at != null && DateTime.now().difference(at) < ServerCache.ttl) {
      return Future.value(value);
    }
    var request = _inFlight;
    if (request == null) {
      request = _load();
      _inFlight = request;
      // The shared request keeps a listener of its own: a screen that walks
      // away mid-flight must not turn a failed request into an unhandled error
      // (the server being unreachable is an ordinary thing here).
      request.then((_) {}, onError: (_) {}).whenComplete(() => _inFlight = null);
    }
    return request;
  }

  Future<T> _load() async {
    final value = await _fetch();
    _value = value;
    _at = DateTime.now();
    return value;
  }

  void forget() {
    _value = null;
    _at = null;
  }
}
