import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/api_config.dart';
import 'services/service_locator.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Read saved preferences before the first frame, so the app opens in the
  // theme and text size the user last chose rather than flashing the default.
  await Services.prefs.load();
  // Applies a saved backend address and, in debug builds, checks in the
  // background that something answers there. Never blocks the first frame.
  ApiConfig.init();
  runApp(const MakharijProApp());
}
