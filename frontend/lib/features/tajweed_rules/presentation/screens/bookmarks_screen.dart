import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_surahs.dart';
import '../../../../dummy/dummy_tajweed_rules.dart';
import '../../../../models/surah.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/cards/rule_card.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../theme/app_spacing.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  late List<Surah> _surahs;
  late List<TajweedRule> _rules;

  @override
  void initState() {
    super.initState();
    _surahs = dummySurahs.where((s) => s.isBookmarked).toList();
    _rules = dummyTajweedRules.where((r) => r.isBookmarked).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _surahs.isEmpty && _rules.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: isEmpty
          ? const EmptyStateWidget(
              icon: Icons.bookmark_border_rounded,
              title: 'No bookmarks yet',
              message: 'Bookmark surahs and Tajweed rules to find them here quickly.',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                if (_surahs.isNotEmpty) ...[
                  Text('Surahs', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ..._surahs.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SurahCard(surah: s, onTap: () => context.push(RoutePaths.surahDetailsPath(s.number))),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_rules.isNotEmpty) ...[
                  Text('Tajweed Rules', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ..._rules.map(
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
