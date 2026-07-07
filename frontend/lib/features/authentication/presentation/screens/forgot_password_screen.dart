import 'package:flutter/material.dart';

import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/validators.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/illustrations/mandala_background.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

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
      setState(() => _sent = true);
      AppSnackbar.show(context, 'Reset link sent to your email');
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
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_reset_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Reset your password',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter the email associated with your account and we\'ll send a reset link.',
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
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Send Reset Link',
                  onPressed: _submit,
                  isLoading: _loading,
                ),
                if (_sent) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 8),
                      Text('Check your inbox for the reset link.'),
                    ],
                  ),
                ],
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
