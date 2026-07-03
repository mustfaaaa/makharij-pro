import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_tajweed_rules.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/rule_card.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../theme/app_spacing.dart';

class TajweedRulesLibraryScreen extends StatefulWidget {
  const TajweedRulesLibraryScreen({super.key});

  @override
  State<TajweedRulesLibraryScreen> createState() => _TajweedRulesLibraryScreenState();
}

class _TajweedRulesLibraryScreenState extends State<TajweedRulesLibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = dummyTajweedRules.where((r) => r.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tajweed Rules'),
        actions: [
          AppIconButton(icon: Icons.bookmark_outline, onPressed: () => context.push(RoutePaths.bookmarks)),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.sm),
            child: AppSearchBar(hint: 'Search rules', onChanged: (v) => setState(() => _query = v)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final rule = filtered[i];
                return RuleCard(rule: rule, onTap: () => context.push(RoutePaths.ruleDetailsPath(rule.id)));
              },
            ),
          ),
        ],
      ),
    );
  }
}
