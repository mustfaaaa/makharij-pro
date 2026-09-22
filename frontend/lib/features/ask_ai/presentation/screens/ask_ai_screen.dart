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
import '../../../../services/api_config.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/audio/qari_player_controller.dart';
import '../../../../shared/widgets/feedback/app_bottom_sheet.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/photo.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../widgets/rattil_widgets.dart';

/// Rattil AI — reference recitations (FR-15 to FR-19) and questions about
/// reciting. A typed message is read first by [RattilRequestParser] --
/// rule-based, tested, instant and offline -- into a surah or ayat, a reciter,
/// a player command or a Tajweed rule. Only a message it cannot read goes to
/// Rattil's assistant (Google Gemini, through the backend), and whatever that
/// asks to do is validated by the same parser before anything plays. The
/// reciter can also be picked on screen (FR-16), and the ayah being recited is
/// shown as it plays.
///
/// It is laid out as a listening room rather than a chat window: reciters as
/// name plates always in reach, answers as study notes, and every player
/// control (once, continue, repeat; slow, normal, fast) visible rather than
/// only typeable.
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
  /// rules -- said under the note, since the user's question went to Google.
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

  /// Whether this player is sounding right now. The header reads it: the bars
  /// and the filling line are only ever shown while audio is really playing.
  final ValueNotifier<bool> playing = ValueNotifier(false);

  bool get attached => _card != null;

  /// Carries out [commands] and says what was done, in a sentence for the chat.
  Future<String> apply(Set<RattilCommand> commands) async {
    final card = _card;
    if (card == null) return 'Nothing is playing yet. Ask for a surah or ayat first.';
    return card._apply(commands);
  }
}

/// Suggested starts, grouped by what the reciter wants to do. Each one is a
/// message the parser or the assistant genuinely handles.
const _promptGroups = [
  ('Listen', ['Al-Fatihah', 'Ayat al-Kursi on loop', 'Al-Ikhlas by Alafasy', 'Al-Mulk slowly']),
  ('Learn', ['What is Ghunnah?', 'What is Madd?', 'What is Qalqalah?']),
  ('Your practice', ['What should I practise next?']),
];

enum _LibraryStatus { loading, ready, failed }

