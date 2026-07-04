import 'package:flutter_bloc/flutter_bloc.dart';

import '../../dummy/dummy_user.dart';

/// Running hasanah total for the current app session, seeded from the dummy
/// profile and incremented live as recitation sessions complete — the Home
/// dashboard's HasanahCard and the Result screen's "earned" reveal both read
/// from this single source so the number keeps accumulating as you recite.
class HasanahCubit extends Cubit<int> {
  HasanahCubit() : super(dummyUser.hasanahCount);

  void addHasanah(int amount) => emit(state + amount);
}
