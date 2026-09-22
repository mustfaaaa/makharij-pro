import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../theme/app_typography.dart';

/// The launch: a Tajweed diagram of the head in profile draws itself, a point
/// of sound rises from deep in the throat and travels to the lips, lighting
/// each makhraj as it passes with the letters born there. It leaves the lips as
/// rings, and the rings become the app's star.
///
/// [full] plays the whole sequence (~2.6s); otherwise only the star and the
/// name settle (~0.8s). Tapping anywhere finishes at once. With animations
/// turned off in the system, the final frame shows and [onDone] follows
/// shortly after.
class MakharijLaunch extends StatefulWidget {
  final bool full;
  final VoidCallback onDone;
  const MakharijLaunch({super.key, required this.full, required this.onDone});

  @override
  State<MakharijLaunch> createState() => _MakharijLaunchState();
}

/// The launch has its own fixed palette: it runs before any theme matters and
/// is the same in light and dark, continuing the native splash's colour.
abstract final class _Palette {
  static const deep = Color(0xFF0E271F);
  static const centre = Color(0xFF16392D);
  static const edge = Color(0xFF081813);
  static const line = Color(0xFFDCD5C6);
  static const tongue = Color(0xFFE9C9B6);
  static const gold = Color(0xFFCDAA66);
  static const light = Color(0xFFF4D797);
  static const spark = Color(0xFFFFF3D1);
  static const label = Color(0xFFE9D6A6);
  static const ivory = Color(0xFFF2E7CE);
  static const green = Color(0xFF1E4D3B);
  static const onDeep = Color(0xFFFBF7EE);
  static const onDeepMuted = Color(0xFFB9C6BE);
}

const double _fullSeconds = 2.6;
const double _shortSeconds = 0.8;

class _MakharijLaunchState extends State<MakharijLaunch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: ((widget.full ? _fullSeconds : _shortSeconds) * 1000).round()),
  );
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _c.value = 1;
        Future<void>.delayed(const Duration(milliseconds: 250), _finish);
      } else {
        _c.forward().whenComplete(_finish);
      }
    });
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.full ? _fullSeconds : _shortSeconds;
    return Semantics(
      label: 'MakharijPro',
      hint: 'Double tap to skip',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.16),
                  radius: 1.1,
                  colors: [_Palette.centre, _Palette.deep, _Palette.edge],
                  stops: [0, 0.62, 1],
                ),
              ),
            ),
            // Film grain at a few percent: the cheapest way to make a flat
            // surface feel like paper rather than a screen.
            const RepaintBoundary(
              child: Opacity(
                opacity: 0.05,
                child: Image(image: AssetImage('assets/images/grain.png'), repeat: ImageRepeat.repeat),
              ),
            ),
            if (widget.full)
              RepaintBoundary(
                child: CustomPaint(painter: _DiagramPainter(_c, seconds, Directionality.of(context))),
              ),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => _Mark(t: _c.value * seconds, full: widget.full),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress of a segment starting at [start] seconds and lasting [dur], 0..1.
double _seg(double t, double start, double dur) => ((t - start) / dur).clamp(0.0, 1.0);

/// Up, then down: a flash that peaks a quarter of the way through.
double _flash(double t, double start, double dur) {
  final p = _seg(t, start, dur);
  if (p <= 0 || p >= 1) return 0;
  return p < 0.25 ? p / 0.25 : 1 - (p - 0.25) / 0.75;
}

// ── the star and the name ────────────────────────────────────────────────────

class _Mark extends StatelessWidget {
  final double t;
  final bool full;
  const _Mark({required this.t, required this.full});

