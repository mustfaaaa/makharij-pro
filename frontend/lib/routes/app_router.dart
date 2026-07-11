import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../dev/component_gallery_screen.dart';
import '../dev/style_guide_screen.dart';
import '../features/ask_ai/presentation/screens/ask_ai_screen.dart';
import '../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/register_screen.dart';
import '../features/authentication/presentation/screens/welcome_screen.dart';
import '../features/feedback/presentation/screens/detailed_feedback_screen.dart';
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
import '../services/service_locator.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';
import 'page_transitions.dart';
import 'route_names.dart';
import 'theme_reactive.dart';

// Routes reachable before/without being signed in. Splash is deliberately
// excluded — it always plays out fully and decides the next route itself
// (see splash_screen.dart), rather than being redirected away mid-animation.
const _preAuthRoutes = {
  RoutePaths.onboarding,
  RoutePaths.welcome,
  RoutePaths.login,
  RoutePaths.register,
};

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  refreshListenable: GoRouterRefreshStream(Services.auth.authStateChanges),
  redirect: (context, state) {
    if (state.matchedLocation == RoutePaths.splash) return null;

    final loggedIn = Services.auth.currentUser != null;
    final onPreAuthRoute = _preAuthRoutes.contains(state.matchedLocation);

    // Forgot-password is reachable both signed-out ("forgot my password")
    // and signed-in (Settings > Change Password), so it's never force-redirected.
    if (!loggedIn && !onPreAuthRoute && state.matchedLocation != RoutePaths.forgotPassword) {
      return RoutePaths.welcome;
    }
    if (loggedIn && onPreAuthRoute) {
      return RoutePaths.home;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      name: RouteNames.splash,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => SplashScreen())),
    ),
    GoRoute(
      path: RoutePaths.onboarding,
      name: RouteNames.onboarding,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => OnboardingScreen())),
    ),
    GoRoute(
      path: RoutePaths.welcome,
      name: RouteNames.welcome,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => WelcomeScreen())),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => LoginScreen())),
    ),
    GoRoute(
      path: RoutePaths.register,
      name: RouteNames.register,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => RegisterScreen())),
    ),
    GoRoute(
      path: RoutePaths.forgotPassword,
      name: RouteNames.forgotPassword,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => ForgotPasswordScreen())),
    ),

    // Internal design-reference screens are only routable in debug builds.
    if (kDebugMode) ...[
      GoRoute(path: RoutePaths.devStyleGuide, name: RouteNames.devStyleGuide, builder: (c, s) => const StyleGuideScreen()),
      GoRoute(path: RoutePaths.devComponents, name: RouteNames.devComponents, builder: (c, s) => const ComponentGalleryScreen()),
    ],

    GoRoute(
      path: RoutePaths.surahDetails,
      name: RouteNames.surahDetails,
      pageBuilder: (c, s) => fadeSlidePage(
        key: s.pageKey,
        child: ThemeReactive(builder: (_) => SurahDetailsScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!))),
      ),
    ),
    GoRoute(
      path: RoutePaths.recitation,
      name: RouteNames.recitation,
      pageBuilder: (c, s) => fadeSlidePage(
        key: s.pageKey,
        child: ThemeReactive(builder: (_) => RecitationScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!))),
      ),
    ),
    GoRoute(
      path: RoutePaths.listening,
      name: RouteNames.listening,
      pageBuilder: (c, s) => fadeSlidePage(
        key: s.pageKey,
        child: ThemeReactive(builder: (_) => ListeningScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!))),
      ),
    ),
    GoRoute(
      path: RoutePaths.processing,
      name: RouteNames.processing,
      pageBuilder: (c, s) => fadeSlidePage(
        key: s.pageKey,
        child: ThemeReactive(builder: (_) => ProcessingScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!))),
      ),
    ),
    GoRoute(
      path: RoutePaths.result,
      name: RouteNames.result,
      pageBuilder: (c, s) => fadeSlidePage(
        key: s.pageKey,
        child: ThemeReactive(builder: (_) => ResultScreen(surahNumber: int.parse(s.pathParameters['surahNumber']!))),
      ),
    ),
    GoRoute(
      path: RoutePaths.detailedFeedback,
      name: RouteNames.detailedFeedback,
      pageBuilder: (c, s) => fadeSlidePage(
        key: s.pageKey,
        child: ThemeReactive(builder: (_) => DetailedFeedbackScreen(sessionId: s.pathParameters['sessionId']!)),
      ),
    ),

    GoRoute(
      path: RoutePaths.practicePlan,
      name: RouteNames.practicePlan,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => PracticePlanScreen())),
    ),
    GoRoute(
      path: RoutePaths.statistics,
      name: RouteNames.statistics,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => StatisticsScreen())),
    ),
    GoRoute(
      path: RoutePaths.achievements,
      name: RouteNames.achievements,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => AchievementsScreen())),
    ),

    GoRoute(
      path: RoutePaths.tajweedRules,
      name: RouteNames.tajweedRules,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => TajweedRulesLibraryScreen())),
    ),
    GoRoute(
      path: RoutePaths.ruleDetails,
      name: RouteNames.ruleDetails,
      pageBuilder: (c, s) => fadeSlidePage(
        key: s.pageKey,
        child: ThemeReactive(builder: (_) => RuleDetailsScreen(ruleId: s.pathParameters['ruleId']!)),
      ),
    ),
    GoRoute(
      path: RoutePaths.bookmarks,
      name: RouteNames.bookmarks,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => BookmarksScreen())),
    ),
    GoRoute(
      path: RoutePaths.search,
      name: RouteNames.search,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => SearchScreen())),
    ),
    GoRoute(
      path: RoutePaths.notifications,
      name: RouteNames.notifications,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => NotificationsScreen())),
    ),

    GoRoute(
      path: RoutePaths.editProfile,
      name: RouteNames.editProfile,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => EditProfileScreen())),
    ),
    GoRoute(
      path: RoutePaths.settings,
      name: RouteNames.settings,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => SettingsScreen())),
    ),
    GoRoute(
      path: RoutePaths.about,
      name: RouteNames.about,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => AboutScreen())),
    ),
    GoRoute(
      path: RoutePaths.helpFaq,
      name: RouteNames.helpFaq,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => HelpFaqScreen())),
    ),
    GoRoute(
      path: RoutePaths.contact,
      name: RouteNames.contact,
      pageBuilder: (c, s) => fadeSlidePage(key: s.pageKey, child: ThemeReactive(builder: (_) => ContactScreen())),
    ),

    StatefulShellRoute(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      navigatorContainerBuilder: (context, navigationShell, children) => AnimatedBranchContainer(
        currentIndex: navigationShell.currentIndex,
        children: children,
      ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.home,
            name: RouteNames.home,
            builder: (c, s) => ThemeReactive(builder: (_) => HomeDashboardScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.quran,
            name: RouteNames.quran,
            builder: (c, s) => ThemeReactive(builder: (_) => SurahSelectionScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.askAi,
            name: RouteNames.askAi,
            builder: (c, s) => ThemeReactive(builder: (_) => const AskAiScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.progress,
            name: RouteNames.progress,
            builder: (c, s) => ThemeReactive(builder: (_) => ProgressDashboardScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.profile,
            name: RouteNames.profile,
            builder: (c, s) => ThemeReactive(builder: (_) => ProfileScreen()),
          ),
        ]),
      ],
    ),
  ],
);
