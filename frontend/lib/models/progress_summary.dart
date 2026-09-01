class ProgressSummary {
  final int totalSessions;
  final int currentStreak;
  final double overallAccuracy;

  /// Session counts per day for the last 10 weeks, shaped [week][day],
  /// capped 0-4 to match the dashboard's 5-level color scale.
  final List<List<int>> activityHeatmap;

  /// Rolling correct-rate (0-100) per Tajweed rule, keyed by display label
  /// (e.g. "Ghunnah (via An-Noon Al-Mushaddadah)"). Only covers the 3 rules
  /// the model actually detects -- absent entirely if there's no session
  /// history yet for a rule.
  final Map<String, double> ruleMastery;

  const ProgressSummary({
    required this.totalSessions,
    required this.currentStreak,
    required this.overallAccuracy,
    this.activityHeatmap = const [],
    this.ruleMastery = const {},
  });
}
