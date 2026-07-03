import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoadingIndicator({super.key, this.message, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
