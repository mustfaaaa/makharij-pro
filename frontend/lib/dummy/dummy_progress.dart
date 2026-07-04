import '../models/progress_point.dart';

final List<ProgressPoint> dummyProgressPoints = List.generate(14, (i) {
  final base = 60.0 + (i * 2.1);
  final wobble = (i % 3 == 0) ? -4.0 : (i % 4 == 0 ? 3.0 : 0.0);
  return ProgressPoint(
    date: DateTime.now().subtract(Duration(days: 13 - i)),
    score: (base + wobble).clamp(0, 100),
  );
});

final Map<String, double> dummyErrorTypeBreakdown = {
  'Makhraj': 32,
  'Ghunnah': 24,
  'Shaddah': 18,
  'Madd': 26,
};

/// Per-rule mastery (0..100) for the profile radar chart.
final Map<String, double> dummyTajweedMastery = {
  'Makhraj': 82,
  'Ghunnah': 68,
  'Shaddah': 90,
  'Madd': 74,
  'Qalqalah': 79,
};
