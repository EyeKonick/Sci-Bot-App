import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/lesson_model.dart';
import '../../../shared/models/progress_model.dart';
import '../../lessons/data/repositories/lesson_repository.dart';
import '../../lessons/data/repositories/progress_repository.dart';
import '../../topics/data/repositories/topic_repository.dart';

/// Learning History Screen - Shows lessons accessed sorted by recency
class LearningHistoryScreen extends StatefulWidget {
  const LearningHistoryScreen({super.key});

  @override
  State<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends State<LearningHistoryScreen> {
  final _progressRepo = ProgressRepository();
  final _lessonRepo = LessonRepository();
  final _topicRepo = TopicRepository();

  @override
  Widget build(BuildContext context) {
    final allProgress = _progressRepo.getAllProgress()
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

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
                'Learning History',
                style: AppTextStyles.appBarTitle,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // Empty State
          if (allProgress.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            ),

          // Count Header
          if (allProgress.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.s16,
                  AppSizes.s20,
                  AppSizes.s16,
                  AppSizes.s12,
                ),
                child: Text(
                  '${allProgress.length} ${allProgress.length == 1 ? 'lesson' : 'lessons'} accessed',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // History List
          if (allProgress.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.s16,
                0,
                AppSizes.s16,
                AppSizes.s64,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final progress = allProgress[index];
                    final lesson =
                        _lessonRepo.getLessonById(progress.lessonId);

                    if (lesson == null) return const SizedBox.shrink();

                    final topic = _topicRepo.getTopicById(lesson.topicId);

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            index < allProgress.length - 1 ? AppSizes.s12 : 0,
                      ),
                      child: _HistoryLessonCard(
                        lesson: lesson,
                        progress: progress,
                        topicName: topic?.name ?? 'Unknown Topic',
                        topicColor: topic != null
                            ? _parseColor(topic.colorHex)
                            : AppColors.primary,
                        onTap: () {
                          final startIndex =
                              _getStartingModuleIndex(lesson, progress);
                          context.push(
                              '/lessons/${lesson.id}/module/$startIndex');
                        },
                      ),
                    );
                  },
                  childCount: allProgress.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: AppSizes.iconXL * 2,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            const SizedBox(height: AppSizes.s24),
            Text(
              'No Learning History Yet',
              style: AppTextStyles.headingMedium.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              'Start a lesson to track your learning journey.\nYour progress will appear here.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s32),
            ElevatedButton.icon(
              onPressed: () => context.push('/topics'),
              icon: const Icon(Icons.explore),
              label: Text(
                'Explore Topics',
                style: AppTextStyles.buttonLabel,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s24,
                  vertical: AppSizes.s16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  int _getStartingModuleIndex(LessonModel lesson, ProgressModel progress) {
    if (progress.isCompleted) return 0;

    for (int i = 0; i < lesson.modules.length; i++) {
      if (!progress.isModuleCompleted(lesson.modules[i].id)) {
        return i;
      }
    }

    return 0;
  }
}

/// Format relative time for last accessed
String _formatLastAccessed(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  if (diff.inDays < 30) {
    final weeks = (diff.inDays / 7).floor();
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  final months = (diff.inDays / 30).floor();
  return months == 1 ? '1 month ago' : '$months months ago';
}

/// History Lesson Card
class _HistoryLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final ProgressModel progress;
  final String topicName;
  final Color topicColor;
  final VoidCallback onTap;

  const _HistoryLessonCard({
    required this.lesson,
    required this.progress,
    required this.topicName,
    required this.topicColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = progress.isCompleted;
    final completionPct = progress.completionPercentage;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: AppSizes.cardElevation,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: isCompleted
            ? const BorderSide(color: AppColors.success, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Topic Badge + Last Accessed
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s12,
                      vertical: AppSizes.s4,
                    ),
                    decoration: BoxDecoration(
                      color: topicColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      topicName,
                      style: AppTextStyles.caption.copyWith(
                        color: topicColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: AppSizes.iconXS,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSizes.s4),
                  Text(
                    _formatLastAccessed(progress.lastAccessed),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.s12),

              // Lesson Title
              Text(
                lesson.title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSizes.s8),

              // Info Row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: AppSizes.iconXS,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSizes.s4),
                  Text(
                    '${lesson.estimatedMinutes} min',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Icon(
                    Icons.list_alt,
                    size: AppSizes.iconXS,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSizes.s4),
                  Text(
                    '${progress.completedModuleIds.length}/${lesson.modules.length} modules',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.s8,
                        vertical: AppSizes.s4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSizes.s4),
                          Text(
                            'Completed',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: AppSizes.s12),

              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(completionPct * 100).toInt()}%',
                    style: AppTextStyles.caption.copyWith(
                      color: isCompleted ? AppColors.success : topicColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: LinearProgressIndicator(
                  value: completionPct.clamp(0.0, 1.0),
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? AppColors.success : topicColor,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
