import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Subtle fade + upward-slide push transition, used for every top-level
/// route so screen-to-screen navigation feels considered rather than the
/// platform default abrupt swap.
CustomTransitionPage<void> fadeSlidePage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(fade);
      return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
    },
  );
}

/// Custom container for [StatefulShellRoute] branch Navigators that
/// crossfades between bottom-nav tabs (a Material "fade through" motion —
/// fade + gentle scale) instead of the default [IndexedStack]'s instant cut.
/// All branch Navigators stay mounted throughout, exactly like
/// [IndexedStack], so each tab's navigation state is preserved.
class AnimatedBranchContainer extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int i = 0; i < children.length; i++)
          AnimatedScale(
            scale: i == currentIndex ? 1 : 1.04,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: i == currentIndex ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: i != currentIndex,
                child: TickerMode(enabled: i == currentIndex, child: children[i]),
              ),
            ),
          ),
      ],
    );
  }
}
