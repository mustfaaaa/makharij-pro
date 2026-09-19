import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../models/tajweed_word_info.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// Which rule in the per-word Tajweed reference a library rule corresponds
/// to, when there is one, so the page can show real examples from the Quran.
String? _referenceKey(TajweedRule rule) {
  final t = rule.title.toLowerCase();
  for (final key in const ['ghunnah', 'shaddah', 'madd', 'qalqalah']) {
    if (t.startsWith(key)) return key;
  }
  return null;
}

/// One Tajweed rule, explained: its example in the Quran's script, what it
/// is, whether MakharijPro checks it when you recite, and real words from the
/// Quran that carry it -- each opening its ayah.
class RuleDetailsScreen extends StatefulWidget {
  final String ruleId;
  const RuleDetailsScreen({super.key, required this.ruleId});

  @override
  State<RuleDetailsScreen> createState() => _RuleDetailsScreenState();
}

class _RuleDetailsScreenState extends State<RuleDetailsScreen> {
  TajweedRule? _rule;
  Future<List<TajweedWordInfo>>? _examples;

  @override
  void initState() {
    super.initState();
    Services.tajweedRule.getRuleById(widget.ruleId).then((r) {
      if (!mounted) return;
      final key = _referenceKey(r);
      setState(() {
        _rule = r;
        if (key != null) _examples = Services.tajweedReference.examples(key, limit: 12);
      });
    });
  }

  Future<void> _toggleBookmark() async {
    final updated = await Services.tajweedRule.toggleBookmark(widget.ruleId);
    if (!mounted) return;
    setState(() => _rule = updated);
    AppSnackbar.show(context, updated.isBookmarked ? 'Saved to your bookmarks' : 'Removed from your bookmarks');
  }

  @override
  Widget build(BuildContext context) {
    final rule = _rule;
    if (rule == null) return const Scaffold(body: AppLoadingIndicator());
    final textTheme = Theme.of(context).textTheme;
    final name = rule.title.split(' (').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: rule.isBookmarked ? 'Remove bookmark' : 'Save this rule',
            onPressed: _toggleBookmark,
            icon: Icon(
              rule.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: rule.isBookmarked ? AppColors.goldInk : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xl),
        children: [
          ClipRRect(
            borderRadius: AppRadii.lgRadius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.goldWash,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                      borderRadius: AppRadii.lgRadius,
                    ),
                    child: GeometricPattern(color: AppColors.gold, opacity: 0.14, cellSize: 40),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
                  child: Center(
                    child: Text(rule.arabicExample,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.quran(fontSize: 40, color: AppColors.textPrimary, height: 1.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(rule.title, style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(rule.category)),
              Chip(
                avatar: Icon(
                  rule.isAiDetectable ? Icons.graphic_eq_rounded : Icons.menu_book_outlined,
                  size: 16,
                  color: rule.isAiDetectable ? AppColors.onPrimarySurface : AppColors.textSecondary,
                ),
                backgroundColor: rule.isAiDetectable ? AppColors.primarySurface : AppColors.surface,
                label: Text(rule.isAiDetectable ? 'Checked when you recite' : 'Reference only'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(rule.fullExplanation, style: textTheme.bodyLarge?.copyWith(height: 1.65)),
          if (_examples != null) ...[
            const OrnamentDivider(verticalPadding: 24),
            SectionHeader(title: 'In the Quran', subtitle: 'Words that carry this rule. Tap one to open its ayah.'),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<TajweedWordInfo>>(
              future: _examples,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: AppLoadingIndicator());
                }
                final words = snap.data ?? const [];
                if (words.isEmpty) {
                  return Text('Examples need a connection to the MakharijPro server.', style: textTheme.bodyMedium);
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in words)
                      Material(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius, side: BorderSide(color: AppColors.border)),
                        child: InkWell(
                          borderRadius: AppRadii.mdRadius,
                          onTap: () => context.push(RoutePaths.surahDetailsPath(w.surah, ayah: w.ayah)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(w.wordAr, textDirection: TextDirection.rtl, style: AppTypography.quran(fontSize: 24, height: 1.8)),
                                Text(
                                  '${dummySurahs.where((s) => s.number == w.surah).firstOrNull?.nameEnglish ?? 'Surah ${w.surah}'} ${w.surah}:${w.ayah}',
                                  style: textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () => context.go(RoutePaths.quran),
            icon: const Icon(Icons.mic_rounded, size: 20),
            label: const Text('Practise by reciting a surah'),
          ),
        ],
      ),
    );
  }
}
