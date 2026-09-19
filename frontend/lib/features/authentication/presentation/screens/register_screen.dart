import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/google_sign_in_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/arch_auth_shell.dart';

/// Sign-up screen rebuilt to the provided mockup: arch-door photo header,
/// 'م' logo circle, "Create Your Account" heading, Google-first, Full Name /
/// Email / Create Password fields, Terms checkbox and gold Sign Up button.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _agreedToTerms = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final nameError = Validators.name(_nameController.text);
    final emailError = Validators.email(_emailController.text);
    final passwordError = Validators.password(_passwordController.text);
    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return nameError == null && emailError == null && passwordError == null;
  }

  void _submit() async {
    if (!_validate()) return;
    if (!_agreedToTerms) {
      AppSnackbar.show(context, 'Please agree to the Terms of Service to continue.', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await Services.auth.registerWithEmail(
        name: _nameController.text,
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

  @override
  Widget build(BuildContext context) {
    return ArchAuthShell(
      title: 'Create your account',
      subtitle: 'Your recitations, feedback and progress are saved to it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoogleSignInButton(onPressed: _googleSignIn, isLoading: _googleLoading),
          const SizedBox(height: 20),
          const AuthOrDivider(label: 'or use your email'),
          const SizedBox(height: 20),
          // Grouped so a password manager sees one sign-up form and offers to
          // save the new credentials; the hints tell it which field is which.
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  hint: 'Full name',
                  icon: Icons.person_rounded,
                  controller: _nameController,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  errorText: _nameError,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: 16),
                AuthField(
                  hint: 'Email',
                  icon: Icons.mail_rounded,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  errorText: _emailError,
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                ),
                const SizedBox(height: 16),
                AuthField(
                  hint: 'Create a password',
                  icon: Icons.lock_rounded,
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  errorText: _passwordError,
                  onChanged: (_) {
                    if (_passwordError != null) setState(() => _passwordError = null);
                  },
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Terms of Service ─────────────────────────────────────────
          // A real 48dp checkbox row: the whole line toggles, and a screen
          // reader hears one checkbox with its label.
          MergeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
              child: Row(
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                    activeColor: AppColors.primary,
                    checkColor: AppColors.textOnPrimary,
                    side: BorderSide(color: AppColors.borderStrong, width: 1.5),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                        ),
                      ]),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AuthGoldButton(label: 'Create account', onPressed: _submit, isLoading: _loading),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text('Already have an account?', style: Theme.of(context).textTheme.bodyMedium)),
              TextButton(
                onPressed: () => context.pushReplacement(RoutePaths.login),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
