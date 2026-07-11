import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/google_sign_in_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
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
      title: 'Create Your Account',
      subtitle: 'Begin your recitation journey with MakharijPro AI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoogleSignInButton(onPressed: _googleSignIn, isLoading: _googleLoading),
          const SizedBox(height: 20),
          const AuthOrDivider(label: 'Or sign up with email'),
          const SizedBox(height: 20),
          AuthField(
            hint: 'Full Name',
            icon: Icons.person_rounded,
            controller: _nameController,
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
            errorText: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: 16),
          AuthField(
            hint: 'Create Password',
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
          const SizedBox(height: 16),
          // ── Terms of Service checkbox row ────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _agreedToTerms ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _agreedToTerms ? AppColors.primary : AppColors.border, width: 1.5),
                  ),
                  child: _agreedToTerms
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Text('I agree to the ',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
              Text('Terms of Service',
                  style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          AuthGoldButton(label: 'Sign Up', onPressed: _submit, isLoading: _loading),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
              GestureDetector(
                onTap: () => context.pushReplacement(RoutePaths.login),
                child: Text(
                  'Login',
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
