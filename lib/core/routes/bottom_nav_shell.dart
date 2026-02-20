import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../../features/chat/presentation/widgets/floating_chat_button.dart';
import '../../features/chat/data/providers/character_provider.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../shared/models/navigation_context_model.dart';
import '../../shared/models/scenario_model.dart';

/// Bottom Navigation Shell for persistent navigation
/// Used as parent widget for Home, Chat, and More tabs
/// Updated with improved styling (Batch 1) + Character System (Week 3 Day 3)
/// Fixed: context reset regression + topic-aware Home active state
class BottomNavShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch navigation context to determine if user is inside a topic/lesson.
    // When inside a topic, Home nav item should NOT appear active.
    final navContext = ref.watch(navigationContextProvider);
    final isInsideTopic = navContext.currentTopicId != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void handleTap(int index) {
      // Only reset character context when tapping Home while already ON the Home branch.
      // That is the one case where goBranch uses initialLocation=true → navigates to root.
      // HomeScreen's initState does NOT re-run (StatefulShellRoute keeps state alive),
      // so we reset context here explicitly.
      //
      // All other tab switches: do NOT reset context.
      // GoRouter restores the branch's last position, and the restored screen
      // already has the correct context. Screens manage their own context via initState.
      if (index == 0 && index == navigationShell.currentIndex) {
        ref.read(navigationContextProvider.notifier).state = NavigationContext.home();
        final scenario = ChatScenario.aristotleGeneral();
        ref.read(characterContextManagerProvider).setScenario(scenario);
        ChatRepository().setScenario(scenario);
      }
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return Stack(
      children: [
        Scaffold(
          body: navigationShell,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      // Home is active only when on branch 0 AND not inside a topic
                      isActive: navigationShell.currentIndex == 0 && !isInsideTopic,
                      isDark: isDark,
                      onTap: () => handleTap(0),
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_outline,
                      activeIcon: Icons.chat_bubble,
                      label: 'Chat',
                      isActive: navigationShell.currentIndex == 1,
                      isDark: isDark,
                      onTap: () => handleTap(1),
                    ),
                    _NavItem(
                      icon: Icons.more_horiz,
                      activeIcon: Icons.more_horiz,
                      label: 'More',
                      isActive: navigationShell.currentIndex == 2,
                      isDark: isDark,
                      onTap: () => handleTap(2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating Chat Button - Only on Home branch (Topics/Lessons share this branch)
        if (navigationShell.currentIndex == 0) // Only show on Home tab, not Chat or More
          const FloatingChatButton(),
      ],
    );
  }
}

/// Individual bottom navigation item with topic-aware active state support.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final Color inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final color = isActive ? activeColor : inactiveColor;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Icon(
                isActive ? activeIcon : icon,
                size: 26,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
