import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Internal reference screen for the design system. Not part of the
/// user-facing navigation graph — reachable only via a debug route.
class StyleGuideScreen extends StatelessWidget {
  const StyleGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Style Guide')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _SectionLabel('Colors'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ColorSwatch('primary', AppColors.primary),
              _ColorSwatch('primaryDark', AppColors.primaryDark),
              _ColorSwatch('primaryLight', AppColors.primaryLight),
              _ColorSwatch('accent', AppColors.accent),
              _ColorSwatch('accentLight', AppColors.accentLight),
              _ColorSwatch('background', AppColors.background, dark: false),
              _ColorSwatch('surface', AppColors.surface, dark: false),
              _ColorSwatch('success', AppColors.success),
              _ColorSwatch('warning', AppColors.warning),
              _ColorSwatch('error', AppColors.error),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Typography'),
          const SizedBox(height: AppSpacing.sm),
          Text('Display Large', style: Theme.of(context).textTheme.displayLarge),
          Text('Headline Medium', style: Theme.of(context).textTheme.headlineMedium),
          Text('Title Large', style: Theme.of(context).textTheme.titleLarge),
          Text('Body Large', style: Theme.of(context).textTheme.bodyLarge),
          Text('Body Medium', style: Theme.of(context).textTheme.bodyMedium),
          Text('Label Large', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', style: AppTypography.arabicVerse(), textAlign: TextAlign.right),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Radii'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _RadiusSwatch('sm', AppRadii.sm),
              _RadiusSwatch('md', AppRadii.md),
              _RadiusSwatch('lg', AppRadii.lg),
              _RadiusSwatch('xl', AppRadii.xl),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.accent));
  }
}

class _ColorSwatch extends StatelessWidget {
  final String name;
  final Color color;
  final bool dark;
  const _ColorSwatch(this.name, this.color, {this.dark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.smRadius,
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        name,
        style: TextStyle(fontSize: 10, color: dark ? Colors.white : AppColors.textPrimary),
      ),
    );
  }
}

class _RadiusSwatch extends StatelessWidget {
  final String name;
  final double radius;
  const _RadiusSwatch(this.name, this.radius);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(name, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
