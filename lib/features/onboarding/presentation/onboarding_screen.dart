import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routes/app_routes.dart';
import '../../../services/preferences/shared_prefs_service.dart';
import '../../../shared/utils/image_utils.dart';
import '../../profile/data/repositories/user_profile_repository.dart';
import '../../profile/presentation/widgets/profile_setup_page.dart';
import '../data/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final GlobalKey<ProfileSetupPageState> _profilePageKey = GlobalKey();
  final UserProfileRepository _profileRepository = UserProfileRepository();
  int _currentPage = 0;

  // Onboarding content
  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      title: 'Welcome to SCI-Bot! 👋',
      description:
          'Your personal AI-powered companion for mastering Grade 9 Science. Learn at your own pace, anytime, anywhere.',
      icon: Icons.science,
      iconColor: AppColors.primary,
      isCustomIcon: true,
    ),
    OnboardingPage(
      title: 'Learn Offline 📚',
      description:
          'Access all lessons and content even without internet. Your learning never stops, no matter where you are.',
      icon: Icons.offline_bolt,
      iconColor: AppColors.success,
    ),
    OnboardingPage(
      title: 'AI-Powered Help 🤖',
      description:
          'Ask questions anytime and get instant help from your AI tutor. No question is too small or too big!',
      icon: Icons.chat_bubble,
      iconColor: AppColors.info,
    ),
    OnboardingPage(
      title: 'Track Your Progress 📈',
      description:
          'Monitor your learning journey with detailed progress tracking. See how far you\'ve come and where to focus next.',
      icon: Icons.show_chart,
      iconColor: AppColors.warning,
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _completeOnboarding() async {
    // Mark onboarding as completed
    await SharedPrefsService.setOnboardingCompleted();
    await SharedPrefsService.setFirstLaunchComplete();

    if (!mounted) return;

    // Navigate to home
    context.go(AppRoutes.home);
  }

  Future<void> _nextPage() async {
    HapticFeedback.lightImpact(); // Haptic feedback on button press

    // Check if we're on the last page (profile setup - index 4)
    if (_currentPage == 4) {
      await _validateAndSaveProfile();
    } else if (_currentPage < 4) {
      // Navigate to next page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _validateAndSaveProfile() async {
    final profileState = _profilePageKey.currentState;
    if (profileState == null) {
      _showError('Profile setup error. Please try again.');
      return;
    }

    if (!profileState.isValid) {
      _showError(profileState.validationMessage);
      return;
    }

    try {
      // Get profile data
      final profile = profileState.getProfile();
      final selectedImage = profileState.selectedImage;

      // Save image if selected
      String? imagePath;
      if (selectedImage != null) {
        imagePath = await ImageUtils.processAndSaveProfileImage(selectedImage);
      }

      // Update profile with image path
      final updatedProfile = profile.copyWith(
        profileImagePath: imagePath,
      );

      // Save to repository
      await _profileRepository.saveProfile(updatedProfile);
      await SharedPrefsService.setProfileCompleted();

      // Complete onboarding
      await _completeOnboarding();
    } catch (e) {
      _showError('Error saving profile. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 56),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: 5, // 4 standard pages + 1 profile setup page
                itemBuilder: (context, index) {
                  // Show profile setup page for index 4
                  if (index == 4) {
                    return ProfileSetupPage(key: _profilePageKey);
                  }
                  // Show standard onboarding pages for indices 0-3
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.s24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5, // 5 total pages
                  (index) => _buildPageIndicator(index),
                ),
              ),
            ),

            // Next/Get Started Button
            Padding(
              padding: const EdgeInsets.all(AppSizes.s24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == 4
                        ? 'Get Started'
                        : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: page.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: page.isCustomIcon == true
                ? Image.asset(
                    'assets/icons/scibot-icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    page.icon,
                    size: 100,
                    color: page.iconColor,
                  ),
          ),
          const SizedBox(height: AppSizes.s48),

          // Title
          Text(
            page.title,
            style: AppTextStyles.headingLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.s16),

          // Description
          Text(
            page.description,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? AppColors.primary
            : (Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
    );
  }
}