  @override
  Widget build(BuildContext context) {
    // Full: the star hands over from the native splash, steps aside for the
    // diagram, and comes back at the end. Short: it is simply there.
    final double starOpacity;
    final double starScale;
    final double starTurn;
    final List<double> bars;
    final double name;
    final double tagline;
    if (full) {
      final away = Curves.easeInCubic.transform(_seg(t, 0, 0.3));
      final back = _seg(t, 1.75, 0.45);
      final backEased = Curves.easeOutBack.transform(back);
      starOpacity = back > 0 ? back.clamp(0.0, 1.0) : 1 - away;
      starScale = back > 0 ? 0.4 + 0.6 * backEased : 1 - 0.25 * away;
      starTurn = back > 0 ? (1 - Curves.easeOutCubic.transform(back)) * -0.35 : 0;
      // The native splash showed the star whole, so it leaves whole; on its
      // return the voice inside it rises again.
      bars = [for (var i = 0; i < 5; i++) t < 1.0 ? 1.0 : _grow(_seg(t, 1.9 + i * 0.05, 0.35))];
      name = _seg(t, 1.9, 0.35);
      tagline = _seg(t, 2.0, 0.35);
    } else {
      starOpacity = 1;
      starScale = 1;
      starTurn = 0;
      // Starts exactly as the native splash left it, then one breath through
      // the bars: they dip and return, left to right.
      bars = [for (var i = 0; i < 5; i++) 1 - 0.45 * math.sin(math.pi * _seg(t, 0.05 + i * 0.06, 0.4))];
      name = _seg(t, 0.1, 0.35);
      tagline = _seg(t, 0.18, 0.32);
    }

    return LayoutBuilder(
      builder: (context, box) {
        const starSize = 112.0;
        final centre = Offset(box.maxWidth / 2, box.maxHeight / 2);
        return Stack(
          children: [
            Positioned(
              left: centre.dx - starSize / 2,
              top: centre.dy - starSize / 2,
              width: starSize,
              height: starSize,
              child: Opacity(
                opacity: starOpacity.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: starTurn,
                  child: Transform.scale(
                    scale: starScale,
                    child: CustomPaint(painter: _StarPainter(bars: bars)),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: centre.dy + starSize / 2 + 18,
              child: Column(
                children: [
                  _Rise(
                    progress: name,
                    child: Text(
                      'MakharijPro',
                      style: AppTypography.displayText(fontSize: 30, color: _Palette.onDeep, height: 1.2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _Rise(
                    progress: tagline,
                    child: Text(
                      'Every letter, from its place',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _Palette.onDeepMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A bar finding its note: from nothing, a little past full, then settling.
double _grow(double p) {
  if (p <= 0) return 0.1;
  return p < 0.55 ? 0.1 + 1.0 * (p / 0.55) : 1.1 - 0.1 * ((p - 0.55) / 0.45);
}

class _Rise extends StatelessWidget {
  final double progress;
  final Widget child;
  const _Rise({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Curves.easeOutCubic.transform(progress);
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, (1 - p) * 10), child: child),
    );
  }
}

/// The app's mark: the Mushaf's eight-point star with a voice inside it -- the
/// same geometry as the launcher icon.
class _StarPainter extends CustomPainter {
  /// Each bar's height as a share of its full height (1 = as on the icon).
  final List<double> bars;
  _StarPainter({required this.bars});

  static final Path _star = _starPath();
  static const _barCentres = [7.06, 9.53, 12.0, 14.47, 16.94];
  static const _barHeights = [3.3, 7.7, 11.5, 6.6, 3.3];

  static Path _starPath() {
    // The rosette used for ayah markers, in its 24-unit box.
    const pts = [
      Offset(12, 2), Offset(14.6, 4.2), Offset(18, 3.7), Offset(18.6, 7.1), Offset(21.5, 9), Offset(20, 12),
      Offset(21.5, 15), Offset(18.6, 16.9), Offset(18, 20.3), Offset(14.6, 19.8), Offset(12, 22), Offset(9.4, 19.8),
      Offset(6, 20.3), Offset(5.4, 16.9), Offset(2.5, 15), Offset(4, 12), Offset(2.5, 9), Offset(5.4, 7.1),
      Offset(6, 3.7), Offset(9.4, 4.2),
    ];
    return Path()..addPolygon(pts, true);
  }

  final Paint _fill = Paint()..color = _Palette.ivory;
  final Paint _stroke = Paint()
    ..color = _Palette.gold
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.55
    ..strokeJoin = StrokeJoin.round;
  final Paint _bar = Paint()..color = _Palette.green;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);
    canvas.drawPath(_star, _fill);
    canvas.drawPath(_star, _stroke);
    for (var i = 0; i < 5; i++) {
      // [bars] holds each bar's height as a share of its full height.
      final h = _barHeights[i] * bars[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(_barCentres[i], 12), width: 1.62, height: h),
          const Radius.circular(0.81),
        ),
        _bar,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StarPainter old) => !_listEquals(old.bars, bars);
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ── the diagram ──────────────────────────────────────────────────────────────

/// One makhraj on the sound's path: where it lights, and the letters born there.
class _Point {
  final Offset at;
  final double time;
  final String letters;
  final Offset lettersAt;
  const _Point(this.at, this.time, this.letters, this.lettersAt);
}

class _Label {
  final String text;
  final Offset at;
  final double time;
  final Offset? leaderFrom;
  final Offset? leaderTo;
  const _Label(this.text, this.at, this.time, [this.leaderFrom, this.leaderTo]);
}

class _DiagramPainter extends CustomPainter {
  final Animation<double> anim;
  final double seconds;
  final TextDirection direction;

  _DiagramPainter(this.anim, this.seconds, this.direction) : super(repaint: anim);

  // Geometry, in the design box the diagram was drawn in (about 250 x 270,
  // y from 110). The head faces left: the direction Arabic is read.
  static final Path _head = Path()
    ..moveTo(190, 382)
    ..cubicTo(190, 350, 196, 322, 212, 300)
    ..cubicTo(232, 272, 240, 234, 232, 196)
    ..cubicTo(222, 146, 180, 116, 132, 118)
    ..cubicTo(94, 120, 70, 144, 64, 176)
    ..cubicTo(62, 188, 58, 196, 50, 206)
    ..cubicTo(44, 214, 42, 222, 48, 226)
    ..cubicTo(54, 229, 60, 230, 60, 236)
    ..cubicTo(60, 240, 56, 243, 57, 247)
    ..cubicTo(58, 252, 64, 252, 63, 257)
    ..cubicTo(62, 262, 57, 264, 60, 270)
    ..cubicTo(64, 278, 76, 280, 84, 286)
    ..cubicTo(96, 294, 118, 296, 128, 304)
    ..cubicTo(134, 312, 134, 340, 132, 382);
  static final Path _palate = Path()
    ..moveTo(66, 238)
    ..cubicTo(84, 232, 110, 230, 132, 234)
    ..cubicTo(146, 237, 154, 244, 158, 254);
  static final Path _nasal = Path()
    ..moveTo(60, 222)
    ..cubicTo(80, 208, 112, 202, 142, 208)
    ..cubicTo(156, 211, 164, 222, 162, 236);
  static final Path _tongue = Path()
    ..moveTo(70, 262)
    ..cubicTo(80, 250, 104, 244, 128, 248)
    ..cubicTo(146, 251, 154, 262, 152, 282)
    ..cubicTo(151, 296, 150, 306, 152, 318);
  static final Path _throat = Path()
    ..moveTo(166, 240)
    ..cubicTo(170, 262, 170, 300, 168, 330)
    ..cubicTo(167, 350, 166, 366, 164, 382);
  static final Path _sound = Path()
    ..moveTo(160, 360)
    ..cubicTo(160, 334, 160, 312, 160, 292)
    ..cubicTo(160, 272, 154, 258, 140, 250)
    ..cubicTo(124, 242, 100, 242, 80, 250)
    ..cubicTo(70, 254, 62, 256, 50, 257)
    ..lineTo(20, 257);

  static final ui.PathMetric _headM = _head.computeMetrics().first;
  static final ui.PathMetric _palateM = _palate.computeMetrics().first;
  static final ui.PathMetric _nasalM = _nasal.computeMetrics().first;
  static final ui.PathMetric _tongueM = _tongue.computeMetrics().first;
  static final ui.PathMetric _throatM = _throat.computeMetrics().first;
  static final ui.PathMetric _soundM = _sound.computeMetrics().first;

  // The sound travels 0.65s -> 1.45s; each makhraj lights as it arrives.
  static const double _travelStart = 0.65;
  static const double _travelDur = 0.8;
  static const _points = [
    _Point(Offset(160, 344), 0.71, 'ء ه', Offset(200, 348)),
    _Point(Offset(160, 318), 0.79, 'ع ح', Offset(200, 300)),
    _Point(Offset(160, 292), 0.87, 'غ خ', Offset(200, 282)),
    _Point(Offset(140, 250), 1.04, 'ق ك', Offset(126, 272)),
    _Point(Offset(108, 244), 1.15, 'ج ش ي', Offset(96, 272)),
    _Point(Offset(80, 250), 1.24, 'ت د ط', Offset(72, 286)),
    _Point(Offset(56, 256), 1.33, 'ب م و', Offset(10, 238)),
  ];
  static const _labels = [
    _Label('الحلق', Offset(200, 322), 0.73, Offset(163, 318), Offset(196, 318)),
    _Label('اللسان', Offset(92, 184), 1.05, Offset(112, 240), Offset(112, 190)),
    _Label('الخيشوم', Offset(64, 170), 1.17),
    _Label('الشفتان', Offset(4, 316), 1.35, Offset(52, 260), Offset(30, 300)),
  ];

  /// Text laid out once per string and per tenth of opacity, so fading a
  /// label costs neither a layout nor a saveLayer on every frame.
  final Map<String, List<TextPainter?>> _textCache = {};

  TextPainter _text(String s, double size, Color color, double opacity) {
    final level = (opacity * 10).round().clamp(1, 10);
    final slots = _textCache.putIfAbsent(s, () => List<TextPainter?>.filled(11, null));
    return slots[level] ??= TextPainter(
      text: TextSpan(
        text: s,
        style: AppTypography.arabicWord(fontSize: size, color: color.withValues(alpha: level / 10), weight: FontWeight.w700),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
  }

  // Paints are made once and only their colours change per frame.
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  final Paint _core = Paint();
  final Paint _bloom = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  final Paint _trailGlow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 5
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  final Paint _trail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2.1;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * seconds;

    // The whole diagram steps back once the sound has left the lips.
    final gone = Curves.easeInCubic.transform(_seg(t, 1.63, 0.35));
    final alpha = 1 - gone;
    if (alpha <= 0) return;

    // Fit the design box to the screen, centred a little above the middle.
    final width = math.min(size.width * 0.84, 330.0);
    final k = width / 250;
    final boxHeight = 280 * k;
    final origin = Offset((size.width - width) / 2, size.height * 0.46 - boxHeight / 2);
    canvas.save();
    canvas.translate(origin.dx + width / 2, origin.dy + boxHeight / 2);
    canvas.scale(1 - 0.18 * gone);
    canvas.translate(-width / 2, -boxHeight / 2 - 20 * gone);
    canvas.scale(k);
    canvas.translate(0, -110);

    // 1. The head, palate, nose, tongue and throat draw themselves.
    _drawPart(canvas, _headM, _seg(t, 0.05, 0.65), _Palette.line, 0.75 * alpha, 1.3);
    _drawPart(canvas, _palateM, _seg(t, 0.25, 0.4), _Palette.line, 0.45 * alpha, 1.1);
    _drawPart(canvas, _nasalM, _seg(t, 0.3, 0.4), _Palette.line, 0.3 * alpha, 1.0);
    _drawPart(canvas, _tongueM, _seg(t, 0.33, 0.42), _Palette.tongue, 0.6 * alpha, 1.6);
    _drawPart(canvas, _throatM, _seg(t, 0.35, 0.4), _Palette.line, 0.38 * alpha, 1.1);

    // 2. Khayshum and jawf: the resonance of ghunnah and the open cavity.
    _drawBloom(canvas, const Offset(104, 216), 80, 22, _bloomLevel(t, 1.17) * alpha);
    _drawBloom(canvas, const Offset(116, 246), 88, 30, _bloomLevel(t, 1.25) * 0.7 * alpha);

    // 3. The trail behind the sound, and the sound itself.
    final travel = _seg(t, _travelStart, _travelDur);
    if (travel > 0) {
      final lit = _soundM.extractPath(0, _soundM.length * travel);
      _trailGlow.color = _Palette.gold.withValues(alpha: 0.35 * alpha);
      _trail.color = _Palette.light.withValues(alpha: 0.9 * alpha);
      canvas.drawPath(lit, _trailGlow);
      canvas.drawPath(lit, _trail);
    }
    final spark = _soundM.getTangentForOffset(_soundM.length * travel)?.position;
    if (spark != null && t >= _travelStart - 0.15) {
      final sparkAlpha = (t < _travelStart ? _seg(t, _travelStart - 0.15, 0.15) : 1.0) * alpha;
      _glow.color = _Palette.light.withValues(alpha: 0.9 * sparkAlpha);
      _core.color = _Palette.spark.withValues(alpha: sparkAlpha);
      canvas.drawCircle(spark, 9, _glow);
      canvas.drawCircle(spark, 4.6, _core);
    }

    // 4. Each makhraj lights as the sound reaches it; its letters flash.
    for (final p in _points) {
      final pop = _seg(t, p.time, 0.3);
      if (pop > 0) {
        final s = pop < 0.6 ? 0.2 + 1.15 * (pop / 0.6) : 1.35 - 0.35 * ((pop - 0.6) / 0.4);
        _glow.color = _Palette.light.withValues(alpha: 0.75 * alpha);
        _core.color = _Palette.light.withValues(alpha: alpha);
        canvas.drawCircle(p.at, 7 * s, _glow);
        canvas.drawCircle(p.at, 3.6 * s, _core);
      }
      final flash = _flash(t, p.time, 0.6) * alpha;
      if (flash > 0.05) _paintText(canvas, _text(p.letters, 12, _Palette.onDeep, flash), p.lettersAt);
    }

    // 5. The names of the makharij, with a hairline to where they are.
    for (final l in _labels) {
      final a = _seg(t, l.time, 0.3) * alpha;
      if (a <= 0) continue;
      if (l.leaderFrom != null) {
        _linePaint
          ..color = _Palette.gold.withValues(alpha: 0.6 * a)
          ..strokeWidth = 0.8;
        canvas.drawLine(l.leaderFrom!, l.leaderTo!, _linePaint);
      }
      _paintText(canvas, _text(l.text, 13, _Palette.label, a), l.at);
    }

    // 6. The recitation leaves the lips as rings.
    for (final start in const [1.35, 1.45, 1.55]) {
      final r = _seg(t, start, 0.55);
      if (r <= 0 || r >= 1) continue;
      final opacity = (r < 0.2 ? r / 0.2 : 1 - (r - 0.2) / 0.8) * 0.9 * alpha;
      _ring.color = _Palette.light.withValues(alpha: opacity);
      canvas.drawCircle(const Offset(38, 257), 12 * (0.2 + 3.0 * Curves.easeOutCubic.transform(r)), _ring);
    }

    canvas.restore();
  }

  double _bloomLevel(double t, double start) {
    final p = _seg(t, start, 0.5);
    if (p <= 0) return 0;
    return p < 0.4 ? 0.55 * (p / 0.4) : 0.55 - 0.37 * ((p - 0.4) / 0.6);
  }

  void _drawPart(Canvas canvas, ui.PathMetric m, double progress, Color color, double opacity, double width) {
    if (progress <= 0) return;
    final eased = Curves.easeInOutCubic.transform(progress);
    _linePaint
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width;
    canvas.drawPath(m.extractPath(0, m.length * eased), _linePaint);
  }

  void _drawBloom(Canvas canvas, Offset centre, double w, double h, double opacity) {
    if (opacity <= 0) return;
    _bloom.color = _Palette.gold.withValues(alpha: opacity);
    canvas.drawOval(Rect.fromCenter(center: centre, width: w, height: h), _bloom);
  }

  void _paintText(Canvas canvas, TextPainter painter, Offset baselineLeft) {
    // Offsets in the design are the text's left edge at its baseline.
    final top = baselineLeft.dy - painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.paint(canvas, Offset(baselineLeft.dx, top));
  }

  @override
  bool shouldRepaint(_DiagramPainter old) => old.seconds != seconds || old.direction != direction;
}
