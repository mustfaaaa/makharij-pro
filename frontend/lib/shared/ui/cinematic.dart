import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'photo.dart';

/// The cinematic surface used by onboarding: a photograph laid into deep
/// green, a slow drift of the camera, light falling across it and dust in the
/// light. Always dark, in both themes, because it is photography, not chrome.
///
/// Everything here is driven by one ambient animation (0..1, looping) that the
/// screen owns, so a whole page costs a single ticker. With animations turned
/// off in the system the screen simply never starts it, and every piece rests
/// in a still, finished state.
abstract final class Cinema {
  static const deep = Color(0xFF0F2A23);
  static const gold = Color(0xFFCDAA66);
  static const goldLight = Color(0xFFF4E3B5);
  static const glow = Color(0xFFF4D797);
  static const onDeep = Color(0xFFFBF7EE);
  static const onDeepMuted = Color(0xFFC9C2B0);
  static const beam = Color(0xFFFFF0C8);
  static const maddOnDeep = Color(0xFFF2B58A);
  static const dots = Color(0xFF3B5A4E);
}

/// A photograph filling [heightFactor] of the page, the camera easing slowly
/// in and out, fading into the deep green below it.
class CinematicPhoto extends StatelessWidget {
  final String asset;
  final Animation<double> ambient;
  final Alignment alignment;
  final double heightFactor;

  /// How dark the photograph sits under the page's text, 0..1.
  final double shade;

  const CinematicPhoto({
    super.key,
    required this.asset,
    required this.ambient,
    this.alignment = Alignment.center,
    this.heightFactor = 0.64,
    this.shade = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.topCenter,
      heightFactor: heightFactor,
      widthFactor: 1,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: ambient,
              // A breath of zoom over the loop: in, then back out.
              builder: (context, child) => Transform.scale(
                scale: 1.0 + 0.08 * (0.5 - 0.5 * math.cos(ambient.value * 2 * math.pi)),
                child: child,
              ),
              child: AppPhoto(asset, alignment: alignment),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.55, 1],
                  colors: [
                    Cinema.deep.withValues(alpha: 0.25 + 0.2 * shade),
                    Cinema.deep.withValues(alpha: 0.35 + 0.35 * shade),
                    Cinema.deep,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shaft of light falling across the photograph. Soft-edged by its own
/// gradient rather than a blur, so it costs nothing to animate.
class LightBeam extends StatelessWidget {
  final Animation<double> ambient;
  final double left;
  final double top;
  final double width;
  final double height;

  /// Degrees from vertical; negative leans the top to the left.
  final double angle;

  /// Peak opacity, and where in the ambient loop this beam is brightest.
  final double strength;
  final double phase;

  const LightBeam({
    super.key,
    required this.ambient,
    required this.left,
    required this.top,
    this.width = 110,
    this.height = 420,
    this.angle = -22,
    this.strength = 0.5,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Transform.rotate(
            angle: angle * math.pi / 180,
            child: AnimatedBuilder(
              animation: ambient,
              builder: (context, child) {
                final breath = 0.5 - 0.5 * math.cos((ambient.value * 2 + phase) * 2 * math.pi);
                return Opacity(opacity: strength * (0.35 + 0.65 * breath), child: child);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Cinema.beam.withValues(alpha: 0),
                      Cinema.beam.withValues(alpha: 0.9),
                      Cinema.beam.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Cinema.deep.withValues(alpha: 0), Cinema.deep.withValues(alpha: 0.92)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A few motes of dust rising slowly through the light.
class DustField extends StatelessWidget {
  final Animation<double> ambient;

  /// The band the motes rise through, as fractions of the page height.
  final double from;
  final double to;
  final int seed;

  const DustField({super.key, required this.ambient, this.from = 0.52, this.to = 0.18, this.seed = 3});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(painter: _DustPainter(ambient, from, to, seed), size: Size.infinite),
        ),
      ),
    );
  }
}

class _Mote {
  final double x;
  final double offset;
  final double speed;
  final double radius;
  const _Mote(this.x, this.offset, this.speed, this.radius);
}

class _DustPainter extends CustomPainter {
  final Animation<double> ambient;
  final double from;
  final double to;
  final List<_Mote> _motes;
  final Paint _paint = Paint();

  _DustPainter(this.ambient, this.from, this.to, int seed)
      : _motes = _make(seed),
        super(repaint: ambient);

  static List<_Mote> _make(int seed) {
    final r = math.Random(seed);
    return [
      for (var i = 0; i < 9; i++)
        _Mote(0.12 + r.nextDouble() * 0.76, r.nextDouble(), 3 + r.nextInt(3).toDouble(), 1.0 + r.nextDouble() * 1.1),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in _motes) {
      // Each mote rises from `from` to `to` several times over the loop,
      // fading in at the bottom and out at the top.
      final p = (ambient.value * m.speed + m.offset) % 1.0;
      final y = size.height * (from + (to - from) * p);
      final x = size.width * m.x + math.sin((p + m.offset) * 2 * math.pi) * 6;
      final a = p < 0.2 ? p / 0.2 : (p > 0.8 ? (1 - p) / 0.2 : 1.0);
      _paint.color = Cinema.goldLight.withValues(alpha: 0.85 * a);
      canvas.drawCircle(Offset(x, y), m.radius, _paint);
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => false;
}
