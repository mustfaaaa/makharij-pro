import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/surah.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../../shared/widgets/cards/rule_card.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../theme/app_spacing.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  late Future<(List<Surah>, List<TajweedRule>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Surah>, List<TajweedRule>)> _load() async {
    final surahs = await Services.surah.getSurahs();
    final rules = await Services.tajweedRule.getRules();
    return (surahs.where((s) => s.isBookmarked).toList(), rules.where((r) => r.isBookmarked).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: ResponsiveCenter(child: AsyncView<(List<Surah>, List<TajweedRule>)>(
        future: _future,
        errorMessage: 'Could not load your bookmarks.',
        onRetry: () => setState(() => _future = _load()),
        loading: const ShimmerSurahList(itemCount: 4),
        builder: (context, data) {
          final (surahs, rules) = data;
          if (surahs.isEmpty && rules.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.bookmark_border_rounded,
              title: 'No bookmarks yet',
              message: 'Bookmark surahs and Tajweed rules to find them here quickly.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              if (surahs.isNotEmpty) ...[
                Text('Surahs', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ...surahs.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SurahCard(surah: s, onTap: () => context.push(RoutePaths.surahDetailsPath(s.number))),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (rules.isNotEmpty) ...[
                Text('Tajweed Rules', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ...rules.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: RuleCard(rule: r, onTap: () => context.push(RoutePaths.ruleDetailsPath(r.id))),
                  ),
                ),
              ],
            ],
          );
        },
      )),
    );
  }
}
