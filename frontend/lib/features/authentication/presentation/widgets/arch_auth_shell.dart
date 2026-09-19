import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

/// The frame of every sign-in screen: a calm photograph of arched windows
/// that melts into the page, the brand mark, a headline in Amiri, and the
/// form. The photograph is decoration and shrinks away when the keyboard is
/// up, so the fields and the button stay in view.
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final top = MediaQuery.paddingOf(context).top;
    final photoHeight = keyboard ? top + 56 : MediaQuery.sizeOf(context).height * 0.26 + top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const AppPhoto(AppPhotos.archesIvory, alignment: Alignment(0, -0.2)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5, 1.0],
                        colors: [
                          AppColors.photoScrim.withValues(alpha: 0.35),
                          AppColors.background.withValues(alpha: 0.25),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                  if (Navigator.of(context).canPop())
                    Positioned(
                      top: top + 4,
                      left: 8,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface.withValues(alpha: 0.85),
                          foregroundColor: AppColors.textPrimary,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding + 4, 0, AppSpacing.screenPadding + 4, AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!keyboard) ...[
                        const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 52)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Semantics(header: true, child: Text(title, style: textTheme.displaySmall)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.lg),
                      child,
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

/// "or" between Google and email sign-in.
class AuthOrDivider extends StatelessWidget {
  final String label;
  const AuthOrDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: AppColors.divider));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        line,
      ],
    );
  }
}

/// A form field with its label always visible above it -- never a placeholder
/// that disappears as you type -- an icon, a focus ring and an inline error.
class AuthField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Autofill hints, so a password manager can recognise and fill the field.
  final List<String>? autofillHints;

  /// Keyboard action, so the email field advances to the password field.
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;

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
    this.autofillHints,
    this.textInputAction,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // The field carries the label for screen readers; the visible copy above
    // it is excluded so it is not announced twice.
    return Semantics(
      textField: true,
      label: hint,
      hint: errorText,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(hint, style: textTheme.labelLarge?.copyWith(color: AppColors.textSecondary)),
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 21),
            suffixIcon: suffixIcon,
            errorText: errorText,
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.mdRadius,
              borderSide: BorderSide(color: AppColors.borderStrong.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

/// The primary action of an auth form: deep green, full width, with an inline
/// spinner that keeps the button's size while the request is in flight.
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
    return Semantics(
      button: true,
      enabled: !isLoading,
      label: isLoading ? '$label, in progress' : label,
      excludeSemantics: true,
      child: SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.85),
          ),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.textOnPrimary),
                )
              : Text(label),
        ),
      ),
    );
  }
}
