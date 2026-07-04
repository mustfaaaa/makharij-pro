import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import '../animated/pressable.dart';

/// Base rounded, bordered card. Other card widgets compose this.
/// Tappable cards get the app-wide [Pressable] scale + haptic feel.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(child: Padding(padding: padding, child: child));
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}
