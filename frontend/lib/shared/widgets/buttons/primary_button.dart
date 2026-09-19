import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

/// The one filled, high-contrast action on a screen: deep green with ivory
/// text (lifted emerald with dark text at night). Styling comes from
/// `filledButtonTheme`; this adds the loading state and a light haptic.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    // The spinner replaces the label but the button keeps its size, so the
    // layout does not jump while an action is in flight.
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.textOnPrimary),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final effectiveOnPressed = (isLoading || onPressed == null)
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };

    final button = Semantics(
      liveRegion: isLoading,
      label: isLoading ? '$label, in progress' : null,
      child: FilledButton(
        onPressed: effectiveOnPressed,
        style: isLoading
            ? FilledButton.styleFrom(disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.85))
            : null,
        child: child,
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
