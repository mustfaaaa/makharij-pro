import 'package:flutter/material.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  bool _sending = false;

  void _send() async {
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _sending = false);
    AppSnackbar.show(context, 'Message sent — we\'ll get back to you soon');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mail_outline, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text('support@makharijpro.ai'),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const CustomTextField(label: 'Subject', hint: 'How can we help?'),
            const SizedBox(height: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Message', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                const TextField(maxLines: 5, decoration: InputDecoration(hintText: 'Describe your issue or feedback...')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'Send Message', onPressed: _send, isLoading: _sending),
          ],
        ),
      ),
    );
  }
}
