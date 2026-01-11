import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../services/preferences/shared_prefs_service.dart';
import 'widgets/greeting_header.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/topic_card.dart';
import 'widgets/quick_stats_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Placeholder topic data (will be replaced with real data in Day 6)
  final List<Map<String, dynamic>> _topics = [
    {
      'id': 'topic-1',
      'title': 'Heredity & Variation',
      'description': 'Learn about genes, DNA, and how traits are inherited',
      'icon': Icons.biotech,
      'iconColor': AppColors.primary,
      'lessonCount': 5,
      'progress': 0.6,
    },
    {
      'id': 'topic-2',
      'title': 'Circulation',
      'description': 'Explore the heart, blood vessels, and circulatory system',
      'icon': Icons.favorite,
      'iconColor': Colors.red,
      'lessonCount': 4,
      'progress': 0.3,
    },
    {
      'id': 'topic-3',
      'title': 'Ecosystems',
      'description': 'Understand food chains, habitats, and biodiversity',
      'icon': Icons.park,
      'iconColor': Colors.green,
      'lessonCount': 6,
      'progress': 0.0,
    },
    {
      'id': 'topic-4',
      'title': 'Forces & Motion',
      'description': 'Discover Newton\'s laws and how objects move',
      'icon': Icons.rocket_launch,
      'iconColor': Colors.orange,
      'lessonCount': 5,
      'progress': 0.2,
    },
    {
      'id': 'topic-5',
      'title': 'Chemical Reactions',
      'description': 'Learn about atoms, molecules, and chemical changes',
      'icon': Icons.science,
      'iconColor': Colors.purple,
      'lessonCount': 7,
      'progress': 0.0,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search functionality coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleTopicTap(String topicId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening topic: $topicId'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Greeting Header
          const SliverToBoxAdapter(
            child: GreetingHeader(),
          ),

          // Main Content
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.s16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Search Bar
                SearchBarWidget(
                  controller: _searchController,
                  onTap: _handleSearch,
                ),
                const SizedBox(height: AppSizes.s24),

                // Quick Stats
                const QuickStatsCard(
                  lessonsCompleted: 6,
                  totalLessons: 27,
                  currentStreak: 3,
                ),
                const SizedBox(height: AppSizes.s24),

                // Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Explore Topics',
                      style: AppTextStyles.headingMedium,
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See All'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s12),

                // Topics List
                ..._topics.map((topic) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.s12),
                      child: TopicCard(
                        title: topic['title'],
                        description: topic['description'],
                        icon: topic['icon'],
                        iconColor: topic['iconColor'],
                        lessonCount: topic['lessonCount'],
                        progress: topic['progress'],
                        onTap: () => _handleTopicTap(topic['id']),
                      ),
                    )),

                const SizedBox(height: AppSizes.s24),

                // Development Tools (REMOVE BEFORE PRODUCTION)
                _buildDevToolsCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevToolsCard() {
    return Card(
      color: AppColors.warning.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.construction,
                  color: AppColors.warning,
                  size: AppSizes.iconS,
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  'Development Tools',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s12),
            Wrap(
              spacing: AppSizes.s8,
              runSpacing: AppSizes.s8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await SharedPrefsService.resetFirstLaunch();
                    if (mounted) {
                      context.go('/');
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/onboarding'),
                  icon: const Icon(Icons.school, size: 18),
                  label: const Text('Onboarding'),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              '⚠️ Remove this card before production',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.warning,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}