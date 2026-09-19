import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/tajweed_error.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../shared/ui/tajweed_marks.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';

/// Three honest steps: what the app is, what happens when you recite, and what
/// you do with the feedback.
///
/// The old slides promised mistakes caught "as they happen" and "highlighted
/// immediately". The app deliberately does neither -- words fill in as they
/// are heard, and verdicts come after -- so this says what it actually does,
/// including that feedback can be wrong. Shown once.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  static const _count = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Services.prefs.setOnboardingSeen();
    context.go(RoutePaths.welcome);
  }

  void _next() {
    if (_index == _count - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pages = [
      const _Page(
        art: _PhotoArt(),
        title: 'The Quran, beautifully',
        body: 'Read every surah in a clear Mushaf script, with translation, transliteration and a Qari whenever you want them.',
      ),
      const _Page(
        art: _ReciteArt(),
        title: 'Recite, and see what was heard',
        body: 'Words fill in as the app hears you. When you stop, each word you recited is checked against its expected pronunciation.',
      ),
      const _Page(
        art: _ReviewArt(),
        title: 'Understand, then try again',
        body: 'See which rule a word needs, hear yourself beside a Qari, and try it again. Feedback can be wrong, and you can always say so.',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                child: TextButton(onPressed: _finish, child: const Text('Skip')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.md),
              child: Row(
                children: [
                  Semantics(
                    label: 'Step ${_index + 1} of $_count',
                    child: Row(
                      children: List.generate(_count, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? AppColors.primary : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_index == _count - 1 ? 'Get started' : 'Next', style: textTheme.labelLarge?.copyWith(color: AppColors.textOnPrimary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final Widget art;
  final String title;
  final String body;
  const _Page({required this.art, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding + 4),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: constraints.maxHeight * 0.46, width: double.infinity, child: art),
              const SizedBox(height: AppSpacing.xl),
              Semantics(header: true, child: Text(title, style: textTheme.displaySmall)),
              const SizedBox(height: AppSpacing.sm),
              Text(body, style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.6)),
            ],
          ),
        ),
      );
    });
  }
}

class _PhotoArt extends StatelessWidget {
  const _PhotoArt();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppPhoto(AppPhotos.mushafGreen, alignment: Alignment(0, 0.1)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.photoScrim.withValues(alpha: 0.4)],
              ),
            ),
          ),
          const Positioned(left: 16, bottom: 16, child: BrandMark(size: 52, color: Color(0xFFE2C98E))),
        ],
      ),
    );
  }
}

/// Real Quran text in the app's own reading style, the first half recited.
/// An illustration of how the page behaves, not a result.
class _ReciteArt extends StatelessWidget {
  const _ReciteArt();

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.textPrimary;
    final pending = AppColors.verseResting;
    return _ArtCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'ٱلْحَمْدُ لِلَّهِ ', style: AppTypography.quran(fontSize: 30, color: ink)),
              TextSpan(text: 'رَبِّ ٱلْعَٰلَمِينَ', style: AppTypography.quran(fontSize: 30, color: pending)),
            ]),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Icon(Icons.mic_rounded, color: AppColors.textOnPrimary, size: 28),
          ),
          const SizedBox(height: 10),
          Text('Example', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ReviewArt extends StatelessWidget {
  const _ReviewArt();

  @override
  Widget build(BuildContext context) {
    const rule = TajweedErrorType.madd;
    final color = TajweedRuleStyle.color(rule);
    return _ArtCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ٱلضَّآلِّينَ',
            textDirection: TextDirection.rtl,
            style: AppTypography.quran(fontSize: 40, color: color, height: 1.9).copyWith(
              decoration: TajweedRuleStyle.decoration(rule),
              decorationStyle: TajweedRuleStyle.decorationStyle(rule),
              decorationColor: color,
              decorationThickness: 2.4,
            ),
          ),
          const SizedBox(height: 10),
          const RuleChip(rule: rule, compact: true),
          const SizedBox(height: 10),
          Text(TajweedCopy.headline(rule), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Pill(icon: Icons.play_arrow_rounded, label: 'Hear yourself', filled: false),
              _Pill(icon: Icons.mic_rounded, label: 'Try this word', filled: true),
            ],
          ),
          const SizedBox(height: 10),
          Text('Example', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  const _Pill({required this.icon, required this.label, required this.filled});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.textOnPrimary : AppColors.onPrimarySurface;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

class _ArtCard extends StatelessWidget {
  final Widget child;
  const _ArtCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 14,
            child: RosetteBadge(size: 22, fill: AppColors.goldWash),
          ),
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(20), child: child)),
        ],
      ),
    );
  }
}
