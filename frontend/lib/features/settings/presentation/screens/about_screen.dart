import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('م', style: AppTypography.arabicVerse(fontSize: 38, color: AppColors.primary)),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('MakharijPro AI', style: Theme.of(context).textTheme.headlineSmall),
                Text('Version 1.0.0', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'MakharijPro AI is an AI-powered application that detects Tajweed errors in Quran recitation in real time. '
            'It listens to your recitation, highlights mispronounced words instantly, and helps you improve through '
            'personalized feedback, accuracy scoring, and progress tracking.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Final Year Project', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Developed by Hammad Fareed & Syed Mustafa\nCOMSATS University Islamabad, Abbottabad Campus\nSupervisor: Aisha Ajmal Khan',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
