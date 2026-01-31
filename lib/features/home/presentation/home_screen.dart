import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../features/topics/data/repositories/topic_repository.dart';
import '../../../features/lessons/data/repositories/lesson_repository.dart';
import '../../../features/lessons/data/repositories/progress_repository.dart';
import 'widgets/greeting_header.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/topic_card.dart';
import 'widgets/quick_stats_card.dart';
import '../../../services/storage/hive_service.dart';
import '../../../services/data/data_seeder_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _topicRepo = TopicRepository();
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();

  @override
  Widget build(BuildContext context) {
    // Get real data from Hive
    final topics = _topicRepo.getAllTopics();
    final completedLessonsCount = _progressRepo.getCompletedLessonsCount();
    
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
       slivers: [
          // Greeting Header
         const SliverToBoxAdapter(
            child: GreetingHeader(),  // ✅ CORRECT - no parameters
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s20),
              child: SearchBarWidget(
                onTap: () {
                  // TODO: Navigate to search
                },
              ),
            ),
          ),

          // Quick Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s24),
              child: QuickStatsCard(
                lessonsCompleted: completedLessonsCount,
                totalLessons: _lessonRepo.getLessonsCount(),
                currentStreak: 0, // TODO: Calculate streak
              ),
            ),
          ),

          // Section Header - Topics
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Topics',
                    style: AppTextStyles.headingMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to Topics screen
                      context.push('/topics');
                    },
                    child: Text(
                      'See All',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Topics List - REAL DATA
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final topic = topics[index];
                  
                  // Calculate progress for this topic
                  int completedCount = 0;
                  int totalCount = topic.lessonIds.length;
                  
                  for (var lessonId in topic.lessonIds) {
                    if (_progressRepo.isLessonCompleted(lessonId)) {
                      completedCount++;
                    }
                  }
                  
                  // Progress as decimal (0.0 to 1.0) for TopicCard
                  final progress = totalCount > 0 
                      ? (completedCount / totalCount)
                      : 0.0;
                  
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < topics.length - 1 ? AppSizes.s16 : 0,
                    ),
                    child: TopicCard(
                      title: topic.name,
                      description: topic.description,
                      icon: Icons.school,
                      iconColor: _parseColor(topic.colorHex),
                      lessonCount: topic.lessonIds.length,
                      progress: progress,
                      onTap: () {
                        // Navigate to topic lessons
                        context.push('/topics/${topic.id}/lessons');
                      },
                    ),
                  );
                },
                childCount: topics.length,
              ),
            ),
          ),

          // Development Tools Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s24),
              child: Card(
                elevation: AppSizes.cardElevation,
                color: AppColors.surface,
                child: ListTile(
                  leading: const Icon(Icons.build, color: AppColors.primary),
                  title: Text(
                    'Development Tools',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Debug and testing options',
                    style: AppTextStyles.bodySmall,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: AppSizes.iconXS),
                  onTap: () => _showDevTools(context),
                ),
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  /// Parse hex color string to Color
  Color _parseColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return AppColors.primary;
    }
  }

  void _showDevTools(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Development Tools',
          style: AppTextStyles.headingSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                'Clear All Data',
                style: AppTextStyles.bodyMedium,
              ),
              leading: const Icon(Icons.delete_forever, color: AppColors.error),
              onTap: () async {
                await HiveService.clearAll();
                await DataSeederService.resetSeededFlag();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Data cleared! Restart app to reseed.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: Text(
                'View Data Stats',
                style: AppTextStyles.bodyMedium,
              ),
              leading: const Icon(Icons.analytics, color: AppColors.primary),
              onTap: () {
                final topics = _topicRepo.getTopicsCount();
                final lessons = _lessonRepo.getLessonsCount();
                final progress = _progressRepo.getAllProgress().length;
                
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Data Statistics',
                      style: AppTextStyles.headingSmall,
                    ),
                    content: Text(
                      'Topics: $topics\n'
                      'Lessons: $lessons\n'
                      'Progress Records: $progress',
                      style: AppTextStyles.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'OK',
                          style: AppTextStyles.buttonLabel.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}