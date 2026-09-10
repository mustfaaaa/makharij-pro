import 'package:flutter/material.dart';

import '../../../../services/service_locator.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

/// Lets the reciter overrule one flagged word.
///
/// On real learner recordings the detector wrongly flags roughly two correct
/// recitations in five (ml/eval/README.md). With a number like that, insisting
/// is the wrong posture: the person who recited the word heard it, and the
/// screen should let them say so instead of arguing.
///
/// What it records is also the scarcest thing here. Every Tajweed corpus we
/// found labels whole clips, or is built from errors produced on purpose. A
/// per-word judgement from a learner on their own recitation exists nowhere
/// else, and it is the material a "real mistake vs recogniser noise" filter
/// would have to be trained on.
class SaidItRightButton extends StatefulWidget {
  final String? sessionId;
  final int ayahNumber;
  final int wordIndex;

  const SaidItRightButton({
    super.key,
    required this.sessionId,
    required this.ayahNumber,
    required this.wordIndex,
  });

  @override
  State<SaidItRightButton> createState() => _SaidItRightButtonState();
}

class _SaidItRightButtonState extends State<SaidItRightButton> {
  bool _sending = false;
  bool _marked = false;

  Future<void> _mark() async {
    final sessionId = widget.sessionId;
    if (sessionId == null) return;

    // Marked immediately rather than after the round trip. The reciter has
    // already made the judgement; making them wait on the network to see it
    // acknowledged would be the screen arguing again, in a smaller way.
    setState(() {
      _marked = true;
      _sending = true;
    });
    try {
      await Services.session.recordWordFeedback(
        sessionId: sessionId,
        ayahNumber: widget.ayahNumber,
        wordIndex: widget.wordIndex,
        agreed: false,
      );
    } catch (_) {
      // The mark stands either way. It is the reciter's own reading of their
      // own recitation -- losing the upload is our problem, not theirs, and
      // reverting it on screen would tell them they were wrong to disagree.
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    // No session to attach it to (a preview result) -- offering the button
    // would promise something it can't keep.
    if (widget.sessionId == null) return const SizedBox.shrink();

    if (_marked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Text(
              _sending ? 'Noting that…' : 'Noted — thank you',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return TextButton.icon(
      onPressed: _mark,
      icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
      label: const Text('I said it right'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
