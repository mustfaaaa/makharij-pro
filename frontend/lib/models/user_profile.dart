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
  });
}
