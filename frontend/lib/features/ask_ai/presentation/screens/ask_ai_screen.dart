import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/after_clip.dart';
import '../../../../models/ayah.dart';
import '../../../../models/qari.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/quran_text_repository.dart';
import '../../../../services/rattil_request_parser.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../theme/app_shadows.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../widgets/rattil_widgets.dart';

/// Rattil AI — reference-recitation retrieval (FR-15 to FR-19), not a general
/// Tajweed-knowledge chatbot. There is no language model behind it: a typed
/// request is read by [RattilRequestParser] -- rule-based, and tested -- into a
/// surah or particular ayat and a reciter. The reciter can also be picked on
/// screen (FR-16), and the ayah being recited is shown as it plays.
class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _ChatMessage {
  final bool fromUser;
  final String text;
  final RecitationResult? recitation;
  const _ChatMessage({required this.fromUser, required this.text, this.recitation});
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  List<Qari> _qaris = const [];
  List<Surah> _surahs = const [];
  bool _ready = false;
  late RattilRequestParser _parser;

  /// The reciter picked on screen (FR-16): who plays when a message names no
  /// one. Starts on whoever has the most of the Quran.
  Qari? _selectedQari;

  /// The last request that played, so picking another reciter can play the
  /// same ayat in their voice.
  RattilRequest? _lastRequest;

