import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/hijri_date.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/illustrations/mandala_background.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: MandalaBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'How MakharijPro works',
                        icon: Icon(
                          Icons.help_outline_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => context.push(RoutePaths.helpFaq),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      children: [
                        const Spacer(),
                        StaggeredFadeSlide(
                          index: 0,
                          child: _BreathingMark(controller: _breathController),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        StaggeredFadeSlide(
                          index: 1,
                          child: _GlassCard(
                            child: Column(
                              children: [
                                Text(
                                  'MakharijPro AI',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Real-time Tajweed error detection for your Quran recitation',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontSize: 13, height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        StaggeredFadeSlide(
                          index: 2,
                          child: _WelcomeButton(
                            label: 'Create Account',
                            filled: true,
                            onTap: () => context.push(RoutePaths.register),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        StaggeredFadeSlide(
                          index: 3,
                          child: _WelcomeButton(
                            label: 'Sign In',
                            filled: false,
                            onTap: () => context.push(RoutePaths.login),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 14,
            right: 18,
            child: Text(
              HijriDate.currentYearLabel(),
              style: AppTypography.arabicWord(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular "Mim" mark, gently scaling and glowing on a slow breathing
/// loop — a calm, meditative entrance cue rather than a static icon.
class _BreathingMark extends StatelessWidget {
  final AnimationController controller;
  const _BreathingMark({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return Transform.scale(
          scale: 1.0 + t * 0.045,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySurface,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22 + t * 0.3),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: Text(
        'م',
        style: AppTypography.arabicVerse(
          fontSize: 52,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Frosted card separating the title/tagline from the drifting background
/// texture behind it — reuses the same glass tokens as the bottom nav/app
/// bar (see AppColors.glassSurface/glassBorder).
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Self-contained button (rather than the shared PrimaryButton/OutlinedAppButton)
/// so it can own a press-driven "lift" — the gradient's shadow grows/shrinks
/// with the press state instead of just a flat scale change.
class _WelcomeButton extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _WelcomeButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: widget.filled
                ? LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.filled ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: widget.filled
                ? null
                : Border.all(color: AppColors.border, width: 1.4),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: _pressed ? 0.18 : 0.32,
                      ),
                      blurRadius: _pressed ? 8 : 18,
                      offset: Offset(0, _pressed ? 2 : 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.filled ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
