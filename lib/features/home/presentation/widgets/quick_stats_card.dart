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