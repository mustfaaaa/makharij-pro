import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

/// Bundled photography (see assets/images/photos/CREDITS.md). One photo per
/// surface, always contained, never behind Quran text.
abstract class AppPhotos {
  static const homeRehal = 'assets/images/photos/home_rehal.jpg';
  static const mushafGreen = 'assets/images/photos/mushaf_green.jpg';
  static const rehalCarved = 'assets/images/photos/rehal_carved.jpg';
  static const archesIvory = 'assets/images/photos/arches_ivory.jpg';
  static const domeCalligraphy = 'assets/images/photos/dome_calligraphy.jpg';
  static const quranGreenCloth = 'assets/images/photos/quran_green_cloth.jpg';
}

/// A decoded-at-display-size photograph. Decoding a 1200px JPEG into a
/// 390-point header on a 3x phone is fine; decoding it at full size for a
/// 120-point thumbnail is not, so the cache width follows the layout.
class AppPhoto extends StatelessWidget {
  final String asset;
  final Alignment alignment;
  final BoxFit fit;
  const AppPhoto(this.asset, {super.key, this.alignment = Alignment.center, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
      return Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: (w * dpr).round().clamp(200, 1200),
        excludeFromSemantics: true,
        // Fade the photo in rather than popping it: a calm arrival, and no
        // flash of empty space on a slow first decode.
        frameBuilder: (context, child, frame, sync) {
          if (sync) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            child: child,
          );
        },
      );
    });
  }
}

/// An atmospheric header: the photograph under a deep green-black scrim at
/// the top (so the status bar and any text there read) that melts into the
/// page background at the bottom, so the content below seems to continue the
/// picture rather than sit under a box.
class PhotoHeader extends StatelessWidget {
  final String asset;
  final double height;
  final Alignment alignment;

  /// Strength of the scrim behind text laid on the top part of the photo.
  final double topScrim;

  /// Strength of the scrim in the middle, where a headline usually sits.
  final double midScrim;
  final Widget? child;

  const PhotoHeader({
    super.key,
    required this.asset,
    required this.height,
    this.alignment = Alignment.center,
    this.topScrim = 0.55,
    this.midScrim = 0.25,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scrim = AppColors.photoScrim;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppPhoto(asset, alignment: alignment),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 0.78, 1.0],
                colors: [
                  scrim.withValues(alpha: topScrim),
                  scrim.withValues(alpha: midScrim),
                  scrim.withValues(alpha: midScrim * 0.6),
                  AppColors.background,
                ],
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// A contained, rounded photograph with an ivory caption at its foot: for a
/// banner inside a scrolling page, not for a full-bleed header.
class PhotoBanner extends StatelessWidget {
  final String asset;
  final double height;
  final Alignment alignment;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const PhotoBanner({
    super.key,
    required this.asset,
    required this.child,
    this.height = 168,
    this.alignment = Alignment.center,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scrim = AppColors.photoScrim;
    final content = ClipRRect(
      borderRadius: AppRadii.lgRadius,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppPhoto(asset, alignment: alignment),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    scrim.withValues(alpha: 0.05),
                    scrim.withValues(alpha: 0.30),
                    scrim.withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: AppColors.textOnPhoto.withValues(alpha: 0.08),
                highlightColor: AppColors.textOnPhoto.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Align(alignment: Alignment.bottomLeft, child: child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: content,
    );
  }
}
