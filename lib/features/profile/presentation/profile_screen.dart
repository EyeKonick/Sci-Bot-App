import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/utils/image_utils.dart';
import '../../lessons/data/repositories/lesson_repository.dart';
import '../../lessons/data/repositories/progress_repository.dart';
import '../../settings/presentation/progress_stats_screen.dart';
import '../../topics/data/repositories/topic_repository.dart';
import '../data/providers/user_profile_provider.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/name_input_field.dart';
import 'widgets/profile_picture_selector.dart';

/// Profile screen with editable name/avatar and progress stats
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _gradeSectionController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  bool _isNameValid = true;
  bool _isEditing = false;
  bool _isSaving = false;
  File? _newImage;
  bool _imageChanged = false;

  @override
  void dispose() {
    _nameController.dispose();
    _fullNameController.dispose();
    _gradeSectionController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  void _startEditing(String currentName, {String? fullName, String? gradeSection, String? school}) {
    setState(() {
      _isEditing = true;
      _nameController.text = currentName;
      _fullNameController.text = fullName ?? '';
      _gradeSectionController.text = gradeSection ?? '';
      _schoolController.text = school ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _newImage = null;
      _imageChanged = false;
      _nameController.clear();
      _fullNameController.clear();
      _gradeSectionController.clear();
      _schoolController.clear();
    });
  }

  Future<void> _saveProfile() async {
    if (!_isNameValid || _nameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      String? imagePath;
      if (_imageChanged && _newImage != null) {
        imagePath = await ImageUtils.processAndSaveProfileImage(_newImage!);
      }

      await ref.read(userProfileProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            profileImagePath: _imageChanged ? imagePath : null,
            fullName: _fullNameController.text.trim().isEmpty
                ? null
                : _fullNameController.text.trim(),
            gradeSection: _gradeSectionController.text.trim().isEmpty
                ? null
                : _gradeSectionController.text.trim(),
            school: _schoolController.text.trim().isEmpty
                ? null
                : _schoolController.text.trim(),
          );

      setState(() {
        _isEditing = false;
        _newImage = null;
        _imageChanged = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile. Please try again.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.s4),
        TextField(
          controller: controller,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.border,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s12,
              vertical: AppSizes.s8,
            ),
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    bool isDark, {
    bool isName = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppSizes.iconXS,
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
          ),
          const SizedBox(width: AppSizes.s8),
          Flexible(
            child: Text(
              text,
              style: isName
                  ? AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )
                  : AppTextStyles.bodySmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () {
                if (_isEditing) {
                  _cancelEditing();
                } else {
                  context.pop();
                }
              },
            ),
            actions: _isEditing
                ? [
                    TextButton(
                      onPressed: _cancelEditing,
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ]
                : null,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Profile',
                style: AppTextStyles.appBarTitle,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.s16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSizes.s8),

                // Profile Card
                _buildProfileCard(profileAsync),

                const SizedBox(height: AppSizes.s24),

                // Progress Stats Section
                _buildProgressSection(),

                const SizedBox(height: AppSizes.s64),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(AsyncValue profileAsync) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: AppSizes.cardElevation,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('No profile found'));
            }

            return Column(
              children: [
                // Avatar
                if (_isEditing) ...[
                  ProfilePictureSelector(
                    initialImage: profile.profileImagePath != null
                        ? File(profile.profileImagePath!)
                        : null,
                    onImageSelected: (file) {
                      setState(() {
                        _newImage = file;
                        _imageChanged = true;
                      });
                    },
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: () => _startEditing(profile.name,
                        fullName: profile.fullName,
                        gradeSection: profile.gradeSection,
                        school: profile.school),
                    child: Stack(
                      children: [
                        ProfileAvatar(
                          imagePath: profile.profileImagePath,
                          size: 100,
                          borderColor: AppColors.primary,
                          borderWidth: 3,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.darkSurface : AppColors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: isDark ? AppColors.darkBackground : AppColors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSizes.s16),

                // Name
                if (_isEditing) ...[
                  NameInputField(
                    controller: _nameController,
                    onValidationChanged: (isValid) {
                      setState(() => _isNameValid = isValid);
                    },
                  ),
                  const SizedBox(height: AppSizes.s12),
                  _buildEditField(
                    label: 'Complete Name',
                    controller: _fullNameController,
                    hint: 'e.g., Maria Clara Santos',
                    maxLength: 60,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSizes.s12),
                  _buildEditField(
                    label: 'Grade and Section',
                    controller: _gradeSectionController,
                    hint: 'e.g., Grade 9 - Mendel',
                    maxLength: 50,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSizes.s12),
                  _buildEditField(
                    label: 'School',
                    controller: _schoolController,
                    hint: 'e.g., Roxas City National High School',
                    maxLength: 80,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSizes.s16),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isNameValid && !_isSaving)
                          ? _saveProfile
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.s12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusL),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  // Username badge with background
                  GestureDetector(
                    onTap: () => _startEditing(profile.name,
                        fullName: profile.fullName,
                        gradeSection: profile.gradeSection,
                        school: profile.school),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.s16,
                        vertical: AppSizes.s8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkPrimary.withValues(alpha: 0.18)
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkPrimary.withValues(alpha: 0.4)
                              : AppColors.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile.name,
                            style: AppTextStyles.headingMedium.copyWith(
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: AppSizes.s8),
                          Icon(
                            Icons.edit_rounded,
                            color: isDark
                                ? AppColors.darkPrimary.withValues(alpha: 0.7)
                                : AppColors.primary.withValues(alpha: 0.7),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Info rows with divider
                  if ((profile.fullName != null && profile.fullName!.isNotEmpty) ||
                      (profile.gradeSection != null && profile.gradeSection!.isNotEmpty) ||
                      (profile.school != null && profile.school!.isNotEmpty)) ...[
                    const SizedBox(height: AppSizes.s16),
                    Divider(
                      color: isDark
                          ? AppColors.darkBorder.withValues(alpha: 0.4)
                          : AppColors.border.withValues(alpha: 0.6),
                      height: 1,
                    ),
                    const SizedBox(height: AppSizes.s12),
                    if (profile.fullName != null && profile.fullName!.isNotEmpty)
                      _buildInfoRow(
                        Icons.person_outline_rounded,
                        profile.fullName!,
                        isDark,
                        isName: true,
                      ),
                    if (profile.gradeSection != null && profile.gradeSection!.isNotEmpty)
                      _buildInfoRow(
                        Icons.school_outlined,
                        profile.gradeSection!,
                        isDark,
                      ),
                    if (profile.school != null && profile.school!.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        profile.school!,
                        isDark,
                      ),
                  ],

                  const SizedBox(height: AppSizes.s16),

                  // SCI-Bot tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s12,
                      vertical: AppSizes.s4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkAccent.withValues(alpha: 0.15)
                          : AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: isDark ? AppColors.darkAccent : AppColors.accent,
                        ),
                        const SizedBox(width: AppSizes.s4),
                        Text(
                          'Learning Science with SCI-Bot',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.darkAccent : AppColors.accent,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (_, __) => const Center(
            child: Text('Error loading profile'),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressRepo = ProgressRepository();
    final lessonRepo = LessonRepository();
    final topicRepo = TopicRepository();

    final allProgress = progressRepo.getAllProgress();
    final allLessons = lessonRepo.getAllLessons();
    final allTopics = topicRepo.getAllTopics();
    final completedLessons = progressRepo.getCompletedLessonsCount();
    final totalLessons = allLessons.length;

    int totalModulesCompleted = 0;
    for (var progress in allProgress) {
      totalModulesCompleted += progress.completedModuleIds.length;
    }

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentActivity = allProgress
        .where((p) => p.lastAccessed.isAfter(sevenDaysAgo))
        .length;

    final overallPercentage =
        totalLessons > 0 ? completedLessons / totalLessons : 0.0;

    final sectionHeaderColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(
            left: AppSizes.s8,
            bottom: AppSizes.s12,
          ),
          child: Text(
            'Learning Progress',
            style: AppTextStyles.headingSmall.copyWith(
              color: sectionHeaderColor,
            ),
          ),
        ),

        // Overall Progress — full width, centered content
        SizedBox(
          width: double.infinity,
          child: OverallProgressCard(
            completedLessons: completedLessons,
            totalLessons: totalLessons,
            percentage: overallPercentage,
          ),
        ),

        const SizedBox(height: AppSizes.s16),

        // Summary Stats
        SummaryStatsRow(
          totalModulesCompleted: totalModulesCompleted,
          recentActivity: recentActivity,
          totalLessons: totalLessons,
          completedLessons: completedLessons,
        ),

        const SizedBox(height: AppSizes.s24),

        // Topic Progress Header
        Padding(
          padding: const EdgeInsets.only(
            left: AppSizes.s8,
            bottom: AppSizes.s12,
          ),
          child: Text(
            'Progress by Topic',
            style: AppTextStyles.headingSmall.copyWith(
              color: sectionHeaderColor,
            ),
          ),
        ),

        // Topic Progress Cards
        ...allTopics.map((topic) {
          final topicLessons = lessonRepo.getLessonsByTopicId(topic.id);
          int topicCompleted = 0;
          int topicModulesCompleted = 0;

          for (var lesson in topicLessons) {
            if (progressRepo.isLessonCompleted(lesson.id)) {
              topicCompleted++;
            }
            final progress = progressRepo.getProgress(lesson.id);
            if (progress != null) {
              topicModulesCompleted += progress.completedModuleIds.length;
            }
          }

          return TopicProgressCard(
            topicName: topic.name,
            imageAsset: topic.imageAsset,
            topicColor: parseTopicColor(topic.colorHex),
            lessonsCompleted: topicCompleted,
            totalLessons: topicLessons.length,
            modulesCompleted: topicModulesCompleted,
            totalModules: topicLessons.length * 6,
          );
        }),
      ],
    );
  }
}
