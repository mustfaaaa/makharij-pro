/// One Tajweed rule the user should work on, ranked by how often their own
/// recitations actually broke it.
///
/// Every recommendation now carries [examples]: the real words, from the user's
/// own sessions, that were flagged for this rule. Before per-word verdicts were
/// stored, the plan could only say "this rule was flagged N times" and had no
/// evidence to show for it.
class PracticePlanItem {
  final String rule;
  final String tajweedRule;
  final String reason;
  final int? errorCount;
  final List<PracticePlanExample> examples;

  const PracticePlanItem({
    required this.rule,
    required this.tajweedRule,
    required this.reason,
    this.errorCount,
    this.examples = const [],
  });

  factory PracticePlanItem.fromJson(Map<String, dynamic> json) {
    return PracticePlanItem(
      rule: json['rule'] as String,
      tajweedRule: json['tajweed_rule'] as String,
      reason: json['reason'] as String,
      errorCount: json['error_count'] as int?,
      examples: ((json['examples'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PracticePlanExample.fromJson)
          .toList(),
    );
  }
}

/// A specific word the user got wrong, kept so the plan can point at evidence
/// instead of asserting a weakness.
class PracticePlanExample {
  final int? surahNumber;
  final int? ayahNumber;
  final String word;
  final String explanation;

  const PracticePlanExample({
    this.surahNumber,
    this.ayahNumber,
    required this.word,
    required this.explanation,
  });

  factory PracticePlanExample.fromJson(Map<String, dynamic> json) {
    return PracticePlanExample(
      surahNumber: json['surah_number'] as int?,
      ayahNumber: json['ayah_number'] as int?,
      word: json['word'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }
}
