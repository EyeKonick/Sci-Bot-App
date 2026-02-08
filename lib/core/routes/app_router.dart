import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/topics/presentation/topics_screen.dart';
import '../../features/lessons/presentation/lessons_screen.dart';
import '../../features/lessons/presentation/module_viewer_screen.dart';
import '../../features/lessons/presentation/bookmarks_screen.dart';
import '../../features/settings/presentation/learning_history_screen.dart';
import '../../features/settings/presentation/progress_stats_screen.dart';
import '../../features/settings/presentation/text_size_screen.dart';
import '../../features/settings/presentation/help_screen.dart';
import '../../features/settings/presentation/privacy_policy_screen.dart';
import '../../features/error/presentation/not_found_screen.dart';
import 'app_routes.dart';
import 'bottom_nav_shell.dart';

/// GoRouter Configuration for SCI-Bot
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    
    // ERROR HANDLING
    errorBuilder: (context, state) => const NotFoundScreen(),
    
    // ROUTE DEFINITIONS
    routes: [
      // SPLASH SCREEN (Initial route)
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),

      // ONBOARDING SCREEN
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // TOPICS SCREEN (Full-screen topic browsing)
      GoRoute(
        path: '/topics',
        name: 'topics',
        builder: (context, state) => const TopicsScreen(),
      ),

      // LESSONS SCREEN (Week 2 Day 3)
      GoRoute(
        path: '/topics/:topicId/lessons',
        name: 'lessons',
        builder: (context, state) {
          final topicId = state.pathParameters['topicId'] ?? '';
          return LessonsScreen(topicId: topicId);
        },
      ),

      // MODULE VIEWER SCREEN (Week 2 Day 4)
      GoRoute(
        path: '/lessons/:lessonId/module/:moduleIndex',
        name: 'module_viewer',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId'] ?? '';
          final moduleIndexStr = state.pathParameters['moduleIndex'] ?? '0';
          final moduleIndex = int.tryParse(moduleIndexStr) ?? 0;
          
          return ModuleViewerScreen(
            lessonId: lessonId,
            moduleIndex: moduleIndex,
          );
        },
      ),

      // BOOKMARKS SCREEN (Week 2 Day 6)
      GoRoute(
        path: '/bookmarks',
        name: 'bookmarks',
        builder: (context, state) => const BookmarksScreen(),
      ),

      // LEARNING HISTORY SCREEN
      GoRoute(
        path: AppRoutes.learningHistory,
        name: AppRoutes.learningHistoryName,
        builder: (context, state) => const LearningHistoryScreen(),
      ),

      // PROGRESS STATS SCREEN
      GoRoute(
        path: AppRoutes.progressStats,
        name: AppRoutes.progressStatsName,
        builder: (context, state) => const ProgressStatsScreen(),
      ),

      // TEXT SIZE SCREEN
      GoRoute(
        path: AppRoutes.textSize,
        name: AppRoutes.textSizeName,
        builder: (context, state) => const TextSizeScreen(),
      ),

      // HELP & SUPPORT SCREEN
      GoRoute(
        path: AppRoutes.help,
        name: AppRoutes.helpName,
        builder: (context, state) => const HelpScreen(),
      ),

      // PRIVACY POLICY SCREEN
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: AppRoutes.privacyPolicyName,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),

      // BOTTOM NAVIGATION SHELL (Persistent navigation for main app)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavShell(navigationShell: navigationShell);
        },
        branches: [
          // BRANCH 1: HOME TAB
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.homeName,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),

          // BRANCH 2: CHAT TAB
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                name: AppRoutes.chatName,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const ChatScreen(),
                ),
              ),
            ],
          ),

          // BRANCH 3: MORE TAB
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                name: AppRoutes.moreName,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // NOT FOUND ROUTE
      GoRoute(
        path: AppRoutes.notFound,
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
}