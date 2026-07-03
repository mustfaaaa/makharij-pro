import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_surahs.dart';
import '../../../../dummy/dummy_tajweed_rules.dart';
import '../../../../models/surah.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/cards/rule_card.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../theme/app_spacing.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final List<Surah> surahResults = q.isEmpty ? [] : dummySurahs.where((s) => s.nameEnglish.toLowerCase().contains(q)).toList();
    final List<TajweedRule> ruleResults = q.isEmpty ? [] : dummyTajweedRules.where((r) => r.title.toLowerCase().contains(q)).toList();
    final hasResults = surahResults.isNotEmpty || ruleResults.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(hint: 'Search surahs, rules...', onChanged: (v) => setState(() => _query = v)),
        toolbarHeight: 68,
      ),
      body: q.isEmpty
          ? const EmptyStateWidget(icon: Icons.search_rounded, title: 'Search MakharijPro', message: 'Find surahs and Tajweed rules by name.')
          : !hasResults
              ? const EmptyStateWidget(icon: Icons.search_off_rounded, title: 'No results', message: 'Try a different search term.')
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    if (surahResults.isNotEmpty) ...[
                      Text('Surahs', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      ...surahResults.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: SurahCard(surah: s, onTap: () => context.push(RoutePaths.surahDetailsPath(s.number))),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (ruleResults.isNotEmpty) ...[
                      Text('Tajweed Rules', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      ...ruleResults.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: RuleCard(rule: r, onTap: () => context.push(RoutePaths.ruleDetailsPath(r.id))),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
