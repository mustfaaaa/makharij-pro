import 'package:flutter/material.dart';

import '../dummy/dummy_achievements.dart';
import '../dummy/dummy_sessions.dart';
import '../dummy/dummy_surahs.dart';
import '../dummy/dummy_tajweed_rules.dart';
import '../shared/widgets/buttons/app_icon_button.dart';
import '../shared/widgets/buttons/outlined_app_button.dart';
import '../shared/widgets/buttons/primary_button.dart';
import '../shared/widgets/buttons/secondary_button.dart';
import '../shared/widgets/cards/achievement_card.dart';
import '../shared/widgets/cards/progress_card.dart';
import '../shared/widgets/cards/recent_session_card.dart';
import '../shared/widgets/cards/rule_card.dart';
import '../shared/widgets/cards/statistics_card.dart';
import '../shared/widgets/cards/surah_card.dart';
import '../shared/widgets/feedback/app_bottom_sheet.dart';
import '../shared/widgets/feedback/app_dialogs.dart';
import '../shared/widgets/feedback/app_snackbar.dart';
import '../shared/widgets/inputs/app_search_bar.dart';
import '../shared/widgets/inputs/custom_text_field.dart';
import '../shared/widgets/loading/app_loading_indicator.dart';
import '../shared/widgets/loading/shimmer_placeholder.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/states/empty_state_widget.dart';
import '../shared/widgets/states/error_state_widget.dart';
import '../shared/widgets/tiles/profile_tile.dart';
import '../shared/widgets/tiles/settings_tile.dart';
import '../theme/app_spacing.dart';

/// Internal reference screen showing every reusable widget in one place.
/// Not part of the user-facing navigation graph.
class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Component Gallery')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SectionHeader(title: 'Buttons'),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(label: 'Primary Button', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Secondary Button', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          OutlinedAppButton(label: 'Outlined Button', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [AppIconButton(icon: Icons.favorite_border, onPressed: () {})]),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Inputs'),
          const SizedBox(height: AppSpacing.sm),
          const CustomTextField(label: 'Email', hint: 'you@example.com'),
          const SizedBox(height: AppSpacing.sm),
          const AppSearchBar(),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Cards'),
          const SizedBox(height: AppSpacing.sm),
          SurahCard(surah: dummySurahs.first),
          const SizedBox(height: AppSpacing.sm),
          RecentSessionCard(session: dummySessions.first),
          const SizedBox(height: AppSpacing.sm),
          RuleCard(rule: dummyTajweedRules.first),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: [
              Expanded(child: ProgressCard(label: 'Accuracy', value: '86%', icon: Icons.percent, trend: '+4%')),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: ProgressCard(label: 'Streak', value: '12 days', icon: Icons.local_fire_department)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const StatisticsCard(label: 'Makhraj', percentage: 82),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 160,
            child: AchievementCard(achievement: dummyAchievements.first),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Tiles'),
          const ProfileTile(name: 'Hammad Fareed', subtitle: 'Intermediate learner'),
          SettingsTile(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Feedback'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedAppButton(
                label: 'Show Dialog',
                fullWidth: false,
                onPressed: () => AppDialogs.confirm(context, title: 'Delete session?', message: 'This cannot be undone.'),
              ),
              OutlinedAppButton(
                label: 'Show Sheet',
                fullWidth: false,
                onPressed: () => AppBottomSheet.show(context, title: 'Options', child: const Text('Sheet content')),
              ),
              OutlinedAppButton(
                label: 'Show Snackbar',
                fullWidth: false,
                onPressed: () => AppSnackbar.show(context, 'Saved successfully'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Loading & Shimmer'),
          const SizedBox(height: AppSpacing.sm),
          const AppLoadingIndicator(message: 'Loading...'),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(height: 60),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Empty / Error States'),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            height: 220,
            child: EmptyStateWidget(icon: Icons.bookmark_border, title: 'No bookmarks yet', message: 'Save rules and surahs to find them here.'),
          ),
          const SizedBox(
            height: 220,
            child: ErrorStateWidget(message: 'Could not load your data.'),
          ),
        ],
      ),
    );
  }
}
