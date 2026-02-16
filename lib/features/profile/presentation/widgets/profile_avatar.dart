import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Reusable circular profile avatar widget
/// Displays user's profile picture or default icon placeholder
class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  const ProfileAvatar({
    super.key,
    this.imagePath,
    this.size = 44,
    this.borderColor,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? AppColors.white.withOpacity(0.6),
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: _buildAvatarContent(),
      ),
    );
  }

  Widget _buildAvatarContent() {
    // If image path exists and file is valid, show image
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image loading fails
            return _buildDefaultIcon();
          },
        );
      }
    }

    // Default: show person icon
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      color: AppColors.white.withOpacity(0.2),
      child: Icon(
        Icons.person,
        color: AppColors.white,
        size: size * 0.5, // Icon is 50% of avatar size
      ),
    );
  }
}
