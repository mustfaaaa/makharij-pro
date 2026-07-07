import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/validators.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/google_sign_in_button.dart';
import '../../../../shared/widgets/buttons/google_web_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/illustrations/mandala_background.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _webGoogleReady = false;
  String? _emailError;
  String? _passwordError;
  StreamSubscription<void>? _googleWebSub;

  @override
  void initState() {
    super.initState();
    // Web can't use a custom button + programmatic sign-in (see
    // GoogleSignIn.supportsAuthenticate) — it must render Google's own
    // button and react to the sign-in completing asynchronously instead.
    if (kIsWeb) {
      Services.auth.initializeGoogleSignIn().then((_) {
        if (!mounted) return;
        setState(() => _webGoogleReady = true);
      });
      _googleWebSub = Services.auth.googleWebSignInCompleted.listen(
        (_) {
          if (mounted) context.go(RoutePaths.home);
        },
        onError: (Object e) {
          if (!mounted) return;
          final message = Services.auth.errorMessageFor(e);
          if (message.isNotEmpty) {
            AppSnackbar.show(context, message, isError: true);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _googleWebSub?.cancel();
    super.dispose();
  }

  bool _validate() {
    final emailError = Validators.email(_emailController.text);
    final passwordError = Validators.password(_passwordController.text);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  void _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      await Services.auth.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      context.go(RoutePaths.home);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        Services.auth.errorMessageFor(e),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _googleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      await Services.auth.signInWithGoogle();
      if (!mounted) return;
      context.go(RoutePaths.home);
    } catch (e) {
      if (!mounted) return;
      final message = Services.auth.errorMessageFor(e);
      if (message.isNotEmpty) AppSnackbar.show(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Widget _buildGoogleButton() {
    if (!kIsWeb) {
      return GoogleSignInButton(
        onPressed: _googleSignIn,
        isLoading: _googleLoading,
      );
    }
    // Web must render Google's own button (see GoogleSignIn.supportsAuthenticate);
    // it handles its own account-picker UI, so there's no separate loading state to show here.
    if (!_webGoogleReady) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Center(child: renderGoogleWebButton()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: MandalaBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 2 * AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Sign in to continue your Tajweed journey',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        CustomTextField(
                          label: 'Email',
                          hint: 'you@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline,
                          errorText: _emailError,
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomTextField(
                          label: 'Password',
                          hint: '••••••••',
                          controller: _passwordController,
                          obscureText: _obscure,
                          prefixIcon: Icons.lock_outline,
                          errorText: _passwordError,
                          onChanged: (_) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                context.push(RoutePaths.forgotPassword),
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PrimaryButton(
                          label: 'Sign In',
                          onPressed: _submit,
                          isLoading: _loading,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _OrDivider(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildGoogleButton(),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            GestureDetector(
                              onTap: () => context.push(RoutePaths.register),
                              child: Text(
                                'Register',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 12,
            right: 16,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('or', style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
