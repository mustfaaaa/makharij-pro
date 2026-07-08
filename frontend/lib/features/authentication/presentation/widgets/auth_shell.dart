import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/frosted_back_button.dart';
import '../../../../shared/widgets/illustrations/auth_background.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

enum AuthTab { login, signup }

/// Shared layout for the auth screens (login / register / forgot password):
/// a photographic header with the title/subtitle sitting over it, and a
/// full-width white sheet with rounded top corners that holds the form. The
/// sheet runs edge-to-edge so there are no awkward side gaps.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;

  /// When set, a Log In / Sign up segmented toggle is shown at the top of the
  /// sheet (login & register). Left null on sub-flows like forgot password.
  final AuthTab? activeTab;

  final Widget child;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: AuthBackground()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header over the image ──────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'MakharijPro',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── White sheet with the form ──────────────────────────────
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (activeTab != null) ...[
                            _AuthTabs(active: activeTab!),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Back to the welcome screen.
            const SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: FrostedBackButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented Log In / Sign up switch shown at the top of the sheet. Tapping the
/// inactive tab swaps to the other screen (keeping the welcome screen beneath).
class _AuthTabs extends StatelessWidget {
  final AuthTab active;
  const _AuthTabs({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tab(context, 'Log In', AuthTab.login, RoutePaths.login),
          _tab(context, 'Sign up', AuthTab.signup, RoutePaths.register),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, AuthTab tab, String route) {
    final selected = tab == active;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : () => context.pushReplacement(route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
