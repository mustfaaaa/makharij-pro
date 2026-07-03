import '../../../../core/base_list_cubit.dart';
import '../../../../models/tajweed_rule.dart';
import '../../../../services/service_locator.dart';

class TajweedRulesCubit extends BaseListCubit<TajweedRule> {
  @override
  Future<List<TajweedRule>> fetch() => Services.tajweedRule.getRules();
}
