import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_ayahs.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../recitation/presentation/bloc/recitation_cubit.dart';

/// Surah screen rebuilt to the two provided mockups. Opening a surah shows
/// the provided Quran photo fading into the page, the surah-name card, the
/// Preview list, and a gold "Tap to Speak" mic. Tapping the mic switches the
/// same screen into the recording state — live waveform, elapsed timer and a
/// red Stop control. Stopping hands off to the existing processing animation
/// and result flow, unchanged.
class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;
  const SurahDetailsScreen({super.key, required this.surahNumber});

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> with SingleTickerProviderStateMixin {
  Surah? _surah;
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    Services.surah.getSurahByNumber(widget.surahNumber).then((s) {
      if (mounted) setState(() => _surah = s);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _toggleBookmark() async {
    final updated = await Services.surah.toggleBookmark(widget.surahNumber);
    if (mounted) setState(() => _surah = updated);
  }

  void _startRecording() {
    HapticFeedback.mediumImpact();
    final cubit = context.read<RecitationCubit>();
    cubit.beginSession(widget.surahNumber);
    cubit.startListening();
    _waveController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
  }

  void _stopRecording() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _waveController.stop();
    setState(() => _recording = false);
    // Hand off to the existing processing animation + result flow.
    context.read<RecitationCubit>().stopAndProcess();
    context.push(RoutePaths.processingPath(widget.surahNumber));
  }

  String get _elapsedText {
    final m = _elapsed.inMinutes;
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surah;
    if (surah == null) {
      return const Scaffold(body: AppLoadingIndicator());
    }
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Photo header with back / title / bookmark ────────────
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset('assets/images/quran_dark.jpg',
                                fit: BoxFit.cover, alignment: const Alignment(0, 0.3)),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.28, 0.70, 1.0],
                                  colors: [
                                    Colors.black.withValues(alpha: 0.30),
                                    Colors.transparent,
                                    AppColors.background.withValues(alpha: 0.55),
                                    AppColors.background,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenPadding, 8, AppSpacing.screenPadding, 0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: const Icon(Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(surah.nameEnglish,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20)),
                              ),
                              GestureDetector(
                                onTap: _toggleBookmark,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    surah.isBookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_outline_rounded,
                                    color: surah.isBookmarked
                                        ? AppColors.primaryDark
                                        : const Color(0xFF2D2A26),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Surah-name card ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: AppRadii.lgRadius,
                      ),
                      child: Column(
                        children: [
                          Text(surah.nameArabic,
                              style: AppTypography.arabicVerse(
                                  fontSize: 34, color: AppColors.primaryDark, height: 1.4)),
                          const SizedBox(height: 6),
                          Text(
                            '${surah.meaning} · ${surah.ayahCount} Ayahs · ${surah.revelationPlace}',
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Preview heading + ayahs ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding, AppSpacing.lg, AppSpacing.screenPadding, 8),
                    child: Text('Preview',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  sliver: SliverList.builder(
                    itemCount: dummyFatihahAyahs.length,
                    itemBuilder: (context, i) {
                      final ayah = dummyFatihahAyahs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(ayah.arabicText,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: AppTypography.arabicVerse(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(ayah.translation,
                                textAlign: TextAlign.right,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary, height: 1.4)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ),
          ),
          // ── Bottom control: Tap to Speak ⇄ recording state ─────────────
          SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _recording
                  ? _RecordingControls(
                      key: const ValueKey('recording'),
                      elapsedText: _elapsedText,
                      waveController: _waveController,
                      onStop: _stopRecording,
                    )
                  : _TapToSpeakControl(
                      key: const ValueKey('idle'),
                      onTap: _startRecording,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Idle state: gold "Tap to Speak" mic, as in the mockup ────────────────────
class _TapToSpeakControl extends StatelessWidget {
  final VoidCallback onTap;
  const _TapToSpeakControl({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, 8, AppSpacing.screenPadding, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryLight, AppColors.primaryDark],
                ),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(width: 20),
          Text('Tap to Speak',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── Recording state: waveform + timer + red Stop, as in the mockup ───────────
class _RecordingControls extends StatelessWidget {
  final String elapsedText;
  final AnimationController waveController;
  final VoidCallback onStop;
  const _RecordingControls({
    super.key,
    required this.elapsedText,
    required this.waveController,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, 4, AppSpacing.screenPadding, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live waveform pill.
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.pillRadius,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: AnimatedBuilder(
              animation: waveController,
              builder: (context, _) => CustomPaint(
                size: const Size(double.infinity, 30),
                painter: _LiveWaveformPainter(
                  phase: waveController.value,
                  activeColor: AppColors.primary,
                  mutedColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(elapsedText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.error, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onStop,
                  child: Text('Stop',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated recording waveform: bars of pseudo-random heights whose amplitude
/// breathes with [phase], gold at the head fading to muted at the tail.
class _LiveWaveformPainter extends CustomPainter {
  final double phase;
  final Color activeColor;
  final Color mutedColor;
  _LiveWaveformPainter({required this.phase, required this.activeColor, required this.mutedColor});

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.5;
    const gap = 4.0;
    final count = (size.width / (barWidth + gap)).floor();
    final rng = Random(7); // fixed seed → stable bar pattern each frame
    final paint = Paint()..strokeCap = StrokeCap.round..strokeWidth = barWidth;

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap) + barWidth / 2;
      final base = 6 + rng.nextDouble() * 18;
      // Breathe: each bar's height oscillates slightly out of phase.
      final wobble = sin((phase * 2 * pi) + i * 0.7) * 4;
      final h = (base + wobble).clamp(4.0, size.height);
      paint.color = i < count * 0.55 ? activeColor : mutedColor;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter old) => old.phase != phase;
}
