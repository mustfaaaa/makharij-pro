import 'package:flutter/material.dart';

import '../../../../models/tajweed_rule.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../shared/widgets/tajweed_color_guide.dart';
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
  TajweedRule? _rule;

  @override
  void initState() {
    super.initState();
    Services.tajweedRule.getRuleById(widget.ruleId).then((r) {
      if (mounted) setState(() => _rule = r);
    });
  }

  void _toggleBookmark() async {
    final updated = await Services.tajweedRule.toggleBookmark(widget.ruleId);
    if (mounted) setState(() => _rule = updated);
  }

  @override
  Widget build(BuildContext context) {
    final rule = _rule;
    if (rule == null) {
      return const Scaffold(body: AppLoadingIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(rule.title),
        actions: [
          AppIconButton(
            icon: rule.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
            iconColor: rule.isBookmarked ? AppColors.accent : AppColors.textPrimary,
            onPressed: _toggleBookmark,
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
            child: Text(rule.category, style: TextStyle(color: AppColors.textOnAccent, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(rule.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(rule.fullExplanation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
          const SizedBox(height: AppSpacing.xl),
          Text('Tajweed Colour Guide', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const TajweedColorGuide(),
        ],
      ),
    );
  }
}
