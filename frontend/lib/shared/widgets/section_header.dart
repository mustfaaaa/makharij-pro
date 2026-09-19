import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A section title in Amiri with an optional action on the trailing edge.
/// Sections are separated by space, not boxes; this is what names them.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ),
        if (actionLabel != null) TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
      ],
    );
  }
}
