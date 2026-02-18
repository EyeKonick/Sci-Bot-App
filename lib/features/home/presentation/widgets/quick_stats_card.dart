import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/neumorphic_styles.dart';

/// Quick stats display for user progress
/// Phase 5: Neumorphic raised container
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completionPercentage =
        totalLessons > 0 ? (lessonsCompleted / totalLessons) : 0.0;
    final trackColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.border.withValues(alpha: 0.6);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Container(
      decoration: NeumorphicStyles.raised(context),
      padding: const EdgeInsets.all(AppSizes.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: AppTextStyles.headingSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.s24),

          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Track circle
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: trackColor,
                        valueColor: AlwaysStoppedAnimation<Color>(trackColor),
                      ),
                    ),
                    // Progress circle
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: completionPercentage,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(completionPercentage * 100).toInt()}%',
                          style: AppTextStyles.headingLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          'Complete',
                          style: AppTextStyles.caption.copyWith(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSizes.s24),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lessons Completed',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s4),
                    Text(
                      '$lessonsCompleted of $totalLessons',
                      style: AppTextStyles.headingMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
