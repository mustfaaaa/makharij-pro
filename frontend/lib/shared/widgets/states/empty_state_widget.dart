import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../ui/ornaments.dart';
import '../buttons/primary_button.dart';

/// An empty state that says what belongs here and how to get it: a rosette
/// holding the subject's icon, a title in Amiri, one sentence, one action.
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
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RosetteBadge(
                size: 92,
                fill: AppColors.goldWash,
                child: ExcludeSemantics(child: Icon(icon, size: 34, color: AppColors.goldInk)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: textTheme.bodyMedium, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: actionLabel!, onPressed: onAction, fullWidth: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
