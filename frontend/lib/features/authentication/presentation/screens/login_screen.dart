import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/google_sign_in_button.dart';
import '../../../../shared/widgets/buttons/google_web_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/arch_auth_shell.dart';

/// Login screen rebuilt to the provided mockup: arch-door photo header,
/// cream sheet, 'م' logo circle, Google-first sign in, gold Login button.
/// All authentication logic is unchanged from the previous version.
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
      AppSnackbar.show(context, Services.auth.errorMessageFor(e), isError: true);
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
      return GoogleSignInButton(onPressed: _googleSignIn, isLoading: _googleLoading);
    }
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
    return ArchAuthShell(
      title: 'MakharijPro AI',
      subtitle: 'Login to Your Journey',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGoogleButton(),
          const SizedBox(height: 20),
          const AuthOrDivider(label: 'Or log in with email'),
          const SizedBox(height: 20),
          AuthField(
            hint: 'Email',
            icon: Icons.mail_rounded,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: 16),
          AuthField(
            hint: 'Password',
            icon: Icons.lock_rounded,
            controller: _passwordController,
            obscureText: _obscure,
            errorText: _passwordError,
            onChanged: (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.push(RoutePaths.forgotPassword),
              child: Text(
                'Forgot password?',
                style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AuthGoldButton(label: 'Login', onPressed: _submit, isLoading: _loading),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
              GestureDetector(
                onTap: () => context.pushReplacement(RoutePaths.register),
                child: Text(
                  'Sign Up',
                  style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
