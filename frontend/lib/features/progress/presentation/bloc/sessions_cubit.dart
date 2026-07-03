import '../../../../core/base_list_cubit.dart';
import '../../../../models/session_result.dart';
import '../../../../services/service_locator.dart';

class SessionsCubit extends BaseListCubit<SessionResult> {
  @override
  Future<List<SessionResult>> fetch() => Services.session.getSessions();
}
