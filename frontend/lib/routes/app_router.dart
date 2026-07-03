import 'package:go_router/go_router.dart';

import '../dev/component_gallery_screen.dart';
import '../dev/style_guide_screen.dart';
import '../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/register_screen.dart';
import '../features/authentication/presentation/screens/welcome_screen.dart';
import '../features/home/presentation/screens/home_dashboard_screen.dart';
import '../features/misc/presentation/screens/notifications_screen.dart';
import '../features/misc/presentation/screens/search_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/practice_plan/presentation/screens/practice_plan_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/progress/presentation/screens/achievements_screen.dart';
import '../features/progress/presentation/screens/progress_dashboard_screen.dart';
import '../features/progress/presentation/screens/statistics_screen.dart';
import '../features/quran/presentation/screens/surah_details_screen.dart';
import '../features/quran/presentation/screens/surah_selection_screen.dart';
import '../features/feedback/presentation/screens/detailed_feedback_screen.dart';
import '../features/recitation/presentation/screens/listening_screen.dart';
import '../features/recitation/presentation/screens/processing_screen.dart';
import '../features/recitation/presentation/screens/recitation_screen.dart';
import '../features/recitation/presentation/screens/result_screen.dart';
import '../features/settings/presentation/screens/about_screen.dart';
import '../features/settings/presentation/screens/contact_screen.dart';
import '../features/settings/presentation/screens/help_faq_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/tajweed_rules/presentation/screens/bookmarks_screen.dart';
import '../features/tajweed_rules/presentation/screens/rule_details_screen.dart';
import '../features/tajweed_rules/presentation/screens/tajweed_rules_library_screen.dart';
import 'app_shell.dart';
import 'route_names.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  routes: [
    GoRoute(path: RoutePaths.splash, name: RouteNames.splash, builder: (c, s) => const SplashScreen()),
    GoRoute(path: RoutePaths.onboarding, name: RouteNames.onboarding, builder: (c, s) => const OnboardingScreen()),
    GoRoute(path: RoutePaths.welcome, name: RouteNames.welcome, builder: (c, s) => const WelcomeScreen()),
    GoRoute(path: RoutePaths.login, name: RouteNames.login, builder: (c, s) => const LoginScreen()),
    GoRoute(path: RoutePaths.register, name: RouteNames.register, builder: (c, s) => const RegisterScreen()),
    GoRoute(path: RoutePaths.forgotPassword, name: RouteNames.forgotPassword, builder: (c, s) => const ForgotPasswordScreen()),

    GoRoute(path: RoutePaths.devStyleGuide, name: RouteNames.devStyleGuide, builder: (c, s) => const StyleGuideScreen()),
    GoRoute(path: RoutePaths.devComponents, name: RouteNames.devComponents, builder: (c, s) => const ComponentGalleryScreen()),

    GoRoute(
      path: RoutePaths.surahDetails,
      name: RouteNames.surahDetails,
      builder: (c, s) => SurahDetailsScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!)),
    ),
    GoRoute(
      path: RoutePaths.recitation,
      name: RouteNames.recitation,
      builder: (c, s) => RecitationScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!)),
    ),
    GoRoute(
      path: RoutePaths.listening,
      name: RouteNames.listening,
      builder: (c, s) => ListeningScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!)),
    ),
    GoRoute(
      path: RoutePaths.processing,
      name: RouteNames.processing,
      builder: (c, s) => ProcessingScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!)),
    ),
    GoRoute(
      path: RoutePaths.result,
      name: RouteNames.result,
      builder: (c, s) => ResultScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!)),
    ),
    GoRoute(
      path: RoutePaths.detailedFeedback,
      name: RouteNames.detailedFeedback,
      builder: (c, s) => DetailedFeedbackScreen(sessionId: s.pathParameters['sessionId']!),
    ),

    GoRoute(path: RoutePaths.practicePlan, name: RouteNames.practicePlan, builder: (c, s) => const PracticePlanScreen()),
    GoRoute(path: RoutePaths.statistics, name: RouteNames.statistics, builder: (c, s) => const StatisticsScreen()),
    GoRoute(path: RoutePaths.achievements, name: RouteNames.achievements, builder: (c, s) => const AchievementsScreen()),

    GoRoute(path: RoutePaths.tajweedRules, name: RouteNames.tajweedRules, builder: (c, s) => const TajweedRulesLibraryScreen()),
    GoRoute(
      path: RoutePaths.ruleDetails,
      name: RouteNames.ruleDetails,
      builder: (c, s) => RuleDetailsScreen(ruleId: s.pathParameters['ruleId']!),
    ),
    GoRoute(path: RoutePaths.bookmarks, name: RouteNames.bookmarks, builder: (c, s) => const BookmarksScreen()),
    GoRoute(path: RoutePaths.search, name: RouteNames.search, builder: (c, s) => const SearchScreen()),
    GoRoute(path: RoutePaths.notifications, name: RouteNames.notifications, builder: (c, s) => const NotificationsScreen()),

    GoRoute(path: RoutePaths.editProfile, name: RouteNames.editProfile, builder: (c, s) => const EditProfileScreen()),
    GoRoute(path: RoutePaths.settings, name: RouteNames.settings, builder: (c, s) => const SettingsScreen()),
    GoRoute(path: RoutePaths.about, name: RouteNames.about, builder: (c, s) => const AboutScreen()),
    GoRoute(path: RoutePaths.helpFaq, name: RouteNames.helpFaq, builder: (c, s) => const HelpFaqScreen()),
    GoRoute(path: RoutePaths.contact, name: RouteNames.contact, builder: (c, s) => const ContactScreen()),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: RoutePaths.home, name: RouteNames.home, builder: (c, s) => const HomeDashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: RoutePaths.quran, name: RouteNames.quran, builder: (c, s) => const SurahSelectionScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: RoutePaths.progress, name: RouteNames.progress, builder: (c, s) => const ProgressDashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: RoutePaths.profile, name: RouteNames.profile, builder: (c, s) => const ProfileScreen()),
        ]),
      ],
    ),
  ],
);
