import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../buttons/outlined_app_button.dart';
import '../buttons/primary_button.dart';

class AppDialogs {
  AppDialogs._();

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Expanded(child: OutlinedAppButton(label: cancelLabel, onPressed: () => Navigator.of(ctx).pop(false))),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> info(BuildContext context, {required String title, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
