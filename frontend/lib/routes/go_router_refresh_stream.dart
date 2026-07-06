import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] (Firebase's `authStateChanges`) into a [Listenable] so
/// go_router's `refreshListenable` re-evaluates `redirect` the moment auth
/// state changes, not just on the next user-initiated navigation.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
