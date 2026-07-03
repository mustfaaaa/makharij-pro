import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AppSnackbar {
  AppSnackbar._();

  static void show(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        ),
      );
  }
}
