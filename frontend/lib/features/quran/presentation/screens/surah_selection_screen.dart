import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

enum _SurahFilter { all, practised, saved }

/// The Quran tab: the 114 surahs, searchable by name, meaning, Arabic or
/// number, with the reader's real place to continue from at the top.
///
/// The list starts in the first viewport. It used to sit under a 300px photo
/// hero, a duplicated "114 Surahs" chip and a caps title, halfway down the
/// screen, as 114 shadowed cards built all at once.
class SurahSelectionScreen extends StatefulWidget {
  const SurahSelectionScreen({super.key});

  @override
  State<SurahSelectionScreen> createState() => _SurahSelectionScreenState();
}

class _SurahSelectionScreenState extends State<SurahSelectionScreen> {
  final _searchController = TextEditingController();
  _SurahFilter _filter = _SurahFilter.all;
  String _query = '';
  late Future<List<Surah>> _surahs = Services.surah.getSurahs();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Surah> _visible(List<Surah> all) {
    Iterable<Surah> list = all;
    switch (_filter) {
      case _SurahFilter.practised:
        list = list.where((s) => s.lastScore != null);
      case _SurahFilter.saved:
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Surah>>(
          future: _surahs,
          builder: (context, snap) {
            final all = snap.data ?? const <Surah>[];
            final surahs = _visible(all);
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, 0),
                  sliver: SliverList.list(children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: Text('Quran', style: textTheme.displayMedium)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('القرآن الكريم',
                              textDirection: TextDirection.rtl,
                              style: AppTypography.arabicWord(fontSize: 22, color: AppColors.goldInk, weight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ContinueBanner(all: all),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Name, meaning or number',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _searchController.clear();
                                  _query = '';
                                }),
                              ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<_SurahFilter>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: _SurahFilter.all, label: Text('All')),
                        ButtonSegment(value: _SurahFilter.practised, label: Text('Practised')),
                        ButtonSegment(value: _SurahFilter.saved, label: Text('Saved')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (v) => setState(() => _filter = v.first),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ]),
                ),
                if (snap.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorStateWidget(
                      title: 'The surah list could not load',
                      message: 'Check your connection and try again.',
                      onRetry: () => setState(() => _surahs = Services.surah.getSurahs()),
                    ),
                  )
                else if (snap.connectionState != ConnectionState.done)
                  SliverList.builder(
                    itemCount: 8,
                    itemBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                      child: SurahCardSkeleton(),
                    ),
                  )
                else if (surahs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateWidget(
                      icon: _filter == _SurahFilter.saved ? Icons.bookmark_outline_rounded : Icons.search_rounded,
                      title: switch (_filter) {
                        _ when _query.isNotEmpty => 'No surah matches “$_query”',
                        _SurahFilter.saved => 'No saved surahs yet',
                        _SurahFilter.practised => 'No surahs practised yet',
                        _SurahFilter.all => 'No surahs',
                      },
                      message: switch (_filter) {
                        _ when _query.isNotEmpty => 'Try a number from 1 to 114, or an English name like Al-Mulk.',
                        _SurahFilter.saved => 'Tap the bookmark on a surah’s page to keep it here.',
                        _SurahFilter.practised => 'Surahs you recite appear here, with your latest session.',
                        _SurahFilter.all => '',
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.bottomNavClearance),
                    sliver: SliverList.builder(
                      itemCount: surahs.length,
                      itemBuilder: (context, i) => _SurahRow(surah: surahs[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Where to pick up: the place the reader last settled on this device, else
/// the most recently practised surah, else an invitation to begin.
class _ContinueBanner extends StatelessWidget {
  final List<Surah> all;
  const _ContinueBanner({required this.all});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final last = Services.prefs.lastRead;
    final lastSurah = last == null ? null : all.where((s) => s.number == last.surah).firstOrNull;

    final String eyebrow;
    final String title;
    final String subtitle;
    final String path;
    if (lastSurah != null) {
      eyebrow = 'Continue reading';
      title = lastSurah.nameEnglish;
      subtitle = 'Ayah ${last!.ayah} of ${lastSurah.ayahCount}';
      path = RoutePaths.surahDetailsPath(lastSurah.number, ayah: last.ayah);
    } else {
      eyebrow = 'Begin reading';
      title = 'Al-Fatihah';
      subtitle = 'The Opening · 7 ayahs';
      path = RoutePaths.surahDetailsPath(1);
    }

    return PhotoBanner(
      asset: AppPhotos.quranGreenCloth,
      height: 148,
      alignment: const Alignment(0.2, -0.2),
      semanticLabel: '$eyebrow: $title, $subtitle',
      onTap: () => context.push(path),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: textTheme.labelMedium?.copyWith(color: AppColors.textOnPhotoSecondary)),
                Text(title, style: AppTypography.displayText(fontSize: 26, color: AppColors.textOnPhoto)),
                Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.textOnPhotoSecondary)),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textOnPhoto.withValues(alpha: 0.16),
              border: Border.all(color: AppColors.textOnPhoto.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.arrow_forward_rounded, color: AppColors.textOnPhoto),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final Surah surah;
  const _SurahRow({required this.surah});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final place = surah.revelationPlace == 'Makkah'
        ? 'Meccan'
        : (surah.revelationPlace == 'Madinah' ? 'Medinan' : surah.revelationPlace);
    final practised = surah.lastScore != null;

    return Semantics(
      button: true,
      label: 'Surah ${surah.number}, ${surah.nameEnglish}, ${surah.meaning}, ${surah.ayahCount} ayahs'
          '${practised ? ', practised' : ''}${surah.isBookmarked ? ', saved' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(RoutePaths.surahDetailsPath(surah.number)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            children: [
              RosetteBadge(
                size: 40,
                fill: AppColors.goldWash,
                child: Text('${surah.number}',
                    style: AppTypography.numeric(fontSize: surah.number > 99 ? 11 : 12.5, color: AppColors.goldInk)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(surah.nameEnglish,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium),
                        ),
                        if (surah.isBookmarked) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bookmark_rounded, size: 15, color: AppColors.goldInk),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${surah.meaning} · ${surah.ayahCount} ayahs · $place',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(surah.nameArabic,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabicWord(fontSize: 22, color: AppColors.textPrimary)),
                  if (practised)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                        const SizedBox(width: 3),
                        Text('Practised', style: textTheme.labelSmall?.copyWith(color: AppColors.success)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
