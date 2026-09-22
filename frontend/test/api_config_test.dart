// What the app does when it has to work out where the backend is.
//
// The ordering here is the difference between "connects at once" and "hangs
// for a minute": the address this device last agreed on is tried first, and a
// build's own address is only a fallback behind it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/services/api_config.dart';
import 'package:frontend/services/service_locator.dart';

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await Services.prefs.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiConfig.normalize', () {
    test('accepts what someone would actually type', () {
      expect(ApiConfig.normalize('192.168.1.23'), 'http://192.168.1.23:8000');
      expect(ApiConfig.normalize('192.168.1.23:9000'), 'http://192.168.1.23:9000');
      expect(ApiConfig.normalize('  192.168.1.23:8000/  '), 'http://192.168.1.23:8000');
      // A deployed server keeps its own port; the dev port is only for http.
      expect(ApiConfig.normalize('https://api.example.com'), 'https://api.example.com');
      expect(ApiConfig.normalize('https://api.example.com:8443'), 'https://api.example.com:8443');
    });

    test('an empty or unusable value is empty, not a broken URL', () {
      expect(ApiConfig.normalize(''), '');
      expect(ApiConfig.normalize('   '), '');
      expect(ApiConfig.normalize('://'), '');
    });
  });

  group('reaching a real socket', () {
    // flutter_test answers every HTTP request itself so tests cannot reach the
    // network. These three are about real sockets -- a dropped packet, a
    // listening server -- so they opt out of that for their own duration.
    late HttpOverrides? previous;
    setUp(() {
      previous = HttpOverrides.current;
      HttpOverrides.global = null;
    });
    tearDown(() => HttpOverrides.global = previous);

    // A black-holed address: packets are dropped rather than refused, which is
    // exactly what a stale LAN address looks like from a phone. Without a
    // timeout the socket sits there for over a minute, which is what made the
    // app feel broken.
    const blackHole = 'http://10.255.255.1:8000';

    test('a dead address is given up on in about a second, not a minute', () async {
      await _prefs({});
      final watch = Stopwatch()..start();
      final reachable = await ApiConfig.canReach(blackHole);
      watch.stop();
      expect(reachable, isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    });

    test('a listening server is found and remembered', () async {
      await _prefs({});
      if (!await ApiConfig.canReach('http://127.0.0.1:8000')) {
        markTestSkipped('no backend answering on 127.0.0.1:8000');
        return;
      }
      expect(await ApiConfig.ensureReachable(force: true), isTrue);
      expect(ApiConfig.baseUrl, 'http://127.0.0.1:8000');
      // Remembered, so a later build with no address of its own finds it too.
      expect(Services.prefs.backendLastGoodUrl, 'http://127.0.0.1:8000');
    });

    test('a dead first choice does not stop the search', () async {
      await _prefs({'flutter.pref.dev.backendLastGoodUrl': blackHole});
      if (!await ApiConfig.canReach('http://127.0.0.1:8000')) {
        markTestSkipped('no backend answering on 127.0.0.1:8000');
        return;
      }
      final watch = Stopwatch()..start();
      final found = await ApiConfig.ensureReachable(force: true);
      watch.stop();
      expect(found, isTrue);
      expect(ApiConfig.baseUrl, 'http://127.0.0.1:8000');
      // The dead one is tried first, then the rest are raced together.
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  group('ApiConfig.candidates', () {
    test('with nothing saved, localhost leads', () async {
      await _prefs({});
      final candidates = ApiConfig.candidates();
      expect(candidates.first, 'http://127.0.0.1:8000');
      // The emulator's route to the host machine is worth trying on Android,
      // and is meaningless anywhere else -- it must never be first.
      expect(candidates.first, isNot('http://10.0.2.2:8000'));
    });

    test('an address set on the device wins over the last one that worked', () async {
      await _prefs({
        'flutter.pref.dev.backendBaseUrl': 'http://192.168.1.23:8000',
        'flutter.pref.dev.backendLastGoodUrl': 'http://192.168.1.99:8000',
      });
      final candidates = ApiConfig.candidates();
      expect(candidates.first, 'http://192.168.1.23:8000');
      expect(candidates[1], 'http://192.168.1.99:8000');
    });

    test('the last address that worked leads when nothing was set by hand', () async {
      await _prefs({'flutter.pref.dev.backendLastGoodUrl': 'http://192.168.1.99:8000'});
      expect(ApiConfig.candidates().first, 'http://192.168.1.99:8000');
    });

    test('localhost is always in the list, so an adb tunnel is always found', () async {
      await _prefs({'flutter.pref.dev.backendLastGoodUrl': 'http://192.168.1.99:8000'});
      expect(ApiConfig.candidates(), contains('http://127.0.0.1:8000'));
    });

    test('no address is listed twice', () async {
      await _prefs({
        'flutter.pref.dev.backendBaseUrl': 'http://127.0.0.1:8000',
        'flutter.pref.dev.backendLastGoodUrl': 'http://127.0.0.1:8000',
      });
      final candidates = ApiConfig.candidates();
      expect(candidates.length, candidates.toSet().length);
    });
  });
}
