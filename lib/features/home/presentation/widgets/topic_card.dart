import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Card displaying a science topic with progress
/// Updated with gradient backgrounds (Batch 1)
class TopicCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? imageAsset; // Optional custom image
  final Color iconColor;
  final List<Color> gradientColors; // NEW: Gradient colors
  final int lessonCount;
  final double progress; // 0.0 to 1.0
  final VoidCallback? onTap;

  const TopicCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.imageAsset,
    required this.iconColor,
    this.gradientColors = const [Color(0xFF4DB8C4), Color(0xFF7BC9A4)], // Default gradient
    required this.lessonCount,
    this.progress = 0.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          padding: const EdgeInsets.all(AppSizes.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon/Image Container
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: imageAsset != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                            child: Image.asset(
                              imageAsset!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(
                            icon,
                            size: 36,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(width: AppSizes.s12),
                  
                  // Title and Lesson Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.headingSmall.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSizes.s4),
                        Text(
                          '$lessonCount ${lessonCount == 1 ? 'lesson' : 'lessons'} • ${(progress * 100).toInt()}% complete',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSizes.s16),
              
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}