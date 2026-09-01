import '../dummy/dummy_achievements.dart';
import '../models/achievement.dart';
import 'api_client.dart';

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

class ApiAchievementService implements AchievementService {
  final ApiClient _client;
  const ApiAchievementService([this._client = const ApiClient()]);

  @override
  Future<List<Achievement>> getAchievements() async {
    final json = await _client.get('/api/v1/achievements');
    final achievements = (json['achievements'] as List).cast<Map<String, dynamic>>();
    return achievements.map(Achievement.fromJson).toList();
  }
}
