import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/navigation/app_bottom_nav.dart';

/// Wraps the five bottom-nav tabs (Home, Quran, Rattil, Progress, Profile) in
/// a single scaffold with a persistent [AppBottomNav], as required by
/// [StatefulShellRoute].
///
/// The bar is opaque and laid out by the Scaffold (no `extendBody`), so tab
/// screens end above it instead of scrolling underneath it.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
