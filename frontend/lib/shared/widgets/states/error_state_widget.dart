import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../buttons/primary_button.dart';

/// What went wrong and how to recover, in plain words, with a retry. Calm on
/// purpose: a quiet icon and the message carry it, not a red alarm disc.
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textMuted),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(message, style: textTheme.bodyMedium, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                      label: 'Try again', onPressed: onRetry, icon: Icons.refresh_rounded, fullWidth: false),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
