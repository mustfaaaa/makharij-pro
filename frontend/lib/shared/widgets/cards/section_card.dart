import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_theme.dart';
import '../animated/pressable.dart';

/// The app's standard content card: unified surface, radius, and soft shadow
/// (via [AppTheme.cardDecoration]) with an optional icon-badge header that
/// follows the type scale. Every dashboard card is built on this so the whole
/// screen reads as one designed system rather than a pile of ad-hoc boxes.
class SectionCard extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Optional tint for the icon badge (defaults to the gold brand tint).
  final Color? accent;

  const SectionCard({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.onTap,
    this.accent,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = accent ?? AppColors.primary;
    final hasHeader = icon != null || title != null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHeader) ...[
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Text(title!, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (child != null) const SizedBox(height: AppSpacing.md),
        ],
        ?child,
      ],
    );

    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: AppTheme.cardDecoration(),
      child: content,
    );

    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}
