import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../core/base_list_cubit.dart';
import '../../../../models/session_result.dart';
import '../../../../models/surah.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/recent_session_card.dart';
import '../../../../shared/widgets/cards/section_card.dart';
import '../../../../shared/widgets/hasanah/hasanah_card.dart';
import '../../../../shared/widgets/illustrations/open_mushaf_illustration.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/navigation/app_drawer.dart';
import '../../../../shared/widgets/refresh/islamic_refresh_indicator.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../progress/presentation/bloc/sessions_cubit.dart';
import '../../../quran/presentation/bloc/surah_list_cubit.dart';

// ── Mock ayahs of the day (rotates by weekday) ────────────────────────────────
const _ayahs = [
  _AyahData(
    'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
    'For indeed, with hardship will be ease.',
    'Al-Inshirah 94:5',
  ),
  _AyahData(
    'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
    'And whoever relies upon Allah — then He is sufficient for him.',
    'At-Talaq 65:3',
  ),
  _AyahData(
    'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    'Indeed, Allah is with the patient.',
    'Al-Baqarah 2:153',
  ),
  _AyahData(
    'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
    'Sufficient for us is Allah, and He is the best disposer of affairs.',
    'Al-Imran 3:173',
  ),
  _AyahData(
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
    'Our Lord, give us good in this world and good in the Hereafter.',
    'Al-Baqarah 2:201',
  ),
  _AyahData(
    'وَبَشِّرِ الصَّابِرِينَ',
    'And give good tidings to the patient.',
    'Al-Baqarah 2:155',
  ),
  _AyahData(
    'إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ',
    'Indeed, the patient will be given their reward without account.',
    'Az-Zumar 39:10',
  ),
];

// Quick-access important surahs
const _quickSurahs = [
  (num: 73, name: 'Al-Muzzammil'),
  (num: 67, name: 'Al-Mulk'),
  (num: 36, name: 'Ya-Sin'),
  (num: 55, name: 'Ar-Rahman'),
  (num: 56, name: "Al-Waqi'ah"),
  (num: 32, name: 'As-Sajdah'),
  (num: 18, name: 'Al-Kahf'),
  (num: 112, name: 'Al-Ikhlas'),
];

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SurahListCubit()),
        BlocProvider(create: (_) => SessionsCubit()),
      ],
      child: const _HomeDashboardView(),
    );
  }
}

class _HomeDashboardView extends StatelessWidget {
  const _HomeDashboardView();

