class Ayah {
  final int number;
  final String arabicText;
  final String translation;
  final List<int> errorWordIndexes;

  const Ayah({
    required this.number,
    required this.arabicText,
    required this.translation,
    this.errorWordIndexes = const [],
  });
}
