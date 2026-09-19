import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AppSnackbar {
  AppSnackbar._();

  /// A short confirmation or problem, floating above the bottom edge. Errors
  /// carry a leading icon as well as the colour, so they are not signalled by
  /// colour alone.
  static void show(BuildContext context, String message, {bool isError = false, SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                size: 20,
                color: isError ? AppColors.textOnAccent : AppColors.textOnInverse,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          action: action,
          backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        ),
      );
  }
}
