import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';

class AppBottomSheet {
  AppBottomSheet._();

  /// A modal sheet with the theme's drag handle, a title in Amiri, and the
  /// keyboard inset respected.
  static Future<T?> show<T>(BuildContext context, {required String title, required Widget child}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
