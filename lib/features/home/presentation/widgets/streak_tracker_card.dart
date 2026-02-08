import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Streak Tracker Card
/// Shows user's learning streak with calendar dots
class StreakTrackerCard extends StatelessWidget {
  final int currentStreak;
  final List<bool> last7Days; // true = completed, false = not completed

  const StreakTrackerCard({
    super.key,
    required this.currentStreak,
    required this.last7Days,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      color: AppColors.white,
      child: Padding(
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
                  color: AppColors.grey600,
                ),
              ),
            ),

            const SizedBox(height: AppSizes.s16),

            // Calendar dots (last 7 days)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final isCompleted = index < last7Days.length && last7Days[index];

                return Column(
                  children: [
                    // Day label
                    Text(
                      dayLabels[index],
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.grey600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s8),
                    // Dot indicator
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppColors.success
                            : AppColors.grey300.withOpacity(0.6),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
