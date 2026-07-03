import '../models/session_result.dart';
import '../models/tajweed_error.dart';

final List<SessionResult> dummySessions = [
  SessionResult(
    id: 's1',
    surahName: 'Al-Fatihah',
    surahNumber: 1,
    dateTime: DateTime.now().subtract(const Duration(hours: 3)),
    accuracyScore: 92,
    duration: const Duration(minutes: 2, seconds: 14),
    errors: const [
      TajweedError(word: 'الْحَمْدُ', ayahNumber: 2, type: TajweedErrorType.madd, explanation: 'The madd on "ح" was shortened; hold it for two counts.'),
      TajweedError(word: 'مَالِكِ', ayahNumber: 4, type: TajweedErrorType.makhraj, explanation: 'The "ك" was pronounced too far back; bring the articulation point forward.'),
    ],
  ),
  SessionResult(
    id: 's2',
    surahName: 'Al-Kahf',
    surahNumber: 18,
    dateTime: DateTime.now().subtract(const Duration(days: 1)),
    accuracyScore: 78,
    duration: const Duration(minutes: 6, seconds: 40),
    errors: const [
      TajweedError(word: 'إِنَّ', ayahNumber: 7, type: TajweedErrorType.shaddah, explanation: 'The shaddah on "ن" was not held firmly enough.'),
      TajweedError(word: 'الْأَرْضِ', ayahNumber: 7, type: TajweedErrorType.ghunnah, explanation: 'Missing nasal sound (ghunnah) before "ن".'),
      TajweedError(word: 'زِينَةً', ayahNumber: 7, type: TajweedErrorType.madd, explanation: 'The madd was extended slightly too long.'),
    ],
  ),
  SessionResult(
    id: 's3',
    surahName: 'Al-Mulk',
    surahNumber: 67,
    dateTime: DateTime.now().subtract(const Duration(days: 2)),
    accuracyScore: 95,
    duration: const Duration(minutes: 4, seconds: 3),
    errors: const [
      TajweedError(word: 'تَبَارَكَ', ayahNumber: 1, type: TajweedErrorType.makhraj, explanation: 'Slight misplacement of the "ت" articulation point.'),
    ],
  ),
  SessionResult(
    id: 's4',
    surahName: 'Ar-Rahman',
    surahNumber: 55,
    dateTime: DateTime.now().subtract(const Duration(days: 4)),
    accuracyScore: 68,
    duration: const Duration(minutes: 8, seconds: 12),
    errors: const [
      TajweedError(word: 'الرَّحْمَٰنِ', ayahNumber: 1, type: TajweedErrorType.ghunnah, explanation: 'Ghunnah on "ن" was too short.'),
      TajweedError(word: 'عَلَّمَ', ayahNumber: 2, type: TajweedErrorType.shaddah, explanation: 'Shaddah on "ل" was not emphasized.'),
    ],
  ),
];
