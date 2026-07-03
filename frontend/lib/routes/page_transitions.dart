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
