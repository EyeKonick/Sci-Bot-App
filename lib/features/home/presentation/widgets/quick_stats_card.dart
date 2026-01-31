import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Quick stats display for user progress
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
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Progress',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: AppSizes.s16),
            
            // Circular Progress Indicator
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Circle
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 12,
                        backgroundColor: AppColors.grey300,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.grey300,
                        ),
                      ),
                    ),
                    // Progress Circle
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: completionPercentage,
                        strokeWidth: 12,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completionPercentage == 1.0 
                              ? AppColors.success 
                              : AppColors.primary,
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
                            color: completionPercentage == 1.0 
                                ? AppColors.success 
                                : AppColors.primary,
                          ),
                        ),
                        Text(
                          'Complete',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppSizes.s20),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle,
                    iconColor: AppColors.success,
                    label: 'Completed',
                    value: '$lessonsCompleted/$totalLessons',
                  ),
                ),
                const SizedBox(width: AppSizes.s16),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.local_fire_department,
                    iconColor: AppColors.warning,
                    label: 'Streak',
                    value: '$currentStreak days',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: AppSizes.iconL,
          ),
          const SizedBox(height: AppSizes.s8),
          Text(
            value,
            style: AppTextStyles.headingSmall.copyWith(
              color: iconColor,
            ),
          ),
          const SizedBox(height: AppSizes.s4),
          Text(
            label,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}