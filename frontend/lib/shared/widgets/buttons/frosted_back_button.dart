import 'package:flutter/material.dart';

/// A circular, translucent back button that stays legible on top of imagery.
/// Used on the auth screens where the hero photo runs to the very top edge,
/// behind the transparent app bar, so a plain dark arrow would disappear
/// against the picture.
class FrostedBackButton extends StatelessWidget {
  const FrostedBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: Material(
          color: Colors.black.withValues(alpha: 0.32),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            iconSize: 20,
            color: Colors.white,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}
