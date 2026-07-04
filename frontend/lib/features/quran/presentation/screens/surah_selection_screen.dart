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
  String _query      = '';
  int    _filterIndex = 0; // 0=All, 1=Recent, 2=Favourites

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<SurahListCubit, ListState<Surah>>(
          builder: (context, state) {
            if (state.status == ListStatus.loading) {
              return const ShimmerListPlaceholder(itemCount: 8);
            }
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

            return Column(children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Explore',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        Text('${all.length} Surahs of the Holy Quran',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${all.length} Surahs',
                        style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ]),
              ),

              // ── Search ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, meaning or number…',
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),

              // ── Filter tabs ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  _FilterTab(
                      label: 'All',
                      isActive: _filterIndex == 0,
                      onTap: () => setState(() => _filterIndex = 0)),
                  const SizedBox(width: 24),
                  _FilterTab(
                      label: 'Recent',
                      isActive: _filterIndex == 1,
                      onTap: () => setState(() => _filterIndex = 1)),
                  const SizedBox(width: 24),
                  _FilterTab(
                      label: 'Favourites',
                      isActive: _filterIndex == 2,
                      onTap: () => setState(() => _filterIndex = 2)),
                ]),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.divider),

              // ── List ────────────────────────────────────────────────
              Expanded(child: _buildContent(context, all)),
            ]);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Surah> all) {
    switch (_filterIndex) {
      case 1:
        return _RecentTab(all: all);
      case 2:
        final favs = all.where((s) => s.isBookmarked).toList();
        return favs.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.bookmark_border_rounded,
                title: 'No favourites yet',
                message:
                    'Bookmark a surah from its details page to find it here.')
            : _SurahList(surahs: favs);
      default: // All tab with search
        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? all
            : all
                .where((s) =>
                    s.nameEnglish.toLowerCase().contains(q) ||
                    s.meaning.toLowerCase().contains(q) ||
                    s.nameArabic.contains(_query) ||
                    s.number.toString() == _query.trim())
                .toList();
        return filtered.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.search_off_rounded,
                title: 'No surah found',
                message: 'Try a different name or number.')
            : _SurahList(surahs: filtered);
    }
  }
}

// ── Surah list renderer ───────────────────────────────────────────────────────
class _SurahList extends StatelessWidget {
  final List<Surah> surahs;
  const _SurahList({required this.surahs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, 14,
          AppSpacing.screenPadding, AppSpacing.lg),
      itemCount: surahs.length,
      itemBuilder: (context, i) {
        final s = surahs[i];
        return StaggeredFadeSlide(
          index: i,
          child: SurahCard(
              surah: s,
              onTap: () =>
                  context.push(RoutePaths.surahDetailsPath(s.number))),
        );
      },
    );
  }
}

// ── Recent tab (uses session history — existing logic kept) ───────────────────
class _RecentTab extends StatelessWidget {
  final List<Surah> all;
  const _RecentTab({required this.all});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SessionResult>>(
      future: Services.session.getSessions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ShimmerListPlaceholder(itemCount: 4);
        }
        final seen   = <int>{};
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
            message:
                'Surahs you recite will appear here for quick access.',
          );
        }
        return _SurahList(surahs: recent);
      },
    );
  }
}

// ── Filter tab ────────────────────────────────────────────────────────────────
class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FilterTab(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 2,
          width: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.success : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]),
    );
  }
}
