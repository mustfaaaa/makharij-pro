import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../buttons/primary_button.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: actionLabel!, onPressed: onAction, fullWidth: false),
            ],
          ],
        ),
      ),
    );
  }
}
