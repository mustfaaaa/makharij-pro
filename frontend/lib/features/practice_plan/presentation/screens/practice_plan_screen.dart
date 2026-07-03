import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/practice_plan_item.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/practice_plan_cubit.dart';

class PracticePlanScreen extends StatelessWidget {
  const PracticePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PracticePlanCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Practice Plan')),
        body: ResponsiveCenter(child: BlocBuilder<PracticePlanCubit, ListState<PracticePlanItem>>(
          builder: (context, state) {
            if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 4);
            if (state.status == ListStatus.error) {
              return ErrorStateWidget(message: state.errorMessage ?? 'Could not load your plan.', onRetry: () => context.read<PracticePlanCubit>().load());
            }
            if (state.items.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.checklist_rounded,
                title: 'No practice plan yet',
                message: 'Complete a recitation session to get a personalized plan.',
              );
            }
            final pending = state.items.where((p) => !p.isCompleted).toList();
            final completed = state.items.where((p) => p.isCompleted).toList();
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Text('Based on your recent sessions, focus on these areas:', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                ...pending.map((item) => _PlanTile(item: item)),
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Completed', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...completed.map((item) => _PlanTile(item: item)),
                ],
              ],
            );
          },
        )),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final PracticePlanItem item;
  const _PlanTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: item.isCompleted ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.isCompleted ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.surahName, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(20)),
                      child: Text(item.focusArea, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.reason, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (!item.isCompleted)
            IconButton(
              icon: const Icon(Icons.play_circle_outline, color: AppColors.primary),
              onPressed: () => context.push(RoutePaths.quran),
            ),
        ],
      ),
    );
  }
}
