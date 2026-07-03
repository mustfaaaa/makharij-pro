import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_spacing.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({super.key, this.width = double.infinity, this.height = 16, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.border,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: borderRadius ?? AppRadii.smRadius),
      ),
    );
  }
}

/// Shimmer skeleton mimicking a list of cards — used while dummy async
/// data is "loading" (simulated delay) on list screens.
class ShimmerListPlaceholder extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerListPlaceholder({super.key, this.itemCount = 5, this.itemHeight = 72});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => ShimmerBox(height: itemHeight, borderRadius: AppRadii.mdRadius),
    );
  }
}
