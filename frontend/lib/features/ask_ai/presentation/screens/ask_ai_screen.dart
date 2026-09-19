import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../data/tajweed_rules.dart';
import '../../../../models/after_clip.dart';
import '../../../../models/assistant_answer.dart';
import '../../../../models/ayah.dart';
import '../../../../models/qari.dart';
import '../../../../models/tajweed_rule.dart';
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

/// Rattil AI — reference recitations (FR-15 to FR-19) and questions about
/// reciting. A typed message is read first by [RattilRequestParser] --
/// rule-based, tested, instant and offline -- into a surah or ayat, a reciter,
/// a player command or a Tajweed rule. Only a message it cannot read goes to
/// Rattil's assistant (Google Gemini, through the backend), and whatever that
/// asks to do is validated by the same parser before anything plays. The
/// reciter can also be picked on screen (FR-16), and the ayah being recited is
/// shown as it plays.
class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _ChatMessage {
  final bool fromUser;
  final String text;
  final RecitationResult? recitation;

  /// How the recitation's player starts -- slower, looping -- when the
  /// request said so ("Ayat al-Kursi on loop").
  final Set<RattilCommand> startWith;

  /// Lets later typed commands reach this message's player.
  final _PlayerController? player;

  /// A Tajweed rule this message explains, to open in the library.
  final TajweedRule? rule;

  /// Written by Rattil's assistant (Google Gemini) rather than the app's own
  /// rules -- said under the bubble, since the user's question went to Google.
  final bool viaAssistant;

  const _ChatMessage({
    required this.fromUser,
    required this.text,
    this.recitation,
    this.startWith = const {},
    this.player,
    this.rule,
    this.viaAssistant = false,
  });
}

/// The chat's handle on the player it most recently put on screen, so a typed
/// "repeat" or "slower" (FR-18) acts on it. The player attaches itself when it
/// is built and lets go when it is disposed.
class _PlayerController {
  _AudioExampleCardState? _card;

  bool get attached => _card != null;

  /// Carries out [commands] and says what was done, in a sentence for the chat.
  Future<String> apply(Set<RattilCommand> commands) async {
    final card = _card;
    if (card == null) return 'Nothing is playing yet -- ask for a surah or ayat first.';
    return card._apply(commands);
  }
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

  /// The player typed commands go to: the one most recently put on screen.
  _PlayerController? _activePlayer;

  /// Waiting on Rattil's assistant.
  bool _thinking = false;

