import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Daily Science Tip Card
/// Shows a random fun science fact that rotates daily
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  // Fun science facts for Grade 9 students
  static const List<String> _scienceTips = [
    'Your heart beats about 100,000 times per day, pumping around 2,000 gallons of blood through your body!',
    'DNA is so long that if you uncoiled all the DNA in your body, it would stretch to the sun and back over 600 times!',
    'The human body contains about 37.2 trillion cells, each working together to keep you alive!',
    'Plants produce the oxygen we breathe through photosynthesis - about 28% of Earth\'s oxygen comes from rainforests!',
    'Blood takes about 20 seconds to circulate through your entire body!',
    'Gregor Mendel discovered the basic principles of heredity by studying pea plants in his garden!',
    'Your lungs contain about 300 million tiny air sacs called alveoli - enough to cover a tennis court if spread out!',
    'Energy flows through ecosystems, and only about 10% passes from one level to the next in a food chain!',
  ];

  String _getTipOfDay() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final tipIndex = dayOfYear % _scienceTips.length;
    return _scienceTips[tipIndex];
  }

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
            // Header with lightbulb emoji
            Row(
              children: [
                const Text(
                  '💡',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  'Did you know?',
                  style: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.s12),

            // Tip text
            Padding(
              padding: const EdgeInsets.only(left: AppSizes.s32 + AppSizes.s4),
              child: Text(
                _getTipOfDay(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.grey600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
