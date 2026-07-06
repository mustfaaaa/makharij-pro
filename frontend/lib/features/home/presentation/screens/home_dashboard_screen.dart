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
import '../../../../shared/widgets/hasanah/hasanah_card.dart';
import '../../../../shared/widgets/illustrations/open_mushaf_illustration.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/navigation/app_drawer.dart';
import '../../../../shared/widgets/refresh/islamic_refresh_indicator.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
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
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
            ),
          ),
        ),
        // ── Notification icon remains exactly as in original ──
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
            AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // ── Header: greeting + avatar ───────────────────────────────
            FutureBuilder<UserProfile>(
              future: Services.user.getCurrentUser(),
              builder: (context, snap) {
                final user = snap.data;
                if (user == null) return const ShimmerBox(height: 58);
                final first = user.name.split(' ').first;
                final initial = first.isNotEmpty ? first[0].toUpperCase() : 'U';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assalamu Alaikum,',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          first,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Week-day tracker ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: AppTheme.cardDecoration(),
              child: Row(
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
                    bg = AppColors.successLight;
                    fg = AppColors.success;
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: bg,
                          shape: BoxShape.circle,
                          border: (!isDone && !isToday)
                              ? Border.all(color: AppColors.divider)
                              : null,
                        ),
                        child: Center(
                          child: isDone && !isToday
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: AppColors.success,
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
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── Hasanah counter ──────────────────────────────────────────
            BlocBuilder<HasanahCubit, int>(
              builder: (context, hasanahCount) => HasanahCard(count: hasanahCount),
            ),
            const SizedBox(height: 18),

            // ── Start Reading card ──────────────────────────────────────
            GestureDetector(
              onTap: () => context.go(RoutePaths.quran),
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
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                            'Explore all 114 Surahs →',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Open Library',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
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
            ),
            const SizedBox(height: 16),

            // ── Goal card (Continue Recitation — existing BLoC) ─────────
            BlocBuilder<SurahListCubit, ListState<Surah>>(
              builder: (context, state) {
                if (state.items.isEmpty) return const ShimmerBox(height: 100);
                final surah = state.items[state.items.length > 1 ? 1 : 0];
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Goal',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              surah.lastScore != null
                                  ? '${surah.lastScore!.round()}%'
                                  : '0%',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${surah.nameEnglish}  |  ${surah.ayahCount} Ayat',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (surah.lastScore ?? 0) / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.push(
                            RoutePaths.recitationPath(surah.number),
                          ),
                          child: const Text('Continue Reading'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            // ── Quick Access Surahs ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Access',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_quickSurahs.length} Surahs',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
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
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Ayah of the Day ─────────────────────────────────────────
            const SectionHeader(title: 'Ayah of the Day'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ayah of the Day',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ayah.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.arabicVerse(
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '"${ayah.text}"',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '[${ayah.ref}]',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Invite card ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite to MakharijPro',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share & help others perfect their recitation',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 9,
                            ),
                          ),
                          child: const Text(
                            'Share Now',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.primary,
                    size: 52,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Recent Sessions (existing BLoC — kept intact) ───────────
            SectionHeader(
              title: 'Recent Sessions',
              actionLabel: 'See all',
              onActionTap: () => context.push(RoutePaths.statistics),
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
                        index: i,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _AyahData {
  final String arabic, text, ref;
  const _AyahData(this.arabic, this.text, this.ref);
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 4)],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
