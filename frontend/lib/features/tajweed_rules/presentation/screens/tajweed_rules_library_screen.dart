import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/tajweed_rules_cubit.dart';

/// The Tajweed rules library: what each rule is, with its example in the
/// Quran's own script, and whether MakharijPro checks it when you recite.
class TajweedRulesLibraryScreen extends StatelessWidget {
  const TajweedRulesLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TajweedRulesCubit(),
      child: const _TajweedRulesLibraryView(),
    );
  }
}

class _TajweedRulesLibraryView extends StatefulWidget {
  const _TajweedRulesLibraryView();

  @override
  State<_TajweedRulesLibraryView> createState() => _TajweedRulesLibraryViewState();
}

class _TajweedRulesLibraryViewState extends State<_TajweedRulesLibraryView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tajweed rules'),
        actions: [
          IconButton(
            tooltip: 'Saved rules and surahs',
            icon: const Icon(Icons.bookmark_outline_rounded),
            onPressed: () => context.push(RoutePaths.bookmarks),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.goldWash.withValues(alpha: 0.5)),
                    child: GeometricPattern(color: AppColors.gold, opacity: 0.12, cellSize: 38),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('The rules of recitation, one at a time. Rules marked “Checked when you recite” are the ones MakharijPro listens for.',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search rules',
                          prefixIcon: const Icon(Icons.search_rounded),
                          fillColor: AppColors.surface,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadii.mdRadius,
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<TajweedRulesCubit, ListState<TajweedRule>>(
            builder: (context, state) {
              if (state.status == ListStatus.loading) {
                return const SliverToBoxAdapter(child: ShimmerListPlaceholder(itemCount: 6));
              }
              if (state.status == ListStatus.error) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorStateWidget(
                    message: state.errorMessage ?? 'The rules could not load.',
                    onRetry: () => context.read<TajweedRulesCubit>().load(),
                  ),
                );
              }
              final q = _query.trim().toLowerCase();
              final filtered = state.items
                  .where((r) => r.title.toLowerCase().contains(q) || r.shortDescription.toLowerCase().contains(q))
                  .toList();
              if (filtered.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: 'No rule matches',
                    message: 'Try a rule name like Madd or Ghunnah.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xl),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _RuleRow(rule: filtered[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final TajweedRule rule;
  const _RuleRow({required this.rule});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = rule.title.split(' (').first;
    final gloss = rule.title.contains('(') ? rule.title.split('(').last.replaceAll(')', '') : null;
    return Semantics(
      button: true,
      label: '${rule.title}. ${rule.shortDescription}${rule.isAiDetectable ? ' Checked when you recite.' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(RoutePaths.ruleDetailsPath(rule.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.goldWash,
                  borderRadius: AppRadii.mdRadius,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(rule.arabicExample,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.quran(fontSize: 22, color: AppColors.goldInk, height: 1.7)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(name, style: textTheme.titleMedium)),
                        if (rule.isBookmarked) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bookmark_rounded, size: 15, color: AppColors.goldInk),
                        ],
                      ],
                    ),
                    if (gloss != null) Text(gloss, style: textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(rule.shortDescription, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    if (rule.isAiDetectable) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, size: 14, color: AppColors.primaryDark),
                          const SizedBox(width: 4),
                          Text('Checked when you recite',
                              style: textTheme.labelSmall?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
