import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/recitation_cubit.dart';
import '../bloc/recitation_state.dart';

class ProcessingScreen extends StatefulWidget {
  final int surahNumber;
  const ProcessingScreen({super.key, required this.surahNumber});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with TickerProviderStateMixin {
  // Continuous intra-phase motion.
  late final AnimationController _motion;
  // Smoothly eases the visualization between its four phases (0..3), matched
  // to the pipeline steps below: audio -> MFCC bars -> comparison -> result.
  late final AnimationController _phase;

  final List<String> _steps = [
    'Uploading audio...',
    'Extracting MFCC features...',
    'Comparing with reference recitation...',
    'Generating feedback...',
  ];
  int _stepIndex = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _phase = AnimationController(vsync: this, lowerBound: 0, upperBound: 3, duration: const Duration(milliseconds: 700));

    _stepTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (_stepIndex < _steps.length - 1) {
        setState(() => _stepIndex++);
        _phase.animateTo(_stepIndex.toDouble(), curve: Curves.easeInOut);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    _phase.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecitationCubit, RecitationState>(
      listener: (context, state) {
        if (state.status == RecitationStatus.result) {
          context.pushReplacement(RoutePaths.resultPath(widget.surahNumber));
        }
      },
      builder: (context, state) {
        if (state.status == RecitationStatus.error) {
          return Scaffold(
            body: ErrorStateWidget(
              title: 'Analysis failed',
              message: state.errorMessage ?? 'Something went wrong while analyzing your recitation.',
              onRetry: () => context.read<RecitationCubit>().stopAndProcess(),
            ),
          );
        }
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 260,
                  height: 150,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_motion, _phase]),
                    builder: (context, _) => CustomPaint(
                      painter: _MfccPainter(t: _motion.value, phase: _phase.value),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Analyzing Your Recitation', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _steps[_stepIndex],
                    key: ValueKey(_stepIndex),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Visualizes the recitation-analysis pipeline as a set of points that morph
/// through four phases:
///   0  flowing audio waveform
///   1  vertical MFCC-style frequency bars
///   2  scattered "neural" dot-field with links (model comparison)
///   3  points converge and settle (feedback ready)
class _MfccPainter extends CustomPainter {
  final double t; // 0..1 continuous
  final double phase; // 0..3
  _MfccPainter({required this.t, required this.phase});

  static const int n = 28;

  // Deterministic pseudo-random in 0..1 for point [i] (GLSL-style hash).
  double _hash(int i) {
    final v = sin(i * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  // Normalized position (0..1 space) of point [i] for an integer [p]hase.
  Offset _layout(int i, int p) {
    final fx = i / (n - 1);
    switch (p) {
      case 0: // waveform
        return Offset(fx, 0.5 + sin(fx * 4 * pi + t * 2 * pi) * 0.22);
      case 1: // MFCC bars (points sit at the top of each bar)
        final h = 0.16 + _hash(i) * 0.42 + sin(t * 2 * pi + i * 0.4) * 0.05;
        return Offset(fx, 0.86 - h);
      case 2: // scattered neural field
        final nx = 0.1 + fx * 0.8 + (_hash(i) - 0.5) * 0.12 + sin(t * 2 * pi + i) * 0.02;
        final ny = 0.18 + _hash(i * 7 + 1) * 0.62 + cos(t * 2 * pi + i * 0.7) * 0.02;
        return Offset(nx, ny);
      default: // settle toward a tight cluster with a gentle pulse
        final pulse = sin(t * 2 * pi) * 0.015;
        return Offset(0.5 + (fx - 0.5) * 0.12, 0.5 + pulse + (_hash(i) - 0.5) * 0.04);
    }
  }

  Offset _pos(int i, Size size) {
    final lo = phase.floor().clamp(0, 3);
    final hi = phase.ceil().clamp(0, 3);
    final frac = phase - lo;
    final a = _layout(i, lo);
    final b = _layout(i, hi);
    final p = Offset.lerp(a, b, frac)!;
    return Offset(p.dx * size.width, p.dy * size.height);
  }

  double _near(double target) => (1 - (phase - target).abs()).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final points = [for (int i = 0; i < n; i++) _pos(i, size)];
    final dotColor = Color.lerp(AppColors.primary, AppColors.accent, (phase / 3).clamp(0.0, 1.0))!;

    // Phase 0: waveform polyline
    final wOp = _near(0);
    if (wOp > 0.02) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primary.withValues(alpha: wOp * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Phase 1: MFCC bars from baseline up to each point
    final bOp = _near(1);
    if (bOp > 0.02) {
      final baseline = size.height * 0.86;
      final barPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: bOp * 0.55)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final p in points) {
        canvas.drawLine(Offset(p.dx, baseline), p, barPaint);
      }
    }

    // Phase 2: neural links between nearby points
    final lOp = _near(2);
    if (lOp > 0.02) {
      final linkPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: lOp * 0.35)
        ..strokeWidth = 1;
      for (int i = 0; i < points.length; i++) {
        for (final j in [i + 1, i + 4]) {
          if (j < points.length && (points[i] - points[j]).distance < size.width * 0.18) {
            canvas.drawLine(points[i], points[j], linkPaint);
          }
        }
      }
    }

    // Phase 3: soft glow as points settle
    final sOp = _near(3);
    if (sOp > 0.02) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        30 + sin(t * 2 * pi) * 6,
        Paint()..color = AppColors.primary.withValues(alpha: sOp * 0.12),
      );
    }

    // Dots on top for every phase
    final dotPaint = Paint()..color = dotColor;
    for (final p in points) {
      canvas.drawCircle(p, 2.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_MfccPainter oldDelegate) => oldDelegate.t != t || oldDelegate.phase != phase;
}
