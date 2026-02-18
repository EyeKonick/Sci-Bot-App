import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/neumorphic_styles.dart';

/// Streak Tracker Card
/// Shows user's learning streak with calendar dots for the current week.
/// Days are fixed Monday(0) through Sunday(6).
class StreakTrackerCard extends StatelessWidget {
  final int currentStreak;
  final List<bool> last7Days; // index 0 = Monday, index 6 = Sunday

  const StreakTrackerCard({
    super.key,
    required this.currentStreak,
    required this.last7Days,
  });

  @override
  Widget build(BuildContext context) {
    final todayWeekday = DateTime.now().weekday; // 1=Mon, 7=Sun
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      decoration: NeumorphicStyles.raised(context),
      padding: const EdgeInsets.all(AppSizes.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with fire emoji
          Row(
            children: [
              const Text(
                '🔥',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: AppSizes.s8),
              Text(
                currentStreak > 0
                    ? '$currentStreak Day Streak!'
                    : '0 Day Streak!',
                style: AppTextStyles.headingSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.s4),

          // Subtitle
          Padding(
            padding: const EdgeInsets.only(left: AppSizes.s32 + AppSizes.s4),
            child: Text(
              currentStreak > 0
                  ? 'Keep it up!'
                  : 'Start learning to begin your streak',
              style: AppTextStyles.bodySmall.copyWith(
                color: textSecondary,
              ),
            ),
          ),

          const SizedBox(height: AppSizes.s16),

          // Calendar dots (Monday through Sunday)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayLabel = weekdayLabels[index];
              final isCompleted =
                  index < last7Days.length && last7Days[index];
              final isToday = (index + 1) == todayWeekday;

              return Column(
                children: [
                  Text(
                    dayLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s8),
                  _buildDayIndicator(
                    isCompleted: isCompleted,
                    isToday: isToday,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Builds a single day indicator circle.
  /// Completed: 3D raised green button with white check.
  /// Today (not completed): green outline ring.
  /// Inactive: flat grey circle.
  Widget _buildDayIndicator({
    required bool isCompleted,
    required bool isToday,
  }) {
    if (isCompleted) {
      // 3D raised green button with white check
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF81C784), // Light green highlight
              Color(0xFF4CAF50), // Mid green
              Color(0xFF388E3C), // Dark green shadow
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          boxShadow: [
            // Top-left highlight for 3D raised effect
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              offset: const Offset(-1, -1),
              blurRadius: 2,
              spreadRadius: -1,
            ),
            // Bottom-right shadow for depth
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
              offset: const Offset(1.5, 2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
            // Ambient glow
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
              offset: const Offset(0, 1),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    if (isToday) {
      // Today (not yet completed): green outline ring hinting "complete me"
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              offset: const Offset(0, 1),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
      );
    }

    // Inactive: flat grey circle
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.border.withValues(alpha: 0.5),
      ),
    );
  }
}
