import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/quran_script_cubit.dart';
import '../../../../app/cubit/theme_cubit.dart';
import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/after_clip.dart';
import '../../../../models/ayah.dart';
import '../../../../models/qari.dart';
import '../../../../models/quran_position.dart';
import '../../../../models/quran_script.dart';
import '../../../../models/recitation_span.dart';
import '../../../../models/surah.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../models/tajweed_word_info.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/juz_division.dart';
import '../../../../services/live_recitation_channel.dart';
import '../../../../services/preferences_service.dart';
import '../../../../services/quran_script_repository.dart';
import '../../../../services/rattil_request_parser.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/audio/qari_player_controller.dart';
import '../../../../shared/ui/ornaments.dart';
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
import '../widgets/ayah_picker_sheet.dart';
import '../widgets/mushaf_ayah.dart';
import '../widgets/mushaf_paragraph.dart';

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
///
/// The whole surah is always on the page. Where recitation begins is marked in
/// the text, not by hiding what comes before it: ayahs outside the recitation
/// stay readable, and are simply never recorded or marked.
class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;

  /// Where recitation begins and, for a fixed practice range, ends (from
  /// Home's "Recite again", a practice-plan example, or a juz), and an ayah to
  /// bring into view. An ayah given alone is also where recitation begins: the
  /// page is opened there, so that is where the reciter will start.
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
  /// The surah the page was opened on, with the reader's bookmark state.
  Surah? _surah;
  List<Ayah> _ayahs = const [];
  final _scroll = ScrollController();

  /// Words of the recitation ahead of each of its ayahs, keyed (surah, ayah).
  /// The live cursor reports how many of the recitation's words have been
  /// heard, counted from the ayah it began at and on across surah boundaries,
  /// so every ayah needs to know how many precede it.
  Map<(int, int), int> _wordsBefore = const {};
  Object? _wordsBeforeFor;

  /// The ayah whose translation is open in a sheet ("on tap" mode), tinted
  /// on the page while it is.
  (int, int)? _tapped;

  /// The page is written continuously, one paragraph per ruku, surah after
  /// surah. Each built paragraph has a key (by its surah and first ayah), so
  /// the page can follow the reciter to an exact line and know where the
  /// reader stopped.
  final Map<(int, int), GlobalKey<MushafParagraphState>> _paragraphKeys = {};

  /// (surah, ayah) -> the (surah, first ayah) of the paragraph it is in.
  Map<(int, int), (int, int)> _paragraphOf = const {};

  /// The first ayah of each paragraph, in page order.
  List<(int, int)> _paragraphStarts = const [];
  (int, int)? _scrolledTo;
  int _followingSeen = 0;

  /// The surah at the top of the page: the one the title names, and the one
  /// the ayah selector chooses in.
  late int _topSurah = widget.surahNumber;

  /// The Uthmani and IndoPak texts load once, from a bundled asset.
  bool _scriptsReady = QuranScriptRepository.instance.isLoaded;

  /// Where each juz begins, to mark it in the text. Null until loaded.
  JuzDivision? _juz;

  bool _appliedInitialRange = false;
  bool _didInitialScroll = false;

  // Reading preferences.
  late TranslationMode _translationMode = Services.prefs.translationMode;
  late bool _transliteration = Services.prefs.showTransliteration;
  String? _highlightRule;
  final Map<(int, int), Map<int, TajweedWordInfo>> _reference = {};
  final Set<(int, int)> _referenceLoading = {};

  // Listening to a Qari.
  final _player = QariPlayerController();
  List<Qari> _qaris = const [];
  Qari? _qari;

  /// The surah the Qari is reciting from -- the one the recitation begins in.
  int? _playingSurah;

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
    if (!_scriptsReady) {
      QuranScriptRepository.instance.ensureLoaded().then((_) {
        if (mounted) setState(() => _scriptsReady = true);
      });
    }
    JuzDivision.load().then((juz) {
      if (mounted) setState(() => _juz = juz);
    });
  }

  @override
  void dispose() {
    _cancelEndWatch();
    _player.removeListener(_onPlayer);
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  (int, int)? _lastFollowed;
  void _onPlayer() {
    final ayah = _player.currentAyah;
    final surah = _playingSurah;
    if (_player.playing && ayah != null && surah != null && (surah, ayah) != _lastFollowed) {
      _lastFollowed = (surah, ayah);
      _scrolledTo = null;
      _bringIntoView((surah, ayah));
    }
  }

  String _surahName(int number) {
    final opened = _surah;
    if (opened != null && opened.number == number) return opened.nameEnglish;
    return dummySurahs.where((s) => s.number == number).firstOrNull?.nameEnglish ?? 'Surah $number';
  }

  /// A place in words: "ayah 57" in the surah at the top of the page,
  /// "Aal-E-Imran 3" in another.
  String _where((int, int) position) =>
      position.$1 == _topSurah ? 'ayah ${position.$2}' : '${_surahName(position.$1)} ${position.$2}';

  Map<(int, int), int> _offsets(RecitationState state) {
    final key = (state.span, state.ayahs, state.following.length);
    if (_wordsBeforeFor == key) return _wordsBefore;
    final offsets = <(int, int), int>{};
    var running = 0;
    for (final (surah, ayah) in state.sessionPositions) {
      offsets[(surah, ayah.number)] = running;
      running += ayah.arabicText.split(' ').length;
    }
    _wordsBeforeFor = key;
    _wordsBefore = offsets;
    return offsets;
  }

  /// What the page lists under its header: the paragraphs of each surah it
  /// shows, with a title where each surah after the first begins.
  List<_Entry> _entries(RecitationState state) {
    final entries = <_Entry>[];
    final paragraphOf = <(int, int), (int, int)>{};
    final starts = <(int, int)>[];
    for (final section in state.passage) {
      if (section.surah != widget.surahNumber) entries.add(_Entry.title(section.surah));
      for (final group in _paragraphs(section, state)) {
        final first = (section.surah, group.first.number);
        starts.add(first);
        for (final a in group) {
          paragraphOf[(section.surah, a.number)] = first;
        }
        entries.add(_Entry.paragraph(section.surah, group));
      }
    }
    _paragraphOf = paragraphOf;
    _paragraphStarts = starts;
    return entries;
  }

  /// One surah's ayahs grouped the way the mushaf paragraphs them: a
  /// paragraph ends where a ruku ends (or where the chosen range does).
  ///
  /// Continuous text has nowhere to put a line of English beside each ayah: it
  /// would land at the end of the ruku, several ayahs away. So when every
  /// ayah's translation or transliteration is shown, the page reads ayah by
  /// ayah instead, each one followed by its own -- still in the chosen script,
  /// with all its marks.
  ///
  /// A paragraph also breaks where recitation begins, after the ayah it ends
  /// on, and where a juz begins -- so each of those can be marked between the
  /// lines, and no paragraph is half inside the recitation and half out.
  List<List<Ayah>> _paragraphs(PassageSurah section, RecitationState state) {
    if (_ayahByAyah) return [for (final ayah in section.ayahs) [ayah]];
    final span = state.span;
    final end = span?.end;
    return paragraphsByRuku(section.surah, section.ayahs, breakBefore: {
      if (span != null && span.start.surah == section.surah) span.start.ayah,
      if (end != null && end.surah == section.surah) end.ayah + 1,
      ..._juzStartsIn(section.surah),
    });
  }

  /// The ayahs of [surah] where a juz begins.
  Iterable<int> _juzStartsIn(int surah) =>
      _juz?.all.where((j) => j.start.surah == surah).map((j) => j.start.ayah) ?? const [];

  bool get _ayahByAyah => _translationMode == TranslationMode.always || _transliteration;

  MushafParagraphState? _paragraphState((int, int) position) {
    final first = _paragraphOf[position];
    return first == null ? null : _paragraphKeys[first]?.currentState;
  }

  // ── Bookmark ──────────────────────────────────────────────────────────────
  Future<void> _toggleBookmark() async {
    HapticFeedback.selectionClick();
    final updated = await Services.surah.toggleBookmark(widget.surahNumber);
    if (!mounted) return;
    setState(() => _surah = updated);
    AppSnackbar.show(context, updated.isBookmarked ? 'Saved to your bookmarks' : 'Removed from your bookmarks');
  }

  // ── Recording ─────────────────────────────────────────────────────────────
  Future<void> _startRecording(RecitationState state) async {
    HapticFeedback.mediumImpact();
    // The microphone would record the Qari too.
    if (_player.hasRecitation) await _player.close();
    if (!mounted) return;
    final span = state.span;
    if (span == null) return;

    // The analysis is told where recitation begins; it does not search for
    // it. Someone who scrolled away from the chosen ayah and recites what is
    // in front of them would be compared against the wrong text entirely, so
    // ask which one they mean rather than guess.
    final start = (span.start.surah, span.start.ayah);
    var showing = _ayahAtTop();
    // The top line is often only the close of an ayah that began above the
    // page; the reader is looking at the one that begins after it.
    if (showing != null && !_isOnScreen(showing)) {
      final next = _after(state, showing);
      if (next != null && _isOnScreen(next)) showing = next;
    }
    if (showing != null && showing != start && !_isOnScreen(start)) {
      final chosen = await _askWhereToBegin(selected: start, showing: showing);
      if (chosen == null || !mounted) return;
      if (chosen != start) {
        context.read<RecitationCubit>().setSpan(span.startingAt(QuranPosition(chosen.$1, chosen.$2)));
      }
      _jumpTo(chosen);
    }

    if (!mounted) return;
    setState(() => _scrolledTo = null);
    await context.read<RecitationCubit>().startListening();
  }

  /// The ayah after [position] on the page, running on into the next surah.
  (int, int)? _after(RecitationState state, (int, int) position) {
    final ayahs = state.ayahsOf(position.$1);
    if (ayahs.isNotEmpty && position.$2 < ayahs.last.number) return (position.$1, position.$2 + 1);
    return state.ayahsOf(position.$1 + 1).isEmpty ? null : (position.$1 + 1, 1);
  }

  Future<(int, int)?> _askWhereToBegin({required (int, int) selected, required (int, int) showing}) {
    return showDialog<(int, int)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Where will you begin?'),
        content: Text('Your recitation is set to begin at ${_where(selected)}, and the page is showing ${_where(showing)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: Text('From ${_where(selected)}'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(showing),
            child: Text('From ${_where(showing)}'),
          ),
        ],
      ),
    );
  }

  void _stopRecording() {
    _cancelEndWatch();
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

  // ── Where recitation begins ───────────────────────────────────────────────
  /// The selector at the top of the page: go to an ayah of the surah the page
  /// is showing, and begin reciting there. A fixed end the reader chose
  /// earlier is kept if it still lies ahead of the new start.
  Future<void> _pickStartAyah(RecitationState state) async {
    HapticFeedback.selectionClick();
    final surah = _topSurah;
    final ayahs = state.ayahsOf(surah);
    if (ayahs.isEmpty) return;
    final span = state.span ?? RecitationSpan(start: QuranPosition(widget.surahNumber, 1));
    final chosen = await AyahPickerSheet.show(
      context,
      surahName: _surahName(surah),
      ayahCount: ayahs.length,
      current: span.start.surah == surah ? span.start.ayah : 1,
    );
    if (chosen == null || !mounted) return;
    context.read<RecitationCubit>().setSpan(span.startingAt(QuranPosition(surah, chosen)));
    setState(() => _scrolledTo = null);
    _jumpTo((surah, chosen));
  }

  /// The dock's passage control: where recitation begins, and -- for fixed
  /// practice -- where it stops. Al-Baqarah is 286 ayahs; reciting it in one
  /// sitting is not how anyone practises. Left open ("keep going"),
  /// recitation is followed from the first ayah onward, into the surahs after
  /// this one, however far the reciter goes.
  Future<void> _pickAyahRange(RecitationState state) async {
    final surah = state.span?.start.surah ?? widget.surahNumber;
    final all = state.ayahsOf(surah);
    if (all.isEmpty) return;
    final current = state.span;
    var from = current?.start.ayah ?? 1;
    final currentEnd = current?.end;
    int? to = currentEnd != null && currentEnd.surah == surah ? currentEnd.ayah : null;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final numbers = all.map((a) => a.number).toList();
          final textTheme = Theme.of(sheetContext).textTheme;
          final stop = to;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Where will you recite?', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'In ${_surahName(surah)}. Your recitation is followed from the ayah you begin at, on into '
                    'the surahs after it, unless you choose where to stop.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _AyahDropdown(
                          label: 'Begin at',
                          value: from,
                          options: numbers,
                          onChanged: (v) => setSheetState(() {
                            from = v!;
                            if (to != null && to! < from) to = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _AyahDropdown(
                          label: 'Stop at',
                          value: to,
                          options: numbers.where((n) => n >= from).toList(),
                          noneLabel: 'Keep going',
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
                          child: Text(
                            stop == null
                                ? 'Recite from ayah $from'
                                : (from == numbers.first && stop == numbers.last
                                    ? 'Recite the whole surah'
                                    : (from == stop ? 'Recite ayah $from' : 'Recite ayahs $from–$stop')),
                          ),
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
    final moved = current == null || from != current.start.ayah || surah != current.start.surah;
    context.read<RecitationCubit>().setSpan(RecitationSpan.inSurah(surah, fromAyah: from, toAyah: to));
    setState(() => _scrolledTo = null);
    if (moved) _jumpTo((surah, from));
  }

  // ── Scrolling ─────────────────────────────────────────────────────────────
  /// Keeps an ayah on screen -- the one being recited, or the one a Qari is
  /// playing -- without yanking the page if it is already there.
  void _followReciter((int, int) position) {
    if (_scrolledTo == position) return;
    _scrolledTo = position;
    if (position.$1 != _topSurah) setState(() => _topSurah = position.$1);
    _bringIntoView(position);
  }

  /// A line already laid out is scrolled to; one further down -- the reciter
  /// has run on into text the list has not built yet -- is stepped to.
  void _bringIntoView((int, int) position) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reveal(position)) _jumpTo(position);
    });
  }

  /// Scrolls so the line where [position] begins sits [alignment] of the way
  /// down the page. The text is continuous, so this is a line inside a
  /// paragraph, not a widget of its own. False when that paragraph is not
  /// built (the list builds lazily).
  bool _reveal((int, int) position, {bool animate = true, double alignment = 0.3}) {
    final spot = _paragraphState(position)?.locate(position.$2);
    if (spot == null || !_scroll.hasClients) return false;
    final viewport = RenderAbstractViewport.maybeOf(spot.box);
    if (viewport == null) return false;
    final scroll = _scroll.position;
    final target = viewport
        .getOffsetToReveal(spot.box, alignment, rect: spot.rect)
        .offset
        .clamp(scroll.minScrollExtent, scroll.maxScrollExtent);
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
    return true;
  }

  /// Opening at an ayah: the one asked for, else the one recitation begins at.
  ///
  /// Called from build, once the text is actually on the page. It used to run
  /// when the ayahs arrived, which on a signed-in phone was before the page
  /// had anything to scroll: the jump found no list, gave up, and never tried
  /// again -- so a juz, or "Continue from ayah 59", opened at ayah 1 with the
  /// recitation set to begin far below.
  void _initialScroll() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    final target = widget.scrollToAyah ?? widget.initialFromAyah;
    if (target != null && target > 1) _jumpTo((widget.surahNumber, target));
  }

  /// Brings [target] near the top of the page, however far down it is. An
  /// ayah already laid out is scrolled to directly.
  ///
  /// Otherwise its paragraph does not exist yet -- the list builds lazily -- so
  /// step towards it a frame at a time, by the paragraphs between here and
  /// there, measured from the ones laid out now, and settle on its line once
  /// it is built. This used to guess 110px an ayah and try six times, which
  /// left a jump to Al-Baqarah 253 stranded near ayah 167.
  void _jumpTo((int, int) target) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      if (target == (widget.surahNumber, 1)) {
        _scroll.jumpTo(_scroll.position.minScrollExtent);
        return;
      }
      if (_reveal(target, alignment: 0.15)) return;
      for (var attempt = 0; attempt < 30; attempt++) {
        final step = _stepTowards(target);
        if (step == null) return;
        final scroll = _scroll.position;
        _scroll.jumpTo((_scroll.offset + step).clamp(scroll.minScrollExtent, scroll.maxScrollExtent));
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !_scroll.hasClients) return;
        if (_reveal(target, animate: false, alignment: 0.15)) return;
      }
    });
  }

  /// How far to scroll to bring the paragraph holding [target] nearer: the
  /// paragraphs between the laid-out ones and it, at their measured average
  /// height. Null when there is nothing to measure by, or the page does not
  /// hold [target] at all.
  double? _stepTowards((int, int) target) {
    final paragraph = _paragraphOf[target];
    if (paragraph == null) return null;
    final goal = _paragraphStarts.indexOf(paragraph);
    if (goal < 0) return null;
    var first = -1;
    var last = -1;
    var height = 0.0;
    for (var i = 0; i < _paragraphStarts.length; i++) {
      final box = _paragraphKeys[_paragraphStarts[i]]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (first < 0) first = i;
      last = i;
      height += box.size.height;
    }
    if (first < 0) return _scroll.position.viewportDimension;
    final each = max(height / (last - first + 1), 60.0);
    if (goal > last) return (goal - last) * each;
    if (goal < first) return -(first - goal) * each;
    return 0;
  }

  /// Whether the line [position] begins on is on screen now, clear of the
  /// dock -- false too when its paragraph is not built, which means it is far
  /// off screen.
  bool _isOnScreen((int, int) position) {
    final spot = _paragraphState(position)?.locate(position.$2);
    if (spot == null || !spot.box.attached || !_scroll.hasClients) return false;
    final viewport = RenderAbstractViewport.maybeOf(spot.box);
    if (viewport == null) return false;
    // Where the line sits below the top of the scrolling page.
    final y = viewport.getOffsetToReveal(spot.box, 0.0, rect: spot.rect).offset - _scroll.offset;
    return y >= 0 && y <= _scroll.position.viewportDimension - 170;
  }

  /// When scrolling settles, remember the ayah at the top of the page as
  /// "last read", and name its surah in the title.
  ///
  /// Read after the frame, not now: a mouse wheel reports the end of its
  /// scroll before the page is laid out at the new position, so reading it
  /// here found the ayah that *was* at the top.
  bool _onScrollEnd(ScrollEndNotification n) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = _ayahAtTop();
      if (position == null) return;
      Services.prefs.setLastRead(position.$1, position.$2);
      if (position.$1 != _topSurah) setState(() => _topSurah = position.$1);
    });
    return false;
  }

  /// The ayah written at the top of the page, with its surah.
  (int, int)? _ayahAtTop() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final top = box.localToGlobal(Offset.zero).dy + kToolbarHeight + MediaQuery.paddingOf(context).top + 24;
    MushafParagraphState? best;
    RenderBox? bestBox;
    int? bestSurah;
    for (final entry in _paragraphKeys.entries) {
      final key = entry.value;
      final rb = key.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached || key.currentState == null) continue;
      final dy = rb.localToGlobal(Offset.zero).dy;
      if (dy + rb.size.height < top) continue; // scrolled past
      if (bestBox == null || dy < bestBox.localToGlobal(Offset.zero).dy) {
        best = key.currentState;
        bestBox = rb;
        bestSurah = entry.key.$1;
      }
    }
    if (best == null || bestBox == null || bestSurah == null) return null;
    final x = bestBox.localToGlobal(bestBox.size.center(Offset.zero)).dx;
    final ayah = best.ayahAt(Offset(x, top));
    return ayah == null ? null : (bestSurah, ayah);
  }

  // ── Reference data (transliteration, rule highlighting) ───────────────────
  void _ensureReference((int, int) position) {
    if (!_transliteration && _highlightRule == null) return;
    if (_reference.containsKey(position) || _referenceLoading.contains(position)) return;
    _referenceLoading.add(position);
    Services.tajweedReference.ayahByDisplayIndex(surah: position.$1, ayah: position.$2).then((map) {
      _referenceLoading.remove(position);
      if (mounted) setState(() => _reference[position] = map);
    });
  }

  String? _transliterationFor(int surah, Ayah ayah) {
    if (!_transliteration) return null;
    final ref = _reference[(surah, ayah.number)];
    if (ref == null || ref.isEmpty) return null;
    final keys = ref.keys.toList()..sort();
    return keys.map((k) => ref[k]!.wordTransliteration).where((t) => t.isNotEmpty).join(' ');
  }

  /// What goes under an ayah when the page reads ayah by ayah: its
  /// translation (in "always" mode) and transliteration.
  List<AyahNote> _notesFor(int surah, List<Ayah> group) {
    if (!_ayahByAyah) return const [];
    final notes = <AyahNote>[];
    for (final ayah in group) {
      final translation = _translationMode == TranslationMode.always;
      final transliteration = _transliterationFor(surah, ayah);
      if (!translation && (transliteration == null || transliteration.isEmpty)) continue;
      notes.add(AyahNote(
        ayah: ayah.number,
        translation: translation ? ayah.translation : null,
        transliteration: transliteration,
      ));
    }
    return notes;
  }

  Set<int> _highlightFor(int surah, Ayah ayah) {
    final rule = _highlightRule;
    if (rule == null) return const {};
    final ref = _reference[(surah, ayah.number)];
    if (ref == null) return const {};
    return {for (final e in ref.entries) if (e.value.rules.contains(rule)) e.key};
  }

  // ── Listening to a Qari ───────────────────────────────────────────────────
  /// The surah a Qari plays: the one the recitation begins in.
  int _listeningSurah(RecitationState state) => state.span?.start.surah ?? widget.surahNumber;

  Future<void> _listen(RecitationState state) async {
    HapticFeedback.selectionClick();
    if (_player.hasRecitation) {
      await _player.toggle();
      return;
    }
    _player.setLoading(true);
    try {
      if (_qaris.isEmpty) _qaris = await Services.rattil.getQaris();
      final surah = _listeningSurah(state);
      final eligible = _qaris.where((q) => q.availableSurahs.contains(surah)).toList();
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
    final surah = _listeningSurah(state);
    final ayahs = state.ayahsOf(surah);
    final end = state.span?.end;
    final result = await Services.rattil.getRecitation(
      qariId: qari.qariId,
      surah: surah,
      ayahStart: state.span?.start.ayah ?? 1,
      ayahEnd: end != null && end.surah == surah ? end.ayah : ayahs.last.number,
    );
    _playingSurah = surah;
    _player.setLoading(false);
    await _player.start(result, startAyah: startAyah);
  }

  Future<void> _pickQari(RecitationState state) async {
    if (_qaris.isEmpty) return;
    final surah = _listeningSurah(state);
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
                  enabled: q.availableSurahs.contains(surah),
                  leading: _QariMonogram(qari: q, size: 44),
                  title: Text(q.nameEnglish),
                  subtitle: Text(q.availableSurahs.contains(surah)
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

  /// "On tap": the tapped ayah's translation, in a sheet that opens where the
  /// reader is -- the continuous text has no room for it beside the ayah. The
  /// ayah stays tinted on the page while the sheet is open.
  Future<void> _showTranslation(int surah, Ayah ayah) async {
    HapticFeedback.selectionClick();
    setState(() => _tapped = (surah, ayah.number));
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_surahName(surah)} $surah:${ayah.number}',
                    style: textTheme.labelMedium?.copyWith(color: AppColors.goldInk)),
                const SizedBox(height: AppSpacing.sm),
                Text(ayah.translation, style: textTheme.bodyLarge?.copyWith(height: 1.6)),
                const SizedBox(height: AppSpacing.md),
                Text('Translation: Saheeh International', style: textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) setState(() => _tapped = null);
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
          final scriptCubit = context.read<QuranScriptCubit>();
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
                  _SettingLabel('Script'),
                  BlocBuilder<QuranScriptCubit, QuranScript>(
                    bloc: scriptCubit,
                    builder: (context, script) => Row(
                      children: [
                        for (final s in QuranScript.values) ...[
                          if (s != QuranScript.values.first) const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ScriptChoice(
                              script: s,
                              selected: s == script,
                              onTap: () => scriptCubit.setScript(s),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                        BlocBuilder<QuranScriptCubit, QuranScript>(
                          bloc: scriptCubit,
                          builder: (context, script) => Text(
                            _basmalaIn(script),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: AppTypography.quranScript(script, fontSize: 28 * size.scale, height: 1.9),
                          ),
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

  /// Al-Fatihah 1:1 written in [script], from that script's own text.
  static String _basmalaIn(QuranScript script) =>
      QuranScriptRepository.instance.ayah(1, 1, script)?.words.join(' ') ?? '';

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
  ///
  /// [wordsBefore] counts the recitation's words ahead of this ayah; null for
  /// an ayah outside the recitation, which is never marked at all.
  Map<int, WordMark> _marksFor(int surah, Ayah ayah, RecitationState state, int? wordsBefore) {
    if (wordsBefore == null) return const {};
    final result = state.result;
    final verdicts = result?.wordVerdicts;
    if (state.status == RecitationStatus.result && result != null && verdicts != null) {
      final marks = <int, WordMark>{};
      for (final v in verdicts.where((v) =>
          (v.surahNumber ?? result.surahNumber) == surah && v.ayahNumber == ayah.number)) {
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
    final settled = state.liveVerdicts[(surah, ayah.number)];
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

  /// The last recitation state that was this page's own surah, with its text
  /// loaded -- what the page shows while another surah's page holds the shared
  /// cubit.
  RecitationState? _lastOwn;
  bool _reclaiming = false;

  /// A page for another surah opened over this one ("Continue to
  /// Aal-E-Imran") moved the shared recitation onto its surah. Back on top,
  /// this page takes it back as it left it, instead of waiting on a surah it no
  /// longer holds.
  void _reclaim() {
    if (_reclaiming) return;
    _reclaiming = true;
    final cubit = context.read<RecitationCubit>();
    final span = _lastOwn?.span;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await cubit.beginSession(widget.surahNumber, span: span);
      _reclaiming = false;
    });
  }

  /// The surah's names and counts from the bundled data, so the text shows at
  /// once. The page used to wait for [_surah] -- the bookmark read from
  /// Firestore and the session history fetched over the network, up to twelve
  /// seconds -- before showing any of the Quran, which needs neither.
  late final Surah _bundled =
      dummySurahs.firstWhere((s) => s.number == widget.surahNumber, orElse: () => dummySurahs.first);

  // ── Ending a fixed range ──────────────────────────────────────────────────
  /// A range with a chosen last ayah ends the recording by itself -- but not
  /// the instant its last word is recognised. An ayah's closing madd can be
  /// held six counts, and stopping in the middle of it would be judged a madd
  /// cut short. So once the last word is heard, it waits for the reciter to
  /// fall quiet, or for [_endMaxWait] in a room too noisy to tell.
  static const _endSilence = Duration(milliseconds: 700);
  static const _endMaxWait = Duration(seconds: 4);

  /// Below this the microphone is taken to be quiet: about -42 dBFS on the
  /// 0..1 scale the recording ring shows. Speech sits well above it.
  static const _quietLevel = 0.3;
  Timer? _endWatch;

  /// Whether the live cursor has reached the last spoken word of the range's
  /// last ayah.
  bool _reachedEnd(RecitationState state, LivePosition live) {
    final end = state.span?.end;
    if (end == null || live.surah != end.surah || live.ayah != end.ayah) return false;
    final ayah = state.ayahsOf(end.surah).where((a) => a.number == end.ayah).firstOrNull;
    if (ayah == null) return false;
    return live.wordIndex >= RecitationSpan.lastSpokenWord(ayah.arabicText.split(' '));
  }

  void _watchForEnd() {
    if (_endWatch != null) return;
    final cubit = context.read<RecitationCubit>();
    const tick = Duration(milliseconds: 100);
    var quiet = Duration.zero;
    var waited = Duration.zero;
    _endWatch = Timer.periodic(tick, (timer) {
      if (!mounted || cubit.state.status != RecitationStatus.listening) {
        _cancelEndWatch();
        return;
      }
      waited += tick;
      final levels = cubit.inputLevels.value;
      quiet = (levels.isEmpty ? 0.0 : levels.last) < _quietLevel ? quiet + tick : Duration.zero;
      if (quiet >= _endSilence || waited >= _endMaxWait) {
        _cancelEndWatch();
        _stopRecording();
      }
    });
  }

  void _cancelEndWatch() {
    _endWatch?.cancel();
    _endWatch = null;
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surah ?? _bundled;
    final verseScale = context.watch<VerseTextSizeCubit>().state.scale;
    final script = context.watch<QuranScriptCubit>().state;
    // Read here so the page rebuilds when a page above it closes.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;

    return BlocConsumer<RecitationCubit, RecitationState>(
      listenWhen: (prev, curr) =>
          prev.livePosition?.ayah != curr.livePosition?.ayah ||
          prev.livePosition?.surah != curr.livePosition?.surah ||
          // Word by word too: a fixed range ends on its last word.
          prev.livePosition?.wordIndex != curr.livePosition?.wordIndex ||
          prev.ayahs != curr.ayahs ||
          prev.following.length != curr.following.length,
      listener: (context, state) {
        // The cubit is shared. While the next surah's page opens over this
        // one, the state is that page's, not this one's.
        if (state.surahNumber != widget.surahNumber) return;
        if (state.ayahs.isNotEmpty && state.ayahs != _ayahs) {
          setState(() => _ayahs = state.ayahs);
          if (!_appliedInitialRange) {
            _appliedInitialRange = true;
            final last = state.ayahs.last.number;
            final from = (widget.initialFromAyah ?? widget.scrollToAyah ?? 1).clamp(1, last);
            final to = widget.initialToAyah?.clamp(from, last);
            context.read<RecitationCubit>().setSpan(RecitationSpan.inSurah(
                  widget.surahNumber,
                  fromAyah: from,
                  // A link whose range stops at the last ayah is a passage
                  // that ran to the end: go on from there, as it did.
                  toAyah: to == last ? null : to,
                ));
          }
        }
        // A surah just added may hold where the reciter already is.
        if (state.following.length != _followingSeen) {
          _followingSeen = state.following.length;
          _scrolledTo = null;
        }
        final live = state.livePosition;
        if (live != null && state.status == RecitationStatus.listening) {
          // Keep the next surah on the page ahead of the reciter, so it is
          // there to read when they reach it.
          final last = state.passage.last;
          if (live.surah > last.surah ||
              (live.surah == last.surah && last.ayahs.isNotEmpty && live.ayah >= last.ayahs.last.number - 2)) {
            context.read<RecitationCubit>().extendPassage();
          }
          _followReciter((live.surah, live.ayah));
          if (_reachedEnd(state, live)) _watchForEnd();
        }
      },
      builder: (context, current) {
        // The cubit is shared by every reading page. While it holds another
        // surah -- a page opened over this one, or one this page is sliding
        // away from -- this page keeps its own last state on screen rather
        // than showing that surah's, or a spinner.
        final own = current.surahNumber == widget.surahNumber;
        if (own && current.ayahs.isNotEmpty) _lastOwn = current;
        if (!own && onTop) _reclaim();
        final state = own && current.ayahs.isNotEmpty ? current : (_lastOwn ?? current);
        final ayahs = state.ayahs;
        if (state.surahNumber != widget.surahNumber || ayahs.isEmpty || !_scriptsReady) {
          return const Scaffold(body: AppLoadingIndicator());
        }
        // The list is about to be laid out. Where a juz begins above the
        // target changes the layout above it, so wait for those marks too, or
        // the page would land on the ayah and then slide off it.
        if (!_didInitialScroll && _juz != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _initialScroll();
          });
        }
        final recording = state.status == RecitationStatus.listening;
        final reading = !recording && state.status != RecitationStatus.result;
        final wordsBefore = _offsets(state);
        final entries = _entries(state);
        final span = state.span;
        final lastSurah = state.passage.last.surah;
        final topAyahs = state.ayahsOf(_topSurah);
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
                  Text(_surahName(_topSurah), style: Theme.of(context).textTheme.titleMedium),
                  if (recording)
                    Text(
                      'Reciting',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.goldInk),
                    )
                  else if (span != null)
                    _AyahSelector(
                      label: span.start.surah == _topSurah
                          ? 'Ayah ${span.start.ayah}'
                          : '${span.start.surah}:${span.start.ayah}',
                      semantics: 'Recitation begins at ${_where((span.start.surah, span.start.ayah))}. '
                          'Choose an ayah of ${_surahName(_topSurah)} to go to, of ${topAyahs.length}.',
                      onTap: () => _pickStartAyah(state),
                    ),
                ],
              ),
              actions: [
                if (!recording) ...[
                  // The bookmark is the opened surah's; further down the
                  // page another surah is at the top, and it is not that one.
                  // Shown once its real state has loaded, never guessed.
                  if (_surah != null && _topSurah == widget.surahNumber)
                    IconButton(
                      tooltip: surah.isBookmarked ? 'Remove bookmark' : 'Bookmark this surah',
                      onPressed: _toggleBookmark,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: c),
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
                        itemCount: entries.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _ReaderHeader(
                              surah: surah,
                              state: state,
                              recording: recording,
                              translationMode: _translationMode,
                            );
                          }
                          if (index == entries.length + 1) {
                            return lastSurah >= 114
                                ? const SizedBox.shrink()
                                : _PassageFooter(
                                    next: lastSurah + 1,
                                    onReached: () => context.read<RecitationCubit>().extendPassage(),
                                  );
                          }
                          final entry = entries[index - 1];
                          final group = entry.ayahs;
                          final surahHere = entry.surah;
                          if (group == null) return _SurahTitle(number: surahHere);
                          for (final ayah in group) {
                            _ensureReference((surahHere, ayah.number));
                          }
                          final first = group.first.number;
                          // Paragraphs break where the recitation begins and
                          // ends, so a paragraph is wholly inside it or out.
                          final inSession = span?.containsAyah(surahHere, first) ?? true;
                          final juzHere = _juz?.juzStartingAt(surahHere, first);
                          final end = span?.end;
                          final endsHere = end != null && end.surah == surahHere && group.last.number == end.ayah;
                          final startsHere = span != null &&
                              span.start.surah == surahHere &&
                              span.start.ayah == first &&
                              !(surahHere == widget.surahNumber && first == 1);
                          final key = _paragraphKeys.putIfAbsent((surahHere, first), GlobalKey<MushafParagraphState>.new);
                          final repo = QuranScriptRepository.instance;
                          final tapped = _tapped;
                          final paragraph = ListenableBuilder(
                            listenable: _player,
                            builder: (context, _) => MushafParagraph(
                              key: key,
                              script: script,
                              fontSize: 28 * verseScale,
                              // Outside the recitation the text stays as it
                              // reads: never softened as "not heard yet",
                              // because it is not going to be heard.
                              readingMode: reading || !inSession,
                              referenceColor: _highlightRule == null ? null : _referenceColor(_highlightRule!),
                              playingAyah: _player.playing && _playingSurah == surahHere ? _player.currentAyah : null,
                              selectedAyahs: {if (tapped != null && tapped.$1 == surahHere) tapped.$2},
                              notes: _notesFor(surahHere, group),
                              ayahs: [
                                for (final ayah in group)
                                  ParagraphAyah(
                                    ayah: ayah,
                                    text: repo.ayah(surahHere, ayah.number, script)!,
                                    placement: repo.placement(surahHere, ayah.number),
                                    leadingCenteredWords: basmalaWordsIn(surahHere, ayah),
                                    marks: _marksFor(surahHere, ayah, state, wordsBefore[(surahHere, ayah.number)]),
                                    referenceWords: reading ? _highlightFor(surahHere, ayah) : const {},
                                  ),
                              ],
                              onAyahTap: _translationMode == TranslationMode.onTap
                                  ? (number) => _showTranslation(surahHere, group.firstWhere((a) => a.number == number))
                                  : null,
                              // Reference data about the text, so it does not
                              // need a recitation to have happened first.
                              onWordLongPress: recording
                                  ? null
                                  : (number, wordIndex) {
                                      final ayah = group.firstWhere((a) => a.number == number);
                                      final written = repo.word(surahHere, number, wordIndex, script);
                                      WordTajweedSheet.show(
                                        context,
                                        surah: surahHere,
                                        ayah: number,
                                        displayWordIndex: wordIndex,
                                        displayWord: (written == null || written.isEmpty)
                                            ? ayah.arabicText.split(' ')[wordIndex]
                                            : written,
                                        script: (written == null || written.isEmpty) ? null : script,
                                      );
                                    },
                            ),
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (juzHere != null) _PassageMarker(label: 'Juz $juzHere'),
                              if (startsHere)
                                _PassageMarker(
                                  label: surahHere == widget.surahNumber
                                      ? 'Recitation begins · Ayah $first'
                                      : 'Recitation begins · ${_surahName(surahHere)} $first',
                                  emphasised: true,
                                ),
                              // While practising, what lies outside the
                              // recitation steps back; it stays legible.
                              AnimatedOpacity(
                                opacity: inSession || reading ? 1 : 0.45,
                                duration: MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                child: paragraph,
                              ),
                              if (endsHere) _PassageMarker(label: 'Recitation ends · Ayah ${end.ayah}'),
                            ],
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
                        onRecord: () => _startRecording(state),
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
    final range = state.passageLabel;
    // Said in two parts, so the part that changes fits the dock: "From ayah
    // 253" was cut short to "From ayah ..." on a phone.
    // Left open, the recitation runs on past this surah, so it is "from" an
    // ayah; in a surah the page ran on into, the ayah says which surah.
    final span = state.span;
    final start = span?.start;
    final end = span?.end;
    final startLabel = start == null
        ? 'Ayah 1'
        : (start.surah == state.surahNumber ? 'Ayah ${start.ayah}' : '${start.surah}:${start.ayah}');
    final (eyebrow, label) = end == null
        ? ('Reciting from', startLabel)
        : (range == 'Whole surah' || end.ayah == start?.ayah
            ? ('Reciting', range)
            : ('Reciting ayahs', '${start?.ayah}–${end.ayah}'));

    return Row(
      children: [
        Expanded(
          child: _DockButton(
            icon: Icons.tune_rounded,
            eyebrow: eyebrow,
            label: label,
            semantics: 'Choose where to begin reciting, and where to stop. Currently $range.',
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
    final end = state.span?.end;
    final live = state.livePosition;
    final String status;
    if (!state.liveConnected) {
      // Nothing is following the reciter, so nothing can tell that the last
      // ayah is done: say who stops it.
      status = end == null
          ? 'Live tracking unavailable. Your recitation will still be checked.'
          : 'Live tracking unavailable. Press stop after ayah ${end.ayah}.';
    } else if (live == null) {
      status = end == null
          ? 'Listening. Begin when you are ready.'
          : 'Listening. Recording ends by itself after ayah ${end.ayah}.';
    } else {
      final at = live.surah == state.surahNumber ? 'Ayah ${live.ayah}' : '${live.surah}:${live.ayah}';
      status = '$at · $words word${words == 1 ? '' : 's'} heard${end == null ? '' : ' · ends after ${end.ayah}'}';
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

/// One script to choose, shown as itself: the Basmala written in it, so the
/// choice is made by looking rather than by knowing the names.
class _ScriptChoice extends StatelessWidget {
  final QuranScript script;
  final bool selected;
  final VoidCallback onTap;
  const _ScriptChoice({required this.script, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${script.label} script, ${script.description}',
      child: Material(
        color: selected ? AppColors.primarySurface : AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdRadius,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _SurahDetailsScreenState._basmalaIn(script),
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          style: AppTypography.quranScript(script, fontSize: 20, height: 1.6),
                        ),
                      ),
                    ),
                  ),
                  Text(script.label, style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    script.description,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
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

/// An ayah to choose from [options]. With [noneLabel] the first choice is
/// "none" (null) -- the "Stop at: End of surah" of an open recitation.
class _AyahDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final List<int> options;
  final String? noneLabel;
  final ValueChanged<int?> onChanged;
  const _AyahDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.noneLabel,
  });

  @override
  Widget build(BuildContext context) {
    final none = noneLabel;
    final current = options.contains(value) ? value : (none != null ? null : options.first);
    return DropdownButtonFormField<int?>(
      // Keyed by the choices too: when the start moves, the stop's options
      // change under it, and the field must show what is now selected.
      key: ValueKey((current, options.first)),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      borderRadius: AppRadii.mdRadius,
      menuMaxHeight: 360,
      items: [
        if (none != null) DropdownMenuItem<int?>(value: null, child: Text(none)),
        for (final n in options) DropdownMenuItem<int?>(value: n, child: Text('Ayah $n')),
      ],
      onChanged: (v) {
        if (v != null || none != null) onChanged(v);
      },
    );
  }
}

/// Where recitation begins, at the top of the page -- and the way to choose
/// another ayah, and go there.
class _AyahSelector extends StatelessWidget {
  final String label;
  final String semantics;
  final VoidCallback onTap;
  const _AyahSelector({required this.label, required this.semantics, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillRadius,
        child: Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.pillRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primaryDark),
              ),
              Icon(Icons.expand_more_rounded, size: 18, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line set between paragraphs of the text: where a juz begins, or where the
/// recitation does. Gold hairlines around a small rosette and a label, like
/// the ornament dividers elsewhere -- illumination, never a button.
class _PassageMarker extends StatelessWidget {
  final String label;

  /// Drawn a little stronger: where the recitation begins is the one the
  /// reciter must not miss.
  final bool emphasised;
  const _PassageMarker({required this.label, this.emphasised = false});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: emphasised ? AppColors.gold.withValues(alpha: 0.7) : AppColors.border),
    );
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            line,
            const SizedBox(width: 8),
            RosetteBadge(size: 12, fill: emphasised ? AppColors.gold : AppColors.goldWash),
            const SizedBox(width: 6),
            // The label takes the room it needs; the hairlines share the rest.
            Flexible(
              flex: 6,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.goldInk,
                      fontWeight: emphasised ? FontWeight.w600 : null,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            line,
          ],
        ),
      ),
    );
  }
}

/// One thing the page lists under its header: the title of a surah it has run
/// on into, or a paragraph of a surah's ayahs.
class _Entry {
  final int surah;

  /// Null for a surah's title.
  final List<Ayah>? ayahs;

  const _Entry.title(this.surah) : ayahs = null;
  const _Entry.paragraph(this.surah, List<Ayah> this.ayahs);
}

/// Where the next surah begins, as the page runs on into it: its cartouche,
/// as the surah the page opened on has at the top.
class _SurahTitle extends StatelessWidget {
  final int number;
  const _SurahTitle({required this.number});

  @override
  Widget build(BuildContext context) {
    final surah = dummySurahs.where((s) => s.number == number).firstOrNull;
    if (surah == null) return const SizedBox.shrink();
    final place = surah.revelationPlace == 'Makkah'
        ? 'Meccan'
        : (surah.revelationPlace == 'Madinah' ? 'Medinan' : surah.revelationPlace);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      child: MushafSurahHeader(
        nameArabic: surah.nameArabic,
        subtitle: '${surah.nameEnglish} · ${surah.ayahCount} ayahs · $place',
      ),
    );
  }
}

/// The end of the page so far. Reaching it runs the page on into the next
/// surah, so the text continues for as long as the reader -- or the reciter --
/// does, instead of stopping at the end of the surah it was opened on.
class _PassageFooter extends StatefulWidget {
  final int next;
  final VoidCallback onReached;
  const _PassageFooter({required this.next, required this.onReached});

  @override
  State<_PassageFooter> createState() => _PassageFooterState();
}

class _PassageFooterState extends State<_PassageFooter> {
  @override
  void initState() {
    super.initState();
    // Built means scrolled near: the list builds lazily.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReached();
    });
  }

  @override
  Widget build(BuildContext context) {
    final next = dummySurahs.where((s) => s.number == widget.next).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: Column(
        children: [
          const OrnamentDivider(verticalPadding: 12),
          Text(
            next == null ? '' : '${next.nameEnglish} follows',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

