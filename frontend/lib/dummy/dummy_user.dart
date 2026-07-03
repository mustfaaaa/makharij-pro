import '../models/user_profile.dart';

final UserProfile dummyUser = UserProfile(
  name: 'Hammad Fareed',
  email: 'hammad.fareed@example.com',
  level: LearningLevel.intermediate,
  currentStreak: 12,
  overallAccuracy: 86.4,
  totalSessions: 47,
  targetSurahs: const ['Al-Baqarah', 'Al-Kahf', 'Ya-Sin'],
  joinedAt: DateTime(2026, 2, 14),
);
