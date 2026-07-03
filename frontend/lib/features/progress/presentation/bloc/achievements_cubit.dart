import '../../../../core/base_list_cubit.dart';
import '../../../../models/achievement.dart';
import '../../../../services/service_locator.dart';

class AchievementsCubit extends BaseListCubit<Achievement> {
  @override
  Future<List<Achievement>> fetch() => Services.achievement.getAchievements();
}
