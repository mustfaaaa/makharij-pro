import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../dummy/dummy_ayahs.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/recitation_cubit.dart';

class ListeningScreen extends StatefulWidget {
  final int surahNumber;
  const ListeningScreen({super.key, required this.surahNumber});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rippleController;
  late final AnimationController _sweepController;

  final int _currentAyah = 0;
  late final List<String> _words;

  @override
  void initState() {
    super.initState();
    _words = dummyFatihahAyahs[_currentAyah].arabicText.split(' ');

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    // One full sweep of the verse, then loop — the "karaoke" illumination.
    _sweepController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();

    // Tactile cue that recording has begun.
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    context.read<RecitationCubit>().stopAndProcess();
    context.pushReplacement(RoutePaths.processingPath(widget.surahNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Listening...'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _sweepController,
                    builder: (context, _) {
                      // The lit "head" sweeps across the words and loops.
                      final head = _sweepController.value * (_words.length + 1);
                      return Wrap(
                        alignment: WrapAlignment.center,
                        textDirection: TextDirection.rtl,
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          for (int i = 0; i < _words.length; i++) _IlluminatedWord(word: _words[i], lit: head - i),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const _Waveform(),
            const SizedBox(height: AppSpacing.xl),
            // Ripple rings expanding out from the stop button like sound waves.
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, _) => CustomPaint(
                      size: const Size(180, 180),
                      painter: _RipplePainter(progress: _rippleController.value),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Transform.scale(scale: 1 + (_pulseController.value * 0.12), child: child),
                    child: AppIconButton(
                      icon: Icons.stop_rounded,
                      size: 76,
                      background: AppColors.primary,
                      iconColor: Colors.white,
                      onPressed: _finish,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Tap to finish recitation', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// A single word that glows gold as the illumination sweep passes over it.
/// [lit] > ~0 means the sweep has reached it; a small window around 0..1
/// gives the brightest "just spoken" highlight.
class _IlluminatedWord extends StatelessWidget {
  final String word;
  final double lit;
  const _IlluminatedWord({required this.word, required this.lit});

  @override
  Widget build(BuildContext context) {
    // t: 0 (not yet reached) -> 1 (fully lit). Brightest right at the head.
    final t = lit.clamp(0.0, 1.0);
    final passed = lit >= 1.0;
    // Dim ink -> green as the sweep lands -> settled gold once passed.
    final color = Color.lerp(AppColors.textMuted, passed ? AppColors.accent : AppColors.primary, t)!;
    final glow = (t * (1 - (lit - 1).clamp(0.0, 1.0))).clamp(0.0, 1.0);
    final scale = context.watch<VerseTextSizeCubit>().state.scale;

    return Text(
      word,
      style: AppTypography.arabicVerse(fontSize: 28 * scale, color: color).copyWith(
        shadows: glow > 0.05
            ? [Shadow(color: AppColors.accent.withValues(alpha: glow * 0.55), blurRadius: 14 * glow)]
            : null,
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress; // 0..1 looping
  _RipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const minR = 40.0;
    final maxR = size.width / 2;
    const rings = 3;

    for (int i = 0; i < rings; i++) {
      // Stagger each ring by a third of the cycle.
      final p = (progress + i / rings) % 1.0;
      final radius = minR + (maxR - minR) * p;
      final opacity = (1 - p) * 0.4;
      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => oldDelegate.progress != progress;
}

class _Waveform extends StatefulWidget {
  const _Waveform();

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(24, (i) {
          final height = 6.0 + _rand.nextInt(36);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 4,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}
