import 'package:flutter/material.dart';

/// Caps content width and centers it on tablet-width screens so single-
/// column lists and forms don't stretch edge-to-edge into unreadably wide
/// lines. A no-op on phone widths.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
