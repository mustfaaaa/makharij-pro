import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../models/ayah.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../shared/widgets/pickers/verse_text_size_picker.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../recitation/presentation/bloc/recitation_cubit.dart';
import '../../../recitation/presentation/bloc/recitation_state.dart';
import '../widgets/mushaf_ayah.dart';

/// The surah reading page, and the one place recitation happens.
///
/// The text is laid out as a mushaf: flowing justified Arabic, gold ayah
/// medallions, translation on tap. It rests entirely in muted ink and *stays*
/// that way when recording starts — words only take on full colour as the
/// backend confirms the reciter has actually said them, so the page reads as a
/// record of what was recited rather than an animation playing on its own.
class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;
  const SurahDetailsScreen({super.key, required this.surahNumber});

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> with SingleTickerProviderStateMixin {
  Surah? _surah;
  List<Ayah> _ayahs = const [];
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  late final AnimationController _waveController;

  int? _expandedAyah;

  /// Keys for the ayahs currently built, so the page can follow the reciter.
  final Map<int, GlobalKey> _ayahKeys = {};
  int? _scrolledToAyah;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    Services.surah.getSurahByNumber(widget.surahNumber).then((s) {
      if (mounted) setState(() => _surah = s);
    });
    // The cubit owns the canonical ayah list (the recitation flow reads it
    // too), so take it from there rather than loading a second copy.
    context.read<RecitationCubit>().beginSession(widget.surahNumber);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _toggleBookmark() async {
    final updated = await Services.surah.toggleBookmark(widget.surahNumber);
    if (mounted) setState(() => _surah = updated);
  }

  void _startRecording() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _elapsed = Duration.zero;
      _expandedAyah = null;
      _scrolledToAyah = null;
    });
    _waveController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    await context.read<RecitationCubit>().startListening();
  }

  void _stopRecording() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _waveController.stop();
    // Hand off to the existing processing animation + result flow.
    context.read<RecitationCubit>().stopAndProcess();
    context.push(RoutePaths.processingPath(widget.surahNumber));
  }

  String get _elapsedText {
    final m = _elapsed.inMinutes;
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Lets the user practise part of a surah. Al-Baqarah is 286 ayahs; reciting
  /// it in one sitting is not how anyone practises, and the backend has always
  /// accepted a range -- the app just never offered one.
  Future<void> _pickAyahRange(RecitationState state) async {
    final all = state.ayahs;
    if (all.isEmpty) return;
    var from = state.fromAyah;
    var to = state.toAyah ?? all.last.number;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final numbers = all.map((a) => a.number).toList();
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Which ayahs?', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Only the ayahs you pick are recorded, highlighted and scored.',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _AyahDropdown(
                        label: 'From',
                        value: from,
                        options: numbers,
                        onChanged: (v) => setSheetState(() {
                          from = v;
                          if (to < from) to = from;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _AyahDropdown(
                        label: 'To',
                        value: to,
                        options: numbers.where((n) => n >= from).toList(),
                        onChanged: (v) => setSheetState(() => to = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(() {
                        from = numbers.first;
                        to = numbers.last;
                      }),
                      child: const Text('Whole surah'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (applied != true || !mounted) return;
    final wholeSurah = from == all.first.number && to == all.last.number;
    context.read<RecitationCubit>().setAyahRange(
          fromAyah: from,
          toAyah: wholeSurah ? null : to,
        );
    setState(() => _scrolledToAyah = null);
  }

  /// Keeps the ayah being recited on screen, without yanking the page around
  /// if the user has scrolled somewhere else deliberately.
  void _followReciter(int ayahNumber) {
    if (_scrolledToAyah == ayahNumber) return;
    _scrolledToAyah = ayahNumber;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _ayahKeys[ayahNumber]?.currentContext;
      if (ctx == null) return; // off-screen and not built -- nothing to scroll to
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    });
  }

  /// Word colouring for one ayah, from whichever signal is live right now:
  /// during recitation the live cursor, afterwards the finished verdicts.
  Map<int, WordTone> _tonesFor(Ayah ayah, RecitationState state, int wordsBefore) {
    final verdicts = state.result?.wordVerdicts;
    if (state.status == RecitationStatus.result && verdicts != null) {
      final tones = <int, WordTone>{};
      for (final v in verdicts.where((v) => v.ayahNumber == ayah.number)) {
        tones[v.wordIndex] = !v.recited
            ? WordTone.pending
            : (v.flagged ? WordTone.flagged : WordTone.recited);
      }
      return tones;
    }

    final recited = state.liveWordsRecited;
    if (recited <= wordsBefore) return const {};
    final wordCount = ayah.arabicText.split(' ').length;
    final upto = min(recited - wordsBefore, wordCount);
    return {for (var i = 0; i < upto; i++) i: WordTone.recited};
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surah;
    final verseScale = context.watch<VerseTextSizeCubit>().state.scale;

    return BlocConsumer<RecitationCubit, RecitationState>(
      listenWhen: (prev, curr) =>
          prev.livePosition?.ayah != curr.livePosition?.ayah || prev.ayahs != curr.ayahs,
      listener: (context, state) {
        if (state.ayahs.isNotEmpty && state.ayahs != _ayahs) {
          setState(() => _ayahs = state.ayahs);
        }
        final live = state.livePosition;
        if (live != null && state.status == RecitationStatus.listening) {
          _followReciter(live.ayah);
        }
      },
      builder: (context, state) {
        final ayahs = state.selectedAyahs;
        if (surah == null || ayahs.isEmpty) {
          return const Scaffold(body: AppLoadingIndicator());
        }
        final recording = state.status == RecitationStatus.listening;

        // Running count so each ayah knows its offset into the surah, which is
        // what the live cursor's whole-surah word index is measured against.
        var wordsBefore = 0;
        final blocks = <Widget>[];
        for (final ayah in ayahs) {
          final before = wordsBefore;
          wordsBefore += ayah.arabicText.split(' ').length;
          final key = _ayahKeys.putIfAbsent(ayah.number, GlobalKey.new);
          blocks.add(MushafAyah(
            key: key,
            ayah: ayah,
            fontSize: 26 * verseScale,
            tones: _tonesFor(ayah, state, before),
            showTranslation: _expandedAyah == ayah.number,
            onTap: () => setState(
              () => _expandedAyah = _expandedAyah == ayah.number ? null : ayah.number,
            ),
          ));
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Text(surah.nameEnglish),
            actions: [
              IconButton(
                tooltip: 'Verse text size',
                icon: const Icon(Icons.format_size_rounded),
                onPressed: () => VerseTextSizePicker.show(context),
              ),
              IconButton(
                tooltip: surah.isBookmarked ? 'Remove bookmark' : 'Bookmark',
                icon: Icon(
                  surah.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  color: surah.isBookmarked ? AppColors.primaryDark : null,
                ),
                onPressed: _toggleBookmark,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
                  children: [
                    MushafSurahHeader(
                      nameArabic: surah.nameArabic,
                      subtitle: '${surah.meaning} · ${surah.ayahCount} Ayahs · ${surah.revelationPlace}',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!recording) ...[
                      _AyahRangeChip(
                        state: state,
                        totalAyahs: state.ayahs.length,
                        onTap: () => _pickAyahRange(state),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          'Tap any ayah to see its translation.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                    ...blocks,
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: recording
                      ? _RecordingControls(
                          key: const ValueKey('recording'),
                          elapsedText: _elapsedText,
                          waveController: _waveController,
                          wordsRecited: state.liveWordsRecited,
                          currentAyah: state.livePosition?.ayah,
                          liveConnected: state.liveConnected,
                          onStop: _stopRecording,
                        )
                      : _TapToSpeakControl(
                          key: const ValueKey('idle'),
                          onTap: _startRecording,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Idle state: gold "Tap to Speak" mic ─────────────────────────────────────
class _TapToSpeakControl extends StatelessWidget {
  final VoidCallback onTap;
  const _TapToSpeakControl({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 8, AppSpacing.screenPadding, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryLight, AppColors.primaryDark],
                ),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(width: 20),
          Text('Tap to Speak',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── Recording state: waveform + live progress + red Stop ────────────────────
class _RecordingControls extends StatelessWidget {
  final String elapsedText;
  final AnimationController waveController;
  final int wordsRecited;
  final int? currentAyah;
  final bool liveConnected;
  final VoidCallback onStop;
  const _RecordingControls({
    super.key,
    required this.elapsedText,
    required this.waveController,
    required this.wordsRecited,
    required this.currentAyah,
    required this.liveConnected,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 4, AppSpacing.screenPadding, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.pillRadius,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: AnimatedBuilder(
              animation: waveController,
              builder: (context, _) => CustomPaint(
                size: const Size(double.infinity, 30),
                painter: _LiveWaveformPainter(
                  phase: waveController.value,
                  activeColor: AppColors.primary,
                  mutedColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Without this line a failed socket looks identical to a working
          // one that hasn't heard anything yet: text stays grey either way.
          Text(
            !liveConnected
                ? 'Recording — live word tracking unavailable, your recitation will still be scored'
                : currentAyah == null
                    ? 'Listening — begin reciting'
                    : 'Ayah $currentAyah · $wordsRecited word${wordsRecited == 1 ? '' : 's'} recited',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: liveConnected ? AppColors.textSecondary : AppColors.warning,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(elapsedText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.error, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration:
                        BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onStop,
                  child: Text('Stop',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated recording waveform: bars of pseudo-random heights whose amplitude
/// breathes with [phase], gold at the head fading to muted at the tail.
class _LiveWaveformPainter extends CustomPainter {
  final double phase;
  final Color activeColor;
  final Color mutedColor;
  _LiveWaveformPainter({required this.phase, required this.activeColor, required this.mutedColor});

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.5;
    const gap = 4.0;
    final count = (size.width / (barWidth + gap)).floor();
    final rng = Random(7); // fixed seed → stable bar pattern each frame
    final paint = Paint()..strokeCap = StrokeCap.round..strokeWidth = barWidth;

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap) + barWidth / 2;
      final base = 6 + rng.nextDouble() * 18;
      final wobble = sin((phase * 2 * pi) + i * 0.7) * 4;
      final h = (base + wobble).clamp(4.0, size.height);
      paint.color = i < count * 0.55 ? activeColor : mutedColor;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter old) => old.phase != phase;
}


/// The current practice range, and the way into changing it.
class _AyahRangeChip extends StatelessWidget {
  final RecitationState state;
  final int totalAyahs;
  final VoidCallback onTap;
  const _AyahRangeChip({required this.state, required this.totalAyahs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final to = state.toAyah;
    final label = state.isWholeSurah
        ? 'Whole surah · $totalAyahs ayahs'
        : 'Ayahs ${state.fromAyah}–${to ?? totalAyahs}';

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AyahDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  const _AyahDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          items: [
            for (final n in options) DropdownMenuItem(value: n, child: Text('Ayah $n')),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}
