import '../../../../core/base_list_cubit.dart';
import '../../../../models/practice_plan_item.dart';
import '../../../../services/service_locator.dart';

class PracticePlanCubit extends BaseListCubit<PracticePlanItem> {
  @override
  Future<List<PracticePlanItem>> fetch() => Services.practicePlan.getPlan();
}
