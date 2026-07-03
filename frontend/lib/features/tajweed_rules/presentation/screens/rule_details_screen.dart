import 'package:flutter/material.dart';

import '../../../../dummy/dummy_tajweed_rules.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class RuleDetailsScreen extends StatefulWidget {
  final String ruleId;
  const RuleDetailsScreen({super.key, required this.ruleId});

  @override
  State<RuleDetailsScreen> createState() => _RuleDetailsScreenState();
}

class _RuleDetailsScreenState extends State<RuleDetailsScreen> {
  late bool _bookmarked;

  TajweedRule get _rule => dummyTajweedRules.firstWhere((r) => r.id == widget.ruleId, orElse: () => dummyTajweedRules.first);

  @override
  void initState() {
    super.initState();
    _bookmarked = _rule.isBookmarked;
  }

  @override
  Widget build(BuildContext context) {
    final rule = _rule;
    return Scaffold(
      appBar: AppBar(
        title: Text(rule.title),
        actions: [
          AppIconButton(
            icon: _bookmarked ? Icons.bookmark : Icons.bookmark_outline,
            iconColor: _bookmarked ? AppColors.accent : AppColors.textPrimary,
            onPressed: () => setState(() => _bookmarked = !_bookmarked),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(18)),
            alignment: Alignment.center,
            child: Text(rule.arabicExample, style: AppTypography.arabicVerse(fontSize: 34, color: AppColors.primary), textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(20)),
            child: Text(rule.category, style: const TextStyle(color: AppColors.textOnAccent, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(rule.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(rule.fullExplanation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
