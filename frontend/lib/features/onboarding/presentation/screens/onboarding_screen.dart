import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/tajweed_error.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/quran_text_repository.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/cinematic.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../shared/ui/tajweed_marks.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// Three screens, one mood: a photograph laid into deep green, light falling
/// across it, and the Quran in gold.
///
/// 1. Where the name comes from -- the ayah Rattil is named after.
/// 2. Recite, and it listens -- words igniting as a voice reaches them.
/// 3. Understand, then try again -- a flagged word, explained and cleared.
///
/// The Quranic text is read from the bundled asset, never typed here, so it
/// matches the reader byte for byte. The demonstrations on screens 2 and 3 are
/// labelled as examples: nothing on these screens is anyone's result.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  static const _count = 3;
  final _pages = PageController();
  int _index = 0;

  /// One slow loop for everything ambient: camera drift, light, dust, the wave.
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  /// Each page's own entrance, replayed whenever the page is arrived at.
  late final List<AnimationController> _entrances = [
    for (var i = 0; i < _count; i++) AnimationController(vsync: this, duration: const Duration(milliseconds: 2400)),
  ];

  String _ayah = '';
  List<String> _basmala = const [];
  String _flaggedWord = '';

  @override
  void initState() {
    super.initState();
    _loadText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        for (final c in _entrances) {
          c.value = 1;
        }
      } else {
        _ambient.repeat();
        _entrances[0].forward();
      }
    });
  }

  Future<void> _loadText() async {
    final repo = QuranTextRepository.instance;
    final muzzammil = await repo.ayahsForSurah(73);
    final fatihah = await repo.ayahsForSurah(1);
    if (!mounted) return;
    setState(() {
      // Al-Muzzammil 73:4, the ayah the word "Rattil" comes from.
      _ayah = muzzammil.length >= 4 ? muzzammil[3].arabicText : '';
      _basmala = fatihah.isEmpty ? const [] : fatihah.first.arabicText.split(' ');
      // The last word of Al-Fatihah: a Madd the reciter must hold.
      _flaggedWord = fatihah.length >= 7 ? fatihah[6].arabicText.split(' ').last : '';
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _ambient.dispose();
    for (final c in _entrances) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (MediaQuery.disableAnimationsOf(context)) return;
    _entrances[i]
      ..reset()
      ..forward();
  }

  void _finish() {
    Services.prefs.setOnboardingSeen();
    context.go(RoutePaths.welcome);
  }

  void _next() {
    if (_index == _count - 1) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Cinema.deep,
        body: Stack(
          children: [
            PageView(
              controller: _pages,
              onPageChanged: _onPageChanged,
              children: [
                _NamePage(ambient: _ambient, entrance: _entrances[0], ayah: _ayah),
                _ListensPage(ambient: _ambient, entrance: _entrances[1], words: _basmala),
                _CorrectedPage(ambient: _ambient, entrance: _entrances[2], word: _flaggedWord),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4, end: 8),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(foregroundColor: Cinema.onDeep),
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding + 4, 0, AppSpacing.screenPadding + 4, AppSpacing.md),
                  child: Row(
                    children: [
                      Semantics(
                        label: 'Step ${_index + 1} of $_count',
                        child: Row(
                          children: [
                            for (var i = 0; i < _count; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsetsDirectional.only(end: 6),
                                width: i == _index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _index ? Cinema.gold : Cinema.dots,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: Cinema.gold,
                          foregroundColor: const Color(0xFF1D211F),
                          minimumSize: const Size(112, 50),
                        ),
                        child: Text(_index == _count - 1 ? 'Begin' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── shared page parts ────────────────────────────────────────────────────────

/// Progress of a segment of the entrance, in seconds, 0..1.
double _seg(double seconds, double start, double dur) => ((seconds - start) / dur).clamp(0.0, 1.0);

class _Copy extends StatelessWidget {
  final Animation<double> entrance;
  final String title;
  final String body;
  final double delay;
  const _Copy({required this.entrance, required this.title, required this.body, this.delay = 0.2});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) {
        final s = entrance.value * 2.4;
        final a = Curves.easeOutCubic.transform(_seg(s, delay, 0.45));
        final b = Curves.easeOutCubic.transform(_seg(s, delay + 0.1, 0.45));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: a,
              child: Transform.translate(
                offset: Offset(0, (1 - a) * 12),
                child: Semantics(
                  header: true,
                  child: Text(title, style: AppTypography.displayText(fontSize: 28, color: Cinema.onDeep, height: 1.2)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: b,
              child: Transform.translate(
                offset: Offset(0, (1 - b) * 12),
                child: Text(
                  body,
                  style: textTheme.bodyMedium?.copyWith(color: Cinema.onDeepMuted, height: 1.55),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The layout every page shares: photograph above, words below, room for the
/// controls at the bottom.
class _Stage extends StatelessWidget {
  final List<Widget> background;
  final Widget feature;
  final Widget copy;
  const _Stage({required this.background, required this.feature, required this.copy});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            ...background,
            Positioned(left: 0, right: 0, top: h * 0.2, height: h * 0.43, child: feature),
            Positioned(
              left: AppSpacing.screenPadding + 4,
              right: AppSpacing.screenPadding + 4,
              top: h * 0.645,
              child: copy,
            ),
          ],
        );
      },
    );
  }
}

class _ExampleTag extends StatelessWidget {
  const _ExampleTag();

  @override
  Widget build(BuildContext context) {
    return Text(
      'AN EXAMPLE',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFFD8C38F),
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ── 1 · where the name comes from ───────────────────────────────────────────

class _NamePage extends StatelessWidget {
  final Animation<double> ambient;
  final Animation<double> entrance;
  final String ayah;
  const _NamePage({required this.ambient, required this.entrance, required this.ayah});

  @override
  Widget build(BuildContext context) {
    return _Stage(
      background: [
        CinematicPhoto(asset: AppPhotos.archesIvory, ambient: ambient, alignment: const Alignment(0, -0.2), shade: 0.35),
        LightBeam(ambient: ambient, left: -40, top: -40, width: 150, height: 520, angle: -22, strength: 0.55),
        LightBeam(ambient: ambient, left: 90, top: -60, width: 80, height: 480, angle: -22, strength: 0.45, phase: 0.35),
        DustField(ambient: ambient, seed: 7),
      ],
      feature: AnimatedBuilder(
        animation: entrance,
        builder: (context, _) {
          final s = entrance.value * 2.4;
          final text = Curves.easeOut.transform(_seg(s, 0.4, 0.9));
          final ref = _seg(s, 0.9, 0.5);
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Opacity(
                opacity: text,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(
                    ayah,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.quran(fontSize: 26, color: Cinema.goldLight, height: 1.9).copyWith(
                      shadows: [Shadow(color: Cinema.gold.withValues(alpha: 0.55), blurRadius: 18)],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: ref,
                child: Text(
                  'Al-Muzzammil 73:4',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Cinema.onDeepMuted),
                ),
              ),
              const SizedBox(height: 14),
            ],
          );
        },
      ),
      copy: _Copy(
        entrance: entrance,
        delay: 1.2,
        title: 'Recite with care',
        body: '"...and recite the Quran with measured recitation." Rattil, the reciter inside the app, '
            'takes its name from this ayah.',
      ),
    );
  }
}

// ── 2 · recite, and it listens ──────────────────────────────────────────────

class _ListensPage extends StatelessWidget {
  final Animation<double> ambient;
  final Animation<double> entrance;
  final List<String> words;
  const _ListensPage({required this.ambient, required this.entrance, required this.words});

  // When each word of the Basmala ignites, in seconds of the entrance.
  static const _ignite = [0.55, 0.95, 1.35, 1.8];

  @override
  Widget build(BuildContext context) {
    return _Stage(
      background: [
        CinematicPhoto(asset: AppPhotos.rehalCarved, ambient: ambient, alignment: const Alignment(0.3, 0), shade: 0.35),
        LightBeam(ambient: ambient, left: 150, top: -60, width: 110, height: 460, angle: 18, strength: 0.45, phase: 0.2),
        DustField(ambient: ambient, seed: 11),
      ],
      feature: AnimatedBuilder(
        animation: Listenable.merge([entrance, ambient]),
        builder: (context, _) {
          final s = entrance.value * 2.4;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const _ExampleTag(),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Wrap(
                  textDirection: TextDirection.rtl,
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  children: [
                    for (var i = 0; i < words.length; i++) _IgnitingWord(words[i], _seg(s, _ignite[math.min(i, _ignite.length - 1)], 0.6)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: CustomPaint(painter: _WavePainter(ambient.value)),
                ),
              ),
            ],
          );
        },
      ),
      copy: _Copy(
        entrance: entrance,
        title: 'Recite. It listens.',
        body: 'Words light up as they are heard. When you stop, each one is checked, and every flag explains itself.',
      ),
    );
  }
}

/// A word going from dim to lit, flaring as the voice reaches it.
class _IgnitingWord extends StatelessWidget {
  final String word;
  final double progress;
  const _IgnitingWord(this.word, this.progress);

  @override
  Widget build(BuildContext context) {
    final flare = progress <= 0 ? 0.0 : (progress < 0.4 ? progress / 0.4 : 1 - 0.5 * ((progress - 0.4) / 0.6));
    final color = Color.lerp(Cinema.onDeep.withValues(alpha: 0.38), Cinema.goldLight, Curves.easeOut.transform(progress))!;
    return Text(
      word,
      textDirection: TextDirection.rtl,
      style: AppTypography.quran(fontSize: 26, color: color, height: 1.9).copyWith(
        shadows: flare > 0 ? [Shadow(color: Cinema.glow.withValues(alpha: 0.9 * flare), blurRadius: 14)] : null,
      ),
    );
  }
}

/// Two sine waves of light flowing beneath the ayah: the recitation itself.
class _WavePainter extends CustomPainter {
  final double phase;
  _WavePainter(this.phase);

  final Paint _bright = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = Cinema.glow.withValues(alpha: 0.9);
  final Paint _soft = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Cinema.gold.withValues(alpha: 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    for (final (paint, amp, speed) in [(_bright, 0.4, 6.0), (_soft, 0.24, 4.0)]) {
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 3) {
        final y = mid + math.sin(x / size.width * 4 * math.pi - phase * 2 * math.pi * speed) * size.height * amp;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.phase != phase;
}

// ── 3 · understand, then try again ──────────────────────────────────────────

class _CorrectedPage extends StatelessWidget {
  final Animation<double> ambient;
  final Animation<double> entrance;
  final String word;
  const _CorrectedPage({required this.ambient, required this.entrance, required this.word});

  @override
  Widget build(BuildContext context) {
    return _Stage(
      background: [
        CinematicPhoto(asset: AppPhotos.homeRehal, ambient: ambient, alignment: const Alignment(0.1, -0.2), shade: 0.55),
        LightBeam(ambient: ambient, left: -30, top: -40, width: 140, height: 480, angle: -24, strength: 0.55, phase: 0.6),
        DustField(ambient: ambient, seed: 19),
      ],
      feature: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding + 4),
        child: AnimatedBuilder(
          animation: entrance,
          builder: (context, _) => _VerdictCard(seconds: entrance.value * 2.4, word: word),
        ),
      ),
      copy: _Copy(
        entrance: entrance,
        delay: 0.4,
        title: 'Understand, then try again',
        body: 'Every flag explains itself. Retry just that word. And if a verdict is wrong, you can say so.',
      ),
    );
  }
}

/// A frosted verdict card that plays the loop once: flagged, tried, cleared.
class _VerdictCard extends StatelessWidget {
  final double seconds;
  final String word;
  const _VerdictCard({required this.seconds, required this.word});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = seconds;
    final appear = Curves.easeOutCubic.transform(_seg(s, 0.15, 0.45));
    final tap = _seg(s, 1.3, 0.45);
    final cleared = _seg(s, 1.6, 0.25);
    final glint = _seg(s, 1.5, 0.5);
    final check = _seg(s, 1.75, 0.35);
    final checkScale = check <= 0 ? 0.0 : (check < 0.65 ? 0.3 + 0.85 * (check / 0.65) : 1.15 - 0.15 * ((check - 0.65) / 0.35));

    return Opacity(
      opacity: appear,
      child: Transform.translate(
        offset: Offset(0, (1 - appear) * 14),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Cinema.onDeep.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Cinema.onDeep.withValues(alpha: 0.22)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ExampleTag(),
                    SizedBox(
                      width: double.infinity,
                      height: 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                word,
                                textDirection: TextDirection.rtl,
                                style: AppTypography.quran(fontSize: 36, color: Cinema.maddOnDeep, height: 1.6),
                              ),
                              Opacity(
                                opacity: 1 - cleared,
                                child: const RuleShapeSwatch(rule: TajweedErrorType.madd, width: 110, color: Cinema.maddOnDeep),
                              ),
                            ],
                          ),
                          // A glint passes over the word as it clears.
                          if (glint > 0 && glint < 1)
                            Positioned.fill(
                              child: ExcludeSemantics(
                                child: FractionallySizedBox(
                                  widthFactor: 0.2,
                                  alignment: Alignment(-1.6 + 3.2 * glint, 0),
                                  child: Transform(
                                    transform: Matrix4.skewX(-0.3),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Cinema.goldLight.withValues(alpha: 0),
                                            Cinema.goldLight.withValues(alpha: 0.75 * math.sin(glint * math.pi)),
                                            Cinema.goldLight.withValues(alpha: 0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            child: Transform.scale(
                              scale: checkScale,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(color: Cinema.gold, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, size: 20, color: Color(0xFF1D211F)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TajweedCopy.headline(TajweedErrorType.madd),
                      style: AppTypography.displayText(fontSize: 18, color: Cinema.onDeep, height: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            TajweedCopy.fallbackBody(TajweedErrorType.madd),
                            style: textTheme.bodySmall?.copyWith(color: Cinema.onDeepMuted),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _DemoButton(tap: tap, cleared: cleared),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Try this word", pressed by the demonstration, becoming "Cleared".
class _DemoButton extends StatelessWidget {
  final double tap;
  final double cleared;
  const _DemoButton({required this.tap, required this.cleared});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: const Color(0xFF1D211F), fontWeight: FontWeight.w700);
    final ripple = tap > 0 && tap < 1;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Cinema.gold,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 1 - cleared, child: Text('Try this word', style: style)),
              Opacity(opacity: cleared, child: Text('Cleared', style: style)),
              if (ripple)
                Transform.scale(
                  scale: 0.3 + 1.4 * tap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5 * (1 - tap)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
