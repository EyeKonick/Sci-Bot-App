import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';

/// Privacy Policy Screen - Static privacy policy content
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const List<Map<String, String>> _policySections = [
    {
      'title': 'Introduction',
      'content':
          'SCI-Bot is committed to protecting your privacy. This Privacy Policy explains how we handle your data when you use our educational application. We believe in transparency and keeping things simple.',
    },
    {
      'title': 'Data We Collect',
      'content':
          'SCI-Bot collects minimal data, all stored locally on your device:\n\n'
          'Lesson progress and completion status\n'
          'Bookmarked lessons\n'
          'App preferences (such as text size)\n'
          'Chat conversation history with AI characters\n\n'
          'We do NOT collect:\n\n'
          'Personal information or identity data\n'
          'Email addresses or account credentials\n'
          'Usage analytics or behavioral tracking\n'
          'Location data\n'
          'Device identifiers',
    },
    {
      'title': 'Data Storage',
      'content':
          'All your data is stored locally on your device using Hive, a lightweight local database. No data is sent to external servers for storage. Your progress, bookmarks, and preferences remain on your device and are deleted when the app is uninstalled.',
    },
    {
      'title': 'AI Chat Feature',
      'content':
          'When you use the AI chat feature, your messages are sent to OpenAI\'s API to generate responses. Important details:\n\n'
          'No personal identification is sent with your messages\n'
          'Conversations are used only for generating real-time responses\n'
          'Chat history is stored locally on your device\n'
          'An internet connection is required for AI chat functionality\n'
          'When offline, the AI chat feature is unavailable but all other app features work normally',
    },
    {
      'title': 'Third-Party Services',
      'content':
          'SCI-Bot uses the following third-party services:\n\n'
          'OpenAI API - Powers the AI chat feature (requires internet)\n'
          'Google Fonts - Provides typography (Poppins, Inter)\n\n'
          'We do not use any analytics, advertising, or tracking services. Your learning experience is private.',
    },
    {
      'title': 'Your Rights',
      'content':
          'You have full control over your data:\n\n'
          'View your progress and chat history anytime within the app\n'
          'Delete all app data through the Development Tools option\n'
          'Uninstall the app to remove all stored data completely\n'
          'No data is shared with third parties for marketing or profiling\n\n'
          'Since all data is stored locally, there is no account to delete or data export needed.',
    },
    {
      'title': 'Children\'s Privacy',
      'content':
          'SCI-Bot is designed for Grade 9 students (ages 14-15). The app does not collect personal information from any users, including minors. No account creation is required, and no personal data is transmitted to external servers beyond the AI chat messages.',
    },
    {
      'title': 'Changes to This Policy',
      'content':
          'We may update this Privacy Policy from time to time. Any changes will be reflected in the app. Continued use of SCI-Bot after changes constitutes acceptance of the updated policy.',
    },
    {
      'title': 'Contact Us',
      'content':
          'If you have questions about this Privacy Policy or how your data is handled, please contact us at:\n\n'
          'scibot.support@example.com',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Privacy Policy',
                style: AppTextStyles.appBarTitle,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // Policy Content
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.s16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Last Updated
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.s8,
                    bottom: AppSizes.s16,
                    top: AppSizes.s8,
                  ),
                  child: Text(
                    'Last Updated: February 8, 2026',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                // Policy Sections
                ..._policySections.map((section) => _PolicySection(
                      title: section['title']!,
                      content: section['content']!,
                    )),

                const SizedBox(height: AppSizes.s64),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual policy section with title and content
class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSizes.s12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              content,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.grey600,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
