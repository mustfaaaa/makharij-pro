import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/progress/presentation/widgets/performance_hero.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_radii.dart';

/// The Progress tab's hero card has to survive the system font scale. The app
/// clamps the scale at 1.3 (see app.dart), so that is the worst case it can
/// actually be asked to render, and 320dp is the narrowest phone it targets.
///
/// `_OldHero` below is the layout as it shipped, kept only so this file shows
/// the failure it was written against rather than asserting into the void.
Future<List<FlutterErrorDetails>> _renderAndCollect(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double textScale,
}) async {
  final caught = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = caught.add;

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  FlutterError.onError = previous;
  return caught;
}

List<String> _overflows(List<FlutterErrorDetails> errors) => errors
    .map((e) => e.exception.toString())
    .where((m) => m.contains('overflowed'))
    .toList();

void main() {
  // A phone at the narrow end, and the largest text the app allows.
  const sizes = {'320x640': Size(320, 640), '360x760': Size(360, 760)};
  const scales = [1.0, 1.15, 1.3];

  group('PerformanceHero (current)', () {
    for (final entry in sizes.entries) {
      for (final scale in scales) {
        testWidgets('no overflow at ${entry.key} @${scale}x', (tester) async {
          final errors = await _renderAndCollect(
            tester,
            const PerformanceHero(overallAccuracy: 87),
            size: entry.value,
            textScale: scale,
          );
          expect(_overflows(errors), isEmpty,
              reason: 'hero overflowed at ${entry.key} text scale $scale');
        });
      }
    }

    testWidgets('keeps its 220dp minimum at the default text size',
        (tester) async {
      await _renderAndCollect(
        tester,
        const PerformanceHero(overallAccuracy: 87),
        size: const Size(360, 760),
        textScale: 1.0,
      );
      expect(tester.getSize(find.byType(PerformanceHero)).height,
          greaterThanOrEqualTo(220.0));
    });

    testWidgets('grows past 220dp rather than clipping at 1.3x',
        (tester) async {
      await _renderAndCollect(
        tester,
        const PerformanceHero(overallAccuracy: 87),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(tester.getSize(find.byType(PerformanceHero)).height,
          greaterThan(220.0));
    });
  });

  group('_OldHero (regression witness)', () {
    testWidgets('the shipped layout overflowed at 320dp @1.3x', (tester) async {
      final errors = await _renderAndCollect(
        tester,
        const _OldHero(overallAccuracy: 87),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      // ignore: avoid_print
      print('OLD HERO overflow reports: ${_overflows(errors)}');
      expect(_overflows(errors), isNotEmpty);
    });
  });
}

/// Verbatim copy of the hero as it shipped, for the regression witness above.
class _OldHero extends StatelessWidget {
  final double overallAccuracy;
  const _OldHero({required this.overallAccuracy});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.lgRadius,
      child: Stack(
        children: [
          const SizedBox(height: 220, width: double.infinity),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERFORMANCE DASHBOARD',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: CircularProgressIndicator(
                                value: overallAccuracy / 100,
                                strokeWidth: 7,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${overallAccuracy.round()}%',
                                    style: const TextStyle(
                                        fontSize: 24, height: 1.0)),
                                const Text('accuracy',
                                    style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Overall Accuracy',
                                style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 4),
                            const Text(
                                'Great progress — you’re improving steadily.',
                                style:
                                    TextStyle(fontSize: 13.5, height: 1.35)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspace_premium_rounded,
                                          size: 14),
                                      SizedBox(width: 4),
                                      Text('Intermediate',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.trending_up_rounded, size: 14),
                                      SizedBox(width: 3),
                                      Text('+4%',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
