import '../dummy/dummy_progress.dart';
import '../models/progress_point.dart';
import '../models/progress_summary.dart';
import 'api_client.dart';

abstract class ProgressService {
  Future<List<ProgressPoint>> getProgressPoints();
  Future<Map<String, double>> getErrorTypeBreakdown();
  Future<ProgressSummary> getSummary();
}

class DummyProgressService implements ProgressService {
  @override
  Future<List<ProgressPoint>> getProgressPoints() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(dummyProgressPoints);
  }

  @override
  Future<Map<String, double>> getErrorTypeBreakdown() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return Map.unmodifiable(dummyErrorTypeBreakdown);
  }

  @override
  Future<ProgressSummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const ProgressSummary(
      totalSessions: 47,
      currentStreak: 12,
      overallAccuracy: 86.4,
      activityHeatmap: [
        [1, 2, 0, 1, 0, 3, 4], [0, 3, 3, 2, 4, 3, 2], [2, 1, 2, 0, 1, 2, 3], [0, 0, 2, 1, 3, 2, 4],
        [1, 2, 0, 3, 2, 4, 3], [2, 0, 1, 2, 3, 2, 4], [0, 1, 3, 2, 1, 3, 2], [1, 3, 2, 4, 2, 3, 4],
        [2, 1, 0, 2, 3, 4, 3], [1, 2, 3, 1, 2, 3, 4],
      ],
      ruleMastery: {'Ghunnah (via An-Noon Al-Mushaddadah)': 68, 'Ikhfa': 90, 'Separate Madd (المد المنفصل)': 74},
    );
  }
}

/// Real backend-backed implementation. /api/v1/progress has no per-rule
/// breakdown of its own, so [getErrorTypeBreakdown] derives one from
/// /api/v1/practice-plan's recommendations, which already rank rules by
/// how often they're flagged incorrect -- the same real per-session data,
/// just viewed through a different endpoint rather than duplicated.
class ApiProgressService implements ProgressService {
  final ApiClient _client;
  const ApiProgressService([this._client = const ApiClient()]);

  @override
  Future<ProgressSummary> getSummary() async {
    final json = await _client.get('/api/v1/progress');
    final heatmapJson = (json['activity_heatmap'] as List?) ?? const [];
    final masteryJson = (json['rule_mastery'] as Map<String, dynamic>?) ?? const {};
    return ProgressSummary(
      totalSessions: json['total_sessions'] as int,
      currentStreak: json['day_streak'] as int,
      overallAccuracy: (json['avg_score'] as num).toDouble() * 100,
      activityHeatmap: heatmapJson.map((week) => (week as List).cast<int>()).toList(),
      ruleMastery: masteryJson.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }

  @override
  Future<List<ProgressPoint>> getProgressPoints() async {
    final json = await _client.get('/api/v1/progress');
    final dailyScores = (json['daily_scores'] as List).cast<Map<String, dynamic>>();
    return dailyScores
        .map((d) => ProgressPoint(
              date: DateTime.parse(d['date'] as String),
              score: (d['avg_score'] as num).toDouble() * 100,
            ))
        .toList();
  }

  @override
  Future<Map<String, double>> getErrorTypeBreakdown() async {
    final json = await _client.get('/api/v1/practice-plan');
    final recommendations = (json['recommendations'] as List).cast<Map<String, dynamic>>();
    final counts = {
      for (final r in recommendations)
        if (r['error_count'] != null) r['tajweed_rule'] as String: (r['error_count'] as num).toDouble(),
    };
    // StatisticsCard expects a true 0-100 share of errors, not a raw count.
    final total = counts.values.fold(0.0, (sum, c) => sum + c);
    if (total == 0) return {for (final key in counts.keys) key: 0};
    return {for (final e in counts.entries) e.key: e.value / total * 100};
  }
}
