import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/models/ai_character_model.dart';

/// Daily check-in popup shown on first app open each day.
/// Congratulates the student and shows their current streak.
class DailyCheckInDialog extends StatelessWidget {
  final String studentName;
  final int currentStreak;

  const DailyCheckInDialog({
    super.key,
    required this.studentName,
    required this.currentStreak,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getMessage() {
    if (currentStreak <= 0) {
      return "Welcome back! Ready to start a new streak?";
    } else if (currentStreak == 1) {
      return "Welcome to your learning journey! Every great discovery starts with a single step.";
    } else if (currentStreak == 2) {
      return "Day 2! You're building momentum. Keep it going!";
    } else if (currentStreak == 3) {
      return "Three days in a row! Consistency is the key to mastery.";
    } else if (currentStreak <= 6) {
      return "Day $currentStreak! You're on a roll, my friend!";
    } else if (currentStreak == 7) {
      return "Seven days straight! You're building an amazing habit!";
    } else if (currentStreak == 14) {
      return "Two weeks of dedication! Aristotle himself would be proud!";
    } else if (currentStreak == 30) {
      return "30-day champion! Your commitment to learning is truly inspiring!";
    } else if (currentStreak > 30) {
      return "Day $currentStreak! You are a true scholar. Keep exploring!";
    } else {
      return "Day $currentStreak! Keep that momentum going!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Image.asset(
              AiCharacter.aristotle.avatarAsset,
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Text(
              '${_getGreeting()}, $studentName!',
              style: AppTextStyles.headingSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Streak display container
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s16,
              vertical: AppSizes.s12,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: AppSizes.s8),
                Text(
                  currentStreak > 0
                      ? '$currentStreak Day Streak!'
                      : 'Start Your Streak!',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.s16),

          // Encouraging message
          Text(
            _getMessage(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: AppSizes.s12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
            child: Text(
              "Let's Learn!",
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSizes.s24,
        0,
        AppSizes.s24,
        AppSizes.s20,
      ),
    );
  }
}
