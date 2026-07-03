import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_ayahs.dart';
import '../../../../dummy/dummy_sessions.dart';
import '../../../../models/session_result.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/outlined_app_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class ResultScreen extends StatelessWidget {
  final int surahNumber;
  const ResultScreen({super.key, required this.surahNumber});

  SessionResult get _session => dummySessions.firstWhere((s) => s.surahNumber == surahNumber, orElse: () => dummySessions.first);

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final color = scoreColor(session.accuracyScore);
    final errorWordSet = {for (final e in session.errors) e.word};

    return Scaffold(
      appBar: AppBar(title: const Text('Result'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1), border: Border.all(color: color, width: 4)),
                          alignment: Alignment.center,
                          child: Text('${session.accuracyScore.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Tajweed Accuracy Score', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('${session.errors.length} words need attention', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      textDirection: TextDirection.rtl,
                      spacing: 6,
                      runSpacing: 10,
                      children: dummyFatihahAyahs.expand((ayah) {
                        return ayah.arabicText.split(' ').map((word) {
                          final isError = errorWordSet.contains(word);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: isError
                                ? BoxDecoration(color: AppColors.errorHighlightBg, borderRadius: BorderRadius.circular(6))
                                : null,
                            child: Text(
                              word,
                              style: AppTypography.arabicWord(fontSize: 22, color: isError ? AppColors.errorHighlight : AppColors.textPrimary),
                            ),
                          );
                        });
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'View Detailed Feedback',
                    icon: Icons.analytics_outlined,
                    onPressed: () => context.push(RoutePaths.detailedFeedbackPath(session.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Practice Again',
                          onPressed: () => context.pushReplacement(RoutePaths.recitationPath(surahNumber)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Done',
                          onPressed: () => context.go(RoutePaths.home),
                        ),
                      ),
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
