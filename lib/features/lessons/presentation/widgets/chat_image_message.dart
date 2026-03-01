import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

/// Widget for displaying images inline with chat messages.
///
/// Images are constrained to max 75% of screen width to match chat bubble sizing.
/// Clickable to trigger enlarged modal view.
///
/// Usage:
/// ```dart
/// ChatImageMessage(
///   imageAssetPath: 'assets/images/topic_1/lesson_1/1.webp',
///   onTap: () => ImageModal.show(context, imagePath),
/// )
/// ```
class ChatImageMessage extends StatelessWidget {
  final String imageAssetPath;
  final VoidCallback onTap;

  const ChatImageMessage({
    super.key,
    required this.imageAssetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s16,
        vertical: AppSizes.s8,
      ),
      child: Align(
        alignment: Alignment.centerLeft, // Align left like assistant messages
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: Image.asset(
                imageAssetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.all(AppSizes.s16),
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.grey100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.grey600,
                        ),
                        const SizedBox(height: AppSizes.s8),
                        Text(
                          'Image not found',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
