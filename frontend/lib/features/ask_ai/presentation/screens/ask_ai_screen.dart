import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/qari.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

/// Rattil AI — real reference-recitation retrieval (FR-15/16/17), not a
/// general Tajweed-knowledge chatbot. There's no NLP/LLM backend behind this;
/// matching a typed request to a surah + Qari is done here by name/number,
/// which is honest about what it actually is (see rattil.py's own docstring:
/// natural-language parsing, FR-19, is explicitly future work).
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
        _ready = true;
        final example = _qaris.isEmpty ? '' : ' — try "Al-Fatihah by ${_qaris.first.nameEnglish}"';
        _messages.add(_ChatMessage(
          fromUser: false,
          text: 'Ask for a surah and (optionally) a reciter$example. '
              '${_availableSurahNames()} are available right now.',
        ));
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

  String _availableSurahNames() {
    final numbers = _qaris.expand((q) => q.availableSurahs).toSet();
    final names = _surahs.where((s) => numbers.contains(s.number)).map((s) => s.nameEnglish);
    return names.isEmpty ? 'A few surahs' : names.join(', ');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Surah? _matchSurah(String text) {
    final lower = text.toLowerCase();
    for (final s in _surahs) {
      if (lower.contains(s.nameEnglish.toLowerCase())) return s;
    }
    final numberMatch = RegExp(r'\b(\d{1,3})\b').firstMatch(text);
    if (numberMatch != null) {
      final n = int.tryParse(numberMatch.group(1)!);
      if (n != null) {
        for (final s in _surahs) {
          if (s.number == n) return s;
        }
      }
    }
    return null;
  }

  Qari? _matchQari(String text) {
    final lower = text.toLowerCase();
    for (final q in _qaris) {
      final firstName = q.nameEnglish.split(' ').first.toLowerCase();
      if (lower.contains(q.nameEnglish.toLowerCase()) || lower.contains(firstName)) return q;
    }
    return null;
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _controller.clear();
    setState(() => _messages.add(_ChatMessage(fromUser: true, text: text)));
    _scrollToEnd();

    final surah = _matchSurah(text);
    if (surah == null) {
      setState(() => _messages.add(_ChatMessage(
            fromUser: false,
            text: "I couldn't find a surah in that — try naming one, like \"Al-Ikhlas\" or \"surah 112\".",
          )));
      _scrollToEnd();
      return;
    }
    final qari = _matchQari(text) ?? (_qaris.isEmpty ? null : _qaris.first);
    if (qari == null) {
      setState(() => _messages.add(const _ChatMessage(fromUser: false, text: 'No reciters are available right now.')));
      return;
    }

    try {
      final result = await Services.rattil.getRecitation(qariId: qari.qariId, surah: surah.number);
      setState(() => _messages.add(_ChatMessage(
            fromUser: false,
            text: '${result.surahNameEnglish}, recited by ${result.qariName}:',
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
                        colors: [AppColors.primaryLight, AppColors.primaryDark],
                      ),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
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
                        for (final n in const ['Al-Fatihah', 'Al-Ikhlas', 'Al-Kawthar', 'An-Nas'])
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
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
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
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
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
              colors: [AppColors.primaryLight, AppColors.primaryDark],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(message.text, style: textTheme.bodyLarge?.copyWith(color: Colors.white, height: 1.45)),
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
          child: Icon(Icons.auto_awesome, size: 15, color: AppColors.primary),
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
              boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
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

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final clip = widget.recitation.clips[_clipIndex];
    await _player.stop();
    await _player.setPlaybackRate(_slow ? 0.75 : 1.0);
    await _player.play(UrlSource(clip.url));
    setState(() => _playing = true);
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
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
                  'Ayah ${clip.ayah}${hasMultiple ? ' of ${widget.recitation.clips.length}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.replay_rounded),
                color: AppColors.textSecondary,
                onPressed: _play,
                tooltip: 'Repeat',
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
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
            child: Icon(Icons.mic_rounded, color: AppColors.primary, size: 24),
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
              child: const Text('Practice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
      ),
    );
  }
}
