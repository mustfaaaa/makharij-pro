import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_surahs.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/recitation_cubit.dart';
import '../bloc/recitation_state.dart';

/// While the recording is analysed.
///
/// This used to narrate four pipeline steps ("Extracting MFCC features...")
/// on a 650ms timer, whatever the backend was doing -- and the recogniser is
/// a phoneme model, not an MFCC pipeline. Now it says only what is true: the
/// recording has been sent, each recited word is being compared with its
/// expected pronunciation, and how long that has taken so far. The motion is
/// an indeterminate indicator; it claims no progress it cannot measure.
class ProcessingScreen extends StatefulWidget {
  final int surahNumber;
  const ProcessingScreen({super.key, required this.surahNumber});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  /// After this long the wait stops being ordinary and the screen says so.
  static const _slowAfter = Duration(seconds: 20);
  bool get _isSlow => _elapsed >= _slowAfter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) _breath.repeat(reverse: true);
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _cancel() {
    context.read<RecitationCubit>().reset();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocConsumer<RecitationCubit, RecitationState>(
      listener: (context, state) {
        if (state.status == RecitationStatus.result) {
          context.pushReplacement(RoutePaths.resultPath(widget.surahNumber));
        }
      },
      builder: (context, state) {
        if (state.status == RecitationStatus.error) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: _cancel),
            ),
            body: ErrorStateWidget(
              title: 'The recitation could not be checked',
              message: state.errorMessage ?? 'Something went wrong while checking your recitation.',
              onRetry: () => context.read<RecitationCubit>().stopAndProcess(),
            ),
          );
        }

        final surah = dummySurahs.where((s) => s.number == widget.surahNumber).firstOrNull;
        final to = state.toAyah;
        final range = state.isWholeSurah
            ? 'Whole surah'
            : (to == null || to == state.fromAyah ? 'Ayah ${state.fromAyah}' : 'Ayahs ${state.fromAyah}–$to');

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: GeometricPattern(color: AppColors.gold, opacity: 0.06, cellSize: 52)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _breath,
                            builder: (context, child) => Transform.scale(
                              scale: 1 + 0.04 * Curves.easeInOut.transform(_breath.value),
                              child: child,
                            ),
                            child: RosetteBadge(
                              size: 112,
                              fill: AppColors.goldWash,
                              child: Icon(Icons.graphic_eq_rounded, size: 40, color: AppColors.goldInk),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          if (surah != null)
                            Text(surah.nameArabic,
                                textDirection: TextDirection.rtl,
                                style: AppTypography.arabicWord(fontSize: 26, color: AppColors.goldInk, weight: FontWeight.w700)),
                          Semantics(
                            liveRegion: true,
                            child: Text('Checking your recitation',
                                textAlign: TextAlign.center, style: textTheme.headlineMedium),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${surah?.nameEnglish ?? 'Surah ${widget.surahNumber}'} · $range',
                            style: textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Each word you recited is being compared with its expected pronunciation.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: const SizedBox(width: 200, child: LinearProgressIndicator(minHeight: 3)),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _isSlow
                                ? 'Taking longer than usual (${_elapsed.inSeconds}s). Longer passages take longer.'
                                : '${_elapsed.inSeconds}s',
                            textAlign: TextAlign.center,
                            style: AppTypography.numeric(
                              fontSize: 13,
                              weight: FontWeight.w500,
                              color: _isSlow ? AppColors.warning : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // Always reachable: without it a hung request left
                          // the user on a screen with no way out.
                          TextButton(onPressed: _cancel, child: Text(_isSlow ? 'Cancel and go back' : 'Cancel')),
                        ],
                      ),
                    ),
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
