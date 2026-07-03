import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

const _faqs = [
  _Faq('How does MakharijPro detect Tajweed errors?', 'The app records your recitation, extracts audio features, and compares them against validated reference recitations using an AI model to flag mispronounced words.'),
  _Faq('Which Surahs are supported?', 'The initial release supports a subset of Surahs. More will be added as the underlying dataset and model coverage expand.'),
  _Faq('Do I need an internet connection?', 'Yes, recitation analysis is processed on our servers, so an internet connection is required during a session.'),
  _Faq('How is my accuracy score calculated?', 'Your score reflects the percentage of words recited without a detected Tajweed error across Makhraj, Ghunnah, Shaddah, and Madd rules.'),
  _Faq('Can I practice without being scored?', 'Yes, you can revisit the Surah text and Tajweed Rules library anytime without starting a scored session.'),
];

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: _faqs.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(faq.question, style: Theme.of(context).textTheme.titleSmall),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(faq.answer, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
