import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import '../../../theme/app_theme.dart';
import '../animated/pressable.dart';

/// Base rounded card sharing the app's canonical surface (see
/// [AppTheme.cardDecoration]) — soft shadow + hairline border. Other card
/// widgets compose this; tappable ones get the app-wide [Pressable] feel.
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
    final card = Container(
      padding: padding,
      decoration: AppTheme.cardDecoration(),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}
