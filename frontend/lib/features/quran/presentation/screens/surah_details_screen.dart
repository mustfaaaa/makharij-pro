import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/theme_cubit.dart';
import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../models/after_clip.dart';
import '../../../../models/ayah.dart';
import '../../../../models/qari.dart';
import '../../../../models/surah.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../models/tajweed_word_info.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/preferences_service.dart';
import '../../../../services/rattil_request_parser.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/audio/qari_player_controller.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_shadows.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../recitation/presentation/bloc/recitation_cubit.dart';
import '../../../recitation/presentation/bloc/recitation_state.dart';
import '../../../tajweed_rules/presentation/widgets/word_tajweed_sheet.dart';
import '../widgets/mushaf_ayah.dart';

/// Reference rules the reading page can highlight, as the Tajweed reference
/// names them, with the colour each is tinted in.
const _referenceRules = ['madd', 'ghunnah', 'shaddah', 'qalqalah', 'tafkheem'];

String _referenceLabel(String rule) => switch (rule) {
      'madd' => 'Madd',
      'ghunnah' => 'Ghunnah',
      'shaddah' => 'Shaddah',
      'qalqalah' => 'Qalqalah',
      'tafkheem' => 'Tafkheem',
      _ => rule,
    };

Color _referenceColor(String rule) => switch (rule) {
      'madd' => AppColors.ruleMadd,
      'ghunnah' => AppColors.ruleGhunnah,
      'shaddah' => AppColors.ruleShaddah,
      'qalqalah' => AppColors.ruleMakhraj,
      _ => AppColors.goldInk,
    };

