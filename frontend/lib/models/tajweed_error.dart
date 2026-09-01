enum TajweedErrorType { makhraj, ghunnah, shaddah, madd, skipped }

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
      case TajweedErrorType.skipped:
        return 'Skipped';
    }
  }

  /// Wire id used by the backend's word-level analysis -- must stay in sync
  /// with backend/app/tajweed_diff.py.
  String get id => name;
}

/// Maps the backend's `error_type` string onto the enum. Returns null for
/// null/unknown ids rather than throwing, so a server that later adds a new
/// rule category doesn't crash an older client.
TajweedErrorType? tajweedErrorTypeFromId(String? id) {
  if (id == null) return null;
  for (final type in TajweedErrorType.values) {
    if (type.id == id) return type;
  }
  return null;
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
