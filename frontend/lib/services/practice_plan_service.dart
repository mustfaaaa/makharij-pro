import '../dummy/dummy_practice_plan.dart';
import '../models/practice_plan_item.dart';
import 'api_client.dart';

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

class ApiPracticePlanService implements PracticePlanService {
  final ApiClient _client;
  const ApiPracticePlanService([this._client = const ApiClient()]);

  @override
  Future<List<PracticePlanItem>> getPlan() async {
    final json = await _client.get('/api/v1/practice-plan');
    final recommendations = (json['recommendations'] as List).cast<Map<String, dynamic>>();
    return recommendations.map(PracticePlanItem.fromJson).toList();
  }
}