/// The surah reading page, and the one place recitation happens.
///
/// Reading is the default: the Quran sits on a mushaf-like page in full ink,
/// with gold ayah rosettes and an illuminated cartouche. When the reciter
/// starts recording, the page switches to practice: words not yet heard
/// soften, and each one inks back in only as the backend confirms it was
/// actually said -- so the page is a record of what was recited, never an
/// animation playing on its own. The live cursor never marks a mistake.
class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;

  /// Optional practice range to preselect (from Home's "Recite again" or a
  /// practice-plan example), and an ayah to bring into view.
  final int? initialFromAyah;
  final int? initialToAyah;
  final int? scrollToAyah;

  const SurahDetailsScreen({
    super.key,
    required this.surahNumber,
    this.initialFromAyah,
    this.initialToAyah,
    this.scrollToAyah,
  });

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> {
  Surah? _surah;
  List<Ayah> _ayahs = const [];
  final _scroll = ScrollController();

  /// Word offset of each ayah into the selected range, cached per ayah list.
  /// The live cursor reports a whole-surah word index, so every ayah needs to
  /// know how many words precede it.
  List<int> _wordOffsets = const [];
  List<Ayah>? _offsetsFor;

  /// Ayahs whose translation the reader has opened (in "on tap" mode).
  final Set<int> _openTranslations = {};

  /// Keys for the ayahs currently built, so the page can follow the reciter
  /// and know where the reader stopped.
  final Map<int, GlobalKey> _ayahKeys = {};
  int? _scrolledToAyah;

  bool _appliedInitialRange = false;
  bool _didInitialScroll = false;

  // Reading preferences.
  late TranslationMode _translationMode = Services.prefs.translationMode;
  late bool _transliteration = Services.prefs.showTransliteration;
  String? _highlightRule;
  final Map<int, Map<int, TajweedWordInfo>> _reference = {};
  final Set<int> _referenceLoading = {};

  // Listening to a Qari.
  final _player = QariPlayerController();
  List<Qari> _qaris = const [];
  Qari? _qari;

  @override
  void initState() {
    super.initState();
    Services.surah.getSurahByNumber(widget.surahNumber).then((s) {
      if (mounted) setState(() => _surah = s);
    });
    // The cubit owns the canonical ayah list (the recitation flow reads it
    // too), so take it from there rather than loading a second copy.
    context.read<RecitationCubit>().beginSession(widget.surahNumber);
    _player.addListener(_onPlayer);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayer);
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int? _lastFollowedAyah;
  void _onPlayer() {
    final ayah = _player.currentAyah;
    if (_player.playing && ayah != null && ayah != _lastFollowedAyah) {
      _lastFollowedAyah = ayah;
      _scrolledToAyah = null;
      _bringIntoView(ayah);
    }
  }

  List<int> _offsets(List<Ayah> ayahs) {
    if (identical(_offsetsFor, ayahs)) return _wordOffsets;
    final offsets = <int>[];
    var running = 0;
    for (final a in ayahs) {
      offsets.add(running);
      running += a.arabicText.split(' ').length;
    }
    _offsetsFor = ayahs;
    _wordOffsets = offsets;
    return offsets;
  }

  /// How many leading words of an ayah are the Basmala the bundled text
  /// prepends: ayah 1 of every surah but Al-Fatihah (where it *is* ayah 1) and
  /// At-Tawbah (which has none). Mirrors the backend's basmala_prefix_len.
  int _basmalaWords(Ayah ayah) =>
      (ayah.number == 1 && widget.surahNumber != 1 && widget.surahNumber != 9 && ayah.arabicText.split(' ').length > 4)
          ? 4
          : 0;

  // ── Bookmark ──────────────────────────────────────────────────────────────
  Future<void> _toggleBookmark() async {
    HapticFeedback.selectionClick();
    final updated = await Services.surah.toggleBookmark(widget.surahNumber);
    if (!mounted) return;
    setState(() => _surah = updated);
    AppSnackbar.show(context, updated.isBookmarked ? 'Saved to your bookmarks' : 'Removed from your bookmarks');
  }

  // ── Recording ─────────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    // The microphone would record the Qari too.
    if (_player.hasRecitation) await _player.close();
    if (!mounted) return;
    setState(() => _scrolledToAyah = null);
    await context.read<RecitationCubit>().startListening();
  }

  void _stopRecording() {
    HapticFeedback.mediumImpact();
    context.read<RecitationCubit>().stopAndProcess();
    context.push(RoutePaths.processingPath(widget.surahNumber));
  }

  /// Leaving mid-recitation used to discard the recording with no warning --
  /// and a back-swipe is easy to trigger by accident while holding the phone
  /// up to read from.
  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop reciting?'),
        content: const Text('You are part-way through a recitation. Leaving now discards the recording.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep reciting'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard recording'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      await context.read<RecitationCubit>().cancelListening();
      if (mounted) context.pop();
    }
  }

  // ── Range ─────────────────────────────────────────────────────────────────
  /// Lets the user practise part of a surah. Al-Baqarah is 286 ayahs; reciting
  /// it in one sitting is not how anyone practises.
  Future<void> _pickAyahRange(RecitationState state) async {
    final all = state.ayahs;
    if (all.isEmpty) return;
    var from = state.fromAyah;
    var to = state.toAyah ?? all.last.number;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final numbers = all.map((a) => a.number).toList();
          final textTheme = Theme.of(sheetContext).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Which ayahs will you recite?', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Only these ayahs are recorded, followed and checked.', style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => setSheetState(() {
                          from = numbers.first;
                          to = numbers.last;
                        }),
                        child: const Text('Whole surah'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          child: Text(from == to ? 'Recite ayah $from' : 'Recite ayahs $from–$to'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (applied != true || !mounted) return;
    final wholeSurah = from == all.first.number && to == all.last.number;
    context.read<RecitationCubit>().setAyahRange(fromAyah: from, toAyah: wholeSurah ? null : to);
    setState(() => _scrolledToAyah = null);
  }

  // ── Scrolling ─────────────────────────────────────────────────────────────
  /// Keeps an ayah on screen -- the one being recited, or the one a Qari is
  /// playing -- without yanking the page if it is already there.
  void _followReciter(int ayahNumber) {
    if (_scrolledToAyah == ayahNumber) return;
    _scrolledToAyah = ayahNumber;
    _bringIntoView(ayahNumber);
  }

  void _bringIntoView(int ayahNumber) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _ayahKeys[ayahNumber]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    });
  }

  /// Opening at an ayah far down a long surah: the list builds lazily, so jump
  /// close to it by estimate, then let ensureVisible settle on the real item.
  void _initialScroll(List<Ayah> ayahs) {
    final target = widget.scrollToAyah;
    if (_didInitialScroll || target == null) return;
    _didInitialScroll = true;
    final index = ayahs.indexWhere((a) => a.number == target);
    if (index <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scroll.hasClients) return;
      final estimate = min(_scroll.position.maxScrollExtent, 220.0 + index * 150.0);
      _scroll.jumpTo(estimate);
      for (var attempt = 0; attempt < 4; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        if (!mounted) return;
        final ctx = _ayahKeys[target]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: 0.15);
          return;
        }
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(min(_scroll.position.maxScrollExtent, _scroll.offset + 600));
      }
    });
  }

  /// When scrolling settles, remember the first ayah in view as "last read".
  bool _onScrollEnd(ScrollEndNotification n) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final top = box.localToGlobal(Offset.zero).dy + kToolbarHeight + MediaQuery.paddingOf(context).top;
    int? best;
    double bestDy = double.infinity;
    for (final entry in _ayahKeys.entries) {
      final rb = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached) continue;
      final dy = rb.localToGlobal(Offset.zero).dy;
      final bottom = dy + rb.size.height;
      if (bottom < top + 24) continue; // scrolled past
      if (dy < bestDy) {
        bestDy = dy;
        best = entry.key;
      }
    }
    if (best != null) Services.prefs.setLastRead(widget.surahNumber, best);
    return false;
  }

  // ── Reference data (transliteration, rule highlighting) ───────────────────
  void _ensureReference(int ayah) {
    if (!_transliteration && _highlightRule == null) return;
    if (_reference.containsKey(ayah) || _referenceLoading.contains(ayah)) return;
    _referenceLoading.add(ayah);
    Services.tajweedReference.ayahByDisplayIndex(surah: widget.surahNumber, ayah: ayah).then((map) {
      _referenceLoading.remove(ayah);
      if (mounted) setState(() => _reference[ayah] = map);
    });
  }

  String? _transliterationFor(Ayah ayah) {
    if (!_transliteration) return null;
    final ref = _reference[ayah.number];
    if (ref == null || ref.isEmpty) return null;
    final keys = ref.keys.toList()..sort();
    return keys.map((k) => ref[k]!.wordTransliteration).where((t) => t.isNotEmpty).join(' ');
  }

  Set<int> _highlightFor(Ayah ayah) {
    final rule = _highlightRule;
    if (rule == null) return const {};
    final ref = _reference[ayah.number];
    if (ref == null) return const {};
    return {for (final e in ref.entries) if (e.value.rules.contains(rule)) e.key};
  }

  // ── Listening to a Qari ───────────────────────────────────────────────────
  Future<void> _listen(RecitationState state) async {
    HapticFeedback.selectionClick();
    if (_player.hasRecitation) {
      await _player.toggle();
      return;
    }
    _player.setLoading(true);
    try {
      if (_qaris.isEmpty) _qaris = await Services.rattil.getQaris();
      final eligible = _qaris.where((q) => q.availableSurahs.contains(widget.surahNumber)).toList();
      if (eligible.isEmpty) {
        _player.setLoading(false);
        if (mounted) AppSnackbar.show(context, 'No reciter has this surah yet.', isError: true);
        return;
      }
      final preferred = Services.prefs.preferredQariId;
      _qari = eligible.where((q) => q.qariId == preferred).firstOrNull ??
          eligible.reduce((a, b) => b.availableSurahs.length > a.availableSurahs.length ? b : a);
      await _playFrom(state, _qari!);
    } catch (_) {
      _player.setLoading(false);
      if (mounted) AppSnackbar.show(context, "The recitation couldn't be loaded. Check your connection.", isError: true);
    }
  }

  Future<void> _playFrom(RecitationState state, Qari qari, {int? startAyah}) async {
    _player.setLoading(true);
    final result = await Services.rattil.getRecitation(
      qariId: qari.qariId,
      surah: widget.surahNumber,
      ayahStart: state.fromAyah,
      ayahEnd: state.toAyah ?? state.ayahs.last.number,
    );
    _player.setLoading(false);
    await _player.start(result, startAyah: startAyah);
  }

  Future<void> _pickQari(RecitationState state) async {
    if (_qaris.isEmpty) return;
    final picked = await showModalBottomSheet<Qari>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a reciter', style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final q in _qaris)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: q.availableSurahs.contains(widget.surahNumber),
                  leading: _QariMonogram(qari: q, size: 44),
                  title: Text(q.nameEnglish),
                  subtitle: Text(q.availableSurahs.contains(widget.surahNumber)
                      ? (q.availableSurahs.length >= 114 ? 'Whole Quran' : '${q.availableSurahs.length} surahs')
                      : 'Does not have this surah'),
                  trailing: q.qariId == _qari?.qariId ? Icon(Icons.check_rounded, color: AppColors.primaryDark) : null,
                  onTap: () => Navigator.of(sheetContext).pop(q),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    Services.prefs.setPreferredQariId(picked.qariId);
    setState(() => _qari = picked);
    try {
      await _playFrom(state, picked, startAyah: _player.currentAyah);
    } catch (_) {
      _player.setLoading(false);
      if (mounted) AppSnackbar.show(context, "The recitation couldn't be loaded. Check your connection.", isError: true);
    }
  }

  // ── Reading settings ──────────────────────────────────────────────────────
  Future<void> _showReadingSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final textTheme = Theme.of(sheetContext).textTheme;
          final sizeCubit = context.read<VerseTextSizeCubit>();
          final themeCubit = context.read<ThemeCubit>();
          void update(VoidCallback fn) {
            setSheet(fn);
            setState(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  _SettingLabel('Text size'),
                  BlocBuilder<VerseTextSizeCubit, VerseTextSize>(
                    bloc: sizeCubit,
                    builder: (context, size) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<VerseTextSize>(
                          showSelectedIcon: false,
                          segments: [
                            for (final s in VerseTextSize.values)
                              ButtonSegment(value: s, label: Text(_sizeShort(s)), tooltip: s.label),
                          ],
                          selected: {size},
                          onSelectionChanged: (v) => sizeCubit.setSize(v.first),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: AppTypography.quran(fontSize: 28 * size.scale, height: 1.9),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingLabel('Translation'),
                  SegmentedButton<TranslationMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: TranslationMode.off, label: Text('Off')),
                      ButtonSegment(value: TranslationMode.onTap, label: Text('On tap')),
                      ButtonSegment(value: TranslationMode.always, label: Text('Always')),
                    ],
                    selected: {_translationMode},
                    onSelectionChanged: (v) {
                      Services.prefs.setTranslationMode(v.first);
                      update(() => _translationMode = v.first);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Transliteration'),
                    subtitle: const Text('Under each ayah. Needs a connection.'),
                    value: _transliteration,
                    onChanged: (v) {
                      Services.prefs.setShowTransliteration(v);
                      update(() => _transliteration = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingLabel('Highlight a Tajweed rule'),
                  Text(
                    'Shows where a rule occurs in the text. This is reference, not feedback on your recitation.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: _highlightRule == null,
                        onSelected: (_) => update(() => _highlightRule = null),
                      ),
                      for (final r in _referenceRules)
                        ChoiceChip(
                          label: Text(_referenceLabel(r)),
                          selected: _highlightRule == r,
                          onSelected: (_) => update(() => _highlightRule = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingLabel('Appearance'),
                  BlocBuilder<ThemeCubit, ThemeMode>(
                    bloc: themeCubit,
                    builder: (context, mode) => SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                        ButtonSegment(value: ThemeMode.system, label: Text('Device')),
                      ],
                      selected: {mode},
                      onSelectionChanged: (v) => themeCubit.setMode(v.first),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _sizeShort(VerseTextSize s) => switch (s) {
        VerseTextSize.small => 'S',
        VerseTextSize.medium => 'M',
        VerseTextSize.large => 'L',
        VerseTextSize.extraLarge => 'XL',
      };

  /// Word marking for one ayah, from whichever signal is live right now:
  /// during recitation the live cursor, afterwards the finished verdicts.
  ///
  /// The live cursor never marks a mistake -- it only knows how far the reciter
  /// has got -- so rule colours appear only once the analysis is in.
  Map<int, WordMark> _marksFor(Ayah ayah, RecitationState state, int wordsBefore) {
    final verdicts = state.result?.wordVerdicts;
    if (state.status == RecitationStatus.result && verdicts != null) {
      final marks = <int, WordMark>{};
      for (final v in verdicts.where((v) => v.ayahNumber == ayah.number)) {
        marks[v.wordIndex] = !v.recited
            ? WordMark.pending
            : (v.flagged ? WordMark(WordTone.flagged, rule: v.errorType) : WordMark.recited);
      }
      return marks;
    }

    final recited = state.liveWordsRecited;
    if (recited <= wordsBefore) return const {};
    final wordCount = ayah.arabicText.split(' ').length;
    final upto = min(recited - wordsBefore, wordCount);
    final marks = {for (var i = 0; i < upto; i++) i: WordMark.recited};

    // An ayah the reciter is already past has been re-analysed on its complete
    // audio, so its words can carry a rule colour while recitation continues.
    // Only ayahs the server has actually settled appear here.
    final settled = state.liveVerdicts[ayah.number];
    if (settled != null) {
      settled.correctByWord.forEach((index, ok) {
        if (index >= wordCount) return;
        marks[index] = ok
            ? WordMark.recited
            : WordMark(WordTone.flagged, rule: tajweedErrorTypeFromId(settled.ruleByWord[index]));
      });
    }
    return marks;
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
          if (!_appliedInitialRange && (widget.initialFromAyah != null || widget.initialToAyah != null)) {
            _appliedInitialRange = true;
            final last = state.ayahs.last.number;
            final from = (widget.initialFromAyah ?? 1).clamp(1, last);
            final to = (widget.initialToAyah ?? last).clamp(from, last);
            context.read<RecitationCubit>().setAyahRange(fromAyah: from, toAyah: (from == 1 && to == last) ? null : to);
          }
          _initialScroll(state.selectedAyahs);
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
        final reading = !recording && state.status != RecitationStatus.result;
        final offsets = _offsets(ayahs);
        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return PopScope(
          // While recording, a system back gesture must not silently throw the
          // recitation away -- intercept it and ask.
          canPop: !recording,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => recording ? _confirmDiscard() : context.pop(),
              ),
              centerTitle: true,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(surah.nameEnglish, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    recording ? 'Reciting' : '${surah.number} · ${surah.ayahCount} ayahs',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: recording ? AppColors.goldInk : AppColors.textMuted,
                        ),
                  ),
                ],
              ),
              actions: [
                if (!recording) ...[
                  IconButton(
                    tooltip: surah.isBookmarked ? 'Remove bookmark' : 'Bookmark this surah',
                    onPressed: _toggleBookmark,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: c),
                      child: Icon(
                        surah.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                        key: ValueKey(surah.isBookmarked),
                        color: surah.isBookmarked ? AppColors.goldInk : null,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reading settings',
                    onPressed: _showReadingSettings,
                    icon: Text('Aa', style: AppTypography.displayText(fontSize: 20, height: 1.0)),
                  ),
                ],
              ],
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: _Page(
                    child: NotificationListener<ScrollEndNotification>(
                      onNotification: _onScrollEnd,
                      child: ListView.builder(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(22, 18, 22, 170 + bottomInset),
                        itemCount: ayahs.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _ReaderHeader(
                              surah: surah,
                              state: state,
                              recording: recording,
                              translationMode: _translationMode,
                            );
                          }
                          final ayah = ayahs[index - 1];
                          _ensureReference(ayah.number);
                          final key = _ayahKeys.putIfAbsent(ayah.number, GlobalKey.new);
                          final showTranslation = _translationMode == TranslationMode.always ||
                              (_translationMode == TranslationMode.onTap && _openTranslations.contains(ayah.number));
                          return ListenableBuilder(
                            key: key,
                            listenable: _player,
                            builder: (context, _) => MushafAyah(
                              ayah: ayah,
                              fontSize: 28 * verseScale,
                              readingMode: reading,
                              leadingCenteredWords: _basmalaWords(ayah),
                              marks: _marksFor(ayah, state, offsets[index - 1]),
                              showTranslation: showTranslation,
                              transliteration: _transliterationFor(ayah),
                              referenceWords: reading ? _highlightFor(ayah) : const {},
                              referenceColor: _highlightRule == null ? null : _referenceColor(_highlightRule!),
                              playing: _player.playing && _player.currentAyah == ayah.number,
                              onTap: _translationMode == TranslationMode.onTap
                                  ? () => setState(() {
                                        if (!_openTranslations.remove(ayah.number)) _openTranslations.add(ayah.number);
                                      })
                                  : null,
                              // Reference data about the text, so it does not
                              // need a recitation to have happened first.
                              onWordLongPress: recording
                                  ? null
                                  : (wordIndex) => WordTajweedSheet.show(
                                        context,
                                        surah: widget.surahNumber,
                                        ayah: ayah.number,
                                        displayWordIndex: wordIndex,
                                        displayWord: ayah.arabicText.split(' ')[wordIndex],
                                      ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10 + bottomInset,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!recording)
                        ListenableBuilder(
                          listenable: _player,
                          builder: (context, _) => AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                            transitionBuilder: (c, a) => SizeTransition(
                              sizeFactor: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                              alignment: Alignment.bottomCenter,
                              child: FadeTransition(opacity: a, child: c),
                            ),
                            child: _player.hasRecitation
                                ? Padding(
                                    key: const ValueKey('player'),
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _ListenBar(
                                      player: _player,
                                      qari: _qari,
                                      onPickQari: () => _pickQari(state),
                                    ),
                                  )
                                : const SizedBox(key: ValueKey('none'), width: double.infinity),
                          ),
                        ),
                      _PracticeDock(
                        state: state,
                        recording: recording,
                        player: _player,
                        levels: context.read<RecitationCubit>().inputLevels,
                        onRange: () => _pickAyahRange(state),
                        onRecord: _startRecording,
                        onStop: _stopRecording,
                        onListen: () => _listen(state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── The page ─────────────────────────────────────────────────────────────────

/// The reading surface: an ivory page inset from the parchment ground, with a
/// fixed double gold rule at its edges like the frame of a printed mushaf
/// page. The text scrolls inside the frame and fades out under its top edge.
class _Page extends StatelessWidget {
  final Widget child;
  const _Page({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: AppColors.border),
            left: BorderSide(color: AppColors.border),
            right: BorderSide(color: AppColors.border),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Stack(
            children: [
              Positioned.fill(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.025, 1.0],
                    colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000)],
                  ).createShader(rect),
                  child: child,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _PageFramePainter(AppColors.gold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageFramePainter extends CustomPainter {
  final Color gold;
  _PageFramePainter(this.gold);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndCorners(
      Rect.fromLTWH(7, 7, size.width - 14, size.height + 40),
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = gold.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    canvas.drawRRect(outer, p);
    canvas.drawRRect(outer.deflate(3.5), p..color = gold.withValues(alpha: 0.28)..strokeWidth = 0.7);
  }

  @override
  bool shouldRepaint(_PageFramePainter old) => old.gold != gold;
}

class _ReaderHeader extends StatelessWidget {
  final Surah surah;
  final RecitationState state;
  final bool recording;
  final TranslationMode translationMode;
  const _ReaderHeader({
    required this.surah,
    required this.state,
    required this.recording,
    required this.translationMode,
  });

  @override
  Widget build(BuildContext context) {
    final meaning = surah.meaning;
    final place = surah.revelationPlace == 'Makkah' ? 'Meccan' : (surah.revelationPlace == 'Madinah' ? 'Medinan' : surah.revelationPlace);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          MushafSurahHeader(
            nameArabic: surah.nameArabic,
            subtitle: '$meaning · ${surah.ayahCount} ayahs · $place',
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: recording
                ? Text(
                    'Recite at your own pace. Words fill in as they are heard.',
                    key: const ValueKey('rec'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Text(
                    translationMode == TranslationMode.onTap
                        ? 'Tap an ayah for its translation. Hold a word to see its Makhraj and Tajweed.'
                        : 'Hold a word to see its Makhraj and Tajweed.',
                    key: const ValueKey('read'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── The practice dock ────────────────────────────────────────────────────────

class _PracticeDock extends StatelessWidget {
  final RecitationState state;
  final bool recording;
  final QariPlayerController player;
  final ValueNotifier<List<double>> levels;
  final VoidCallback onRange;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onListen;

  const _PracticeDock({
    required this.state,
    required this.recording,
    required this.player,
    required this.levels,
    required this.onRange,
    required this.onRecord,
    required this.onStop,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubicEmphasized,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: recording ? AppColors.gold.withValues(alpha: 0.6) : AppColors.border),
        boxShadow: AppShadows.lg,
      ),
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
        child: recording
            ? _RecordingControls(key: const ValueKey('rec'), state: state, levels: levels, onStop: onStop)
            : _IdleControls(
                key: const ValueKey('idle'),
                state: state,
                player: player,
                onRange: onRange,
                onRecord: onRecord,
                onListen: onListen,
              ),
      ),
    );
  }
}

class _IdleControls extends StatelessWidget {
  final RecitationState state;
  final QariPlayerController player;
  final VoidCallback onRange;
  final VoidCallback onRecord;
  final VoidCallback onListen;
  const _IdleControls({
    super.key,
    required this.state,
    required this.player,
    required this.onRange,
    required this.onRecord,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final to = state.toAyah;
    final range = state.isWholeSurah
        ? 'Whole surah'
        : (state.fromAyah == (to ?? state.ayahs.last.number) ? 'Ayah ${state.fromAyah}' : 'Ayahs ${state.fromAyah}–${to ?? state.ayahs.last.number}');

    return Row(
      children: [
        Expanded(
          child: _DockButton(
            icon: Icons.tune_rounded,
            eyebrow: 'Reciting',
            label: range,
            semantics: 'Choose which ayahs to recite. Currently $range.',
            onTap: onRange,
          ),
        ),
        const SizedBox(width: 10),
        _RecordButton(onTap: onRecord),
        const SizedBox(width: 10),
        Expanded(
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) => _DockButton(
              icon: player.loading
                  ? Icons.hourglass_top_rounded
                  : (player.playing ? Icons.pause_rounded : Icons.headphones_rounded),
              eyebrow: 'Qari',
              label: player.loading ? 'Loading' : (player.playing ? 'Pause' : 'Listen'),
              semantics: player.playing ? 'Pause the reciter' : 'Listen to a reciter recite this passage',
              onTap: player.loading ? null : onListen,
              alignEnd: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String label;
  final String semantics;
  final VoidCallback? onTap;
  final bool alignEnd;
  const _DockButton({
    required this.icon,
    required this.eyebrow,
    required this.label,
    required this.semantics,
    required this.onTap,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // On the narrowest phones the words matter more than the icon, and may
    // take a second line.
    final compact = MediaQuery.sizeOf(context).width < 360;
    final text = Flexible(
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(eyebrow, maxLines: 1, style: textTheme.labelSmall),
          Text(label,
              maxLines: compact ? 2 : 1,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(fontSize: 13.5)),
        ],
      ),
    );
    final iconW = Icon(icon, size: 20, color: AppColors.primaryDark);
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: compact
                  ? [text]
                  : alignEnd
                      ? [text, const SizedBox(width: 8), iconW]
                      : [iconW, const SizedBox(width: 8), text],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one live control on the page: deep green, the microphone inside.
class _RecordButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RecordButton({required this.onTap});

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start reciting',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: AppShadows.brandGlow,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.5),
            ),
            child: Icon(Icons.mic_rounded, color: AppColors.textOnPrimary, size: 30),
          ),
        ),
      ),
    );
  }
}

/// Recording: the live waveform of the reciter's own voice, the elapsed time,
/// where they have reached, and Stop inside a ring that breathes with the
/// microphone level.
class _RecordingControls extends StatefulWidget {
  final RecitationState state;
  final ValueNotifier<List<double>> levels;
  final VoidCallback onStop;
  const _RecordingControls({super.key, required this.state, required this.levels, required this.onStop});

  @override
  State<_RecordingControls> createState() => _RecordingControlsState();
}

class _RecordingControlsState extends State<_RecordingControls> {
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Scoped here so a tick repaints this bar, not the whole surah.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsedText {
    final m = _elapsed.inMinutes;
    final sec = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;
    final words = state.liveWordsRecited;
    final String status;
    if (!state.liveConnected) {
      status = 'Live tracking unavailable. Your recitation will still be checked.';
    } else if (state.livePosition == null) {
      status = 'Listening. Begin when you are ready.';
    } else {
      status = 'Ayah ${state.livePosition!.ayah} · $words word${words == 1 ? '' : 's'} heard';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 34,
          child: RepaintBoundary(
            child: ValueListenableBuilder<List<double>>(
              valueListenable: widget.levels,
              builder: (context, levels, _) => CustomPaint(
                size: const Size(double.infinity, 34),
                painter: _WaveformPainter(levels: levels, color: AppColors.primary, faint: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Elapsed $_elapsedText',
                excludeSemantics: true,
                child: Text(_elapsedText, style: AppTypography.numeric(fontSize: 26)),
              ),
            ),
            _StopButton(levels: widget.levels, onTap: widget.onStop),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  textAlign: TextAlign.end,
                  maxLines: 3,
                  style: textTheme.bodySmall?.copyWith(
                    color: state.liveConnected ? AppColors.textSecondary : AppColors.warning,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StopButton extends StatelessWidget {
  final ValueNotifier<List<double>> levels;
  final VoidCallback onTap;
  const _StopButton({required this.levels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: 'Stop and check my recitation',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The ring follows the real microphone level: it only moves
              // when the reciter's voice is arriving.
              ValueListenableBuilder<List<double>>(
                valueListenable: levels,
                builder: (context, values, _) {
                  final level = values.isEmpty ? 0.0 : values.last;
                  return AnimatedContainer(
                    duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
                    width: 64 + (reduce ? 8 : level * 20),
                    height: 64 + (reduce ? 8 : level * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.10 + level * 0.12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.75), width: 2),
                    ),
                  );
                },
              ),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bars from the real microphone level history, newest on the right. Flat
/// when silent: it shows the voice arriving, never an animation of its own.
class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color color;
  final Color faint;
  _WaveformPainter({required this.levels, required this.color, required this.faint});

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 3.0;
    const gap = 3.0;
    final count = (size.width / (bar + gap)).floor();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bar;
    final mid = size.height / 2;
    for (var i = 0; i < count; i++) {
      final li = levels.length - count + i;
      final level = li >= 0 ? levels[li] : 0.0;
      final h = max(2.0, level * (size.height - 4));
      final x = i * (bar + gap) + bar / 2;
      final age = count - i;
      paint.color = li >= 0 ? color.withValues(alpha: (1 - age / count * 0.7).clamp(0.25, 1.0)) : faint;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.levels != levels || old.color != color;
}

// ── Listening bar ────────────────────────────────────────────────────────────

class _ListenBar extends StatelessWidget {
  final QariPlayerController player;
  final Qari? qari;
  final VoidCallback onPickQari;
  const _ListenBar({required this.player, required this.qari, required this.onPickQari});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = player.recitation;
    final clips = r?.clips ?? const [];
    final ayah = player.currentAyah;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (qari != null) _QariMonogram(qari: qari!, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onPickQari,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(qari?.nameEnglish ?? r?.qariName ?? 'Reciter',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleSmall),
                          ),
                          Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                      Text(
                        ayah == null ? '' : 'Ayah $ayah · ${player.index + 1} of ${clips.length}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous ayah',
                onPressed: player.index > 0 ? player.previous : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              IconButton.filled(
                tooltip: player.playing ? 'Pause' : 'Play',
                onPressed: player.toggle,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                icon: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: 'Next ayah',
                onPressed: player.index < clips.length - 1 ? player.next : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              IconButton(
                tooltip: 'Close player',
                onPressed: player.close,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: player.clipProgress, minHeight: 3),
                ),
              ),
              const SizedBox(width: 10),
              _MiniChoice<AfterClip>(
                value: player.afterClip,
                options: const {
                  AfterClip.stop: 'Once',
                  AfterClip.continueOn: 'Continue',
                  AfterClip.repeatOne: 'Repeat',
                },
                onChanged: player.setAfterClip,
              ),
              _MiniChoice<QariSpeed>(
                value: player.speed,
                options: {for (final s in QariSpeed.values) s: s.label},
                onChanged: player.setSpeed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact value that cycles on tap, for the listening bar's mode and speed.
class _MiniChoice<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  const _MiniChoice({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final keys = options.keys.toList();
    final next = keys[(keys.indexOf(value) + 1) % keys.length];
    return TextButton(
      onPressed: () => onChanged(next),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(options[value]!, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primaryDark)),
    );
  }
}

/// A reciter as an Arabic-name monogram in a gold ring. Reciters are shown by
/// name, never by photograph.
class _QariMonogram extends StatelessWidget {
  final Qari qari;
  final double size;
  const _QariMonogram({required this.qari, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = qari.nameArabic.trim().isEmpty ? '' : qari.nameArabic.trim().split(' ').last.characters.first;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.goldWash,
          border: Border.all(color: AppColors.gold, width: 1.2),
        ),
        child: Text(
          initial.isEmpty ? RattilRequestParser.shortName(qari).characters.first : initial,
          style: AppTypography.arabicWord(fontSize: size * 0.46, color: AppColors.goldInk, weight: FontWeight.w700)
              .copyWith(height: 1.1),
        ),
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  final String text;
  const _SettingLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
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
    return DropdownButtonFormField<int>(
      initialValue: options.contains(value) ? value : options.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      borderRadius: AppRadii.mdRadius,
      menuMaxHeight: 360,
      items: [for (final n in options) DropdownMenuItem(value: n, child: Text('Ayah $n'))],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}

