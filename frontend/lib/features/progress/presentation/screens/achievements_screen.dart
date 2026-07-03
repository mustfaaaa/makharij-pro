import 'package:flutter/material.dart';

import '../../../../dummy/dummy_achievements.dart';
import '../../../../shared/widgets/cards/achievement_card.dart';
import '../../../../theme/app_spacing.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.92,
        ),
        itemCount: dummyAchievements.length,
        itemBuilder: (context, i) => AchievementCard(achievement: dummyAchievements[i]),
      ),
    );
  }
}