class _AskAiScreenState extends State<AskAiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  List<Qari> _qaris = const [];
  List<Surah> _surahs = const [];
  _LibraryStatus _status = _LibraryStatus.loading;
  late RattilRequestParser _parser;

  bool get _ready => _status != _LibraryStatus.loading;

  /// The header folds while the conversation is scrolled, and wakes while a
  /// Qari is reciting. Both are plain flags; nothing here invents motion.
  bool _collapsed = false;
  bool _reciting = false;

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
    _loadLibrary();
  }

  /// Loads the reciters and surah list. It used to mark the screen "ready"
  /// even when this failed, so a green status sat beside an error; the status
  /// now says what actually happened, and a failure can be retried.
  /// The Retry beside "Offline": look for the server again, then reload. A
  /// button that only repeated the same failing call would be a lie.
  Future<void> _retryLibrary() async {
    setState(() => _status = _LibraryStatus.loading);
    await ApiConfig.ensureReachable(force: true);
    if (!mounted) return;
    _loadLibrary();
  }

  void _loadLibrary() {
    setState(() => _status = _LibraryStatus.loading);
    Future.wait([Services.rattil.getQaris(), Services.surah.getSurahs()])
        .then((results) {
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
            _status = _LibraryStatus.ready;
            _messages.removeWhere((m) => !m.fromUser && m.recitation == null && m.text == _unreachable);
            // No welcome paragraph: the resting screen already asks the
            // question, and who has which surahs is on the reciter sheet.
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _status = _LibraryStatus.failed;
            if (_messages.isEmpty) _messages.add(const _ChatMessage(fromUser: false, text: _unreachable));
          });
        });
  }

  static const _unreachable = 'The reciters could not be reached. Check your connection, then tap Retry above.';

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

    if (_status != _LibraryStatus.ready || _qaris.isEmpty) {
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
  /// the same validation a typed request gets.
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
          final request = RattilRequest(surah: surah, qari: qari, ayahStart: action.ayahStart, ayahEnd: action.ayahEnd);
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
    final before = _messages.length - 2;
    for (final m in _messages.skip(1).take(before < 0 ? 0 : before)) {
      if (m.text.isEmpty) continue;
      final text = m.text.length > 1200 ? m.text.substring(0, 1200) : m.text;
      turns.add({'role': m.fromUser ? 'user' : 'model', 'text': text});
    }
    return turns.length > 6 ? turns.sublist(turns.length - 6) : turns;
  }

  /// Picking a reciter (FR-16): the default from now on, and -- if something
  /// has already played -- the same ayat again in their voice.
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
        said = 'Nothing is playing yet. Ask for a surah or ayat first.';
      } else if (!player.attached) {
        said = 'That recitation has scrolled out of view. Ask for it again to keep going.';
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
        // FR-19: particular ayat, when asked for.
        ayahStart: reply.ayahStart,
        ayahEnd: reply.ayahEnd,
      );
      final said = '${reply.label}, recited by ${result.qariName}.';
      final player = _PlayerController();
      _watchPlayer(player);
      setState(
        () => _messages.add(
          _ChatMessage(
            fromUser: false,
            text: reply.note == null ? said : '${reply.note}\n$said',
            recitation: result,
            startWith: reply.commands,
            player: player,
          ),
        ),
      );
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
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final conversationStarted = _messages.any((m) => m.fromUser);
    final restingWithPrompts = _ready && !conversationStarted && _status == _LibraryStatus.ready;
    // Plain Column, not a CustomScrollView with a pinned SliverAppBar: that
    // arrangement rendered nothing at all on a real phone (the Scaffold
    // painted, the scrolling area stayed empty) while behaving on the web.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _RattilHeader(
            topPadding: top,
            status: _status,
            onRetry: _retryLibrary,
            collapsed: _collapsed,
            reciting: _reciting,
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                children: [
                  if (restingWithPrompts) _RestingLead(onPick: _send),
                  for (final message in _messages) _Message(message: message),
                  if (_thinking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Semantics(
                        liveRegion: true,
                        child: Row(
                          children: [
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Text('Rattil is thinking', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (conversationStarted && _status == _LibraryStatus.ready) _PromptStrip(onPick: _send),
          if (_ready && _qaris.isNotEmpty)
            _ReciterRow(
              qari: _selectedQari,
              totalSurahs: _surahs.length,
              onTap: _openReciterSheet,
            ),
          _Composer(controller: _controller, onSend: _send, enabled: _ready),
        ],
      ),
    );
  }

  /// Follows the player now on screen, so the header only wakes while that
  /// player is really sounding.
  void _watchPlayer(_PlayerController player) {
    _activePlayer?.playing.removeListener(_onPlayingChanged);
    _activePlayer = player;
    player.playing.addListener(_onPlayingChanged);
  }

  void _onPlayingChanged() {
    final value = _activePlayer?.playing.value ?? false;
    if (value != _reciting && mounted) setState(() => _reciting = value);
  }

  /// Folds the header once the reader has scrolled past the first lines.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final past = notification.metrics.pixels > 28;
    if (past != _collapsed) setState(() => _collapsed = past);
    return false;
  }

  /// The three reciters, on demand. FR-16 unchanged: picking one makes them
  /// the default and replays the last request in their voice.
  Future<void> _openReciterSheet() async {
    final picked = await AppBottomSheet.show<Qari>(
      context,
      title: 'Choose a reciter',
      child: _ReciterSheet(qaris: _qaris, selected: _selectedQari, totalSurahs: _surahs.length),
    );
    if (picked != null) await _pickQari(picked);
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _RattilHeader extends StatelessWidget {
  final double topPadding;
  final _LibraryStatus status;
  final VoidCallback onRetry;

  /// Folded while the conversation is scrolled.
  final bool collapsed;

  /// True only while a Qari is actually sounding.
  final bool reciting;

  const _RattilHeader({
    required this.topPadding,
    required this.status,
    required this.onRetry,
    required this.collapsed,
    required this.reciting,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 300);
    // The Mushaf is laid into the deep green at low opacity: it gives the
    // header its material without becoming the thing you look at first.
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      height: topPadding + (collapsed ? 62 : 134),
      decoration: BoxDecoration(color: AppColors.brandDeep),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.30,
              child: AppPhoto(AppPhotos.quranGreenCloth, alignment: const Alignment(0, 0.25)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.brandDeep.withValues(alpha: 0.72),
                    AppColors.brandDeep.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -14,
              bottom: -20,
              child: ExcludeSemantics(
                child: Text(
                  'رَتِّل',
                  textDirection: TextDirection.rtl,
                  style: AppTypography.quran(fontSize: 78, color: AppColors.gold, height: 1.0)
                      .copyWith(color: AppColors.gold.withValues(alpha: 0.17)),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.screenPadding,
              top: topPadding + 10,
              child: _StatusChip(status: status, onRetry: onRetry, reciting: reciting),
            ),
            Positioned(
              left: AppSpacing.screenPadding + 2,
              right: AppSpacing.screenPadding,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Semantics(
                        header: true,
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          style: AppTypography.displayText(
                            fontSize: collapsed ? 20 : 27,
                            color: AppColors.textOnPhoto,
                            height: 1.15,
                          ),
                          child: const Text('Rattil'),
                        ),
                      ),
                      if (reciting) ...[
                        const SizedBox(width: 12),
                        const _RecitingBars(),
                      ],
                    ],
                  ),
                  AnimatedSize(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: collapsed
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              'Listen to a Qari, or ask about Tajweed.',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textOnPhotoSecondary),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _HeaderRule(reciting: reciting)),
          ],
        ),
      ),
    );
  }
}

