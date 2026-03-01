import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/user_profile_model.dart';
import 'name_input_field.dart';
import 'profile_picture_selector.dart';

/// Profile setup page - 5th onboarding page
/// All fields are required except profile picture.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => ProfileSetupPageState();
}

class ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _gradeSectionController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  File? _selectedImage;
  bool _isNameValid = false;
  String? _selectedGender;

  // Inline field error messages
  String? _fullNameError;
  String? _gradeSectionError;
  String? _schoolError;
  String? _genderError;

  // Keys for auto-scrolling to first error
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _fullNameKey = GlobalKey();
  final GlobalKey _gradeSectionKey = GlobalKey();
  final GlobalKey _schoolKey = GlobalKey();
  final GlobalKey _genderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Listen to text changes so isValid updates reactively
    _fullNameController.addListener(() => setState(() {}));
    _gradeSectionController.addListener(() => setState(() {}));
    _schoolController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fullNameController.dispose();
    _gradeSectionController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  /// All fields except profile picture are required.
  bool get isValid =>
      _isNameValid &&
      _nameController.text.trim().isNotEmpty &&
      _fullNameController.text.trim().isNotEmpty &&
      _gradeSectionController.text.trim().isNotEmpty &&
      _schoolController.text.trim().isNotEmpty &&
      _selectedGender != null;

  /// Returns a user-friendly message describing the first missing required field.
  String get validationMessage {
    if (!_isNameValid || _nameController.text.trim().isEmpty) {
      return 'Please enter a valid display name (2–20 characters).';
    }
    if (_fullNameController.text.trim().isEmpty) {
      return 'Please enter your complete name.';
    }
    if (_gradeSectionController.text.trim().isEmpty) {
      return 'Please enter your grade and section.';
    }
    if (_schoolController.text.trim().isEmpty) {
      return 'Please enter your school name.';
    }
    if (_selectedGender == null) {
      return 'Please select your gender.';
    }
    return '';
  }

  /// Get profile data for saving — all required fields are guaranteed non-null.
  UserProfileModel getProfile() {
    final now = DateTime.now();
    return UserProfileModel(
      name: _nameController.text.trim(),
      profileImagePath: null, // Will be set after image is saved
      createdAt: now,
      updatedAt: now,
      fullName: _fullNameController.text.trim(),
      gradeSection: _gradeSectionController.text.trim(),
      school: _schoolController.text.trim(),
      gender: _selectedGender,
    );
  }

  /// Get selected image file
  File? get selectedImage => _selectedImage;

  /// Shows inline errors on all failing fields and scrolls to the first one.
  /// Called by parent when user presses "Get Started" and form is invalid.
  void showErrors() {
    setState(() {
      _fullNameError = _fullNameController.text.trim().isEmpty
          ? 'Please enter your complete name.'
          : null;
      _gradeSectionError = _gradeSectionController.text.trim().isEmpty
          ? 'Please enter your grade and section.'
          : null;
      _schoolError = _schoolController.text.trim().isEmpty
          ? 'Please enter your school name.'
          : null;
      _genderError = _selectedGender == null
          ? 'Please select your gender.'
          : null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalKey? firstErrorKey;
      if (!_isNameValid || _nameController.text.trim().isEmpty) {
        firstErrorKey = _nameFieldKey;
      } else if (_fullNameController.text.trim().isEmpty) {
        firstErrorKey = _fullNameKey;
      } else if (_gradeSectionController.text.trim().isEmpty) {
        firstErrorKey = _gradeSectionKey;
      } else if (_schoolController.text.trim().isEmpty) {
        firstErrorKey = _schoolKey;
      } else if (_selectedGender == null) {
        firstErrorKey = _genderKey;
      }

      if (firstErrorKey?.currentContext != null) {
        Scrollable.ensureVisible(
          firstErrorKey!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  /// Builds a field label with a red required asterisk.
  Widget _requiredLabel(String text, bool isDark) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

          // Profile picture selector (optional)
          ProfilePictureSelector(
            onImageSelected: (file) {
              setState(() {
                _selectedImage = file;
              });
            },
          ),
          const SizedBox(height: AppSizes.s8),
          Text(
            'Profile picture is optional',
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSizes.s24),

          // Display name (required)
          Column(
            key: _nameFieldKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requiredLabel('What should we call you?', isDark),
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

          // Complete Name (required)
          Column(
            key: _fullNameKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requiredLabel('Complete Name', isDark),
              const SizedBox(height: AppSizes.s8),
              TextField(
                controller: _fullNameController,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Maria Clara Santos',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.border,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  counterText: '',
                  errorText: (_fullNameError != null && _fullNameController.text.trim().isEmpty)
                      ? _fullNameError
                      : null,
                  errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s16),

          // Grade and Section (required)
          Column(
            key: _gradeSectionKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requiredLabel('Grade and Section', isDark),
              const SizedBox(height: AppSizes.s8),
              TextField(
                controller: _gradeSectionController,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Grade 9 - Mendel',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.border,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  counterText: '',
                  errorText: (_gradeSectionError != null && _gradeSectionController.text.trim().isEmpty)
                      ? _gradeSectionError
                      : null,
                  errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s16),

          // School (required)
          Column(
            key: _schoolKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requiredLabel('School', isDark),
              const SizedBox(height: AppSizes.s8),
              TextField(
                controller: _schoolController,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Roxas City National High School',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.border,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  counterText: '',
                  errorText: (_schoolError != null && _schoolController.text.trim().isEmpty)
                      ? _schoolError
                      : null,
                  errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s16),

          // Gender (required)
          Column(
            key: _genderKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requiredLabel('Gender', isDark),
              const SizedBox(height: AppSizes.s8),
              Wrap(
                spacing: AppSizes.s8,
                children: ['Male', 'Female', 'Prefer not to say'].map((option) {
                  final selected = _selectedGender == option;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      option,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: selected
                            ? AppColors.white
                            : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedGender = selected ? null : option;
                        _genderError = null;
                      });
                    },
                  );
                }).toList(),
              ),
              if (_genderError != null && _selectedGender == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _genderError!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.s16),

          // Required fields note
          Text(
            '* All fields except profile picture are required.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
