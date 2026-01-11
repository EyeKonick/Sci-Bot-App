import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'app_routes.dart';

/// Navigation Helper Service
/// Provides type-safe navigation methods
class NavigationService {
  NavigationService._();

  // GET ROUTER INSTANCE
  static GoRouter get router => GoRouter.of(_navigatorKey.currentContext!);

  // GLOBAL NAVIGATOR KEY
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  // NAVIGATION METHODS

  /// Navigate to splash screen
  static void goToSplash(BuildContext context) {
    context.go(AppRoutes.splash);
  }

  /// Navigate to onboarding
  static void goToOnboarding(BuildContext context) {
    context.go(AppRoutes.onboarding);
  }

  /// Navigate to home (clears navigation stack)
  static void goToHome(BuildContext context) {
    context.go(AppRoutes.home);
  }

  /// Navigate to chat tab
  static void goToChat(BuildContext context) {
    context.go(AppRoutes.chat);
  }

  /// Navigate to more tab
  static void goToMore(BuildContext context) {
    context.go(AppRoutes.more);
  }

  /// Navigate to topic detail
  static void goToTopicDetail(BuildContext context, String topicId) {
    context.push('/topics/$topicId');
  }

  /// Navigate to lesson detail
  static void goToLessonDetail(
    BuildContext context,
    String topicId,
    String lessonId,
  ) {
    context.push('/topics/$topicId/lessons/$lessonId');
  }

  /// Navigate to module viewer
  static void goToModuleViewer(
    BuildContext context,
    String topicId,
    String lessonId,
    String moduleId,
  ) {
    context.push('/topics/$topicId/lessons/$lessonId/modules/$moduleId');
  }

  /// Navigate to bookmarks
  static void goToBookmarks(BuildContext context) {
    context.push(AppRoutes.bookmarks);
  }

  /// Navigate to settings
  static void goToSettings(BuildContext context) {
    context.push(AppRoutes.settings);
  }

  /// Navigate to search results
  static void goToSearchResults(BuildContext context, String query) {
    context.push('${AppRoutes.searchResults}?q=$query');
  }

  /// Go back
  static void goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    }
  }

  /// Replace current route
  static void replace(BuildContext context, String path) {
    context.pushReplacement(path);
  }

  /// Check if can pop
  static bool canPop(BuildContext context) {
    return context.canPop();
  }
}