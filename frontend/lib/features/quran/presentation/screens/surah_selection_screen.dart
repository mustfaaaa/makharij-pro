import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_surahs.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../theme/app_spacing.dart';

class SurahSelectionScreen extends StatefulWidget {
  const SurahSelectionScreen({super.key});

  @override
  State<SurahSelectionScreen> createState() => _SurahSelectionScreenState();
}

class _SurahSelectionScreenState extends State<SurahSelectionScreen> {
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulates the future backend fetch delay so the shimmer skeleton
    // has a real place to appear, even while the data source is dummy.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = dummySurahs
        .where((s) => s.nameEnglish.toLowerCase().contains(_query.toLowerCase()) || s.number.toString() == _query)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select a Surah')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.sm),
            child: AppSearchBar(hint: 'Search surah name or number', onChanged: (v) => setState(() => _query = v)),
          ),
          Expanded(
            child: _isLoading
                ? const ShimmerListPlaceholder(itemCount: 6)
                : filtered.isEmpty
                    ? const EmptyStateWidget(icon: Icons.search_off_rounded, title: 'No surah found', message: 'Try a different name or number.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final surah = filtered[i];
                          return SurahCard(surah: surah, onTap: () => context.push(RoutePaths.surahDetailsPath(surah.number)));
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
