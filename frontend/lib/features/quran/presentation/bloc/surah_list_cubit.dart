import '../../../../core/base_list_cubit.dart';
import '../../../../models/surah.dart';
import '../../../../services/service_locator.dart';

class SurahListCubit extends BaseListCubit<Surah> {
  @override
  Future<List<Surah>> fetch() => Services.surah.getSurahs();
}
