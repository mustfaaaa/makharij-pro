import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/service_locator.dart';

/// User-adjustable verse text size, applied on recitation screens so the
/// Arabic text stays legible when the phone is propped up at a distance.
enum VerseTextSize { small, medium, large }

extension VerseTextSizeX on VerseTextSize {
  double get scale {
    switch (this) {
      case VerseTextSize.small:
        return 0.85;
      case VerseTextSize.medium:
        return 1.0;
      case VerseTextSize.large:
        return 1.3;
    }
  }

  String get label {
    switch (this) {
      case VerseTextSize.small:
        return 'Small';
      case VerseTextSize.medium:
        return 'Medium';
      case VerseTextSize.large:
        return 'Large';
    }
  }
}

class VerseTextSizeCubit extends Cubit<VerseTextSize> {
  VerseTextSizeCubit() : super(Services.prefs.verseTextSize);

  Future<void> setSize(VerseTextSize size) async {
    if (size == state) return;
    emit(size);
    await Services.prefs.setVerseTextSize(size);
  }
}
