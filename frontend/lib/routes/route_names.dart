abstract class RouteNames {
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String welcome = 'welcome';
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgotPassword';

  static const String home = 'home';
  static const String quran = 'quran';
  static const String progress = 'progress';
  static const String profile = 'profile';

  static const String surahDetails = 'surahDetails';
  static const String recitation = 'recitation';
  static const String listening = 'listening';
  static const String processing = 'processing';
  static const String result = 'result';
  static const String detailedFeedback = 'detailedFeedback';

  static const String practicePlan = 'practicePlan';
  static const String statistics = 'statistics';
  static const String achievements = 'achievements';

  static const String tajweedRules = 'tajweedRules';
  static const String ruleDetails = 'ruleDetails';
  static const String bookmarks = 'bookmarks';
  static const String search = 'search';
  static const String notifications = 'notifications';

  static const String editProfile = 'editProfile';
  static const String settings = 'settings';
  static const String about = 'about';
  static const String helpFaq = 'helpFaq';
  static const String contact = 'contact';

  static const String devStyleGuide = 'devStyleGuide';
  static const String devComponents = 'devComponents';
}

abstract class RoutePaths {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String home = '/home';
  static const String quran = '/quran';
  static const String progress = '/progress';
  static const String profile = '/profile';

  static const String surahDetails = '/surah/:surahNumber';
  static const String recitation = '/recitation/:surahNumber';
  static const String listening = '/recitation/:surahNumber/listening';
  static const String processing = '/recitation/:surahNumber/processing';
  static const String result = '/recitation/:surahNumber/result';
  static const String detailedFeedback = '/session/:sessionId/feedback';

  static const String practicePlan = '/practice-plan';
  static const String statistics = '/statistics';
  static const String achievements = '/achievements';

  static const String tajweedRules = '/tajweed-rules';
  static const String ruleDetails = '/tajweed-rules/:ruleId';
  static const String bookmarks = '/bookmarks';
  static const String search = '/search';
  static const String notifications = '/notifications';

  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String helpFaq = '/settings/help';
  static const String contact = '/settings/contact';

  static const String devStyleGuide = '/dev/style-guide';
  static const String devComponents = '/dev/components';

  static String surahDetailsPath(int number) => '/surah/$number';
  static String recitationPath(int number) => '/recitation/$number';
  static String listeningPath(int number) => '/recitation/$number/listening';
  static String processingPath(int number) => '/recitation/$number/processing';
  static String resultPath(int number) => '/recitation/$number/result';
  static String detailedFeedbackPath(String sessionId) => '/session/$sessionId/feedback';
  static String ruleDetailsPath(String ruleId) => '/tajweed-rules/$ruleId';
}
