import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.s16),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSizes.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grade 9 Student',
                                style: AppTextStyles.headingSmall,
                              ),
                              const SizedBox(height: AppSizes.s4),
                              Text(
                                'Learning Science with SCI-Bot',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.grey600,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.s24),

                // Learning Section
                _buildSectionHeader('Learning'),
                _buildSettingsTile(
                  context,
                  icon: Icons.bookmark,
                  title: 'Bookmarks',
                  subtitle: 'Your saved lessons',
                  onTap: () => _showComingSoon(context, 'Bookmarks'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.history,
                  title: 'Learning History',
                  subtitle: 'View your past lessons',
                  onTap: () => _showComingSoon(context, 'Learning History'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.leaderboard,
                  title: 'Progress Stats',
                  subtitle: 'Detailed progress analytics',
                  onTap: () => _showComingSoon(context, 'Progress Stats'),
                ),
                const SizedBox(height: AppSizes.s24),

                // Preferences Section
                _buildSectionHeader('Preferences'),
                _buildSettingsTile(
                  context,
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Manage alerts and reminders',
                  onTap: () => _showComingSoon(context, 'Notifications'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.text_fields,
                  title: 'Text Size',
                  subtitle: 'Adjust reading comfort',
                  onTap: () => _showComingSoon(context, 'Text Size'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.storage,
                  title: 'Storage',
                  subtitle: 'Manage offline content',
                  onTap: () => _showComingSoon(context, 'Storage'),
                ),
                const SizedBox(height: AppSizes.s24),

                // About Section
                _buildSectionHeader('About'),
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
                  onTap: () => _showComingSoon(context, 'Help & Support'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  onTap: () => _showComingSoon(context, 'Privacy Policy'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSizes.s8,
        bottom: AppSizes.s8,
      ),
      child: Text(
        title,
        style: AppTextStyles.headingSmall.copyWith(
          color: AppColors.grey600,
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.s8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
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
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.grey600,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About SCI-Bot'),
        content: Column(
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
              'Your AI-powered companion for mastering Grade 9 Science.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              '© 2025 SCI-Bot. All rights reserved.',
              style: AppTextStyles.caption,
            ),
          ],
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