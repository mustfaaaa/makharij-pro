import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

const _supportEmail = 'support@makharijpro.ai';

/// How to reach the team. There is no in-app message service yet, so this
/// gives the address plainly rather than a form that only pretends to send.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!context.mounted) return;
    AppSnackbar.show(context, 'Email address copied');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.xl),
          children: [
            Text('Questions, problems or ideas: write to us by email.', style: textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.mdRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.mail_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(child: SelectableText(_supportEmail, style: textTheme.titleMedium)),
                  TextButton(onPressed: () => _copy(context), child: const Text('Copy')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('To help us help you', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final tip in const [
              'If it is about feedback on a word, include the surah, the ayah and the word.',
              'If something did not work, say what you tapped and what you expected.',
              'To say a single word was marked wrongly, you do not need to write: open it in your results and tap '
                  '"I said it right".',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(child: Text(tip, style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
