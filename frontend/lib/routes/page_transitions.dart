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

/// Container for [StatefulShellRoute] branch Navigators. All branches stay
/// mounted, so each tab keeps its scroll position and navigation state.
///
/// This was a cross-fade: every branch wrapped in an [AnimatedOpacity] and a
/// [TickerMode], the inactive ones at opacity 0. On a real phone that left the
/// Rattil tab blank -- its Scaffold painted, its body did not. An opacity of 0
/// skips painting the subtree entirely, and muting a branch's tickers freezes
/// the route transition its Navigator runs when the branch is first built, so
/// the page could stay at the start of a transition that never resumed.
///
/// [IndexedStack] is what go_router does by default: one branch painted, the
/// others laid out and left alone, and no animation to get stuck. The tab
/// change is instant; the screens have their own entrance motion.
class AnimatedBranchContainer extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  @override
  Widget build(BuildContext context) => IndexedStack(index: currentIndex, children: children);
}
