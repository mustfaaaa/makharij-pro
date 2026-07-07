import 'package:flutter/material.dart';

/// A single centered mandala sitting behind screen content as a decorative
/// backdrop. Expects a transparent-background PNG (gold line art, everything
/// else transparent) at `assets/images/mandala.png`. Until that file exists
/// it renders nothing (errorBuilder), so screens stay clean.
class MandalaBackground extends StatelessWidget {
  final double opacity;
  const MandalaBackground({super.key, this.opacity = 0.68});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            'assets/images/mandala.png',
            width: size.width * 2.25,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
