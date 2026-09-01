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

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      number: json['number'] as int,
      arabicText: json['arabicText'] as String,
      translation: json['translation'] as String,
    );
  }
}
