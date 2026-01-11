import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

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
                'AI Chat',
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.s24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // AI Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s32),

                  Text(
                    'Your AI Tutor is Ready! 🤖',
                    style: AppTextStyles.headingLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.s16),

                  Text(
                    'Ask me anything about Grade 9 Science!\nI\'m here to help you understand concepts, solve problems, and answer your questions.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.grey600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.s32),

                  // Sample questions
                  _buildSampleQuestion(
                    context,
                    'What is DNA?',
                    Icons.biotech,
                  ),
                  const SizedBox(height: AppSizes.s12),
                  _buildSampleQuestion(
                    context,
                    'How does the heart pump blood?',
                    Icons.favorite,
                  ),
                  const SizedBox(height: AppSizes.s12),
                  _buildSampleQuestion(
                    context,
                    'What is Newton\'s first law?',
                    Icons.rocket_launch,
                  ),
                  const SizedBox(height: AppSizes.s32),

                  // Coming Soon Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s16,
                      vertical: AppSizes.s8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Full chat functionality coming in Week 3',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleQuestion(
    BuildContext context,
    String question,
    IconData icon,
  ) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat will answer: "$question"'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(
            color: AppColors.grey300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: AppSizes.iconM,
            ),
            const SizedBox(width: AppSizes.s12),
            Expanded(
              child: Text(
                question,
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.grey600,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}