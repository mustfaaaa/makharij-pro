import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../dummy/dummy_ayahs.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/outlined_app_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/hasanah/hasanah_earned_banner.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/recitation_cubit.dart';

class ResultScreen extends StatefulWidget {
  final int surahNumber;
  const ResultScreen({super.key, required this.surahNumber});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _hasanahCredited = false;

  @override
  Widget build(BuildContext context) {
    final result = context.watch<RecitationCubit>().state.result;
    if (result == null) {
      // Guards against a direct deep-link to this route without going
      // through the Listening -> Processing flow first.
      return const Scaffold(body: Center(child: Text('No result available for this session.')));
    }

    if (!_hasanahCredited) {
      _hasanahCredited = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<HasanahCubit>().addHasanah(result.hasanahEarned);
      });
    }

    final color = scoreColor(result.accuracyScore);
    final errorWordSet = {for (final e in result.errors) e.word};

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
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: FittedBox(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: result.accuracyScore),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Text('${value.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color));
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Tajweed Accuracy Score', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HasanahEarnedBanner(amount: result.hasanahEarned),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    result.errors.isEmpty ? 'No errors detected — excellent recitation!' : '${result.errors.length} words need attention',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                    onPressed: () => context.push(RoutePaths.detailedFeedbackPath(result.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Practice Again',
                          onPressed: () {
                            context.read<RecitationCubit>().beginSession(widget.surahNumber);
                            context.pushReplacement(RoutePaths.recitationPath(widget.surahNumber));
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Done',
                          onPressed: () {
                            context.read<RecitationCubit>().reset();
                            context.go(RoutePaths.home);
                          },
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
