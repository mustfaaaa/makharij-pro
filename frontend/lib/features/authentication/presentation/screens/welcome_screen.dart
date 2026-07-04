import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/outlined_app_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('م', style: AppTypography.arabicVerse(fontSize: 52, color: AppColors.primary)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('MakharijPro AI', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Real-time Tajweed error detection for your Quran recitation',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(label: 'Create Account', onPressed: () => context.push(RoutePaths.register)),
              const SizedBox(height: AppSpacing.sm),
              OutlinedAppButton(label: 'Sign In', onPressed: () => context.push(RoutePaths.login)),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
