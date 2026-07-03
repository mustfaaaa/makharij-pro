import 'package:equatable/equatable.dart';

import '../../../../models/session_result.dart';

enum RecitationStatus { idle, listening, processing, result, error }

class RecitationState extends Equatable {
  final RecitationStatus status;
  final int? surahNumber;
  final SessionResult? result;
  final String? errorMessage;

  const RecitationState({
    this.status = RecitationStatus.idle,
    this.surahNumber,
    this.result,
    this.errorMessage,
  });

  RecitationState copyWith({
    RecitationStatus? status,
    int? surahNumber,
    SessionResult? result,
    String? errorMessage,
  }) {
    return RecitationState(
      status: status ?? this.status,
      surahNumber: surahNumber ?? this.surahNumber,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, surahNumber, result, errorMessage];
}
