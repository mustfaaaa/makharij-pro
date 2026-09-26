import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// Choose an ayah of the open surah: the page goes there, and recitation will
/// begin there.
///
/// Every ayah is on the grid, so a reader can go straight to one they can see
/// the number of, and one they know by number can be typed. Returns the ayah
/// chosen, or null when the sheet is dismissed.
class AyahPickerSheet extends StatefulWidget {
  final String surahName;
  final int ayahCount;
  final int current;

  const AyahPickerSheet({
    super.key,
    required this.surahName,
    required this.ayahCount,
    required this.current,
  });

  static Future<int?> show(
    BuildContext context, {
    required String surahName,
    required int ayahCount,
    required int current,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AyahPickerSheet(surahName: surahName, ayahCount: ayahCount, current: current),
    );
  }

  @override
  State<AyahPickerSheet> createState() => _AyahPickerSheetState();
}

class _AyahPickerSheetState extends State<AyahPickerSheet> {
  static const _cell = 52.0;
  static const _gap = 8.0;

  final _field = TextEditingController();
  ScrollController? _grid;
  int? _typed;

  @override
  void dispose() {
    _field.dispose();
    _grid?.dispose();
    super.dispose();
  }

  void _onTyped(String text) {
    final n = int.tryParse(text);
    setState(() => _typed = (n != null && n >= 1 && n <= widget.ayahCount) ? n : null);
  }

  /// The grid opens with the current ayah in view rather than at ayah 1: on a
  /// 286-ayah surah the reader is usually far from the top.
  ScrollController _gridFor(int columns, double rowExtent) =>
      _grid ??= ScrollController(
        initialScrollOffset: max(0.0, ((widget.current - 1) ~/ columns - 1) * rowExtent),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final typed = _typed;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: min(media.size.height * 0.72, 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Go to ayah', style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${widget.surahName} has ${widget.ayahCount} ayahs. Your recitation begins at the one you choose, '
                  'and you can read on from it.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _field,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                        textInputAction: TextInputAction.go,
                        onChanged: _onTyped,
                        onSubmitted: (_) {
                          if (typed != null) Navigator.of(context).pop(typed);
                        },
                        decoration: InputDecoration(
                          labelText: 'Ayah number',
                          hintText: '1–${widget.ayahCount}',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: typed == null ? null : () => Navigator.of(context).pop(typed),
                      child: const Text('Go'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = max(4, ((constraints.maxWidth + _gap) / (_cell + _gap)).floor());
                      final side = (constraints.maxWidth - (columns - 1) * _gap) / columns;
                      return GridView.builder(
                        controller: _gridFor(columns, side + _gap),
                        itemCount: widget.ayahCount,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: _gap,
                          crossAxisSpacing: _gap,
                        ),
                        itemBuilder: (context, i) => _AyahCell(
                          number: i + 1,
                          selected: i + 1 == widget.current,
                          onTap: () => Navigator.of(context).pop(i + 1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AyahCell extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;
  const _AyahCell({required this.number, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ayah $number',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primarySurface : AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdRadius,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
          child: Center(
            child: Text(
              '$number',
              style: AppTypography.numeric(
                fontSize: number > 99 ? 14 : 15,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
