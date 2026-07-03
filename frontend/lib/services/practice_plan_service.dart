import '../dummy/dummy_practice_plan.dart';
import '../models/practice_plan_item.dart';

abstract class PracticePlanService {
  Future<List<PracticePlanItem>> getPlan();
}

class DummyPracticePlanService implements PracticePlanService {
  @override
  Future<List<PracticePlanItem>> getPlan() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(dummyPracticePlan);
  }
}
