import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

/// Fullscreen modal overlay for viewing images in enlarged mode.
///
/// Displays the image centered and maximized (respecting aspect ratio) with
/// a dark semi-transparent backdrop. Dismisses on tap anywhere or via close button.
///
/// Usage:
/// ```dart
/// ImageModal.show(context, 'assets/images/topic_1/lesson_1/1.png');
/// ```
class ImageModal extends StatelessWidget {
  final String imageAssetPath;

  const ImageModal({
    super.key,
    required this.imageAssetPath,
  });

  /// Show the image modal overlay.
  static void show(BuildContext context, String imageAssetPath) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => ImageModal(imageAssetPath: imageAssetPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Centered image
            Center(
              child: GestureDetector(
                onTap: () {}, // Prevent dismiss when tapping on image
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.asset(
                    imageAssetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.all(AppSizes.s32),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D3B35) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                            const SizedBox(height: AppSizes.s16),
                            Text(
                              'Image not found',
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
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

            // Close button in top-right corner
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSizes.s16,
              right: AppSizes.s16,
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSizes.s8),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
