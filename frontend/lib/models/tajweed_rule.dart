class TajweedRule {
  final String id;
  final String title;
  final String arabicExample;
  final String shortDescription;
  final String fullExplanation;
  final String category;
  final bool isBookmarked;

  const TajweedRule({
    required this.id,
    required this.title,
    required this.arabicExample,
    required this.shortDescription,
    required this.fullExplanation,
    required this.category,
    this.isBookmarked = false,
  });
}
