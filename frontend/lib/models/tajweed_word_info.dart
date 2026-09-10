/// What a word *is* — its articulation point and the Tajweed rules that apply
/// to it — as opposed to how any particular recitation of it went.
///
/// This comes from `GET /api/v1/tajweed/word/...`, a reference table derived
/// from the Quran's own phone sequences. It runs no model, so unlike a
/// [WordVerdict] there is no confidence to weigh and nothing to hedge: when
/// this says a word carries a four-count madd, that is what the word is.
///
/// That is why the app can teach from this on screens where it would not
/// dare pass judgement.
class TajweedWordInfo {
  final int surah;
  final int ayah;

  /// 1-based within the ayah, Basmala excluded — the reference table's own
  /// indexing, not the reading page's. The backend does the conversion.
  final int wordIndex;

  final String wordAr;
  final String wordTransliteration;

  /// The articulation point the word's first consonant comes from.
  final String makhrajId;
  final String makhrajLetters;
  final String makhrajEnglish;

  /// Every articulation point the word touches, not just the opening one.
  final List<String> makhrajSet;

  /// Rule ids that apply: ghunnah, shaddah, madd, qalqalah, tafkheem.
  final List<String> rules;

  /// Prescribed elongation in harakat (0, 2, 4 or 6).
  ///
  /// Prescribed, not measured: this is how long the madd *should* be held,
  /// never how long the reciter actually held it. Wording in the UI has to
  /// respect that distinction.
  final int maddLength;

  final String? qalqalahClass;
  final String? ghunnahType;
  final String? tafkheemClass;
  final int phoneCount;

  const TajweedWordInfo({
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.wordAr,
    required this.wordTransliteration,
    required this.makhrajId,
    required this.makhrajLetters,
    required this.makhrajEnglish,
    required this.makhrajSet,
    required this.rules,
    required this.maddLength,
    this.qalqalahClass,
    this.ghunnahType,
    this.tafkheemClass,
    required this.phoneCount,
  });

  factory TajweedWordInfo.fromJson(Map<String, dynamic> json) {
    final makhraj = (json['makhraj'] as Map?)?.cast<String, dynamic>() ?? const {};
    final detail = (json['detail'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TajweedWordInfo(
      surah: json['surah'] as int? ?? 0,
      ayah: json['ayah'] as int? ?? 0,
      wordIndex: json['word_index'] as int? ?? 0,
      wordAr: json['word_ar'] as String? ?? '',
      wordTransliteration: json['word_tr'] as String? ?? '',
      makhrajId: makhraj['id'] as String? ?? '',
      makhrajLetters: makhraj['letters'] as String? ?? '',
      makhrajEnglish: makhraj['english'] as String? ?? '',
      makhrajSet: ((json['makhraj_set'] as List?) ?? const []).map((e) => '$e').toList(),
      rules: ((json['rules'] as List?) ?? const []).map((e) => '$e').toList(),
      maddLength: json['madd_length'] as int? ?? 0,
      qalqalahClass: detail['qalqalah_class'] as String?,
      ghunnahType: detail['ghunnah_type'] as String?,
      tafkheemClass: detail['tafkheem_class'] as String?,
      phoneCount: json['n_phones'] as int? ?? 0,
    );
  }

  /// Every articulation point *after* the opening one, for the "also touches"
  /// line. Empty when the word never leaves where it started.
  List<String> get secondaryMakharij =>
      makhrajSet.where((m) => m != makhrajId).toList();
}