  @override
  Widget build(BuildContext context) {
    final ayah = _ayahs[DateTime.now().weekday % _ayahs.length];
    final today = DateTime.now().weekday; // 1=Mon … 7=Sun
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const doneDays = {1, 2}; // mock: Mon & Tue completed

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Frosted "liquid glass" bar — lets the scrolling content behind it
        // (see extendBodyBehindAppBar) show through, blurred.
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                border: Border(
                  bottom: BorderSide(color: AppColors.glassBorder),
                ),
              ),
            ),
          ),
        ),
        actions: [
          AppIconButton(
            icon: Icons.search,
            onPressed: () => context.push(RoutePaths.search),
          ),
          const SizedBox(width: 8),
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            onPressed: () => context.push(RoutePaths.notifications),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        title: Text(
          'MakharijPro AI',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: IslamicRefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<SurahListCubit>().load(),
          context.read<SessionsCubit>().load(),
        ]),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            kToolbarHeight + MediaQuery.of(context).padding.top + 16,
            20,
            AppSpacing.bottomNavClearance +
                MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // ── Header: greeting + avatar ───────────────────────────────
            const StaggeredFadeSlide(index: 0, child: _GreetingHeader()),
            const SizedBox(height: 20),

            // ── Week tracker ────────────────────────────────────────────
            StaggeredFadeSlide(
              index: 1,
              child: SectionCard(
                icon: Icons.calendar_month_rounded,
                title: 'This Week',
                subtitle: '${doneDays.length} of 7 days practised',
                child: _WeekTracker(
                  today: today,
                  doneDays: doneDays,
                  dayLabels: dayLabels,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Hasanah counter ─────────────────────────────────────────
            StaggeredFadeSlide(
              index: 2,
              child: BlocBuilder<HasanahCubit, int>(
                builder: (context, hasanahCount) =>
                    HasanahCard(count: hasanahCount),
              ),
            ),
            const SizedBox(height: 16),

            // ── Start Reading (hero) ────────────────────────────────────
            StaggeredFadeSlide(
              index: 3,
              child: _StartReadingCard(
                onTap: () => context.go(RoutePaths.quran),
              ),
            ),
            const SizedBox(height: 16),

            // ── Daily Goal (Continue Recitation) ────────────────────────
            StaggeredFadeSlide(
              index: 4,
              child: BlocBuilder<SurahListCubit, ListState<Surah>>(
                builder: (context, state) {
                  if (state.items.isEmpty) {
                    return const ShimmerBox(height: 120);
                  }
                  final surah = state.items[state.items.length > 1 ? 1 : 0];
                  final score = surah.lastScore ?? 0;
                  return SectionCard(
                    icon: Icons.flag_rounded,
                    title: 'Daily Goal',
                    subtitle: '${surah.nameEnglish} · ${surah.ayahCount} Ayat',
                    trailing: _Pill(label: '${score.round()}%'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: score / 100,
                            minHeight: 8,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push(
                              RoutePaths.recitationPath(surah.number),
                            ),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: const Text('Continue Reading'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── Quick Access ────────────────────────────────────────────
            StaggeredFadeSlide(
              index: 5,
              child: SectionCard(
                icon: Icons.bolt_rounded,
                title: 'Quick Access',
                trailing: Text(
                  '${_quickSurahs.length} Surahs',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _quickSurahs
                      .map(
                        (s) => _SurahChip(
                          name: s.name,
                          onTap: () =>
                              context.push(RoutePaths.recitationPath(s.num)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Ayah of the Day ─────────────────────────────────────────
            StaggeredFadeSlide(
              index: 6,
              child: SectionCard(
                icon: Icons.format_quote_rounded,
                title: 'Ayah of the Day',
                accent: AppColors.accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ayah.arabic,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabicVerse(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '“${ayah.text}”',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ayah.ref,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Invite ──────────────────────────────────────────────────
            StaggeredFadeSlide(
              index: 7,
              child: SectionCard(
                icon: Icons.card_giftcard_rounded,
                title: 'Invite friends',
                subtitle: 'Share MakharijPro and help others',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text(
                      'Share Now',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Recent Sessions ─────────────────────────────────────────
            StaggeredFadeSlide(
              index: 8,
              child: SectionHeader(
                title: 'Recent Sessions',
                actionLabel: 'See all',
                onActionTap: () => context.push(RoutePaths.statistics),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            BlocBuilder<SessionsCubit, ListState<SessionResult>>(
              builder: (context, state) {
                if (state.status == ListStatus.loading) {
                  return const ShimmerListPlaceholder(
                    itemCount: 3,
                    itemHeight: 64,
                  );
                }
                final sessions = state.items.take(3).toList();
                return Column(
                  children: [
                    for (int i = 0; i < sessions.length; i++)
                      StaggeredFadeSlide(
                        index: 9 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: RecentSessionCard(
                            session: sessions[i],
                            onTap: () => context.push(
                              RoutePaths.detailedFeedbackPath(sessions[i].id),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: Services.user.getCurrentUser(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return const ShimmerBox(height: 58);
        final first = user.name.split(' ').first;
        final initial = first.isNotEmpty ? first[0].toUpperCase() : 'U';
        return Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assalamu Alaikum,',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(first, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Week tracker row ─────────────────────────────────────────────────────────

class _WeekTracker extends StatelessWidget {
  final int today;
  final Set<int> doneDays;
  final List<String> dayLabels;

  const _WeekTracker({
    required this.today,
    required this.doneDays,
    required this.dayLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayNum = i + 1;
        final isToday = dayNum == today;
        final isDone = doneDays.contains(dayNum);
        Color bg = Colors.transparent;
        Color fg = AppColors.textSecondary;
        if (isToday) {
          bg = AppColors.primary;
          fg = Colors.white;
        } else if (isDone) {
          bg = AppColors.primarySurface;
          fg = AppColors.primaryDark;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: (!isDone && !isToday)
                    ? Border.all(color: AppColors.divider)
                    : null,
              ),
              alignment: Alignment.center,
              child: isDone && !isToday
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.primaryDark,
                    )
                  : Text(
                      dayLabels[i],
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Start Reading hero card ──────────────────────────────────────────────────

class _StartReadingCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StartReadingCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start Reading',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Explore all 114 Surahs',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Library',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.primaryDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const OpenMushafIllustration(size: 76),
          ],
        ),
      ),
    );
  }
}

// ── Small pieces ─────────────────────────────────────────────────────────────

class _AyahData {
  final String arabic, text, ref;
  const _AyahData(this.arabic, this.text, this.ref);
}

/// Small rounded stat pill (e.g. the score chip on the Daily Goal card).
class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SurahChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _SurahChip({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
