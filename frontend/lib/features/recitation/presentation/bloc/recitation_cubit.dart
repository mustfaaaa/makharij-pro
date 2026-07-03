import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../services/service_locator.dart';
import 'recitation_state.dart';

/// Owns the Idle -> Listening -> Processing -> Result state machine for a
/// single recitation session. This is the exact shape the real audio-upload
/// + AI-inference flow will follow once the backend lands (Phase 10-12) —
/// only [_stopAndProcess] changes from a dummy delay to a real API call.
class RecitationCubit extends Cubit<RecitationState> {
  RecitationCubit() : super(const RecitationState());

  void beginSession(int surahNumber) {
    emit(RecitationState(status: RecitationStatus.idle, surahNumber: surahNumber));
  }

  void startListening() {
    if (state.surahNumber == null) return;
    emit(state.copyWith(status: RecitationStatus.listening));
  }

  Future<void> stopAndProcess() async {
    final surahNumber = state.surahNumber;
    if (surahNumber == null) return;
    emit(state.copyWith(status: RecitationStatus.processing));
    try {
      final result = await Services.session.generateSessionResult(surahNumber);
      emit(state.copyWith(status: RecitationStatus.result, result: result));
    } on AppException catch (e) {
      emit(state.copyWith(status: RecitationStatus.error, errorMessage: e.message));
    }
  }

  void reset() {
    emit(const RecitationState());
  }
}
