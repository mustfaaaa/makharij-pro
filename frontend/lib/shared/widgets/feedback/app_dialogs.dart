import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AppDialogs {
  AppDialogs._();

  /// A two-choice confirmation. The actions sit in their own Row: they used
  /// to be `Expanded` children placed straight into `AlertDialog.actions`,
  /// which is not a flex layout, so the dialog threw a parent-data error.
  /// A destructive confirmation is drawn in the error colour so it never looks
  /// like the safe choice.
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
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(cancelLabel, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: isDestructive
                      ? FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.textOnAccent,
                        )
                      : null,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(confirmLabel, textAlign: TextAlign.center),
                ),
              ),
            ],
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
