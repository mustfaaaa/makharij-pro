import 'package:flutter/widgets.dart';

/// Non-web stub — never actually called (the login screen only reaches for
/// this on kIsWeb), kept so the conditional-import switcher compiles on
/// every platform.
Widget renderGoogleWebButton() {
  throw StateError('renderGoogleWebButton() should only be called on web.');
}
