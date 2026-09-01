import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/service_locator.dart';

/// Real, persisted running hasanah total — loaded from Firestore on startup
/// and incremented live as recitation sessions complete, with each increment
/// also persisted so the total survives an app restart instead of resetting
/// to a placeholder every launch. The Home dashboard's HasanahCard and the
/// Result screen's "earned" reveal both read from this single source.
class HasanahCubit extends Cubit<int> {
  HasanahCubit() : super(0) {
    Services.user.getHasanahTotal().then((total) {
      if (!isClosed) emit(total);
    });
  }

  void addHasanah(int amount) {
    emit(state + amount);
    Services.user.addHasanahTotal(amount);
  }
}
