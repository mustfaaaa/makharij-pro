import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/practice_plan_item.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../shared/ui/tajweed_marks.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';
import '../bloc/practice_plan_cubit.dart';

/// The practice plan: the Tajweed rules the reciter's own recitations most
/// often flagged, each with the actual words it was flagged on -- tap one to
/// open exactly that ayah and practise it.
class PracticePlanScreen extends StatelessWidget {
  const PracticePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocProvider(
      create: (_) => PracticePlanCubit(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 180,
              backgroundColor: AppColors.photoScrim,
              foregroundColor: AppColors.textOnPhoto,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14),
                title: Text('Practice plan', style: AppTypography.displayText(fontSize: 20, color: AppColors.textOnPhoto)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    const AppPhoto(AppPhotos.domeCalligraphy),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.photoScrim.withValues(alpha: 0.5), AppColors.photoScrim.withValues(alpha: 0.8)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BlocBuilder<PracticePlanCubit, ListState<PracticePlanItem>>(
              builder: (context, state) {
                if (state.status == ListStatus.loading) {
                  return const SliverToBoxAdapter(child: ShimmerListPlaceholder(itemCount: 3, itemHeight: 110));
                }
                if (state.status == ListStatus.error) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorStateWidget(
                      title: 'Your plan could not load',
                      message: state.errorMessage ?? 'Check your connection and try again.',
                      onRetry: () => context.read<PracticePlanCubit>().load(),
                    ),
                  );
                }
                final personal = state.items.where((i) => (i.errorCount ?? 0) > 0 && i.rule.isNotEmpty).toList();
                if (personal.isEmpty) {
                  // The backend's beginner and "no weak areas" plans: nothing
                  // personal to show yet, so say what that means.
                  final reason = state.items.isEmpty ? null : state.items.first.reason;
                  final clean = reason != null && reason.toLowerCase().contains('no recurring');
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateWidget(
                      icon: clean ? Icons.check_circle_outline_rounded : Icons.checklist_rounded,
                      title: clean ? 'Nothing keeps coming up' : 'Your plan builds as you recite',
                      message: clean
                          ? 'No rule has been flagged repeatedly in your recent recitations.'
                          : 'After a few recitations, the rules you are flagged on most, and the words, appear here.',
                      actionLabel: 'Choose a surah',
                      onAction: () => context.go(RoutePaths.quran),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.lg, AppSpacing.screenPadding, AppSpacing.xl),
                  sliver: SliverList.list(children: [
                    Text('Built from the words flagged in your own recitations, most frequent first.',
                        style: textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    for (final item in personal) _PlanItem(item: item),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanItem extends StatelessWidget {
  final PracticePlanItem item;
  const _PlanItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rule = tajweedErrorTypeFromId(item.rule);
    final color = rule == null ? AppColors.primaryDark : TajweedRuleStyle.color(rule);
    final count = item.errorCount ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rule != null) ...[RuleShapeSwatch(rule: rule, width: 26), const SizedBox(width: 10)],
              Expanded(child: Text(item.tajweedRule, style: textTheme.headlineSmall?.copyWith(color: color))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Flagged on $count word${count == 1 ? '' : 's'} recently', style: textTheme.bodySmall),
          if (rule != null) ...[
            const SizedBox(height: 8),
            Text(TajweedCopy.fallbackBody(rule), style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          ],
          if (item.examples.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Your words', style: textTheme.labelMedium),
            const SizedBox(height: 8),
            // The actual words this was measured on: the plan shows its
            // working instead of just asserting a weak area.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in item.examples) _WordLink(example: e, rule: rule, color: color),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WordLink extends StatelessWidget {
  final PracticePlanExample example;
  final TajweedErrorType? rule;
  final Color color;
  const _WordLink({required this.example, required this.rule, required this.color});

  @override
  Widget build(BuildContext context) {
    final surah = example.surahNumber;
    final ayah = example.ayahNumber;
    final name = surah == null ? null : dummySurahs.where((s) => s.number == surah).firstOrNull?.nameEnglish;
    final where = (surah == null || ayah == null) ? null : '${name ?? 'Surah $surah'} $surah:$ayah';
    return Semantics(
      button: surah != null,
      label: 'Practise ${example.word}${where == null ? '' : ', $where'}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius, side: BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: AppRadii.mdRadius,
          onTap: surah == null
              ? null
              : () => context.push(RoutePaths.surahDetailsPath(surah, from: ayah, to: ayah, ayah: ayah)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MarkedWord(word: example.word, rule: rule, color: color),
                if (where != null) ...[
                  const SizedBox(height: 4),
                  Text(where, style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
