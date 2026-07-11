import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';

/// New auth layout matching the provided mockups: the ornamental arch-door
/// photo fills the top of the screen, a cream sheet with rounded top corners
/// holds the form, and a gold-ringed 'م' logo circle straddles the sheet edge.
class ArchAuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const ArchAuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final height = MediaQuery.of(context).size.height;
    // The sheet starts roughly a third of the way down, like the mockup.
    final imageHeight = height * 0.38;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF3A2C1B),
        body: Stack(
          children: [
            // ── Arch door photo across the top ─────────────────────────
            // Aligned toward the top so the arch's upper corners stay
            // visible, then blended softly into the sheet below.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageHeight + 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/arch_door.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.55, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Cream sheet with the form ───────────────────────────────
            Positioned.fill(
              top: imageHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    58, // room for the overlapping logo circle
                    24,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
            // ── Gold-ringed 'م' logo straddling the sheet edge ──────────
            Positioned(
              top: imageHeight - 52,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'م',
                    style: AppTypography.arabicVerse(fontSize: 44, color: AppColors.primaryDark, height: 1.0),
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

/// "Or … with email" divider with hairline rules either side.
class AuthOrDivider extends StatelessWidget {
  final String label;
  const AuthOrDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

/// Rounded white input pill with a gold prefix icon, matching the mockup
/// fields exactly.
class AuthField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const AuthField({
    super.key,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: errorText != null ? AppColors.error : AppColors.border),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 16),
              prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 22),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: Text(errorText!, style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ],
    );
  }
}

/// The wide gold gradient CTA button (Login / Sign Up) from the mockups.
class AuthGoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const AuthGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryLight, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
      ),
    );
  }
}