/// The gold hairline under the header. It breathes slowly while nothing is
/// playing; it never pretends to be a progress bar.
class _HeaderRule extends StatefulWidget {
  final bool reciting;
  const _HeaderRule({required this.reciting});

  @override
  State<_HeaderRule> createState() => _HeaderRuleState();
}

class _HeaderRuleState extends State<_HeaderRule> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reciting) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_HeaderRule old) {
    super.didUpdateWidget(old);
    if (widget.reciting) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.reciting) {
      return Container(
        height: 2,
        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.22)),
      );
    }
    final line = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0),
            AppColors.gold,
            AppColors.gold.withValues(alpha: 0),
          ],
        ),
      ),
      child: const SizedBox(height: 1, width: double.infinity),
    );
    if (reduce) return Opacity(opacity: 0.5, child: line);
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) => Opacity(
        opacity: 0.30 + 0.45 * Curves.easeInOut.transform(_breath.value),
        child: child,
      ),
      child: line,
    );
  }
}

/// Four gold bars beside the wordmark while a Qari is reciting.
class _RecitingBars extends StatefulWidget {
  const _RecitingBars();

  @override
  State<_RecitingBars> createState() => _RecitingBarsState();
}

class _RecitingBarsState extends State<_RecitingBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Reciting',
      excludeSemantics: true,
      child: SizedBox(
        height: 16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  final phase = (_c.value + i * 0.18) % 1.0;
                  final scale = reduce ? 0.7 : 0.28 + 0.72 * Curves.easeInOut.transform(phase);
                  return SizedBox(height: 16 * scale, child: child);
                },
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _LibraryStatus status;
  final VoidCallback onRetry;
  final bool reciting;
  const _StatusChip({required this.status, required this.onRetry, this.reciting = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (Color dot, String label) = switch (status) {
      _LibraryStatus.loading => (AppColors.textOnPhotoSecondary, 'Loading reciters'),
      _LibraryStatus.ready => (const Color(0xFF7FD6A6), reciting ? 'Reciting' : 'Ready'),
      _LibraryStatus.failed => (const Color(0xFFF2B8A0), 'Offline'),
    };
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.photoScrim.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.textOnPhoto.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: textTheme.labelSmall?.copyWith(color: AppColors.textOnPhoto)),
          if (status == _LibraryStatus.failed) ...[
            const SizedBox(width: 8),
            Text(
              'Retry',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textOnPhoto,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textOnPhoto,
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      button: status == _LibraryStatus.failed,
      label: status == _LibraryStatus.failed ? 'Reciters could not be reached. Retry' : label,
      excludeSemantics: true,
      child: status == _LibraryStatus.failed
          ? InkWell(onTap: onRetry, borderRadius: BorderRadius.circular(999), child: chip)
          : chip,
    );
  }
}

