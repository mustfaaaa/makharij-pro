import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../widgets/makharij_launch.dart';

/// The first screen: the makharij launch, then straight on.
///
/// The whole sequence plays on the first launch of each day; every other
/// launch gets the short version, because an animation seen many times a day
/// stops being a welcome and becomes a wait. A tap skips it either way.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final bool _full = _takeFullLaunch();

  static bool _takeFullLaunch() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (Services.prefs.lastFullLaunchDay == today) return false;
    Services.prefs.setLastFullLaunchDay(today);
    return true;
  }

  void _next() {
    if (!mounted) return;
    final String next;
    if (Services.auth.currentUser != null) {
      next = RoutePaths.home;
    } else if (Services.prefs.onboardingSeen) {
      next = RoutePaths.welcome;
    } else {
      next = RoutePaths.onboarding;
    }
    context.go(next);
  }

  @override
  Widget build(BuildContext context) {
    // Dark ground, so the status bar's icons go light for the launch.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: MakharijLaunch(full: _full, onDone: _next),
      ),
    );
  }
}
