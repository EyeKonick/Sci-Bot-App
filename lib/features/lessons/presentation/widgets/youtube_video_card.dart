import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import 'youtube_video_modal.dart';

/// Inline YouTube video card shown inside chat messages.
///
/// Displays the video thumbnail (fetched from img.youtube.com) with a play
/// button overlay. Tapping opens [YoutubeVideoModal] as a bottom sheet.
///
/// Usage:
/// ```dart
/// YouTubeVideoCard(
///   videoUrl: 'https://www.youtube.com/watch?v=HVHQzZWupko',
///   themeColor: character.themeColor,
/// )
/// ```
class YouTubeVideoCard extends StatelessWidget {
  final String videoUrl;
  final Color themeColor;

  const YouTubeVideoCard({
    super.key,
    required this.videoUrl,
    required this.themeColor,
  });

  /// Extracts the 11-character YouTube video ID from a URL.
  static String? extractVideoId(String url) {
    final regex = RegExp(r'(?:v=|youtu\.be/)([A-Za-z0-9_-]{11})');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final videoId = extractVideoId(videoUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s16,
        vertical: AppSizes.s8,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => YoutubeVideoModal.show(context, videoUrl),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thumbnail with play button overlay
                  SizedBox(
                    height: 180,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail image
                        if (videoId != null)
                          CachedNetworkImage(
                            imageUrl:
                                'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.grey100,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.grey100,
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 48,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.grey600,
                              ),
                            ),
                          )
                        else
                          Container(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.grey100,
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.grey600,
                            ),
                          ),

                        // Semi-transparent overlay for better play button visibility
                        Container(
                          color: Colors.black.withValues(alpha: 0.15),
                        ),

                        // Play button
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: themeColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // "Watch Video" label bar
                  Container(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s12,
                      vertical: AppSizes.s8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.smart_display_outlined,
                          size: AppSizes.iconS,
                          color: themeColor,
                        ),
                        const SizedBox(width: AppSizes.s8),
                        Text(
                          'Watch Video',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
