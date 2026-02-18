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
      'title': 'Information Collection and Use',
      'content':
          'For the purpose of enhancing our Service, this application may require users to provide personally identifiable information. This information will only be retained on the user\'s device and will not be collected by the developer in any way. The app may use third-party services that collect additional information for user identification.',
    },
    {
      'title': 'Log Data',
      'content':
          'In the event of an error in the app, the developer may collect data and information (through third-party products) on the device called Log Data. This Log Data may include information such as the device\'s Internet Protocol ("IP") address, device name, operating system version, app configuration, time and date of use, and other statistics.',
    },
    {
      'title': 'Cookies',
      'content':
          'This app does not use "cookies" explicitly. However, it may use third-party code and libraries that use "cookies" to collect information and improve their services. Users have the option to accept or refuse these cookies and can be notified when a cookie is being sent to their device. Refusing cookies may limit the use of some portions of the Service.',
    },
    {
      'title': 'Service Providers',
      'content':
          'This app may employ third-party companies and individuals to facilitate, provide, or analyze the Service. These third parties may have access to Personal Information but are obligated not to disclose or use it for any other purposes.',
    },
    {
      'title': 'Security',
      'content':
          'The developer aims to use commercially acceptable means to protect users\' Personal Information, although no electronic storage method is 100% secure. Therefore, absolute security cannot be guaranteed.',
    },
    {
      'title': 'Links and Other Sites',
      'content':
          'The Service may contain links to other sites that are not operated by the developer. When users click on a third-party link, they will be directed to that site and are advised to review the external site\'s Privacy Policy as the developer has no control over its content, privacy policies, or practices.',
    },
    {
      'title': 'Children\'s Privacy',
      'content':
          'The Services do not address anyone under the age of 13 and do not knowingly collect personally identifiable information from children under 13 years of age. If it is discovered that a child under 13 has provided personal information, the developer will immediately delete it from their servers.',
    },
    {
      'title': 'Changes to This Privacy Policy',
      'content':
          'The developer may update the Privacy Policy from time to time. Users are advised to review this page periodically for changes. Any updates will be notified by posting the new Privacy Policy on this page. This policy is effective as of August, 2025.',
    },
    {
      'title': 'Contact Us',
      'content':
          'For any queries or suggestions about this Privacy Policy, please feel free to contact us at:\n\n'
          'scibot05@gmail.com',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                    'Effective as of August, 2025',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
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
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              content,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
