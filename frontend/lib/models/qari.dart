class Qari {
  final String qariId;
  final String nameEnglish;
  final String nameArabic;
  final List<int> availableSurahs;

  const Qari({
    required this.qariId,
    required this.nameEnglish,
    required this.nameArabic,
    required this.availableSurahs,
  });

  factory Qari.fromJson(Map<String, dynamic> json) {
    return Qari(
      qariId: json['qariId'] as String,
      nameEnglish: json['nameEnglish'] as String,
      nameArabic: json['nameArabic'] as String,
      availableSurahs: (json['availableSurahs'] as List).cast<int>(),
    );
  }
}

class RecitationClip {
  final int ayah;
  final String url;
  const RecitationClip({required this.ayah, required this.url});

  factory RecitationClip.fromJson(Map<String, dynamic> json) {
    return RecitationClip(ayah: json['ayah'] as int, url: json['url'] as String);
  }
}

class RecitationResult {
  final String qariId;
  final String qariName;
  final int surah;
  final String surahNameEnglish;
  final List<RecitationClip> clips;

  const RecitationResult({
    required this.qariId,
    required this.qariName,
    required this.surah,
    required this.surahNameEnglish,
    required this.clips,
  });

  factory RecitationResult.fromJson(Map<String, dynamic> json) {
    final surahName = json['surah_name'] as Map<String, dynamic>? ?? const {};
    return RecitationResult(
      qariId: json['qari_id'] as String,
      qariName: json['qari_name'] as String,
      surah: json['surah'] as int,
      surahNameEnglish: surahName['en'] as String? ?? 'Surah ${json['surah']}',
      clips: (json['clips'] as List).map((c) => RecitationClip.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }
}
