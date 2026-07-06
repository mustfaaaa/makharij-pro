import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Renders Google's own pre-built sign-in button — required on web, since
/// browsers block a custom button from triggering the FedCM/Identity
/// Services sign-in flow (see [GoogleSignIn.supportsAuthenticate]).
Widget renderGoogleWebButton() {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      shape: web.GSIButtonShape.pill,
      text: web.GSIButtonText.continueWith,
    ),
  );
}
