import 'achievement_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'practice_plan_service.dart';
import 'progress_service.dart';
import 'session_service.dart';
import 'surah_service.dart';
import 'tajweed_rule_service.dart';
import 'user_service.dart';

/// Simple singleton service locator. Dummy implementations hold in-memory
/// state (bookmarks, generated sessions) that must survive navigation, so
/// every consumer shares one instance per service rather than constructing
/// its own. A DI package (get_it / provider) can replace this without
/// touching call sites once real API-backed services arrive.
abstract class Services {
  static final SurahService surah = DummySurahService();
  static final SessionService session = DummySessionService();
  static final TajweedRuleService tajweedRule = DummyTajweedRuleService();
  static final PracticePlanService practicePlan = DummyPracticePlanService();
  static final AchievementService achievement = DummyAchievementService();
  static final NotificationService notification = DummyNotificationService();
  static final UserService user = FirebaseUserService();
  static final ProgressService progress = DummyProgressService();
  static final AuthService auth = FirebaseAuthService();
}
