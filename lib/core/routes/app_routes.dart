/// SCI-Bot Route Names and Paths
/// Centralized route definitions for type-safe navigation
class AppRoutes {
  AppRoutes._();

  // ROOT ROUTES
  static const String splash = '/';
  static const String onboarding = '/onboarding';

  // MAIN APP ROUTES (with bottom navigation)
  static const String home = '/home';
  static const String chat = '/chat';
  static const String more = '/more';

  // TOPIC & LESSON ROUTES
  static const String topics = '/topics';
  static const String topicDetail = '/topics/:topicId';
  static const String lessonDetail = '/topics/:topicId/lessons/:lessonId';
  
  // MODULE ROUTES
  static const String moduleViewer = '/topics/:topicId/lessons/:lessonId/modules/:moduleId';

  // SETTINGS & OTHER ROUTES
  static const String settings = '/settings';
  static const String bookmarks = '/bookmarks';
  static const String searchResults = '/search';
  static const String about = '/about';
  
  // ERROR ROUTES
  static const String notFound = '/not-found';
  static const String error = '/error';

  // ROUTE NAMES (for named navigation)
  static const String splashName = 'splash';
  static const String onboardingName = 'onboarding';
  static const String homeName = 'home';
  static const String chatName = 'chat';
  static const String moreName = 'more';
  static const String topicsName = 'topics';
  static const String topicDetailName = 'topic-detail';
  static const String lessonDetailName = 'lesson-detail';
  static const String moduleViewerName = 'module-viewer';
  static const String settingsName = 'settings';
  static const String bookmarksName = 'bookmarks';
  static const String searchResultsName = 'search';
  static const String aboutName = 'about';
}