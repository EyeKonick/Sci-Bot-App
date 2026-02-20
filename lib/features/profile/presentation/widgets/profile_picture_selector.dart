import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/utils/image_utils.dart';

/// Profile picture selection widget with camera and gallery options
class ProfilePictureSelector extends StatefulWidget {
  final Function(File? imageFile) onImageSelected;
  final File? initialImage;

  const ProfilePictureSelector({
    super.key,
    required this.onImageSelected,
    this.initialImage,
  });

  @override
  State<ProfilePictureSelector> createState() => _ProfilePictureSelectorState();
}

class _ProfilePictureSelectorState extends State<ProfilePictureSelector> {
  File? _selectedImage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
  }

  Future<void> _pickFromCamera() async {
    setState(() => _isProcessing = true);

    try {
      final pickedFile = await ImageUtils.pickImageFromCamera();
      if (pickedFile != null) {
        final processedFile = await ImageUtils.resizeAndCropImage(pickedFile);
        if (processedFile != null) {
          setState(() {
            _selectedImage = processedFile;
          });
          widget.onImageSelected(processedFile);
        } else {
          _showError('Could not process image');
        }
      }
    } catch (e) {
      _showError('Error accessing camera');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessing = true);

    try {
      final pickedFile = await ImageUtils.pickImageFromGallery();
      if (pickedFile != null) {
        final processedFile = await ImageUtils.resizeAndCropImage(pickedFile);
        if (processedFile != null) {
          setState(() {
            _selectedImage = processedFile;
          });
          widget.onImageSelected(processedFile);
        } else {
          _showError('Could not process image');
        }
      }
    } catch (e) {
      _showError('Error accessing gallery');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
    widget.onImageSelected(null);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Circular preview
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceTint,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 2,
            ),
          ),
          child: ClipOval(
            child: _isProcessing
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _selectedImage != null
                    ? Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.person,
                        size: 60,
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
          ),
        ),
        const SizedBox(height: AppSizes.s16),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Camera button
            _ActionButton(
              icon: Icons.camera_alt,
              label: 'Camera',
              onTap: _isProcessing ? null : _pickFromCamera,
            ),
            const SizedBox(width: AppSizes.s12),

            // Gallery button
            _ActionButton(
              icon: Icons.photo_library,
              label: 'Gallery',
              onTap: _isProcessing ? null : _pickFromGallery,
            ),

            // Remove button (only show if image selected)
            if (_selectedImage != null) ...[
              const SizedBox(width: AppSizes.s12),
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Remove',
                onTap: _isProcessing ? null : _removeImage,
                isDestructive: true,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Small action button for image picker
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.s12,
            vertical: AppSizes.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? AppColors.error
                    : onTap == null
                        ? (isDark ? AppColors.darkBorder : AppColors.border)
                        : AppColors.primary,
                size: 28,
              ),
              const SizedBox(height: AppSizes.s4),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDestructive
                      ? AppColors.error
                      : onTap == null
                          ? (isDark ? AppColors.darkBorder : AppColors.border)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
