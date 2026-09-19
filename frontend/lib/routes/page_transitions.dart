import 'package:flutter/material.dart';

/// The page every top-level route is pushed with.
///
/// This used to be a [CustomTransitionPage] with its own fade-and-slide, which
/// quietly removed the iOS edge-swipe back gesture and Android's predictive
/// back -- a custom transition builder replaces the platform route that
/// provides both. A [MaterialPage] takes its motion from
/// `ThemeData.pageTransitionsTheme` (Cupertino on iOS, FadeForwards on
/// Android), so the gestures come back and the motion matches the platform.
///
/// The name is kept so the router's call sites stay unchanged.
Page<void> fadeSlidePage({required LocalKey key, required Widget child}) {
  return MaterialPage<void>(key: key, child: child);
}

/// Container for [StatefulShellRoute] branch Navigators that cross-fades
/// between tabs instead of the default [IndexedStack]'s instant cut. All
/// branch Navigators stay mounted, exactly like [IndexedStack], so each tab
/// keeps its scroll position and navigation state.
///
/// A plain fade: the 1.04 zoom it used to add read as the page lurching.
class AnimatedBranchContainer extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200);
    return Stack(
      children: [
        for (int i = 0; i < children.length; i++)
          AnimatedOpacity(
            opacity: i == currentIndex ? 1 : 0,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              ignoring: i != currentIndex,
              child: TickerMode(enabled: i == currentIndex, child: children[i]),
            ),
          ),
      ],
    );
  }
}
