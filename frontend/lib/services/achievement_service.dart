import '../dummy/dummy_achievements.dart';
import '../models/achievement.dart';

abstract class AchievementService {
  Future<List<Achievement>> getAchievements();
}

class DummyAchievementService implements AchievementService {
  @override
  Future<List<Achievement>> getAchievements() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(dummyAchievements);
  }
}
