import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/quran_script.dart';
import '../../services/service_locator.dart';

/// Which script the Quran is written in -- Uthmani or IndoPak -- chosen under
/// "Aa" on the reading page and kept on this device.
class QuranScriptCubit extends Cubit<QuranScript> {
  QuranScriptCubit() : super(Services.prefs.quranScript);

  Future<void> setScript(QuranScript script) async {
    if (script == state) return;
    emit(script);
    await Services.prefs.setQuranScript(script);
  }
}
