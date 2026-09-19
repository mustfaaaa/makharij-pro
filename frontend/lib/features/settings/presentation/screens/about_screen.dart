import 'package:flutter/material.dart';

import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

/// What MakharijPro is, what it is not, who made it, and whose work it rests
/// on: the fonts and photographs it bundles, with their licences.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final body = textTheme.bodyLarge?.copyWith(height: 1.65);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.primarySurface),
                    child: GeometricPattern(color: AppColors.primary, opacity: 0.07),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Column(
                      children: [
                        const BrandMark(size: 72),
                        const SizedBox(height: AppSpacing.md),
                        Semantics(header: true, child: Text('MakharijPro AI', style: textTheme.headlineMedium)),
                        const SizedBox(height: 2),
                        Text('Version 1.0.0', style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.lg, AppSpacing.screenPadding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MakharijPro follows along while you recite. When you stop, a speech model trained on Quran '
                    'recitation compares the sounds of each word with its expected pronunciation, and marks the '
                    'words worth reviewing: Madd, Ghunnah, Shaddah and Makhraj.',
                    style: body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'It is a practice companion, not a replacement for a teacher. Its feedback can be wrong, and you '
                    'can say so on any word.',
                    style: body,
                  ),
                  const OrnamentDivider(verticalPadding: 28),
                  _Section(
                    title: 'Final year project',
                    lines: const [
                      'Developed by Hammad Fareed & Syed Mustafa',
                      'COMSATS University Islamabad, Abbottabad Campus',
                      'Supervisor: Aisha Ajmal Khan',
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Section(
                    title: 'Typefaces',
                    lines: const [
                      'Amiri and Amiri Quran, by Khaled Hosny',
                      'Figtree, by Erik Kennedy',
                      'Both under the SIL Open Font License 1.1',
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Section(
                    title: 'Photographs',
                    lines: const [
                      'Anis Coquelet, Abdulloh Fauzan, Abdullah Arif, Jasurbek Hasanov, Paul Bill and Ali Burhan, '
                          'on Unsplash',
                      'Used under the Unsplash License',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _Section({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: textTheme.headlineSmall)),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(line, style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          ),
      ],
    );
  }
}
