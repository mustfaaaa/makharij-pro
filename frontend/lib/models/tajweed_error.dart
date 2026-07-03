enum TajweedErrorType { makhraj, ghunnah, shaddah, madd }

extension TajweedErrorTypeLabel on TajweedErrorType {
  String get label {
    switch (this) {
      case TajweedErrorType.makhraj:
        return 'Makhraj';
      case TajweedErrorType.ghunnah:
        return 'Ghunnah';
      case TajweedErrorType.shaddah:
        return 'Shaddah';
      case TajweedErrorType.madd:
        return 'Madd';
    }
  }
}

class TajweedError {
  final String word;
  final int ayahNumber;
  final TajweedErrorType type;
  final String explanation;

  const TajweedError({
    required this.word,
    required this.ayahNumber,
    required this.type,
    required this.explanation,
  });
}
