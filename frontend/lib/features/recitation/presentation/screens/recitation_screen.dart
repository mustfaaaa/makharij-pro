import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../dummy/dummy_ayahs.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/coach_mark/tajweed_scoring_coach_mark.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/pickers/verse_text_size_picker.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/recitation_cubit.dart';

class RecitationScreen extends StatefulWidget {
  final int surahNumber;
  const RecitationScreen({super.key, required this.surahNumber});

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  late final Future<Surah> _surahFuture;
  bool _showCoachMark = false;

  @override
  void initState() {
    super.initState();
    _surahFuture = Services.surah.getSurahByNumber(widget.surahNumber);
    context.read<RecitationCubit>().beginSession(widget.surahNumber);
    if (!RecitationCoachMarkFlags.tajweedScoringShown) {
      RecitationCoachMarkFlags.tajweedScoringShown = true;
      _showCoachMark = true;
    }
  }

  void _dismissCoachMark() => setState(() => _showCoachMark = false);

  @override
  Widget build(BuildContext context) {
    final verseScale = context.watch<VerseTextSizeCubit>().state.scale;
    return FutureBuilder<Surah>(
      future: _surahFuture,
      builder: (context, snapshot) {
        final surah = snapshot.data;
        return Stack(
          children: [
            _buildScaffold(context, surah, snapshot.hasData, verseScale),
            if (_showCoachMark)
              TajweedScoringCoachMark(onDismiss: _dismissCoachMark),
          ],
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    Surah? surah,
    bool hasData,
    double verseScale,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(surah?.nameEnglish ?? ''),
        actions: [
          AppIconButton(
            icon: Icons.format_size_rounded,
            tooltip: 'Verse text size',
            onPressed: () => VerseTextSizePicker.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !hasData
                ? const ShimmerListPlaceholder(itemCount: 4, itemHeight: 48)
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    children: [
                      Text(
                        'Recite clearly and at a natural pace. MakharijPro will listen and flag any Tajweed mistakes.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ...dummyFatihahAyahs.map(
                        (ayah) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              ayah.arabicText,
                              style: AppTypography.arabicVerse(
                                fontSize: 26 * verseScale,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIconButton(
                    icon: Icons.mic_rounded,
                    size: 68,
                    background: AppColors.primary,
                    iconColor: Colors.white,
                    onPressed: () {
                      context.read<RecitationCubit>().startListening();
                      context.push(
                        RoutePaths.listeningPath(widget.surahNumber),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
