import 'package:flutter/material.dart';

/// Full-bleed photographic backdrop for the auth screens. The image covers the
/// header area (the lower part of the screen is covered by the white form
/// sheet), darkened toward the top so the white header title/subtitle read
/// cleanly against it.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF17130E),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login.jpeg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          // Darken the top so the white header text stays legible; fades out
          // before the sheet so the middle of the photo keeps its colour.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x4D000000),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.45, 0.75],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
