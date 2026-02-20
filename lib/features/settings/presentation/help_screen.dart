import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';

/// Help & Support Screen - FAQ and app usage tips
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<Map<String, String>> _faqData = [
    {
      'question': 'How do I start a lesson?',
      'answer':
          'From the Home screen, tap on a topic card or go to Topics. Select the topic you want to study, then choose a lesson from the list. Each lesson contains 6 interactive modules that guide you through the material.',
    },
    {
      'question': 'How does the AI chatbot work?',
      'answer':
          'SCI-Bot features expert AI characters for each science topic. They automatically switch based on what you are studying. Aristotle is your general guide, while topic experts like Herophilus, Mendel, and Odum help with specific subjects. Tap the floating chat button to ask questions anytime.',
    },
    {
      'question': 'How do I bookmark a lesson?',
      'answer':
          'While viewing a lesson, tap the bookmark icon to save it for later. You can access all your bookmarks from the More tab or the Bookmarks section on the Home screen.',
    },
    {
      'question': 'What are the 6 parts of the lesson?',
      'answer':
          'Each lesson has 6 parts:\n\n'
          'Fa-SCI-nate – introductory activities to activate prior knowledge;\n'
          'Goal SCI-tting – learning objectives and targets;\n'
          'Pre-SCI-ntation – engaging explanations and discussions;\n'
          'Inve-SCI-tigation – inquiry-based activities and exploration;\n'
          'Self-A-SCI-ssment – reflective questions and self-checks; and\n'
          'SCI-pplumentary – additional resources and examples.',
    },
    {
      'question': 'How is my progress tracked?',
      'answer':
          'Your progress is tracked automatically. Each module is marked complete when you finish it, and lesson progress is calculated based on how many modules you have completed. You can view detailed stats in the Progress Stats section under More.',
    },
    {
      'question': 'Can I use the app offline?',
      'answer':
          'Yes! All lesson content is stored locally on your device and available offline. However, the AI chat feature requires an internet connection to work. When offline, you can still browse topics, read lessons, and track your progress.',
    },
    {
      'question': 'How do I change the text size?',
      'answer':
          'Go to More > Text Size to adjust the reading comfort level. You can choose from Small, Medium, or Large presets. Changes will apply after restarting the app.',
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
                'Help & Support',
                style: AppTextStyles.appBarTitle,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // FAQ Section
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.s16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section Header
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.s8,
                    bottom: AppSizes.s12,
                    top: AppSizes.s8,
                  ),
                  child: Text(
                    'Frequently Asked Questions',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),

                // FAQ Cards
                ..._faqData.map((faq) => _FAQCard(
                      question: faq['question']!,
                      answer: faq['answer']!,
                    )),

                const SizedBox(height: AppSizes.s24),

                // Contact Section
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.s8,
                    bottom: AppSizes.s12,
                  ),
                  child: Text(
                    'Contact & Feedback',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),

                Card(
                  elevation: AppSizes.cardElevation,
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusS),
                              ),
                              child: const Icon(
                                Icons.email,
                                color: AppColors.primary,
                                size: AppSizes.iconM,
                              ),
                            ),
                            const SizedBox(width: AppSizes.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email Us',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.s4),
                                  Text(
                                    'scibot05@gmail.com',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.s12),
                        Text(
                          'Have a question or suggestion? We would love to hear from you!',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSizes.s16),

                // Version Info
                Card(
                  elevation: AppSizes.cardElevation,
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.cardPadding),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusS),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: AppSizes.iconM,
                          ),
                        ),
                        const SizedBox(width: AppSizes.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SCI-Bot Version 1.0.0',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSizes.s4),
                              Text(
                                'Last updated: February 2026',
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSizes.s64),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable FAQ Card
class _FAQCard extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQCard({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: AppSizes.cardElevation,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSizes.s8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          Icons.help_outline,
          color: AppColors.primary,
          size: AppSizes.iconM,
        ),
        title: Text(
          question,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: AppColors.primary,
        collapsedIconColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSizes.s16,
          0,
          AppSizes.s16,
          AppSizes.s16,
        ),
        children: [
          Text(
            answer,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
