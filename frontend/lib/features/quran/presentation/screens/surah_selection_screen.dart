import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/session_result.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/surah_list_cubit.dart';

class SurahSelectionScreen extends StatelessWidget {
  const SurahSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SurahListCubit(),
      child: const _SurahSelectionView(),
    );
  }
}

class _SurahSelectionView extends StatefulWidget {
  const _SurahSelectionView();

  @override
  State<_SurahSelectionView> createState() => _SurahSelectionViewState();
}

class _SurahSelectionViewState extends State<_SurahSelectionView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select a Surah'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Recent'),
              Tab(text: 'Favourites'),
            ],
          ),
        ),
        body: BlocBuilder<SurahListCubit, ListState<Surah>>(
          builder: (context, state) {
            if (state.status == ListStatus.loading) return const ShimmerSurahList(itemCount: 7);
            if (state.status == ListStatus.error) {
              return ErrorStateWidget(
                message: state.errorMessage ?? 'Could not load surahs.',
                onRetry: () => context.read<SurahListCubit>().load(),
              );
            }
            final all = state.items;
            return TabBarView(
              children: [
                _AllTab(surahs: all, query: _query, onQuery: (v) => setState(() => _query = v)),
                _RecentTab(all: all),
                _FavouritesTab(favourites: all.where((s) => s.isBookmarked).toList()),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shared list renderer with the staggered entrance.
class _SurahList extends StatelessWidget {
  final List<Surah> surahs;
  const _SurahList({required this.surahs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.lg),
      itemCount: surahs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final surah = surahs[i];
        return StaggeredFadeSlide(
          index: i,
          child: SurahCard(surah: surah, onTap: () => context.push(RoutePaths.surahDetailsPath(surah.number))),
        );
      },
    );
  }
}

class _AllTab extends StatelessWidget {
  final List<Surah> surahs;
  final String query;
  final ValueChanged<String> onQuery;
  const _AllTab({required this.surahs, required this.query, required this.onQuery});

  @override
  Widget build(BuildContext context) {
    final filtered = surahs
        .where((s) => s.nameEnglish.toLowerCase().contains(query.toLowerCase()) || s.number.toString() == query)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, 0),
          child: AppSearchBar(hint: 'Search surah name or number', onChanged: onQuery),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateWidget(icon: Icons.search_off_rounded, title: 'No surah found', message: 'Try a different name or number.')
              : _SurahList(surahs: filtered),
        ),
      ],
    );
  }
}

class _RecentTab extends StatelessWidget {
  final List<Surah> all;
  const _RecentTab({required this.all});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SessionResult>>(
      future: Services.session.getSessions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const ShimmerSurahList(itemCount: 4);
        // Unique surahs in most-recent-first session order.
        final seen = <int>{};
        final recent = <Surah>[];
        for (final session in snapshot.data!) {
          if (seen.add(session.surahNumber)) {
            final match = all.where((s) => s.number == session.surahNumber);
            if (match.isNotEmpty) recent.add(match.first);
          }
        }
        if (recent.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history_rounded,
            title: 'No recent recitations',
            message: 'Surahs you recite will appear here for quick access.',
          );
        }
        return _SurahList(surahs: recent);
      },
    );
  }
}

class _FavouritesTab extends StatelessWidget {
  final List<Surah> favourites;
  const _FavouritesTab({required this.favourites});

  @override
  Widget build(BuildContext context) {
    if (favourites.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.bookmark_border_rounded,
        title: 'No favourites yet',
        message: 'Bookmark a surah from its details page to find it here.',
      );
    }
    return _SurahList(surahs: favourites);
  }
}
