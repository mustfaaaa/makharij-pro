import 'package:flutter/material.dart';

import '../../../../core/utils/validators.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../widgets/auth_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _emailError;
  String? _sentTo;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() async {
    final error = Validators.email(_emailController.text);
    if (error != null) {
      setState(() => _emailError = error);
      return;
    }
    setState(() => _loading = true);
    try {
      await Services.auth.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sentTo = _emailController.text.trim();
      });
      AppSnackbar.show(context, 'Reset link sent — check your inbox');
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
    return AuthShell(
      title: 'Reset Password',
      subtitle: 'Enter your email and we\'ll send you a reset link',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Send Reset Link',
            onPressed: _submit,
            isLoading: _loading,
          ),
          if (_sent) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.mark_email_read_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email on its way',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppColors.success),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If an account exists for ${_sentTo ?? 'that email'}, a reset link is being sent. '
                          'Check your inbox — and your spam folder if you don\'t see it.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
