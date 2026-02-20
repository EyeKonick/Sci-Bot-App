import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../profile/data/providers/user_profile_provider.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Gradient
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'More',
                style: AppTextStyles.appBarTitle,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // Settings List
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.s16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Profile Section
                Card(
                  child: InkWell(
                    onTap: () => context.push('/profile'),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.s16),
                      child: Row(
                        children: [
                          profileAsync.when(
                            data: (profile) => ProfileAvatar(
                              imagePath: profile?.profileImagePath,
                              size: 64,
                              borderColor: AppColors.primary,
                              borderWidth: 2,
                            ),
                            loading: () => const ProfileAvatar(
                              size: 64,
                            ),
                            error: (_, __) => const ProfileAvatar(
                              size: 64,
                            ),
                          ),
                          const SizedBox(width: AppSizes.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                profileAsync.when(
                                  data: (profile) => Text(
                                    profile?.name ?? 'Grade 9 Student',
                                    style: AppTextStyles.headingSmall,
                                  ),
                                  loading: () => Text(
                                    'Grade 9 Student',
                                    style: AppTextStyles.headingSmall,
                                  ),
                                  error: (_, __) => Text(
                                    'Grade 9 Student',
                                    style: AppTextStyles.headingSmall,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.s4),
                                Text(
                                  'Learning Science with SCI-Bot',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.s24),

                // Learning Section
                _buildSectionHeader('Learning', isDark: isDark),
                _buildSettingsTile(
                  context,
                  icon: Icons.bookmark,
                  title: 'Bookmarks',
                  subtitle: 'Your saved lessons',
                  onTap: () => context.push('/bookmarks'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.history,
                  title: 'Learning History',
                  subtitle: 'View your past lessons',
                  onTap: () => context.push('/learning-history'),
                ),
                const SizedBox(height: AppSizes.s24),

                // Preferences Section
                _buildSectionHeader('Preferences', isDark: isDark),
                _buildSettingsTile(
                  context,
                  icon: Icons.text_fields,
                  title: 'Text Size',
                  subtitle: 'Adjust reading comfort',
                  onTap: () => context.push('/text-size'),
                ),
                // Dark Mode Toggle
                Card(
                  margin: const EdgeInsets.only(bottom: AppSizes.s8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkPrimary.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: Icon(
                        ref.watch(isDarkModeProvider)
                            ? Icons.dark_mode
                            : Icons.dark_mode_outlined,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        size: AppSizes.iconM,
                      ),
                    ),
                    title: Text(
                      'Dark Mode',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Switch to dark theme',
                      style: AppTextStyles.caption,
                    ),
                    trailing: Switch(
                      value: ref.watch(isDarkModeProvider),
                      onChanged: (_) =>
                          ref.read(themeModeProvider.notifier).toggle(),
                      activeThumbColor: AppColors.white,
                      activeTrackColor: AppColors.primary,
                      inactiveThumbColor: AppColors.primary,
                      inactiveTrackColor:
                          AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.s24),

                // About Section
                _buildSectionHeader('About', isDark: isDark),
                _buildSettingsTile(
                  context,
                  icon: Icons.info,
                  title: 'About SCI-Bot',
                  subtitle: 'Version 1.0.0',
                  onTap: () => _showAboutDialog(context),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.help,
                  title: 'Help & Support',
                  subtitle: 'Get help with the app',
                  onTap: () => context.push('/help'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  onTap: () => context.push('/privacy-policy'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSizes.s8,
        bottom: AppSizes.s8,
      ),
      child: Text(
        title,
        style: AppTextStyles.headingSmall.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.s8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkPrimary.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
            size: AppSizes.iconM,
          ),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.caption,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About SCI-Bot'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCI-Bot',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Text(
                'Version 1.0.0',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSizes.s16),
              Text(
                'The Science Contextualized Instruction through AI-based Chatbot (SCI-Bot) mobile learning application is an AI-powered supplementary learning tool designed to support Grade 9 Science students, with a special focus on mastering the least-learned skills identified in the Grade 9 Science curriculum.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                'Powered by OpenAI, SCI-Bot uses artificial intelligence to provide interactive, learner-centered, and contextualized instruction that helps make complex scientific concepts clearer, more engaging, and easier to understand.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                'SCI-Bot presents science lessons through real-life situations, familiar examples, and simplified explanations that are aligned with students\' local context. This contextualized approach bridges the gap between abstract scientific ideas and everyday experiences, enhancing comprehension, engagement, and long-term retention of knowledge.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSizes.s16),
              const Divider(),
              const SizedBox(height: AppSizes.s16),
              Text(
                'Developer',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.s12),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2.5,
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/profile.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                'This mobile app was developed by Joecil Orola Villanueva, a graduate student of West Visayas State University – La Paz Campus, taking up Master of Arts in Education (MAEd), Major in Biological Science. He is currently a Teacher II at Roxas City School for Philippine Craftsmen, where he actively teaches science and works closely with high school learners.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                'As a classroom practitioner, the developer brings firsthand experience in identifying students\' learning gaps, particularly in science concepts that are often challenging for Grade 9 learners. His exposure to diverse learning needs, coupled with his academic training in biological science and education, inspired the development of SCI-Bot as an innovative, technology-driven support tool for students.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                'Driven by a commitment to learner-centered and inclusive education, Villanueva integrates pedagogy, content knowledge, and educational technology in the design of SCI-Bot. The application reflects his advocacy for contextualized instruction, inquiry-based learning, and the meaningful use of artificial intelligence to enhance science education and improve student learning outcomes beyond the traditional classroom setting.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSizes.s16),
              Text(
                '© 2026 SCI-Bot. All rights reserved.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}