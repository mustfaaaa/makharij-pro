import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

// Each answer describes what the app and its server actually do; keep them in
// step with the backend if the analysis changes.
const _faqs = [
  _Faq(
    'How does MakharijPro check my recitation?',
    'Your recording is analysed on the MakharijPro server by a speech model trained on Quran recitation. It '
        'transcribes the sounds you made, letter by letter, and compares each word with its expected '
        'pronunciation. Where they differ, the word is marked with the rule most likely involved: Madd, '
        'Ghunnah, Shaddah or Makhraj.',
  ),
  _Faq(
    'Which surahs can I recite?',
    'All 114. Choose a whole surah or a range of ayahs from the reader, and stop whenever you like: only the '
        'words you reached are checked.',
  ),
  _Faq(
    'What does the number after a recitation mean?',
    'It is the share of the words you recited that were not marked. Words you did not reach are not counted. '
        'It describes what the model heard in that recitation; it is not a grade.',
  ),
  _Faq(
    'What if a word was marked wrongly?',
    'Open the word in your results and tap "I said it right". Your note is saved with that recitation. You can '
        'also tap "Try this word" to recite just that word again.',
  ),
  _Faq(
    'Do I need an internet connection?',
    'To check a recitation, yes: the analysis runs on the server. Reading the Quran works without one.',
  ),
  _Faq(
    'Can I practise without being checked?',
    'Yes. Read any surah, listen to a Qari recite it from the reader or from Rattil, and browse the Tajweed '
        'rules. Nothing is checked until you tap the microphone.',
  ),
];

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Help and questions')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xl),
          children: [
            Text('How MakharijPro listens, what its feedback means, and what to do when it is wrong.',
                style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            for (final faq in _faqs)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    iconColor: AppColors.primary,
                    title: Text(faq.question, style: textTheme.titleMedium),
                    children: [
                      Text(faq.answer, style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, height: 1.6)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text('Still have a question?', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.contact),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Contact us'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
