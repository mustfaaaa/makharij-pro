import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

/// Rattil AI — the in-app Tajweed coach chat (Ask AI tab), built to match the
/// provided mockup: gold user bubbles, white AI bubbles with an embedded
/// reference-audio player, a bordered "Practice Now" card, suggestion chips
/// and a rounded composer at the bottom.
class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _ChatMessage {
  final bool fromUser;
  final List<InlineSpan> Function(BuildContext) spans;
  final bool showAudioCard;
  final bool showActions;
  _ChatMessage({
    required this.fromUser,
    required this.spans,
    this.showAudioCard = false,
    this.showActions = false,
  });
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final List<_ChatMessage> _messages;

  static TextSpan _gold(String text) => TextSpan(
        text: text,
        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
      );

  @override
  void initState() {
    super.initState();
    _messages = [
      _ChatMessage(
        fromUser: true,
        spans: (_) => [
          const TextSpan(text: "How do I make the distinct "),
          _gold("'ض'"),
          const TextSpan(text: " (Dhad) sound without merging it into "),
          _gold("'د'"),
          const TextSpan(text: " (Dal)?"),
        ],
      ),
      _ChatMessage(
        fromUser: false,
        showAudioCard: true,
        showActions: true,
        spans: (_) => [
          const TextSpan(text: 'Excellent question! While '),
          _gold("'د'"),
          const TextSpan(text: ' is formed at the tip of the tongue, '),
          _gold("'ض'"),
          const TextSpan(
              text:
                  ' uses the entire side-edge (حافة اللسان) of the tongue, pressing it against the inner surfaces of the upper molars.'),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, spans: (_) => [TextSpan(text: text)]));
      _messages.add(_ChatMessage(
        fromUser: false,
        spans: (_) => [
          const TextSpan(
              text:
                  'Great question! Rattil AI will answer this with a reference recitation once the backend is connected. For now, try the practice card below for live makhraj feedback.'),
        ],
      ));
      _controller.clear();
    });
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
            // ── Header: Rattil AI · Your tajweed coach ───────────────────
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
                        Text('Rattil AI',
                            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text('Your tajweed coach',
                                style: textTheme.bodyMedium?.copyWith(color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.history_rounded, color: AppColors.textSecondary, size: 22),
                      onPressed: () {},
                      tooltip: 'Chat history',
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
                  const SizedBox(height: 4),
                  const _PracticeNowCard(),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Try these questions',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _QuestionChip(label: 'Explain Sifat of Raa (ر)', onTap: () => _send('Explain Sifat of Raa (ر)')),
                      _QuestionChip(label: 'Rules of Waqf (stopping)', onTap: () => _send('Rules of Waqf (stopping)')),
                      _QuestionChip(label: 'Example of Ikhfa', onTap: () => _send('Example of Ikhfa')),
                    ],
                  ),
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
                          hintText: 'Ask Rattil AI anything...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.mic_rounded, color: AppColors.textSecondary),
                      tooltip: 'Voice input',
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
          child: Text.rich(
            TextSpan(
              children: message.spans(context),
              style: textTheme.bodyLarge?.copyWith(color: Colors.white, height: 1.45),
            ),
          ),
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
                Text.rich(
                  TextSpan(
                    children: message.spans(context),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
                if (message.showAudioCard) ...[
                  const SizedBox(height: 14),
                  const _AudioExampleCard(),
                ],
                if (message.showActions) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Pressable(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppRadii.pillRadius,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.mic_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Try it now',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: AppRadii.pillRadius,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text('More examples',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ],
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

// ── Reference audio player embedded in the AI bubble ─────────────────────────
class _AudioExampleCard extends StatelessWidget {
  const _AudioExampleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadii.mdRadius,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(child: _MiniWaveform()),
            ],
          ),
          const SizedBox(height: 8),
          Text('Correct Dhad example · 0:06',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Static decorative waveform bars — gold on the left fading to muted on the
/// right, echoing the mockup.
class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform();

  @override
  Widget build(BuildContext context) {
    const heights = [8.0, 14.0, 9.0, 18.0, 12.0, 16.0, 8.0, 13.0, 10.0, 7.0, 12.0, 9.0, 7.0, 11.0, 8.0, 12.0, 7.0, 10.0, 8.0, 6.0, 9.0, 7.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < heights.length; i++)
          Container(
            width: 3.5,
            height: heights[i],
            decoration: BoxDecoration(
              color: i < heights.length * 0.4
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
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
                Text('Practice Now: Dhad (ض)',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Say "Al-Ardu" (الأَرْض) with the mic for live feedback',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () => context.push(RoutePaths.surahDetailsPath(1)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadii.pillRadius),
              child: const Text('Practice',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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
        child: Text(label,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
      ),
    );
  }
}
