import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/user_profile_model.dart';
import 'name_input_field.dart';
import 'profile_picture_selector.dart';

/// Profile setup page - 5th onboarding page
/// Collects user name (required) and profile picture (optional)
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => ProfileSetupPageState();
}

class ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;
  bool _isNameValid = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Check if profile setup is valid (name is required)
  bool get isValid => _isNameValid && _nameController.text.trim().isNotEmpty;

  /// Get profile data for saving
  UserProfileModel getProfile() {
    final now = DateTime.now();
    return UserProfileModel(
      name: _nameController.text.trim(),
      profileImagePath: null, // Will be set after image is saved
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get selected image file
  File? get selectedImage => _selectedImage;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSizes.s24),

          // Title
          Text(
            'Create Your Profile',
            style: AppTextStyles.headingLarge.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.s8),

          // Subtitle
          Text(
            'Let\'s personalize your learning experience!',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.s40),

          // Profile picture selector
          ProfilePictureSelector(
            onImageSelected: (file) {
              setState(() {
                _selectedImage = file;
              });
            },
          ),
          const SizedBox(height: AppSizes.s32),

          // Name input section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What should we call you?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.s8),

              NameInputField(
                controller: _nameController,
                onValidationChanged: (isValid) {
                  setState(() {
                    _isNameValid = isValid;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s16),

          // Hint text
          Text(
            'Your name will be used throughout the app',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          // Extra bottom spacing for keyboard
          const SizedBox(height: AppSizes.s48),
        ],
      ),
    );
  }
}
