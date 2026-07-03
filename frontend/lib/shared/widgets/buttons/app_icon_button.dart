import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

/// A circular icon button on a soft surface — used in app bars, cards,
/// and floating controls throughout the app. Pass [tooltip] to give it an
/// accessible label (announced by screen readers and shown on long-press).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? iconColor;
  final double size;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.background,
    this.iconColor,
    this.size = 44,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: background ?? AppColors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.46, color: iconColor ?? AppColors.textPrimary),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return Semantics(button: true, label: tooltip, child: button);
  }
}
