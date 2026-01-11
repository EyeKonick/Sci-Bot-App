import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routes/app_routes.dart';
import '../../../services/preferences/shared_prefs_service.dart';
import '../data/onboarding_page.dart';
import 'package:flutter/services.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Onboarding content
  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      title: 'Welcome to SCI-Bot! 👋',
      description:
          'Your personal AI-powered companion for mastering Grade 9 Science. Learn at your own pace, anytime, anywhere.',
      icon: Icons.science,
      iconColor: AppColors.primary,
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

  void _nextPage() {
    HapticFeedback.lightImpact(); // Haptic feedback on button press
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: AppColors.grey600,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
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
                  _pages.length,
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
                    _currentPage == _pages.length - 1
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
              color: page.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: Icon(
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
              color: AppColors.grey600,
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
        color: _currentPage == index ? AppColors.primary : AppColors.grey300,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
    );
  }
}