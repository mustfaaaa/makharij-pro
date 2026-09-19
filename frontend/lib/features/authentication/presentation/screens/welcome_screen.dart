import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/hijri_date.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// The first screen a signed-out reciter sees: an open Mushaf, the name, one
/// line on what MakharijPro does, and the two ways in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: size.height * 0.52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AppPhoto(AppPhotos.mushafGreen, alignment: Alignment(0, 0.25)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.55, 1.0],
                      colors: [
                        AppColors.photoScrim.withValues(alpha: 0.35),
                        AppColors.photoScrim.withValues(alpha: 0.0),
                        AppColors.background,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: top + 4,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Help',
                    onPressed: () => context.push(RoutePaths.helpFaq),
                    style: IconButton.styleFrom(foregroundColor: AppColors.textOnPhoto),
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                ),
                Positioned(
                  top: top + 16,
                  left: AppSpacing.screenPadding,
                  child: Text(HijriDate.currentYearLabel(),
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabicWord(fontSize: 16, color: AppColors.textOnPhotoSecondary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding + 4, 0, AppSpacing.screenPadding + 4, AppSpacing.lg),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduce ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) =>
                      Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandMark(size: 56),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(header: true, child: Text('MakharijPro', style: textTheme.displayMedium)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Recite the Quran and see, word by word, what was heard. Understand each rule, and try again.',
                        style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.6),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: () => context.push(RoutePaths.register),
                          child: const Text('Create an account'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () => context.push(RoutePaths.login),
                          child: const Text('I already have an account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
