import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../lessons/data/repositories/lesson_repository.dart';
import '../../lessons/data/repositories/progress_repository.dart';
import '../../topics/data/repositories/topic_repository.dart';

/// Progress Stats Screen - Detailed analytics
class ProgressStatsScreen extends StatelessWidget {
  const ProgressStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progressRepo = ProgressRepository();
    final lessonRepo = LessonRepository();
    final topicRepo = TopicRepository();

    final allProgress = progressRepo.getAllProgress();
    final allLessons = lessonRepo.getAllLessons();
    final allTopics = topicRepo.getAllTopics();
    final completedLessons = progressRepo.getCompletedLessonsCount();
    final totalLessons = allLessons.length;

    // Calculate total modules completed
    int totalModulesCompleted = 0;
    for (var progress in allProgress) {
      totalModulesCompleted += progress.completedModuleIds.length;
    }

    // Calculate recent activity (last 7 days)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentActivity = allProgress
        .where((p) => p.lastAccessed.isAfter(sevenDaysAgo))
        .length;

    final overallPercentage =
        totalLessons > 0 ? completedLessons / totalLessons : 0.0;

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
                'Progress Stats',
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
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.s16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSizes.s8),

                // Overall Progress Card
                OverallProgressCard(
                  completedLessons: completedLessons,
                  totalLessons: totalLessons,
                  percentage: overallPercentage,
                ),

                const SizedBox(height: AppSizes.s24),

                // Summary Stats Row
                SummaryStatsRow(
                  totalModulesCompleted: totalModulesCompleted,
                  recentActivity: recentActivity,
                  totalLessons: totalLessons,
                  completedLessons: completedLessons,
                ),

                const SizedBox(height: AppSizes.s24),

                // Topic Progress Header
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.s8,
                    bottom: AppSizes.s12,
                  ),
                  child: Text(
                    'Progress by Topic',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.grey600,
                    ),
                  ),
                ),

                // Topic Progress Cards
                ...allTopics.map((topic) {
                  final topicLessons =
                      lessonRepo.getLessonsByTopicId(topic.id);
                  int topicCompleted = 0;
                  int topicModulesCompleted = 0;

                  for (var lesson in topicLessons) {
                    if (progressRepo.isLessonCompleted(lesson.id)) {
                      topicCompleted++;
                    }
                    final progress = progressRepo.getProgress(lesson.id);
                    if (progress != null) {
                      topicModulesCompleted +=
                          progress.completedModuleIds.length;
                    }
                  }

                  return TopicProgressCard(
                    topicName: topic.name,
                    imageAsset: topic.imageAsset,
                    topicColor: parseTopicColor(topic.colorHex),
                    lessonsCompleted: topicCompleted,
                    totalLessons: topicLessons.length,
                    modulesCompleted: topicModulesCompleted,
                    totalModules: topicLessons.length * 6,
                  );
                }),

                const SizedBox(height: AppSizes.s64),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parse a hex color string to Color
Color parseTopicColor(String hexString) {
  try {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return AppColors.primary;
  }
}

/// Large circular progress indicator card
class OverallProgressCard extends StatelessWidget {
  final int completedLessons;
  final int totalLessons;
  final double percentage;

  const OverallProgressCard({
    super.key,
    required this.completedLessons,
    required this.totalLessons,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          children: [
            // Circular Progress
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: percentage.clamp(0.0, 1.0),
                      strokeWidth: 10,
                      backgroundColor: AppColors.grey300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(percentage * 100).toInt()}%',
                        style: AppTextStyles.displayLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Complete',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.s16),

            Text(
              'Lessons Completed',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.s4),
            Text(
              '$completedLessons of $totalLessons',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary stats in a row of cards
class SummaryStatsRow extends StatelessWidget {
  final int totalModulesCompleted;
  final int recentActivity;
  final int totalLessons;
  final int completedLessons;

  const SummaryStatsRow({
    super.key,
    required this.totalModulesCompleted,
    required this.recentActivity,
    required this.totalLessons,
    required this.completedLessons,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProgressStatCard(
            icon: Icons.view_module,
            label: 'Modules Done',
            value: '$totalModulesCompleted',
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: ProgressStatCard(
            icon: Icons.trending_up,
            label: 'This Week',
            value: '$recentActivity',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: ProgressStatCard(
            icon: Icons.emoji_events,
            label: 'Rate',
            value: totalLessons > 0
                ? '${((completedLessons / totalLessons) * 100).toInt()}%'
                : '0%',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

/// Individual stat card
class ProgressStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const ProgressStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.s12,
          vertical: AppSizes.s16,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: AppSizes.iconL),
            const SizedBox(height: AppSizes.s8),
            Text(
              value,
              style: AppTextStyles.headingSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.s4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-topic progress card
class TopicProgressCard extends StatelessWidget {
  final String topicName;
  final String? imageAsset;
  final Color topicColor;
  final int lessonsCompleted;
  final int totalLessons;
  final int modulesCompleted;
  final int totalModules;

  const TopicProgressCard({
    super.key,
    required this.topicName,
    this.imageAsset,
    required this.topicColor,
    required this.lessonsCompleted,
    required this.totalLessons,
    required this.modulesCompleted,
    required this.totalModules,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalLessons > 0 ? lessonsCompleted / totalLessons : 0.0;

    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSizes.s12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: lessonsCompleted == totalLessons && totalLessons > 0
            ? BorderSide(color: topicColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: topicColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: imageAsset != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          child: Image.asset(
                            imageAsset!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.science,
                          color: topicColor,
                          size: AppSizes.iconM,
                        ),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topicName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s4),
                      Text(
                        '$lessonsCompleted of $totalLessons lessons completed',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: topicColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.s16),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.grey300,
                valueColor: AlwaysStoppedAnimation<Color>(topicColor),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: AppSizes.s12),

            // Module stats
            Row(
              children: [
                Icon(
                  Icons.view_module,
                  size: AppSizes.iconXS,
                  color: AppColors.grey600,
                ),
                const SizedBox(width: AppSizes.s4),
                Text(
                  '$modulesCompleted of $totalModules modules completed',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
