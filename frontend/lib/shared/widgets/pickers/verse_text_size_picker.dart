import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cubit/verse_text_size_cubit.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../feedback/app_bottom_sheet.dart';

class VerseTextSizePicker {
  VerseTextSizePicker._();

  static Future<void> show(BuildContext context) {
    final cubit = context.read<VerseTextSizeCubit>();
    return AppBottomSheet.show<void>(
      context,
      title: 'Verse Text Size',
      child: BlocBuilder<VerseTextSizeCubit, VerseTextSize>(
        bloc: cubit,
        builder: (context, current) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final size in VerseTextSize.values)
              _SizeOption(
                size: size,
                selected: size == current,
                onTap: () => cubit.setSize(size),
              ),
          ],
        ),
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  final VerseTextSize size;
  final bool selected;
  final VoidCallback onTap;
  const _SizeOption({required this.size, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(size.label, style: Theme.of(context).textTheme.bodyLarge)),
            Text('بِسْمِ اللَّهِ', style: TextStyle(fontSize: 18 * size.scale, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
