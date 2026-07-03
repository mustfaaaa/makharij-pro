import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../models/session_result.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class DetailedFeedbackScreen extends StatefulWidget {
  final String sessionId;
  const DetailedFeedbackScreen({super.key, required this.sessionId});

  @override
  State<DetailedFeedbackScreen> createState() => _DetailedFeedbackScreenState();
}

class _DetailedFeedbackScreenState extends State<DetailedFeedbackScreen> {
  late final Future<SessionResult> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = Services.session.getSessionById(widget.sessionId);
  }

  Color _typeColor(TajweedErrorType type) {
    switch (type) {
      case TajweedErrorType.makhraj:
        return AppColors.info;
      case TajweedErrorType.ghunnah:
        return AppColors.accent;
      case TajweedErrorType.shaddah:
        return AppColors.warning;
      case TajweedErrorType.madd:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detailed Feedback')),
      body: FutureBuilder<SessionResult>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AppLoadingIndicator();
          final session = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.surahName, style: Theme.of(context).textTheme.titleLarge),
                        Text(DateFormat.yMMMd().add_jm().format(session.dateTime), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  ScoreBadge(score: session.accuracyScore, fontSize: 16),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Errors Breakdown', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (session.errors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text('No Tajweed errors detected in this session. Excellent recitation!', style: Theme.of(context).textTheme.bodyMedium),
                )
              else
                ...session.errors.map((error) {
                  final color = _typeColor(error.type);
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(error.type.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ayah ${error.ayahNumber} · "${error.word}"', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(error.explanation, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'View Practice Plan',
                icon: Icons.checklist_rounded,
                onPressed: () => context.push(RoutePaths.practicePlan),
              ),
            ],
          );
        },
      ),
    );
  }
}
