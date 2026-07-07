import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/validators.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/illustrations/mandala_background.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

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
      AppSnackbar.show(
        context,
        Services.auth.errorMessageFor(e),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create your account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Start learning correct Tajweed today',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                CustomTextField(
                  label: 'Full Name',
                  hint: 'Your name',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  errorText: _nameError,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
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
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Create Account',
                  onPressed: _submit,
                  isLoading: _loading,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    GestureDetector(
                      onTap: () => context.push(RoutePaths.login),
                      child: Text(
                        'Sign In',
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
