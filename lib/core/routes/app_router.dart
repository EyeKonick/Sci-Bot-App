import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/topics/presentation/topics_screen.dart';
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

      // LESSONS SCREEN (Placeholder for Day 3)
      GoRoute(
        path: '/topics/:topicId/lessons',
        name: 'lessons',
        builder: (context, state) {
          final topicId = state.pathParameters['topicId'] ?? '';
          return _PlaceholderLessonsScreen(topicId: topicId);
        },
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

/// Placeholder screen for lesson list (Week 2 Day 3)
class _PlaceholderLessonsScreen extends StatelessWidget {
  final String topicId;

  const _PlaceholderLessonsScreen({required this.topicId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lessons'),
        backgroundColor: const Color(0xFF4DB8C4), // AppColors.primary
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction,
                size: 80,
                color: Color(0xFFE0E0E0), // AppColors.grey300
              ),
              const SizedBox(height: 16),
              const Text(
                'Lesson List Coming Soon!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This screen will be built in Week 2, Day 3',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Topic ID: $topicId',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Topics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4DB8C4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}