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
    // shrinkWrap + NeverScrollableScrollPhysics: sizes to its content instead
    // of demanding a bounded height, so it's safe to nest inside another
    // scrollable (e.g. shown as one item of an outer ListView while loading).
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => ShimmerBox(height: itemHeight, borderRadius: AppRadii.mdRadius),
    );
  }
}

/// A content-aware skeleton shaped like a [SurahCard] (avatar circle, two
/// text lines, trailing block) so the loading state previews the real layout
/// instead of a plain bar.
class SurahCardSkeleton extends StatelessWidget {
  const SurahCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.mdRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(22))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 120, height: 13),
                SizedBox(height: 8),
                ShimmerBox(width: 80, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerBox(width: 52, height: 20, borderRadius: BorderRadius.all(Radius.circular(6))),
        ],
      ),
    );
  }
}

/// A list of [SurahCardSkeleton]s for surah-listing screens.
class ShimmerSurahList extends StatelessWidget {
  final int itemCount;
  const ShimmerSurahList({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => const SurahCardSkeleton(),
    );
  }
}
