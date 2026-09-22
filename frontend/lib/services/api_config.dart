import 'dart:async';
import 'dart:io' show NetworkInterface, InternetAddressType;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'service_locator.dart';

/// Where the backend is. Resolved at runtime, because "the backend" sits at a
/// different address depending on how the app was started:
///
///   - VS Code's "App on phone (Wi-Fi backend)": the address is baked in with
///     --dart-define.
///   - Android Studio, or plain `flutter run`: nothing is baked in, so the app
///     uses the last address that answered on this device.
///   - A phone reached through `adb reverse tcp:8000 tcp:8000`: 127.0.0.1.
///   - The Android emulator: 10.0.2.2 is the machine it runs on.
///   - Desktop or web beside the server: 127.0.0.1.
///
/// Order: what someone set by hand on the device, then the last address that
/// answered, then the build's address, then the local defaults -- and each is
/// only adopted if something really answers /health there. A failed request
/// re-runs the search once, so starting the server, or plugging in adb,
/// recovers without restarting the app.
///
/// Release builds do none of this: they take the --dart-define (or
/// [_fallback]) and nothing else, so a shipped app can only talk to the server
/// it was built for.
const String _defineBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Used when nothing else is known. Localhost covers desktop, web, and a phone
/// with `adb reverse` up.
const String _fallback = 'http://127.0.0.1:8000';

/// The port the backend listens on, and the port a local search looks for.
const int _port = 8000;

/// Tried when the configured address does not answer. 10.0.2.2 is the Android
/// emulator's route to the machine it runs on.
const List<String> _probeCandidates = [
  'http://127.0.0.1:8000',
  'http://10.0.2.2:8000',
];

class ApiConfig {
  ApiConfig._();

  static String _base = _defineBaseUrl.isNotEmpty ? normalize(_defineBaseUrl) : _fallback;
  static Future<bool>? _probing;
  static DateTime? _probedAt;
  static final Completer<void> _ready = Completer<void>();

  /// Completes once the first search for the server has finished, or after
  /// [_startupBudget], whichever comes first. Every request waits on it, so no
  /// screen can fire at an address that was only a guess -- and nothing waits
  /// longer than the budget, so a server that is simply down never holds the
  /// app in a loading state.
  static Future<void> get ready => _ready.future;

  static const Duration _startupBudget = Duration(milliseconds: 2500);

  /// The first candidate is the one this device last agreed on, so it gets a
  /// short exclusive try before the rest are raced.
  static const Duration _preferredTimeout = Duration(milliseconds: 700);
  static const Duration _raceTimeout = Duration(milliseconds: 1500);

  /// A failed search is not repeated for this long, so a burst of failing
  /// requests cannot turn into a burst of searches.
  static const Duration _probeCooldown = Duration(seconds: 3);

  /// The base URL every request is built on, without a trailing slash.
  static String get baseUrl => _base;

  /// Whether the address can be changed on the device. Debug builds only -- but
  /// true even when the build carried its own address, so an app installed from
  /// VS Code can still be re-pointed from the phone.
  static bool get isConfigurable => kDebugMode;

  /// Where the current address came from, for the developer screen.
  static String get source {
    if (_base == Services.prefs.backendBaseUrl) return 'Set on this device';
    if (_defineBaseUrl.isNotEmpty && _base == normalize(_defineBaseUrl)) return 'From this build';
    if (_base == Services.prefs.backendLastGoodUrl) return 'Last address that worked';
    return 'Default';
  }

  /// Called once at startup, after preferences are loaded. Takes the best
  /// address known without touching the network, then checks in the background
  /// that something answers there.
  static void init() {
    if (!isConfigurable) {
      _markReady();
      return;
    }
    _base = candidates().first;
    unawaited(ensureReachable().whenComplete(_markReady));
    // Whatever the network does, requests start no later than this.
    Future<void>.delayed(_startupBudget).then((_) => _markReady());
  }

