import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../core/utils/current_user_display.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/surah.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../shared/ui/list_row.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/feedback/app_dialogs.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// Profile: who you are, the hasanah your recitations have earned, the surahs
/// you are working towards, and everything else a reciter reaches less often.
///
/// Everything shown is real: name, email and join date from Firestore and
/// Firebase Auth, target surahs from the profile document, hasanah from its
/// running total. The fixed "Intermediate reciter", "15 saved" and "Daily at
/// 7:00 PM" labels it used to show are gone, and a Firestore failure now says
/// so instead of leaving a blank page.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Stream<UserProfile> _profile = _watch();

  Stream<UserProfile> _watch() {
    try {
      return Services.user.watchCurrentUser();
    } catch (e) {
      return Stream.error(e);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Sign out?',
      message: 'Your recitations and progress stay saved to your account.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await Services.auth.signOut();
    } catch (_) {
      // Signing out of a local session cannot meaningfully fail.
    }
    if (mounted) context.go(RoutePaths.welcome);
  }

  Future<void> _addTargetSurah(UserProfile? profile) async {
    final surahs = await Services.surah.getSurahs();
    final current = profile?.targetSurahs ?? const [];
    final choices = surahs.where((s) => !current.contains(s.nameEnglish)).toList();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Surah>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.sm),
                child: Text('Add a surah to work towards', style: Theme.of(sheetContext).textTheme.headlineSmall),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: choices.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: RosetteBadge(
                      size: 34,
                      fill: AppColors.goldWash,
                      child: Text('${choices[i].number}', style: AppTypography.numeric(fontSize: 11, color: AppColors.goldInk)),
                    ),
                    title: Text(choices[i].nameEnglish),
                    subtitle: Text(choices[i].meaning),
                    trailing: Text(choices[i].nameArabic,
                        textDirection: TextDirection.rtl, style: AppTypography.arabicWord(fontSize: 20)),
                    onTap: () => Navigator.pop(context, choices[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await Services.user.updateTargetSurahs([...current, chosen.nameEnglish]);
  }

  Future<void> _removeTargetSurah(String name, List<String> current) async {
    await Services.user.updateTargetSurahs(current.where((s) => s != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<UserProfile>(
        stream: _profile,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final failed = snapshot.hasError;
          final targetSurahs = profile?.targetSurahs ?? const <String>[];

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
            children: [
              _Header(profile: profile, onSettings: () => context.push(RoutePaths.settings)),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (failed)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: AppRadii.mdRadius,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Your profile details could not load.',
                                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
                            ),
                            TextButton(onPressed: () => setState(() => _profile = _watch()), child: const Text('Retry')),
                          ],
                        ),
                      ),
                    BlocBuilder<HasanahCubit, int>(
                      builder: (context, hasanah) => Row(
                        children: [
                          RosetteBadge(
                            size: 44,
                            fill: AppColors.goldWash,
                            child: Icon(Icons.star_rounded, size: 18, color: AppColors.goldInk),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${formatWithCommas(hasanah)} hasanah',
                                    style: AppTypography.numeric(fontSize: 20, color: AppColors.goldInk)),
                                Text('Ten for every letter you have recited in the app',
                                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'Surahs you are working towards',
                      actionLabel: 'Add',
                      onActionTap: failed ? null : () => _addTargetSurah(profile),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (targetSurahs.isEmpty)
                      Text('Add the surahs you want to recite well. They stay here as a reminder.',
                          style: textTheme.bodyMedium)
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final name in targetSurahs)
                            InputChip(
                              label: Text(name),
                              onPressed: () {
                                final number = _numberFor(name);
                                if (number != null) context.push(RoutePaths.surahDetailsPath(number));
                              },
                              onDeleted: () => _removeTargetSurah(name, targetSurahs),
                              deleteButtonTooltipMessage: 'Remove $name',
                            ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Practice and library'),
                    const SizedBox(height: AppSpacing.xs),
                    ListRow(
                      icon: Icons.checklist_rounded,
                      title: 'Practice plan',
                      subtitle: 'Built from the words you recite',
                      onTap: () => context.push(RoutePaths.practicePlan),
                    ),
                    ListRow(
                      icon: Icons.menu_book_rounded,
                      title: 'Tajweed rules',
                      subtitle: 'What each rule is, with examples from the Quran',
                      onTap: () => context.push(RoutePaths.tajweedRules),
                    ),
                    ListRow(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'Saved',
                      subtitle: 'Surahs and rules you bookmarked',
                      onTap: () => context.push(RoutePaths.bookmarks),
                    ),
                    ListRow(
                      icon: Icons.emoji_events_outlined,
                      title: 'Milestones',
                      onTap: () => context.push(RoutePaths.achievements),
                      showDivider: false,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Account and app'),
                    const SizedBox(height: AppSpacing.xs),
                    ListRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit profile',
                      onTap: () => context.push(RoutePaths.editProfile),
                    ),
                    ListRow(
                      icon: Icons.tune_rounded,
                      title: 'Settings',
                      subtitle: 'Appearance, reading, notifications',
                      onTap: () => context.push(RoutePaths.settings),
                    ),
                    ListRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help and questions',
                      onTap: () => context.push(RoutePaths.helpFaq),
                    ),
                    ListRow(
                      icon: Icons.info_outline_rounded,
                      title: 'About MakharijPro',
                      onTap: () => context.push(RoutePaths.about),
                    ),
                    ListRow(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      destructive: true,
                      onTap: _signOut,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int? _numberFor(String name) => dummySurahs.where((s) => s.nameEnglish == name).firstOrNull?.number;
}

class _Header extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback onSettings;
  const _Header({required this.profile, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final name = profile == null ? greetingName(null) : _fullName(profile!);
    final email = profile?.email ?? currentUserEmail();
    final since = profile == null ? null : DateFormat('MMMM yyyy').format(profile!.joinedAt);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: GeometricPattern(color: AppColors.primary, opacity: 0.07, cellSize: 44),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.screenPadding, top + 8, 8, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Profile', style: textTheme.titleMedium?.copyWith(color: AppColors.onPrimarySurface)),
                  const Spacer(),
                  IconButton(tooltip: 'Settings', onPressed: onSettings, icon: const Icon(Icons.settings_outlined)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  RosetteBadge(
                    size: 76,
                    stroke: AppColors.gold,
                    fill: AppColors.surface,
                    child: Text(
                      name.isEmpty ? 'M' : name[0].toUpperCase(),
                      style: AppTypography.displayText(fontSize: 28, color: AppColors.goldInk, height: 1.1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.headlineMedium),
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        if (since != null)
                          Text('Reciting with MakharijPro since $since',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fullName(UserProfile p) {
    final first = greetingName(p);
    final full = p.name.trim();
    return full.startsWith(first) ? full : first;
  }
}