  /// The server said it has no assistant configured. Not asked again this
  /// visit: the answer will not change until the server restarts with a key.
  bool _assistantOff = false;

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
        // The rules library is bundled with the app, so questions about a
        // rule are answered offline and from the same text the library shows.
        _parser = RattilRequestParser(surahs: _surahs, qaris: _qaris, rules: tajweedRules);
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
    final reply = _parser.decide(request, preferred: _selectedQari);
    // Only what the rules could not read goes to the assistant: everything
    // they can handle stays instant, free, offline and tested.
    if (reply.unread && !_assistantOff) {
      await _askAssistant(text, fallback: reply.message!);
      return;
    }
    await _play(request, reply);
  }

  /// Rattil's assistant (Google Gemini, via the backend), for a message the
  /// app's own parser could not read.
  ///
  /// Whatever it asks to do goes back through the parser's own [decide] --
  /// the same validation a typed request gets -- so a surah it names is played
  /// only if it exists, the ayat are in range, and the reciter has it.
  Future<void> _askAssistant(String text, {required String fallback}) async {
    setState(() => _thinking = true);
    _scrollToEnd();

    AssistantAnswer? answer;
    String? failure;
    try {
      answer = await Services.rattil.ask(text, history: _historyForAssistant());
    } on AppException catch (e) {
      if (e.statusCode == 503 && e.message.contains('GEMINI_API_KEY')) _assistantOff = true;
      // A busy assistant says so; any other failure just gets the parser's
      // own reply, as if the assistant did not exist.
      failure = e.statusCode == 429 ? e.message : null;
    }
    if (!mounted) return;
    setState(() => _thinking = false);

    if (answer == null) {
      setState(() => _messages.add(_ChatMessage(fromUser: false, text: failure ?? fallback)));
      _scrollToEnd();
      return;
    }
    if (answer.reply.isNotEmpty) {
      setState(() => _messages.add(_ChatMessage(fromUser: false, text: answer!.reply, viaAssistant: true)));
      _scrollToEnd();
    }
    for (final action in answer.actions) {
      switch (action) {
        case PlayAction():
          final surah = _surahs.where((s) => s.number == action.surah).firstOrNull;
          final qari = _qaris.where((q) => q.qariId == action.qariId).firstOrNull;
          if (surah == null || qari == null) continue;
          final request = RattilRequest(
              surah: surah, qari: qari, ayahStart: action.ayahStart, ayahEnd: action.ayahEnd);
          await _play(request, _parser.decide(request));
        case RuleAction():
          final rule = tajweedRules
              .where((r) => r.title.toLowerCase().startsWith(action.rule.toLowerCase()))
              .firstOrNull;
          if (rule == null) continue;
          final request = RattilRequest(rule: rule);
          await _play(request, _parser.decide(request));
      }
    }
  }

  /// The last few turns, oldest first, for the assistant's context. The
  /// newest user message is excluded -- it is sent as the message itself --
  /// and so is the welcome, which is long and says nothing about this chat.
  List<Map<String, String>> _historyForAssistant() {
    final turns = <Map<String, String>>[];
    final before = _messages.length - 2; // everything but the welcome and the newest
    for (final m in _messages.skip(1).take(before < 0 ? 0 : before)) {
      if (m.text.isEmpty) continue;
      final text = m.text.length > 1200 ? m.text.substring(0, 1200) : m.text;
      turns.add({'role': m.fromUser ? 'user' : 'model', 'text': text});
    }
    return turns.length > 6 ? turns.sublist(turns.length - 6) : turns;
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
    // A command for the player already on screen (FR-18).
    if (reply.controls) {
      final player = _activePlayer;
      final String said;
      if (player == null) {
        said = 'Nothing is playing yet -- ask for a surah or ayat first.';
      } else if (!player.attached) {
        // The list lets a player go once it scrolls far out of view, and its
        // audio with it -- so "nothing is playing" would be untrue, not just
        // unhelpful.
        said = 'That recitation has scrolled out of view -- ask for it again to keep going.';
      } else {
        said = await player.apply(reply.commands);
      }
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(fromUser: false, text: said)));
      _scrollToEnd();
      return;
    }
    // A Tajweed rule, answered from the library, with a way into it.
    if (reply.rule != null) {
      setState(() => _messages.add(_ChatMessage(fromUser: false, text: reply.message!, rule: reply.rule)));
      _scrollToEnd();
      return;
    }
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
      final player = _PlayerController();
      _activePlayer = player;
      setState(() => _messages.add(_ChatMessage(
            fromUser: false,
            text: reply.note == null ? said : '${reply.note}\n$said',
            recitation: result,
            startWith: reply.commands,
            player: player,
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
                  if (_thinking)
                    Padding(
                      padding: const EdgeInsets.only(left: 46, bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text('Rattil is thinking…',
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      ),
                    ),
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
                if (message.viaAssistant) ...[
                  const SizedBox(height: 6),
                  // The user's question went to Google to get this; say so, and
                  // that it can be wrong -- the app's own answers are not marked.
                  Text('Answered with Google Gemini · can make mistakes',
                      style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                ],
                if (message.recitation != null) ...[
                  const SizedBox(height: 14),
                  _AudioExampleCard(
                    recitation: message.recitation!,
                    startWith: message.startWith,
                    controller: message.player,
                  ),
                ],
                if (message.rule != null) ...[
                  const SizedBox(height: 10),
                  // The chat gives the short answer; the library has the full
                  // explanation and the example.
                  TextButton.icon(
                    onPressed: () => context.push(RoutePaths.ruleDetailsPath(message.rule!.id)),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('Open in Tajweed Rules'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 44),
                    ),
                  ),
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

  /// Settings the request asked for up front: slower, looping, playing on.
  final Set<RattilCommand> startWith;

  /// How typed commands reach this player.
  final _PlayerController? controller;

  const _AudioExampleCard({required this.recitation, this.startWith = const {}, this.controller});

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
    widget.controller?._card = this;
    // "Ayat al-Kursi slowly, on loop": the player starts set up that way.
    final start = widget.startWith;
    _slow = start.contains(RattilCommand.slower);
    if (start.contains(RattilCommand.loop)) {
      _afterClip = AfterClip.repeatOne;
    } else if (start.contains(RattilCommand.playOn)) {
      _afterClip = AfterClip.continueOn;
    }
  }

  /// Carries out typed commands (FR-18) and says, in a sentence, what changed.
  ///
  /// Order matters when several arrive together ("slower and repeat"): speed
  /// and mode are set first, so the replay or next ayah that follows is heard
  /// with them. A pause overrides everything else in the same message.
  Future<String> _apply(Set<RattilCommand> commands) async {
    if (!mounted) return 'Nothing is playing yet -- ask for a surah or ayat first.';
    final said = <String>[];

    if (commands.contains(RattilCommand.pause)) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return 'Paused.';
    }

    if (commands.contains(RattilCommand.slower) && !_slow) {
      await _toggleSlow();
      said.add('Slowed down.');
    } else if (commands.contains(RattilCommand.slower)) {
      said.add('Already at the slower speed.');
    } else if (commands.contains(RattilCommand.normalSpeed) && _slow) {
      await _toggleSlow();
      said.add('Back to normal speed.');
    }

    if (commands.contains(RattilCommand.loop)) {
      setState(() => _afterClip = AfterClip.repeatOne);
      said.add('Looping this ayah.');
    } else if (commands.contains(RattilCommand.playOn)) {
      setState(() => _afterClip = AfterClip.continueOn);
      said.add('Playing on through the passage.');
    }

    final clips = widget.recitation.clips;
    if (commands.contains(RattilCommand.next)) {
      if (_clipIndex >= clips.length - 1) return [...said, 'That was the last ayah here.'].join(' ');
      setState(() => _clipIndex += 1);
      await _play();
      said.add('Ayah ${clips[_clipIndex].ayah}.');
    } else if (commands.contains(RattilCommand.previous)) {
      if (_clipIndex == 0) return [...said, 'That is the first ayah here.'].join(' ');
      setState(() => _clipIndex -= 1);
      await _play();
      said.add('Ayah ${clips[_clipIndex].ayah}.');
    } else if (commands.contains(RattilCommand.replay)) {
      await _play();
      said.add('Playing it again.');
    } else if (commands.contains(RattilCommand.resume) ||
        (said.isNotEmpty && !_playing && commands.intersection(_startsPlayback).isNotEmpty)) {
      await _play();
      said.add('Playing.');
    }
    return said.isEmpty ? 'Okay.' : said.join(' ');
  }

  /// Asking for a loop or to play on, with nothing playing, means "play it".
  static const _startsPlayback = {RattilCommand.loop, RattilCommand.playOn};

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
    if (widget.controller?._card == this) widget.controller!._card = null;
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
