import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../core/utils/current_user_display.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/ayah.dart';
import '../../../../models/practice_plan_item.dart';
import '../../../../models/progress_summary.dart';
import '../../../../models/session_result.dart';
import '../../../../models/surah.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/preferences_service.dart';
import '../../../../services/quran_text_repository.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../shared/ui/tajweed_marks.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/navigation/app_drawer.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_shadows.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';

/// Surahs people most often return to. Links, not data: each opens the real
/// surah in the reader.
const _oftenRecited = [1, 18, 36, 55, 56, 67, 73, 112];

/// Short, well-known ayat to reflect on, by reference. The text always comes
/// from the bundled Quran; one is picked by the day of the year, so it
/// genuinely changes daily and is the same for everyone on a given day.
const _reflectionAyat = [
  (2, 152), (2, 153), (2, 186), (2, 201), (3, 8), (3, 139), (7, 56), (13, 28),
  (14, 7), (16, 128), (20, 114), (25, 74), (29, 69), (33, 41), (39, 53), (40, 60),
  (49, 13), (50, 16), (55, 13), (57, 4), (59, 22), (65, 3), (93, 5), (94, 5), (94, 6),
];

Surah? _surah(int number) => dummySurahs.where((s) => s.number == number).firstOrNull;

/// Home: the reciter's own space. It answers "where was I, and what should I
/// do next?" in one glance, with nothing on it that isn't theirs:
///
///  * the last recitation, with its real ayah range, from `/sessions`;
///  * the rule they most need to practise, from `/practice-plan`, with one of
///    their own flagged words as the example;
///  * where they stopped reading, from this device;
///  * streak, sessions and hasanah, from `/progress` and Firestore;
///  * an ayah to reflect on, chosen by date from the bundled text.
///
/// It used to open on hardcoded prayer times, a fixed "last read", and an
/// invented daily goal and streak; all of that is gone.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Future<List<SessionResult>> _sessions;
  late Future<List<PracticePlanItem>> _plan;
  late Future<ProgressSummary> _summary;
  late Future<UserProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _sessions = Services.session.getSessions();
    _plan = Services.practicePlan.getPlan();
    _summary = Services.progress.getSummary();
    _profile = _fetchProfile();
  }

  Future<UserProfile?> _fetchProfile() async {
    try {
      return await Services.user.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _sessions.then((_) {}, onError: (_) {}),
      _summary.then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final lastRead = Services.prefs.lastRead;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HeaderWithContinue(profile: _profile, sessions: _sessions),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, AppSpacing.xl, AppSpacing.screenPadding, AppSpacing.bottomNavClearance),
              sliver: SliverList.list(children: [
                _PractiseSection(plan: _plan),
                const SizedBox(height: AppSpacing.xl),
                _ReadSection(lastRead: lastRead),
                const SizedBox(height: AppSpacing.xl),
                const _RattilPanel(),
                const SizedBox(height: AppSpacing.xl),
                _ProgressGlance(summary: _summary),
                const _ReflectAyah(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header: photograph, greeting, Hijri date, and the continue block ─────────

class _HeaderWithContinue extends StatelessWidget {
  final Future<UserProfile?> profile;
  final Future<List<SessionResult>> sessions;
  const _HeaderWithContinue({required this.profile, required this.sessions});

  static const _overlap = 64.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final headerHeight = 290.0 + top;
    final scrim = AppColors.photoScrim;
    final now = DateTime.now();

    return Stack(
      children: [
        SizedBox(
          height: headerHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AppPhoto(AppPhotos.homeRehal, alignment: Alignment(-0.1, 0.1)),
              // Dark enough at the top for the controls, deepest behind the
              // greeting, then a short melt into the page under the block that
              // overlaps it -- so ivory text never lands on parchment.
              // A side scrim under the greeting: the window light sits on the
              // left of this photograph.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.75],
                    colors: [scrim.withValues(alpha: 0.5), scrim.withValues(alpha: 0.0)],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.32, 0.72, 0.86, 1.0],
                    colors: [
                      scrim.withValues(alpha: 0.55),
                      scrim.withValues(alpha: 0.18),
                      scrim.withValues(alpha: 0.62),
                      scrim.withValues(alpha: 0.72),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: top + 4,
                left: 8,
                right: 12,
                child: Row(
                  children: [
                    Builder(
                      builder: (context) => _GlassButton(
                        icon: Icons.menu_rounded,
                        label: 'Open menu',
                        onTap: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const Spacer(),
                    _GlassButton(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () => context.push(RoutePaths.notifications),
                    ),
                    const SizedBox(width: 4),
                    _AvatarButton(profile: profile),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                bottom: _overlap + 18,
                child: FutureBuilder<UserProfile?>(
                  future: profile,
                  builder: (context, snap) {
                    final name = greetingName(snap.data);
                    return Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assalamu alaikum,',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textOnPhotoSecondary,
                                  )),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.displayText(fontSize: 34, color: AppColors.textOnPhoto),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${HijriDate.format(now)} AH',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textOnPhotoSecondary,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, headerHeight - _overlap, AppSpacing.screenPadding, 0),
          child: _ContinueBlock(sessions: sessions),
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.photoScrim.withValues(alpha: 0.32),
        foregroundColor: AppColors.textOnPhoto,
        side: BorderSide(color: AppColors.textOnPhoto.withValues(alpha: 0.18)),
        fixedSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final Future<UserProfile?> profile;
  const _AvatarButton({required this.profile});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: profile,
      builder: (context, snap) {
        final name = greetingName(snap.data);
        return Semantics(
          button: true,
          label: 'Your profile',
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => context.go(RoutePaths.profile),
            radius: 26,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldWash,
                border: Border.all(color: AppColors.gold, width: 1.2),
              ),
              child: Text(
                name.isEmpty ? 'M' : name[0].toUpperCase(),
                style: AppTypography.displayText(fontSize: 20, color: AppColors.goldInk, height: 1.1),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Continue your recitation ─────────────────────────────────────────────────

class _ContinueBlock extends StatelessWidget {
  final Future<List<SessionResult>> sessions;
  const _ContinueBlock({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: AppRadii.lgRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.lg,
      ),
      child: FutureBuilder<List<SessionResult>>(
        future: sessions,
        builder: (context, snap) {
          final Widget child;
          if (snap.connectionState != ConnectionState.done) {
            child = const _ContinueSkeleton();
          } else if (snap.hasError) {
            child = const _ContinueFresh(
              note: 'Your recent recitations could not be loaded. You can still start one.',
            );
          } else if ((snap.data ?? const []).isEmpty) {
            child = const _ContinueFresh();
          } else {
            child = _ContinueLast(session: snap.data!.first);
          }
          return AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(snap.connectionState == ConnectionState.done), child: child),
          );
        },
      ),
    );
  }
}

class _ContinueSkeleton extends StatelessWidget {
  const _ContinueSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: 150, height: 12),
        SizedBox(height: 12),
        ShimmerBox(width: 190, height: 24),
        SizedBox(height: 10),
        ShimmerBox(width: 230, height: 12),
        SizedBox(height: 18),
        ShimmerBox(height: 52, borderRadius: BorderRadius.all(Radius.circular(AppRadii.md))),
      ],
    );
  }
}

class _ContinueLast extends StatelessWidget {
  final SessionResult session;
  const _ContinueLast({required this.session});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final surah = _surah(session.surahNumber);
    final from = session.fromAyah;
    // An end in a later surah is not an ayah of this one.
    final to = session.toAyahInOwnSurah;
    final range = from == null
        ? null
        : to == null
            ? 'From ayah $from'
            : (to == from ? 'Ayah $from' : 'Ayahs $from–$to');
    final matched = session.totalWords > 0
        ? '${(session.wordsRecited - session.errors.length).clamp(0, session.wordsRecited)} of ${session.wordsRecited} words matched'
        : null;
    final meta = [?range, ?matched, relativeTime(session.dateTime)].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Continue your recitation', style: textTheme.labelMedium?.copyWith(color: AppColors.goldInk)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                surah?.nameEnglish ?? session.surahName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium,
              ),
            ),
            if (surah != null)
              Text(surah.nameArabic,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.arabicWord(fontSize: 24, color: AppColors.goldInk, weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Text(meta, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push(RoutePaths.surahDetailsPath(session.surahNumber, from: from, to: to)),
                icon: const Icon(Icons.mic_rounded, size: 20),
                label: const Text('Recite again'),
              ),
            ),
            if (session.errors.isNotEmpty) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => context.push(RoutePaths.detailedFeedbackPath(session.id)),
                child: Text('Review ${session.errors.length}'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ContinueFresh extends StatelessWidget {
  final String? note;
  const _ContinueFresh({this.note});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Begin your first recitation', style: textTheme.labelMedium?.copyWith(color: AppColors.goldInk)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: Text('Al-Fatihah', style: textTheme.headlineMedium)),
            Text('الفاتحة',
                textDirection: TextDirection.rtl,
                style: AppTypography.arabicWord(fontSize: 24, color: AppColors.goldInk, weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          note ?? 'Recite and watch each word fill in as it is heard. When you stop, you see what to review.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(RoutePaths.surahDetailsPath(1)),
            icon: const Icon(Icons.mic_rounded, size: 20),
            label: const Text('Start reciting'),
          ),
        ),
      ],
    );
  }
}

// ── Practise your Tajweed ────────────────────────────────────────────────────

class _PractiseSection extends StatelessWidget {
  final Future<List<PracticePlanItem>> plan;
  const _PractiseSection({required this.plan});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PracticePlanItem>>(
      future: plan,
      builder: (context, snap) {
        // Only rules the reciter's own recitations actually flagged. A new
        // user's "beginner" plan lists every rule at zero, which says nothing
        // about them, so it is not shown here.
        final items = (snap.data ?? const <PracticePlanItem>[])
            .where((i) => (i.errorCount ?? 0) > 0 && i.rule.isNotEmpty)
            .toList();
        if (snap.connectionState != ConnectionState.done || items.isEmpty) return const SizedBox.shrink();
        final item = items.first;
        final rule = tajweedErrorTypeFromId(item.rule);
        final example = item.examples.where((e) => e.surahNumber != null && e.ayahNumber != null).firstOrNull;
        final color = rule == null ? AppColors.primaryDark : TajweedRuleStyle.color(rule);
        final textTheme = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Practise your Tajweed',
              subtitle: 'From the words you recited',
              actionLabel: items.length > 1 ? 'Your plan' : null,
              onActionTap: () => context.push(RoutePaths.practicePlan),
            ),
            const SizedBox(height: AppSpacing.md),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadii.lgRadius,
                onTap: example == null
                    ? () => context.push(RoutePaths.practicePlan)
                    : () => context.push(RoutePaths.surahDetailsPath(example.surahNumber!,
                        from: example.ayahNumber, to: example.ayahNumber, ayah: example.ayahNumber)),
                child: Ink(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.lgRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (rule != null) ...[
                                  RuleShapeSwatch(rule: rule),
                                  const SizedBox(width: 10),
                                ],
                                Flexible(
                                  child: Text(rule?.label ?? item.tajweedRule,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.titleMedium?.copyWith(color: color)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                                'Flagged on ${item.errorCount} word${item.errorCount == 1 ? '' : 's'} in your recent recitations',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            if (example != null) ...[
                              const SizedBox(height: 10),
                              Text('Practise it in ${_surah(example.surahNumber!)?.nameEnglish ?? 'Surah ${example.surahNumber}'} ${example.surahNumber}:${example.ayahNumber}',
                                  style: textTheme.labelMedium?.copyWith(color: AppColors.primaryDark)),
                            ],
                          ],
                        ),
                      ),
                      if (example != null) ...[
                        const SizedBox(width: 14),
                        Text(
                          example.word,
                          textDirection: TextDirection.rtl,
                          style: AppTypography.quran(fontSize: 30, color: color, height: 1.7).copyWith(
                            decoration: rule == null ? null : TajweedRuleStyle.decoration(rule),
                            decorationStyle: rule == null ? null : TajweedRuleStyle.decorationStyle(rule),
                            decorationColor: color,
                            decorationThickness: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A surah link as a pill: the Arabic name on the reading side of the
/// English one, never clipped.
class _SurahChip extends StatelessWidget {
  final Surah surah;
  const _SurahChip({required this.surah});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Read ${surah.nameEnglish}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => context.push(RoutePaths.surahDetailsPath(surah.number)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(surah.nameEnglish, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13.5)),
                const SizedBox(width: 8),
                Text(
                  surah.nameArabic,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.arabicWord(fontSize: 17, color: AppColors.goldInk).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Read the Quran ───────────────────────────────────────────────────────────

class _ReadSection extends StatelessWidget {
  final LastRead? lastRead;
  const _ReadSection({required this.lastRead});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final last = lastRead;
    final Surah? lastSurah = last == null ? null : _surah(last.surah);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Read the Quran',
          actionLabel: 'All surahs',
          onActionTap: () => context.go(RoutePaths.quran),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (lastSurah != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: RosetteBadge(
              size: 40,
              fill: AppColors.goldWash,
              child: Icon(Icons.bookmark_rounded, size: 18, color: AppColors.goldInk),
            ),
            title: Text('Continue ${lastSurah.nameEnglish}', style: textTheme.titleMedium),
            subtitle: Text('Ayah ${last!.ayah} of ${lastSurah.ayahCount}'
                '${last.at == null ? '' : ' · ${relativeTime(last.at!)}'}'),
            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () => context.push(RoutePaths.surahDetailsPath(lastSurah.number, ayah: last.ayah)),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in _oftenRecited)
              if (_surah(n) case final s?) _SurahChip(surah: s),
          ],
        ),
      ],
    );
  }
}

// ── Rattil ───────────────────────────────────────────────────────────────────

class _RattilPanel extends StatelessWidget {
  const _RattilPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Listen with Rattil. Hear Sudais, Alafasy and Al-Dosari recite any surah or ayah.',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadii.lgRadius,
        child: Material(
          color: AppColors.brandCardGradient.first,
          child: InkWell(
            onTap: () => context.go(RoutePaths.askAi),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GeometricPattern(color: AppColors.textOnBrandCard, opacity: 0.07, cellSize: 40),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Listen with Rattil',
                                style: textTheme.headlineSmall?.copyWith(color: AppColors.textOnBrandCard)),
                            const SizedBox(height: 6),
                            Text(
                              'Hear Sudais, Alafasy and Al-Dosari recite any surah or ayah, slowly or on repeat.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textOnBrandCard.withValues(alpha: 0.82),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.gold),
                                const SizedBox(width: 6),
                                Text('Open Rattil',
                                    style: textTheme.labelLarge?.copyWith(color: AppColors.textOnBrandCard)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'رَتِّل',
                        textDirection: TextDirection.rtl,
                        style: AppTypography.quran(fontSize: 58, color: AppColors.gold, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progress glance ──────────────────────────────────────────────────────────

class _ProgressGlance extends StatelessWidget {
  final Future<ProgressSummary> summary;
  const _ProgressGlance({required this.summary});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProgressSummary>(
      future: summary,
      builder: (context, snap) {
        final s = snap.data;
        // Nothing to glance at before the first session; Continue above
        // already invites it.
        if (s == null || s.totalSessions == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Your progress',
                actionLabel: 'See all',
                onActionTap: () => context.go(RoutePaths.progress),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(horizontal: BorderSide(color: AppColors.divider)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _Stat(value: '${s.currentStreak}', label: 'day streak')),
                      VerticalDivider(color: AppColors.divider, width: 1),
                      Expanded(child: _Stat(value: '${s.totalSessions}', label: s.totalSessions == 1 ? 'session' : 'sessions')),
                      VerticalDivider(color: AppColors.divider, width: 1),
                      Expanded(
                        child: BlocBuilder<HasanahCubit, int>(
                          builder: (context, h) => _Stat(value: formatWithCommas(h), label: 'hasanah', gold: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool gold;
  const _Stat({required this.value, required this.label, this.gold = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: AppTypography.numeric(fontSize: 24, color: gold ? AppColors.goldInk : AppColors.textPrimary)),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── An ayah to reflect on ────────────────────────────────────────────────────

class _ReflectAyah extends StatefulWidget {
  const _ReflectAyah();

  @override
  State<_ReflectAyah> createState() => _ReflectAyahState();
}

class _ReflectAyahState extends State<_ReflectAyah> {
  late final (int, int) _ref;
  late final Future<Ayah?> _ayah;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    _ref = _reflectionAyat[dayOfYear % _reflectionAyat.length];
    _ayah = QuranTextRepository.instance
        .ayahsForSurah(_ref.$1)
        .then((ayahs) => ayahs.where((a) => a.number == _ref.$2).firstOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<Ayah?>(
      future: _ayah,
      builder: (context, snap) {
        final ayah = snap.data;
        if (ayah == null) return const SizedBox.shrink();
        final surah = _surah(_ref.$1);
        return InkWell(
          borderRadius: AppRadii.lgRadius,
          onTap: () => context.push(RoutePaths.surahDetailsPath(_ref.$1, ayah: _ref.$2)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                const OrnamentDivider(verticalPadding: 8),
                Text('An ayah to reflect on', style: textTheme.labelMedium?.copyWith(color: AppColors.goldInk)),
                const SizedBox(height: 10),
                Text(
                  ayah.arabicText,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.quran(fontSize: 25, height: 2.0),
                ),
                const SizedBox(height: 6),
                Text(
                  ayah.translation,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, height: 1.6),
                ),
                const SizedBox(height: 8),
                Text('${surah?.nameEnglish ?? 'Surah ${_ref.$1}'} ${_ref.$1}:${_ref.$2}',
                    style: textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
