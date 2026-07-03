import '../dummy/dummy_user.dart';
import '../models/user_profile.dart';

abstract class UserService {
  Future<UserProfile> getCurrentUser();
}

class DummyUserService implements UserService {
  @override
  Future<UserProfile> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return dummyUser;
  }
}
