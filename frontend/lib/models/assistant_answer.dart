/// What Rattil's assistant sent back for a message the app's own parser could
/// not read (POST /api/v1/rattil/chat).
///
/// The reply is words only. Anything to do with the Quran itself comes as an
/// [AssistantAction] -- play these ayat, open this rule -- which the app carries
/// out with its own verified audio, text and library. The model is never the
/// source of Quranic text, so nothing here carries any.
class AssistantAnswer {
  final String reply;
  final List<AssistantAction> actions;

  const AssistantAnswer({required this.reply, this.actions = const []});

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) => AssistantAnswer(
        reply: (json['reply'] as String?)?.trim() ?? '',
        actions: [
          for (final a in (json['actions'] as List? ?? const []))
            if (a is Map<String, dynamic>) ?AssistantAction.fromJson(a),
        ],
      );
}

sealed class AssistantAction {
  const AssistantAction();

  /// Null for an action type this version of the app does not know -- a newer
  /// server must not be able to crash an older client.
  static AssistantAction? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'play':
        final surah = json['surah'];
        final qari = json['qari_id'];
        if (surah is! int || qari is! String) return null;
        return PlayAction(
          surah: surah,
          ayahStart: json['ayah_start'] as int?,
          ayahEnd: json['ayah_end'] as int?,
          qariId: qari,
        );
      case 'rule':
        final rule = json['rule'];
        return rule is String ? RuleAction(rule) : null;
      default:
        return null;
    }
  }
}

/// Play a surah, or a range of its ayat, by one reciter.
class PlayAction extends AssistantAction {
  final int surah;
  final int? ayahStart;
  final int? ayahEnd;
  final String qariId;

  const PlayAction({required this.surah, this.ayahStart, this.ayahEnd, required this.qariId});
}

/// Open a Tajweed rule in the app's library, by its everyday name ("ghunnah").
class RuleAction extends AssistantAction {
  final String rule;
  const RuleAction(this.rule);
}
