class TajweedRule {
  final String id;
  final String title;
  final String arabicExample;
  final String shortDescription;
  final String fullExplanation;
  final String category;
  final bool isBookmarked;

  /// Whether MakharijPro actually checks this rule during recitation analysis.
  /// Shown in the UI so a rule being in this library doesn't imply the AI is
  /// grading it.
  ///
  /// Must match what backend/app/tajweed_diff.py reports: makhraj, madd,
  /// ghunnah (ikhfa is reported under it) and shaddah. Qalqalah is not
  /// checked. This used to follow model v1, the clip-level classifier, which
  /// covered only Ghunnah, Ikhfa and Separate Madd -- so after the app moved
  /// to word-level analysis, Makhraj and Shaddah were labelled "reference
  /// only" while being checked on every recitation.
  final bool isAiDetectable;

  const TajweedRule({
    required this.id,
    required this.title,
    required this.arabicExample,
    required this.shortDescription,
    required this.fullExplanation,
    required this.category,
    this.isBookmarked = false,
    this.isAiDetectable = false,
  });

  TajweedRule copyWith({bool? isBookmarked}) {
    return TajweedRule(
      id: id,
      title: title,
      arabicExample: arabicExample,
      shortDescription: shortDescription,
      fullExplanation: fullExplanation,
      category: category,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isAiDetectable: isAiDetectable,
    );
  }
}