  @override
  void initState() {
    super.initState();
    Future.wait([
      Services.rattil.getQaris(),
      Services.surah.getSurahs(),
    ]).then((results) {
      if (!mounted) return;
      setState(() {
        _qaris = results[0] as List<Qari>;
        _surahs = results[1] as List<Surah>;
        _parser = RattilRequestParser(surahs: _surahs, qaris: _qaris);
        _selectedQari = _qaris.isEmpty
            ? null
            : _qaris.reduce((a, b) => b.availableSurahs.length > a.availableSurahs.length ? b : a);
        _ready = true;
        // Summarised by reciter. It used to list every available surah by name,
        // which became 114 names in one bubble once a reciter had the whole Quran.
        _messages.add(_ChatMessage(fromUser: false, text: _parser.describeLibrary()));
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _messages.add(const _ChatMessage(
          fromUser: false,
          text: 'Could not reach the recitation library. Check your connection and try again.',
        ));
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _controller.clear();
    setState(() => _messages.add(_ChatMessage(fromUser: true, text: text)));
    _scrollToEnd();

    if (!_ready || _qaris.isEmpty) {
      setState(() => _messages.add(const _ChatMessage(fromUser: false, text: 'No reciters are available right now.')));
      _scrollToEnd();
      return;
    }

    // The parser decides, and never plays a different reciter from the one
    // asked for -- it says who has the surah instead.
    final request = _parser.parse(text);
    await _play(request, _parser.decide(request, preferred: _selectedQari));
  }

  /// Picking a reciter (FR-16): the default from now on, and -- if something
  /// has already played -- the same ayat again in their voice, which is what
  /// comparing reciters actually needs.
  Future<void> _pickQari(Qari qari) async {
    if (_selectedQari?.qariId == qari.qariId) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedQari = qari);
    final last = _lastRequest;
    if (last == null) return;
    final again = last.withQari(qari);
    await _play(again, _parser.decide(again));
  }

  Future<void> _play(RattilRequest request, RattilReply reply) async {
    if (!reply.plays) {
      setState(() => _messages.add(_ChatMessage(fromUser: false, text: reply.message!)));
      _scrollToEnd();
      return;
    }
    if (request.isPlayable) _lastRequest = request;

    try {
      final result = await Services.rattil.getRecitation(
        qariId: reply.qari!.qariId,
        surah: reply.surah!.number,
        // FR-19: particular ayat, when asked for. The backend already took a
        // range; the chat just never read one out of a message.
        ayahStart: reply.ayahStart,
        ayahEnd: reply.ayahEnd,
      );
      final said = '${reply.label}, recited by ${result.qariName}:';
      setState(() => _messages.add(_ChatMessage(
            fromUser: false,
            text: reply.note == null ? said : '${reply.note}\n$said',
            recitation: result,
          )));
    } on AppException catch (e) {
      setState(() => _messages.add(_ChatMessage(fromUser: false, text: e.message)));
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header: Rattil AI · Reference recitations ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 8),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.brandControlGradient,
                      ),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(Icons.auto_awesome, color: AppColors.textOnPrimary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rattil AI', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: _ready ? AppColors.success : AppColors.textMuted, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text('Reference recitation library',
                                style: textTheme.bodyMedium?.copyWith(color: _ready ? AppColors.success : AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Reciter picker (FR-16) ───────────────────────────────────
            // Outside the scrolling chat so it is always in reach: before this
            // the only way to change reciter was to know a name and type it.
            if (_ready && _qaris.isNotEmpty)
              QariPicker(
                qaris: _qaris,
                selected: _selectedQari,
                totalSurahs: _surahs.length,
                onPick: _pickQari,
              ),
            // ── Chat + cards ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 8, AppSpacing.screenPadding, 16),
                children: [
                  for (final m in _messages) _Bubble(message: m),
                  if (_ready) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const _PracticeNowCard(),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Try these', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final n in const ['Al-Fatihah', 'Ayat al-Kursi', 'Al-Ikhlas', 'Al-Kawthar', 'An-Nas'])
                          _QuestionChip(label: n, onTap: () => _send(n)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // ── Composer ─────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                4,
                AppSpacing.screenPadding,
                AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Ask for a surah, e.g. "Al-Ikhlas by Alafasy"',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    Pressable(
                      onTap: _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: Icon(Icons.arrow_upward_rounded, color: AppColors.textOnPrimary, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.brandControlGradient,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(message.text, style: textTheme.bodyLarge?.copyWith(color: AppColors.textOnPrimary, height: 1.45)),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Icon(Icons.auto_awesome, size: 15, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                if (message.recitation != null) ...[
                  const SizedBox(height: 14),
                  _AudioExampleCard(recitation: message.recitation!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Real reference audio player embedded in the AI bubble ────────────────────
class _AudioExampleCard extends StatefulWidget {
  final RecitationResult recitation;
  const _AudioExampleCard({required this.recitation});

  @override
  State<_AudioExampleCard> createState() => _AudioExampleCardState();
}

class _AudioExampleCardState extends State<_AudioExampleCard> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _slow = false;
  int _clipIndex = 0;
  AfterClip _afterClip = AfterClip.stop;

  /// Set while we stop the player ourselves. Some platform implementations
  /// deliver a completion event for a stop we asked for, which would look
  /// exactly like a clip ending and start the next one behind the user's back.
  bool _stoppingOurselves = false;

  /// The text of each ayah in this surah, from the bundled Quran asset --
  /// so it shows offline, and instantly, while the audio is still loading.
  Map<int, Ayah> _ayahs = const {};
  String _basmala = '';

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => _onClipEnded());
    _loadText();
  }

  Future<void> _loadText() async {
    final repo = QuranTextRepository.instance;
    final ayahs = await repo.ayahsForSurah(widget.recitation.surah);
    final basmala = await repo.basmala();
    if (!mounted) return;
    setState(() {
      _ayahs = {for (final a in ayahs) a.number: a};
      _basmala = basmala;
    });
  }

  Future<void> _onClipEnded() async {
    if (!mounted || _stoppingOurselves) return;

    switch (_afterClip) {
      case AfterClip.repeatOne:
        await _play();
      case AfterClip.continueOn:
        // Runs on to the end of the passage and stops there rather than
        // looping back to the first ayah -- wrapping around would be the app
        // deciding to start the surah again on its own.
        if (_clipIndex < widget.recitation.clips.length - 1) {
          setState(() => _clipIndex += 1);
          await _play();
        } else {
          if (mounted) setState(() => _playing = false);
        }
      case AfterClip.stop:
        if (mounted) setState(() => _playing = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final clip = widget.recitation.clips[_clipIndex];
    _stoppingOurselves = true;
    await _player.stop();
    _stoppingOurselves = false;
    await _player.setPlaybackRate(_slow ? 0.75 : 1.0);
    await _player.play(UrlSource(clip.url));
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    await _play();
  }

  Future<void> _toggleSlow() async {
    setState(() => _slow = !_slow);
    if (_playing) await _player.setPlaybackRate(_slow ? 0.75 : 1.0);
  }

  /// "Ayah 3 of 7" for a whole surah, where the ayah number and the position
  /// in the list are the same thing. For a range they are not -- 285-286
  /// would read "Ayah 285 of 2" -- so the position is given separately.
  String _ayahLabel(int ayah, bool hasMultiple) {
    final clips = widget.recitation.clips;
    if (!hasMultiple) return 'Ayah $ayah';
    if (clips.first.ayah == 1) return 'Ayah $ayah of ${clips.length}';
    return 'Ayah $ayah  ·  ${_clipIndex + 1} of ${clips.length}';
  }

  Future<void> _skip(int delta) async {
    final next = _clipIndex + delta;
    if (next < 0 || next >= widget.recitation.clips.length) return;
    setState(() => _clipIndex = next);
    if (_playing) await _play();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.recitation.clips[_clipIndex];
    final hasMultiple = widget.recitation.clips.length > 1;
    final ayah = _ayahs[clip.ayah];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The words being recited, so the listener can follow along -- the
          // point of a reference recitation. Before this the card showed only
          // "Ayah 255".
          if (ayah != null) ...[
            AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
              child: RattilAyahText(
                key: ValueKey('${widget.recitation.surah}:${clip.ayah}'),
                arabic: QuranTextRepository.asRecited(widget.recitation.surah, ayah, _basmala),
                translation: ayah.translation,
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.15)),
            const SizedBox(height: 2),
          ],
          Row(
            children: [
              if (hasMultiple)
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: AppColors.primary,
                  onPressed: _clipIndex > 0 ? () => _skip(-1) : null,
                  tooltip: 'Previous ayah',
                ),
              Pressable(
                onTap: _toggle,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.textOnPrimary, size: 26),
                ),
              ),
              if (hasMultiple)
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  color: AppColors.primary,
                  onPressed: _clipIndex < widget.recitation.clips.length - 1 ? () => _skip(1) : null,
                  tooltip: 'Next ayah',
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _ayahLabel(clip.ayah, hasMultiple),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.replay_rounded),
                color: AppColors.textSecondary,
                onPressed: _play,
                tooltip: 'Play again',
              ),
              IconButton(
                icon: Icon(
                  _afterClip == AfterClip.repeatOne
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: _afterClip == AfterClip.stop
                      ? AppColors.textSecondary
                      : AppColors.primary,
                ),
                onPressed: () => setState(() => _afterClip = _afterClip.next),
                tooltip: switch (_afterClip) {
                  AfterClip.stop => 'Keep playing through the passage',
                  AfterClip.continueOn => 'Loop this ayah',
                  AfterClip.repeatOne => 'Stop at the end',
                },
              ),
              IconButton(
                icon: Icon(Icons.slow_motion_video_rounded, color: _slow ? AppColors.primary : AppColors.textSecondary),
                onPressed: _toggleSlow,
                tooltip: _slow ? 'Normal speed' : 'Slow down',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Practice Now card ─────────────────────────────────────────────────────────
class _PracticeNowCard extends StatelessWidget {
  const _PracticeNowCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
            child: Icon(Icons.mic_rounded, color: AppColors.primaryDark, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ready to practice?', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Recite along and get real Tajweed feedback', style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () => context.go(RoutePaths.quran),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadii.pillRadius),
              child: Text('Practice',
                  style: TextStyle(
                      color: AppColors.textOnPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggested question chip ───────────────────────────────────────────────────
class _QuestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.pillRadius,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
      ),
    );
  }
}
