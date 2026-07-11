import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

enum _SurahFilter { all, recent, favourites }

/// Quran tab rebuilt to the provided mockup: QURAN heading with a
/// "114 Surahs" chip, search by name / meaning / number, the provided Quran
/// photo as a hero card with the Last Read strip, and All / Recent /
/// Favourites tabs over the full 114-surah list.
class SurahSelectionScreen extends StatefulWidget {
  const SurahSelectionScreen({super.key});

  @override
  State<SurahSelectionScreen> createState() => _SurahSelectionScreenState();
}

class _SurahSelectionScreenState extends State<SurahSelectionScreen> {
  final _searchController = TextEditingController();
  _SurahFilter _filter = _SurahFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Surah> get _visibleSurahs {
    Iterable<Surah> list = dummySurahs;
    switch (_filter) {
      case _SurahFilter.recent:
        list = list.where((s) => s.lastScore != null);
      case _SurahFilter.favourites:
        list = list.where((s) => s.isBookmarked);
      case _SurahFilter.all:
        break;
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) =>
          s.nameEnglish.toLowerCase().contains(q) ||
          s.meaning.toLowerCase().contains(q) ||
          s.nameArabic.contains(q) ||
          s.number.toString() == q);
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final surahs = _visibleSurahs;
    final bottomPad = AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 12, AppSpacing.screenPadding, bottomPad),
          children: [
            // ── QURAN heading ────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QURAN',
                          style: textTheme.displayLarge?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text('114 Surahs of the Holy Quran',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text('114 Surahs',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Search ───────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.pillRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, meaning or number...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14.5),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Hero: the provided Quran photo + Last Read strip ─────────
            const _QuranHeroCard(),
            const SizedBox(height: AppSpacing.md),
            // ── All / Recent / Favourites tabs ───────────────────────────
            Row(
              children: [
                _FilterTab(
                    label: 'All',
                    selected: _filter == _SurahFilter.all,
                    onTap: () => setState(() => _filter = _SurahFilter.all)),
                const SizedBox(width: AppSpacing.lg),
                _FilterTab(
                    label: 'Recent',
                    selected: _filter == _SurahFilter.recent,
                    onTap: () => setState(() => _filter = _SurahFilter.recent)),
                const SizedBox(width: AppSpacing.lg),
                _FilterTab(
                    label: 'Favourites',
                    selected: _filter == _SurahFilter.favourites,
                    onTap: () => setState(() => _filter = _SurahFilter.favourites)),
              ],
            ),
            Divider(color: AppColors.divider, height: 18),
            const SizedBox(height: 4),
            // ── The surah list ───────────────────────────────────────────
            if (surahs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text('No surahs match your search',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              )
            else
              for (final surah in surahs) _SurahListCard(surah: surah),
          ],
        ),
      ),
    );
  }
}

// ── Hero card: provided Quran photo + frosted Last Read strip ────────────────
class _QuranHeroCard extends StatelessWidget {
  const _QuranHeroCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.lgRadius,
      child: Stack(
        children: [
          Image.asset(
            'assets/images/quran_dark.jpg',
            opacity: const AlwaysStoppedAnimation(0.8),
            height: 300,
            width: double.infinity,
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.5),
          ),
          // Book sits in the upper area; the blend begins around the rehal
          // curve so the lower portion of the mushaf's stand and carpet stays
          // visible through the blended area, melting into the Last Read strip.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 0.72, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.20),
                  ],
                ),
              ),
            ),
          ),
          // Frosted "Last Read" strip pinned to the bottom of the photo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  color: Colors.white.withValues(alpha: 0.82),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
                        child: Icon(Icons.menu_book_rounded, color: AppColors.primaryDark, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LAST READ',
                                style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                    letterSpacing: 1.8)),
                            const Text('Al-Fatihah',
                                style: TextStyle(
                                    color: Color(0xFF2D2A26), fontWeight: FontWeight.w700, fontSize: 16)),
                            const Text('Ayah 5 of 7 · Juz 1',
                                style: TextStyle(color: Color(0xFF8A8378), fontSize: 12)),
                          ],
                        ),
                      ),
                      Pressable(
                        onTap: () => context.push(RoutePaths.surahDetailsPath(1)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          decoration:
                              BoxDecoration(color: AppColors.primary, borderRadius: AppRadii.pillRadius),
                          child: const Text('Continue',
                              style:
                                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── All / Recent / Favourites tab item ───────────────────────────────────────
class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: selected ? 26 : 0,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }
}

// ── One surah row card ────────────────────────────────────────────────────────
class _SurahListCard extends StatelessWidget {
  final Surah surah;
  const _SurahListCard({required this.surah});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(RoutePaths.surahDetailsPath(surah.number)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.lgRadius,
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${surah.number}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surah.nameArabic,
                      style: AppTypography.arabicWord(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text('${surah.nameEnglish} / ${surah.meaning}',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (surah.lastScore != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Text('Practiced ${surah.lastScore!.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
              )
            else
              Text('${surah.ayahCount} Ayat',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