  static void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Every address worth trying, best first, without duplicates.
  static List<String> candidates() {
    final chosen = Services.prefs.backendBaseUrl;
    final lastGood = Services.prefs.backendLastGoodUrl;
    return <String>{
      // What someone typed into Settings wins: it is the most deliberate.
      if (chosen != null && chosen.isNotEmpty) chosen,
      if (lastGood != null && lastGood.isNotEmpty) lastGood,
      if (_defineBaseUrl.isNotEmpty) normalize(_defineBaseUrl),
      for (final c in _probeCandidates)
        // The emulator address means nothing anywhere but Android.
        if (c != 'http://10.0.2.2:8000' || (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) c,
      _fallback,
    }.toList();
  }

  /// Tries the candidates in order and keeps the first that answers. False when
  /// none did. Concurrent calls share one search, so a burst of failed requests
  /// does not start a burst of searches.
  /// [force] is for a search someone asked for -- the Retry beside "Offline",
  /// or Settings testing an address they just typed. Those must really look,
  /// even if a search has just failed; only the app's own automatic retries
  /// respect the cooldown.
  static Future<bool> ensureReachable({bool force = false}) {
    if (!isConfigurable) return Future.value(true);
    final running = _probing;
    if (running != null) return running;
    final last = _probedAt;
    if (!force && last != null && DateTime.now().difference(last) < _probeCooldown) {
      return Future.value(false);
    }
    return _probing = _probe().whenComplete(() {
      _probing = null;
      _probedAt = DateTime.now();
    });
  }

  /// Asks the candidates for /health: the one this device last agreed on
  /// first, on its own, then all the others at once. Racing them matters --
  /// asked one at a time, an address that is merely unreachable costs the full
  /// timeout before the next is tried, and that wait is what the reciter feels.
  static Future<bool> _probe() async {
    final all = <String>{_base, ...candidates()}.toList();
    final preferred = all.first;
    if (await canReach(preferred, timeout: _preferredTimeout)) {
      await _use(preferred);
      return true;
    }

    final rest = all.skip(1).toList();
    if (rest.isEmpty) return false;
    final winner = Completer<String?>();
    var pending = rest.length;
    for (final candidate in rest) {
      unawaited(canReach(candidate, timeout: _raceTimeout).then((reachable) {
        if (reachable && !winner.isCompleted) winner.complete(candidate);
        pending -= 1;
        if (pending == 0 && !winner.isCompleted) winner.complete(null);
      }));
    }
    final found = await winner.future;
    if (found == null) return false;
    await _use(found);
    return true;
  }

  /// Uses [address] from the next call on, and remembers it as the last one
  /// that worked. That is what lets an Android Studio run -- which carries no
  /// address of its own -- find the server a VS Code run had found.
  static Future<void> _use(String address) async {
    _base = address;
    if (Services.prefs.backendLastGoodUrl != address) {
      await Services.prefs.setBackendLastGoodUrl(address);
    }
  }

  /// One quick health check. Short timeout: this runs while someone waits.
  static Future<bool> canReach(String candidate, {Duration timeout = const Duration(milliseconds: 1500)}) async {
    try {
      final response = await http.get(Uri.parse('$candidate/health')).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Looks for the server on the network this device is on: the machine running
  /// it is nearly always another address in the same range. Only ever started
  /// by someone tapping "Find it for me", and only in debug builds. Returns the
  /// address it found, or null.
  static Future<String?> findOnLocalNetwork() async {
    if (!isConfigurable || kIsWeb) return null;
    final prefixes = <String>{};
    try {
      for (final interface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final address in interface.addresses) {
          if (address.isLoopback) continue;
          final parts = address.address.split('.');
          if (parts.length == 4) prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
    } catch (_) {
      return null;
    }

    for (final prefix in prefixes) {
      // A phone cannot ask 254 machines one at a time and still feel quick, so
      // they are asked in batches, each with a short patience.
      for (var start = 1; start < 255; start += 32) {
        final batch = <Future<String?>>[];
        for (var host = start; host < start + 32 && host < 255; host++) {
          final candidate = 'http://$prefix.$host:8000';
          batch.add(
            canReach(candidate, timeout: const Duration(milliseconds: 600))
                .then((ok) => ok ? candidate : null),
          );
        }
        final found = (await Future.wait(batch)).whereType<String>().firstOrNull;
        if (found != null) {
          await setBaseUrl(found);
          return found;
        }
      }
    }
    return null;
  }

  /// Saves an address typed (or found) on the device and uses it from the next
  /// call on. An empty value clears it and falls back to the other candidates.
  ///
  /// A typed address is not recorded as "the last one that worked" -- that
  /// title belongs to an address something actually answered on, and is what
  /// a later build with no address of its own falls back to.
  static Future<void> setBaseUrl(String? value) async {
    final cleaned = normalize(value ?? '');
    await Services.prefs.setBackendBaseUrl(cleaned.isEmpty ? null : cleaned);
    _base = cleaned.isEmpty ? candidates().first : cleaned;
    _probedAt = null; // the next failure may search again straight away
  }

  /// Accepts what a person would actually type -- "192.168.18.178",
  /// "192.168.18.178:8000", a trailing slash -- and returns a usable base URL.
  static String normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '';
    if (uri.hasPort) return '${uri.scheme}://${uri.host}:${uri.port}';
    // Only a plain http address gets the development port. An https address
    // with no port is a deployed server on 443, and appending 8000 to it would
    // quietly point a release build at nothing.
    return uri.scheme == 'http' ? '${uri.scheme}://${uri.host}:$_port' : '${uri.scheme}://${uri.host}';
  }
}
