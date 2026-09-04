import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/service_locator.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Read saved preferences before the first frame, so the app opens in the
  // theme and text size the user last chose rather than flashing the default.
  await Services.prefs.load();
  runApp(const MakharijProApp());
}
