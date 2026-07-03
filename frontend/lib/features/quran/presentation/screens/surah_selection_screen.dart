import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Select a Surah')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.sm),
            child: AppSearchBar(hint: 'Search surah name or number', onChanged: (v) => setState(() => _query = v)),
          ),
          Expanded(
            child: BlocBuilder<SurahListCubit, ListState<Surah>>(
              builder: (context, state) {
                if (state.status == ListStatus.loading) {
                  return const ShimmerListPlaceholder(itemCount: 6);
                }
                if (state.status == ListStatus.error) {
                  return ErrorStateWidget(
                    message: state.errorMessage ?? 'Could not load surahs.',
                    onRetry: () => context.read<SurahListCubit>().load(),
                  );
                }
                final filtered = state.items
                    .where((s) => s.nameEnglish.toLowerCase().contains(_query.toLowerCase()) || s.number.toString() == _query)
                    .toList();
                if (filtered.isEmpty) {
                  return const EmptyStateWidget(icon: Icons.search_off_rounded, title: 'No surah found', message: 'Try a different name or number.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final surah = filtered[i];
                    return StaggeredFadeSlide(
                      index: i,
                      child: SurahCard(surah: surah, onTap: () => context.push(RoutePaths.surahDetailsPath(surah.number))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
