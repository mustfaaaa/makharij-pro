enum LearningLevel { beginner, intermediate, advanced }

class UserProfile {
  final String name;
  final String email;
  final String? avatarUrl;
  final LearningLevel level;
  final int currentStreak;
  final double overallAccuracy;
  final int totalSessions;
  final List<String> targetSurahs;
  final DateTime joinedAt;

  /// Accumulated hasanah (reward) count from recited letters, per the
  /// hadith that each letter of the Qur'an recited earns ten hasanah.
  /// Dummy/estimated for the prototype — a real backend would derive this
  /// from actual letters recited per session.
  final int hasanahCount;

  const UserProfile({
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.level,
    required this.currentStreak,
    required this.overallAccuracy,
    required this.totalSessions,
    required this.targetSurahs,
    required this.joinedAt,
    this.hasanahCount = 0,
  });
}
