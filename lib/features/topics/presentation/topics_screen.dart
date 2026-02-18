import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../data/repositories/topic_repository.dart';
import '../../lessons/data/repositories/progress_repository.dart';
import '../../chat/data/providers/character_provider.dart';
import '../../chat/data/repositories/chat_repository.dart';
import '../../../shared/models/scenario_model.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/neumorphic_styles.dart';

/// Full-screen topic browsing
/// Shows all available topics with progress and navigation
class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key});

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
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
      backgroundColor: AppColors.background,
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

          // Loading State - Phase 8: Skeleton cards instead of bare spinner
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.all(AppSizes.s20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSizes.s16),
                    child: SkeletonTopicCard(),
                  ),
                  childCount: 3,
                ),
              ),
            ),

          // Empty State - Phase 4: Forward action added
          if (!_isLoading && topics.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.s24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 80,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: AppSizes.s16),
                      Text(
                        'No Topics Available',
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s8),
                      Text(
                        'Topics will appear here once loaded. Try restarting the app.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.s24),
                      ElevatedButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                        ),
                      ),
                    ],
                  ),
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
                        onTap: () async {
                          // Update character context before navigating
                          ref.read(characterContextManagerProvider).navigateToTopic(topic.id);
                          await context.push('/topics/${topic.id}/lessons');
                          // Restore aristotle_general scenario when returning
                          if (mounted) {
                            ref.read(characterContextManagerProvider).navigateToHome();
                            final aristotleScenario = ChatScenario.aristotleGeneral();
                            ref.read(currentScenarioProvider.notifier).state = aristotleScenario;
                            await ChatRepository().setScenario(aristotleScenario);
                          }
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

  /// Learning competencies mapped by topic ID
  static const Map<String, String> _learningCompetencies = {
    'topic_body_systems': 'Explain how the respiratory and circulatory systems work together to transport nutrients, gases and other molecules to and from the different parts of the body (S9LT-la-b-26)',
    'topic_heredity': 'Explain the different patterns of non-Mendelian inheritance (S9LT-Id-29)',
    'topic_energy': 'Differentiate basic features and importance of photosynthesis and respiration (S9LT-lg-j-31)',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _parseColor(topic.colorHex);
    final icon = _parseIcon(topic.iconName);
    final progressPercent = (progress * 100).toInt();
    final competency = _learningCompetencies[topic.id];
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final trackColor = isDark ? AppColors.darkBorder : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: NeumorphicStyles.raised(context),
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Icon/Image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: topic.imageAsset != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          child: Image.asset(
                            topic.imageAsset!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(icon, size: 36, color: iconColor),
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
                          color: textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSizes.s4),
                      Row(
                        children: [
                          Icon(Icons.play_circle_outline,
                              size: 16, color: textSecondary),
                          const SizedBox(width: AppSizes.s4),
                          Text(
                            '$totalLessons ${totalLessons == 1 ? 'lesson' : 'lessons'}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: textSecondary),
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
                    color: iconColor.withValues(alpha: 0.15),
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
              style: AppTextStyles.bodySmall.copyWith(color: textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Learning Competency
            if (competency != null) ...[
              const SizedBox(height: AppSizes.s12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.s12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  border: Border(
                    left: BorderSide(color: iconColor, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Competency',
                      style: AppTextStyles.caption.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s4),
                    Text(
                      competency,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSizes.s12),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress',
                        style: AppTextStyles.caption
                            .copyWith(color: textSecondary)),
                    Text(
                      '$completedLessons of $totalLessons completed',
                      style: AppTextStyles.caption.copyWith(color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    minHeight: 8,
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