import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import 'youtube_video_card.dart';

/// Full-screen bottom sheet YouTube player.
///
/// Loads the YouTube mobile page in a WebView — bypasses embedding restrictions
/// (error 101/150) that affect the IFrame Player API.
/// Show via [YoutubeVideoModal.show].
class YoutubeVideoModal extends StatefulWidget {
  final String videoUrl;

  const YoutubeVideoModal({super.key, required this.videoUrl});

  /// Opens the modal as a bottom sheet.
  static void show(BuildContext context, String videoUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => YoutubeVideoModal(videoUrl: videoUrl),
    );
  }

  @override
  State<YoutubeVideoModal> createState() => _YoutubeVideoModalState();
}

class _YoutubeVideoModalState extends State<YoutubeVideoModal> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final videoId = YouTubeVideoCard.extractVideoId(widget.videoUrl);
    // Load mobile YouTube URL directly — bypasses embedding restrictions
    final url = videoId != null
        ? 'https://m.youtube.com/watch?v=$videoId'
        : widget.videoUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppSizes.s12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s16,
              vertical: AppSizes.s12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.smart_display_outlined,
                  size: AppSizes.iconM,
                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  'Watch Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // WebView player
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppSizes.radiusXL),
              ),
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color:
                            isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSizes.s16),
        ],
      ),
    );
  }
}
