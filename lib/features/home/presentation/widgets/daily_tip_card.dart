import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Daily Science Tip Card
/// Shows a random fun science fact that rotates daily
/// 
/// Week 3 Batch 1 - UI Improvement
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  // Fun science facts for Grade 9 students
  static const List<String> _scienceTips = [
    'Your heart beats around 100,000 times per day, pumping about 2,000 gallons of blood through your body!',
    'DNA is so long that if you uncoiled all the DNA in your body, it would stretch to the sun and back over 600 times!',
    'The human body contains about 37.2 trillion cells, each working together to keep you alive!',
    'Plants produce the oxygen we breathe through photosynthesis - about 28% of Earth\'s oxygen comes from rainforests!',
    'Blood takes about 20 seconds to circulate through your entire body!',
    'Gregor Mendel discovered the basic principles of heredity by studying pea plants in his garden!',
    'Your lungs contain about 300 million tiny air sacs called alveoli - enough to cover a tennis court if spread out!',
    'Energy flows through ecosystems, and only about 10% passes from one level to the next in a food chain!',
  ];

  String _getTipOfDay() {
    // Use current day of year to get consistent daily tip
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
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE3F2FD), // Light blue
              const Color(0xFFE1F5FE).withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lightbulb icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFC107), Color(0xFFFFEB3B)],
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
              ),
              child: const Icon(
                Icons.lightbulb,
                color: Colors.white,
                size: 24,
              ),
            ),
            
            const SizedBox(width: AppSizes.s12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Did you know? 💡',
                    style: AppTextStyles.subtitle.copyWith(
                      color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s8),
                  Text(
                    _getTipOfDay(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF0D47A1),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}