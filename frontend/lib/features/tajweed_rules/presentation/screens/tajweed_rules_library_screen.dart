import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/rule_card.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/tajweed_rules_cubit.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tajweed Rules'),
        actions: [
          AppIconButton(icon: Icons.bookmark_outline, onPressed: () => context.push(RoutePaths.bookmarks)),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ResponsiveCenter(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.sm),
            child: AppSearchBar(hint: 'Search rules', onChanged: (v) => setState(() => _query = v)),
          ),
          Expanded(
            child: BlocBuilder<TajweedRulesCubit, ListState<TajweedRule>>(
              builder: (context, state) {
                if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 6);
                if (state.status == ListStatus.error) {
                  return ErrorStateWidget(message: state.errorMessage ?? 'Could not load rules.', onRetry: () => context.read<TajweedRulesCubit>().load());
                }
                final filtered = state.items.where((r) => r.title.toLowerCase().contains(_query.toLowerCase())).toList();
                if (filtered.isEmpty) {
                  return const EmptyStateWidget(icon: Icons.search_off_rounded, title: 'No rules found', message: 'Try a different search term.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final rule = filtered[i];
                    return StaggeredFadeSlide(
                      index: i,
                      child: RuleCard(rule: rule, onTap: () => context.push(RoutePaths.ruleDetailsPath(rule.id))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}