class _Message extends StatelessWidget {
  final _ChatMessage message;
  const _Message({required this.message});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final Widget body;
    if (message.fromUser) {
      body = Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.container,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(message.text, style: textTheme.bodyLarge),
          ),
        ),
      );
    } else {
      // A study note, not a speech bubble: Rattil's words sit on the page.
      body = Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RosetteBadge(size: 18, fill: AppColors.goldWash),
                const SizedBox(width: 8),
                Text(
                  'Rattil',
                  style: textTheme.labelMedium?.copyWith(color: AppColors.goldInk, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(message.text, style: textTheme.bodyLarge?.copyWith(height: 1.55)),
            if (message.viaAssistant) ...[
              const SizedBox(height: 6),
              // The user's question went to Google to get this; say so, and
              // that it can be wrong. The app's own answers are not marked.
              Text('Answered with Google Gemini · can make mistakes', style: textTheme.labelSmall),
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
              // explanation and the examples.
              OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.ruleDetailsPath(message.rule!.id)),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text('Read about ${message.rule!.title.split(' (').first}'),
              ),
            ],
          ],
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: body,
    );
  }
}

// ── The listening card ───────────────────────────────────────────────────────

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

  /// One place to change the flag, so the header hears about it too.
  void _reportPlaying(bool value) {
    if (mounted) setState(() => _playing = value);
    widget.controller?.playing.value = value;
  }
  QariSpeed _speed = QariSpeed.normal;
  int _clipIndex = 0;
  AfterClip _afterClip = AfterClip.stop;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

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
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _loadText();
    widget.controller?._card = this;
    // "Ayat al-Kursi slowly, on loop": the player starts set up that way.
    final start = widget.startWith;
    if (start.contains(RattilCommand.slower)) _speed = QariSpeed.slow;
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
    if (!mounted) return 'Nothing is playing yet. Ask for a surah or ayat first.';
    final said = <String>[];

    if (commands.contains(RattilCommand.pause)) {
      await _player.pause();
      _reportPlaying(false);
      return 'Paused.';
    }

    if (commands.contains(RattilCommand.slower) && _speed != QariSpeed.slow) {
      await _setSpeed(QariSpeed.slow);
      said.add('Slowed down.');
    } else if (commands.contains(RattilCommand.slower)) {
      said.add('Already at the slower speed.');
    } else if (commands.contains(RattilCommand.normalSpeed) && _speed != QariSpeed.normal) {
      await _setSpeed(QariSpeed.normal);
      said.add('Back to normal speed.');
    }

    if (commands.contains(RattilCommand.loop)) {
      setState(() => _afterClip = AfterClip.repeatOne);
      said.add('Repeating this ayah.');
    } else if (commands.contains(RattilCommand.playOn)) {
      setState(() => _afterClip = AfterClip.continueOn);
      said.add('Continuing through the passage.');
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
        // looping back to the first ayah.
        if (_clipIndex < widget.recitation.clips.length - 1) {
          setState(() => _clipIndex += 1);
          await _play();
        } else {
          _reportPlaying(false);
        }
      case AfterClip.stop:
        _reportPlaying(false);
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
    await _player.setPlaybackRate(_speed.rate);
    await _player.play(UrlSource(clip.url));
    _reportPlaying(true);
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      _reportPlaying(false);
      return;
    }
    await _play();
  }

  Future<void> _setSpeed(QariSpeed speed) async {
    setState(() => _speed = speed);
    if (_playing) await _player.setPlaybackRate(speed.rate);
  }

  /// "Ayah 3 of 7" for a whole surah, where the ayah number and the position
  /// in the list are the same thing. For a range they are not -- 285-286
  /// would read "Ayah 285 of 2" -- so the position is given separately.
  String _ayahLabel(int ayah, bool hasMultiple) {
    final clips = widget.recitation.clips;
    if (!hasMultiple) return 'Ayah $ayah';
    if (clips.first.ayah == 1) return 'Ayah $ayah of ${clips.length}';
    return 'Ayah $ayah · ${_clipIndex + 1} of ${clips.length}';
  }

  Future<void> _skip(int delta) async {
    final next = _clipIndex + delta;
    if (next < 0 || next >= widget.recitation.clips.length) return;
    setState(() => _clipIndex = next);
    if (_playing) await _play();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final clip = widget.recitation.clips[_clipIndex];
    final hasMultiple = widget.recitation.clips.length > 1;
    final ayah = _ayahs[clip.ayah];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final progress = _duration.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final qariName = widget.recitation.qariName;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldWash,
                  border: Border.all(color: AppColors.gold, width: 1.2),
                ),
                child: Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.goldInk),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(qariName, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleSmall),
                    Text(
                      '${widget.recitation.surahNameEnglish} · ${_ayahLabel(clip.ayah, hasMultiple)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ayah != null) ...[
            const SizedBox(height: 10),
            // The words being recited, so the listener can follow along -- the
            // point of a reference recitation.
            AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
              child: RattilAyahText(
                key: ValueKey('${widget.recitation.surah}:${clip.ayah}'),
                arabic: QuranTextRepository.asRecited(widget.recitation.surah, ayah, _basmala),
                translation: ayah.translation,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Real playback position through this ayah's recording.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: progress, minHeight: 3),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(tooltip: 'Play again', icon: const Icon(Icons.replay_rounded), onPressed: _play),
              IconButton(
                tooltip: 'Previous ayah',
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: hasMultiple && _clipIndex > 0 ? () => _skip(-1) : null,
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: _playing ? 'Pause' : 'Play',
                onPressed: _toggle,
                iconSize: 30,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  fixedSize: const Size(56, 56),
                ),
                icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Next ayah',
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: hasMultiple && _clipIndex < widget.recitation.clips.length - 1 ? () => _skip(1) : null,
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (mode, label) in const [
                (AfterClip.stop, 'Once'),
                (AfterClip.continueOn, 'Continue'),
                (AfterClip.repeatOne, 'Repeat ayah'),
              ])
                _Toggle(label: label, selected: _afterClip == mode, onTap: () => setState(() => _afterClip = mode)),
              const SizedBox(width: 4),
              for (final s in QariSpeed.values)
                _Toggle(label: s.label, selected: _speed == s, onTap: () => _setSpeed(s)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Toggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: selected ? AppColors.onPrimarySurface : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ── Prompts and composer ─────────────────────────────────────────────────────

/// What the screen says before anything has been asked: one question, two
/// large ways to answer it, and the rest of the prompts kept quiet underneath.
/// Fewer choices at the top, bigger targets at the bottom.
class _RestingLead extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _RestingLead({required this.onPick});

  static const _cards = [
    ('Al-Fatihah', 'الفاتحة', '7 ayahs, from the start', 'Al-Fatihah'),
    ('Ayat al-Kursi', 'آية الكرسي', '2:255, on repeat', 'Ayat al-Kursi on loop'),
  ];

  static const _quiet = [
    'Al-Mulk slowly',
    'Al-Ikhlas by Alafasy',
    'What is Ghunnah?',
    'What should I practise next?',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RosetteBadge(size: 18, stroke: AppColors.gold),
            const SizedBox(width: 8),
            Text('Rattil', style: textTheme.labelSmall?.copyWith(color: AppColors.goldInk, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text('What would you like to hear?', style: textTheme.headlineMedium),
        ),
        const SizedBox(height: 4),
        Text(
          'Name a surah or an ayah, and a reciter if you have one in mind.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.55),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final (title, arabic, subtitle, prompt) in _cards)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SuggestionCard(
              title: title,
              arabic: arabic,
              subtitle: subtitle,
              onTap: () => onPick(prompt),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final p in _quiet) _PromptChip(label: p, onTap: () => onPick(p))],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// One large way in: a surah, its name in Arabic, and what will happen.
class _SuggestionCard extends StatelessWidget {
  final String title;
  final String arabic;
  final String subtitle;
  final VoidCallback onTap;
  const _SuggestionCard({required this.title, required this.arabic, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Play $title, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.lgRadius, side: BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.lgRadius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.play_arrow_rounded, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(arabic, textDirection: TextDirection.rtl, style: AppTypography.arabicWord(fontSize: 19, color: AppColors.goldInk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Who will recite, said plainly, one row above the place you type. Always
/// readable, never loud; the three reciters open in a sheet when tapped.
class _ReciterRow extends StatelessWidget {
  final Qari? qari;
  final int totalSurahs;
  final VoidCallback onTap;
  const _ReciterRow({required this.qari, required this.totalSurahs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final q = qari;
    final name = q == null ? 'a reciter' : RattilRequestParser.shortName(q);
    final coverage = q == null
        ? ''
        : (q.availableSurahs.length >= totalSurahs ? 'Whole Quran' : '${q.availableSurahs.length} surahs');
    return Semantics(
      button: true,
      label: 'Reciter: $name, $coverage. Choose another.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.background,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: AppColors.goldWash, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    q == null ? '؟' : q.nameArabic.characters.first,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.arabicWord(fontSize: 13, color: AppColors.goldInk),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      children: [
                        const TextSpan(text: 'Reciting with '),
                        TextSpan(
                          text: name,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        if (coverage.isNotEmpty) TextSpan(text: ' · $coverage'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The three reciters, each with their name as it is written and how much of
/// the Quran they have here.
class _ReciterSheet extends StatelessWidget {
  final List<Qari> qaris;
  final Qari? selected;
  final int totalSurahs;
  const _ReciterSheet({required this.qaris, required this.selected, required this.totalSurahs});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Used for everything you ask next.', style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        for (final q in qaris) ...[
          Builder(
            builder: (context) {
              final isSelected = q.qariId == selected?.qariId;
              final coverage =
                  q.availableSurahs.length >= totalSurahs ? 'Whole Quran' : '${q.availableSurahs.length} surahs';
              return Semantics(
                button: true,
                selected: isSelected,
                label: 'Reciter ${q.nameEnglish}, $coverage',
                excludeSemantics: true,
                child: Material(
                  color: isSelected ? AppColors.primarySurface : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.lgRadius,
                    side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(q),
                    borderRadius: AppRadii.lgRadius,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              q.nameArabic,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.arabicWord(fontSize: 19, color: AppColors.goldInk),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(RattilRequestParser.shortName(q), style: textTheme.titleSmall),
                                const SizedBox(height: 2),
                                Text(coverage, style: textTheme.bodySmall),
                              ],
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_rounded, size: 20, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PromptStrip extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _PromptStrip({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final prompts = [for (final (_, p) in _promptGroups) ...p];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 4, AppSpacing.screenPadding, 4),
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _PromptChip(label: prompts[i], onTap: () => onPick(prompts[i])),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13.5)),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  const _Composer({required this.controller, required this.onSend, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding - 4, 10, AppSpacing.screenPadding - 4, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 4, 5, 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ask for a surah, a reciter or a rule',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: enabled ? onSend : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  fixedSize: const Size(46, 46),
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
