import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Quick stats display for user progress
/// Matches Figma design exactly - just progress circle with text
class QuickStatsCard extends StatelessWidget {
  final int lessonsCompleted;
  final int totalLessons;
  final int currentStreak;

  const QuickStatsCard({
    super.key,
    required this.lessonsCompleted,
    required this.totalLessons,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    final completionPercentage = totalLessons > 0 
        ? (lessonsCompleted / totalLessons) 
        : 0.0;

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
            // Header
            Text(
              'Your Progress',
              style: AppTextStyles.headingSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.s24),
            
            // Progress Circle with Text on Side
            Row(
              children: [
                // Circular Progress Indicator
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background Circle
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 10,
                          backgroundColor: AppColors.grey300,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.grey300,
                          ),
                        ),
                      ),
                      // Progress Circle
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: completionPercentage,
                          strokeWidth: 10,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      // Percentage Text
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(completionPercentage * 100).toInt()}%',
                            style: AppTextStyles.headingLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 32,
                            ),
                          ),
                          Text(
                            'Complete',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: AppSizes.s24),
                
                // Text on Side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lessons Completed',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s4),
                      Text(
                        '$lessonsCompleted of $totalLessons',
                        style: AppTextStyles.headingMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ), 
          ],
        ),
      ),
    );
  }
}