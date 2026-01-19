import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../data/repositories/topic_repository.dart';
import '../../lessons/data/repositories/progress_repository.dart';

/// Full-screen topic browsing
/// Shows all available topics with progress and navigation
class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final _topicRepo = TopicRepository();
  final _progressRepo = ProgressRepository();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Simulate loading (data already in Hive)
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = _topicRepo.getAllTopics();

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          // App Bar with Gradient
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
                'All Topics',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // Loading State
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),

          // Empty State
          if (!_isLoading && topics.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 80,
                      color: AppColors.grey300,
                    ),
                    const SizedBox(height: AppSizes.s16),
                    Text(
                      'No Topics Available',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s8),
                    Text(
                      'Topics will appear here once loaded',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Topics List
          if (!_isLoading && topics.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(AppSizes.s20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final topic = topics[index];

                    // Calculate progress
                    int completedCount = 0;
                    int totalCount = topic.lessonIds.length;

                    for (var lessonId in topic.lessonIds) {
                      if (_progressRepo.isLessonCompleted(lessonId)) {
                        completedCount++;
                      }
                    }

                    final progressPercent = totalCount > 0
                        ? (completedCount / totalCount)
                        : 0.0;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < topics.length - 1 ? AppSizes.s16 : 0,
                      ),
                      child: _TopicListCard(
                        topic: topic,
                        progress: progressPercent,
                        completedLessons: completedCount,
                        totalLessons: totalCount,
                        onTap: () {
                          context.push('/topics/${topic.id}/lessons');
                        },
                      ),
                    );
                  },
                  childCount: topics.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Enhanced topic card for topic list screen
class _TopicListCard extends StatelessWidget {
  final dynamic topic; // TopicModel
  final double progress; // 0.0 to 1.0
  final int completedLessons;
  final int totalLessons;
  final VoidCallback onTap;

  const _TopicListCard({
    required this.topic,
    required this.progress,
    required this.completedLessons,
    required this.totalLessons,
    required this.onTap,
  });

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

  IconData _parseIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'favorite':
        return Icons.favorite;
      case 'biotech':
        return Icons.biotech;
      case 'science':
        return Icons.science;
      case 'park':
        return Icons.park;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'local_fire_department':
        return Icons.local_fire_department;
      default:
        return Icons.school;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _parseColor(topic.colorHex);
    final icon = _parseIcon(topic.iconName);
    final progressPercent = (progress * 100).toInt();

    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s16),

                  // Title and Lesson Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.name,
                          style: AppTextStyles.headingSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSizes.s4),
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 16,
                              color: AppColors.grey600,
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Text(
                              '$totalLessons ${totalLessons == 1 ? 'lesson' : 'lessons'}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Progress Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s12,
                      vertical: AppSizes.s8,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      '$progressPercent%',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.s12),

              // Description
              Text(
                topic.description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.grey600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSizes.s12),

              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                      Text(
                        '$completedLessons of $totalLessons completed',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.grey300,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}