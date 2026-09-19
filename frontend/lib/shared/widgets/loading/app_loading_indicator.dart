import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// A small, quiet progress ring with an optional caption. For content-shaped
/// screens prefer a skeleton (shimmer_placeholder.dart); this is for the few
/// places with nothing to preview.
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoadingIndicator({super.key, this.message, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message ?? 'Loading',
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
