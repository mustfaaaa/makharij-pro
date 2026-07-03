class PracticePlanItem {
  final String id;
  final String surahName;
  final String reason;
  final String focusArea;
  final bool isCompleted;

  const PracticePlanItem({
    required this.id,
    required this.surahName,
    required this.reason,
    required this.focusArea,
    this.isCompleted = false,
  });
}
