class TajweedRule {
  final String id;
  final String title;
  final String arabicExample;
  final String shortDescription;
  final String fullExplanation;
  final String category;
  final bool isBookmarked;

  /// Whether MakharijPro's model actually checks this rule during recitation
  /// analysis (only Ghunnah, Ikhfa, and Separate Madd are -- see
  /// model_card.json known_limitations). Shown in the UI so a rule being in
  /// this library doesn't imply the AI is grading it.
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
