import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../models/achievement.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/cards/achievement_card.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/achievements_cubit.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AchievementsCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Achievements')),
        body: BlocBuilder<AchievementsCubit, ListState<Achievement>>(
          builder: (context, state) {
            final columns = gridColumns(context);
            if (state.status == ListStatus.loading) {
              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: AppSpacing.sm, crossAxisSpacing: AppSpacing.sm, childAspectRatio: 0.92),
                itemCount: 6,
                itemBuilder: (context, i) => const ShimmerBox(height: double.infinity),
              );
            }
            if (state.status == ListStatus.error) {
              return ErrorStateWidget(message: state.errorMessage ?? 'Could not load achievements.', onRetry: () => context.read<AchievementsCubit>().load());
            }
            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: AppSpacing.sm, crossAxisSpacing: AppSpacing.sm, childAspectRatio: 0.92),
              itemCount: state.items.length,
              itemBuilder: (context, i) => StaggeredFadeSlide(index: i, child: AchievementCard(achievement: state.items[i])),
            );
          },
        ),
      ),
    );
  }
}
