import '../models/achievement.dart';

final List<Achievement> dummyAchievements = [
  const Achievement(id: 'a1', title: 'First Recitation', description: 'Complete your first recitation session', iconKey: 'mic', isUnlocked: true),
  const Achievement(id: 'a2', title: '7-Day Streak', description: 'Practice for 7 consecutive days', iconKey: 'local_fire_department', isUnlocked: true),
  const Achievement(id: 'a3', title: 'Perfect Score', description: 'Score 100% accuracy in a session', iconKey: 'star', isUnlocked: false, progress: 0.92),
  const Achievement(id: 'a4', title: 'Surah Explorer', description: 'Recite 10 different surahs', iconKey: 'menu_book', isUnlocked: true),
  const Achievement(id: 'a5', title: 'Tajweed Scholar', description: 'Read all Tajweed rule explanations', iconKey: 'school', isUnlocked: false, progress: 0.5),
  const Achievement(id: 'a6', title: '30-Day Streak', description: 'Practice for 30 consecutive days', iconKey: 'whatshot', isUnlocked: false, progress: 0.4),
];
