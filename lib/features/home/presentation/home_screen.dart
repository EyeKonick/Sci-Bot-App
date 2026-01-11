import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCI-Bot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.s16),
        children: [
          // Greeting
          Text(
            'Hello, Learner! 👋',
            style: AppTextStyles.headingLarge,
          ),
          const SizedBox(height: AppSizes.s8),
          Text(
            'What would you like to learn today?',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.grey600,
            ),
          ),
          const SizedBox(height: AppSizes.s24),

          // Search Bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search lessons and topics...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSizes.s24),

          // Topics Section
          Text(
            'Explore Topics',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: AppSizes.s16),

          // Placeholder Topic Cards
          _buildTopicCard(
            context,
            'Heredity & Variation',
            Icons.biotech,
            '5 lessons',
          ),
          _buildTopicCard(
            context,
            'Circulation',
            Icons.favorite,
            '4 lessons',
          ),
          _buildTopicCard(
            context,
            'Ecosystems',
            Icons.park,
            '6 lessons',
          ),

          const SizedBox(height: AppSizes.s24),

          // Route Testing Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Navigation Testing',
                    style: AppTextStyles.headingSmall,
                  ),
                  const SizedBox(height: AppSizes.s12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => context.go('/onboarding'),
                        child: const Text('Onboarding'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.go('/chat'),
                        child: const Text('Chat Tab'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.go('/more'),
                        child: const Text('More Tab'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.go('/not-found'),
                        child: const Text('404 Page'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(
    BuildContext context,
    String title,
    IconData icon,
    String lessonCount,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.s12),
      child: InkWell(
        onTap: () {
          // Will navigate using GoRouter
        },
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconL,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSizes.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.lessonCardTitle,
                    ),
                    const SizedBox(height: AppSizes.s4),
                    Text(
                      lessonCount,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}