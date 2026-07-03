import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/google_sign_in_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

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
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _loading = false);
    context.go(RoutePaths.home);
  }

  // UI-only dummy. Later this calls Firebase Auth's Google sign-in and only
  // navigates on success; the button + this method stay, the body swaps.
  void _googleSignIn() async {
    setState(() => _googleLoading = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _googleLoading = false);
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text('Sign in to continue your Tajweed journey', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              CustomTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
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
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(RoutePaths.forgotPassword),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(label: 'Sign In', onPressed: _submit, isLoading: _loading),
              const SizedBox(height: AppSpacing.lg),
              const _OrDivider(),
              const SizedBox(height: AppSpacing.lg),
              GoogleSignInButton(onPressed: _googleSignIn, isLoading: _googleLoading),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: Theme.of(context).textTheme.bodyMedium),
                  GestureDetector(
                    onTap: () => context.push(RoutePaths.register),
                    child: Text('Register', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
