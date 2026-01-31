import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/models.dart';
import '../../topics/data/repositories/topic_repository.dart';
import '../data/repositories/lesson_repository.dart';
import '../data/repositories/progress_repository.dart';

/// Lesson List Screen - Shows all lessons for a selected topic
/// Week 2 Day 3 Implementation
class LessonsScreen extends StatefulWidget {
  final String topicId;

  const LessonsScreen({
    super.key,
    required this.topicId,
  });

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final _topicRepo = TopicRepository();
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();
  
  bool _isLoading = true;
  TopicModel? _topic;
  List<LessonModel> _lessons = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load topic
    _topic = _topicRepo.getTopicById(widget.topicId);

    // Load lessons for this topic
    if (_topic != null) {
      _lessons = _topic!.lessonIds
          .map((id) => _lessonRepo.getLessonById(id))
          .whereType<LessonModel>()
          .toList();
    }

    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          // App Bar with Topic Info
          _buildAppBar(),

          // Loading State
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),

          // Error State (Topic not found)
          if (!_isLoading && _topic == null)
            SliverFillRemaining(
              child: _buildErrorState(),
            ),

          // Empty State (No lessons)
          if (!_isLoading && _topic != null && _lessons.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            ),

          // Lessons List
          if (!_isLoading && _topic != null && _lessons.isNotEmpty)
            _buildLessonsList(),
        ],
      ),
    );
  }

  /// App Bar with gradient and topic info - FIXED LAYOUT
  Widget _buildAppBar() {
    final topicColor = _topic != null 
        ? _parseColor(_topic!.colorHex) 
        : AppColors.primary;

    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: topicColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        // Centered title for collapsed state
        centerTitle: false,
        title: null, // Remove title to prevent overlap
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                topicColor,
                topicColor.withOpacity(0.9),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.s20,
                AppSizes.s64, // Below back button
                AppSizes.s20,
                AppSizes.s16,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic Name
                  Text(
                    _topic?.name ?? 'Lessons',
                    style: AppTextStyles.headingMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.s8),
                  
                  // Topic Description
                  Text(
                    _topic?.description ?? '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.white.withOpacity(0.95),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.s8),
                  
                  // Lesson Count
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 16,
                        color: AppColors.white.withOpacity(0.95),
                      ),
                      const SizedBox(width: AppSizes.s4),
                      Text(
                        '${_lessons.length} ${_lessons.length == 1 ? 'lesson' : 'lessons'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lessons List
  Widget _buildLessonsList() {
    return SliverPadding(
      padding: const EdgeInsets.all(AppSizes.s20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final lesson = _lessons[index];
            final isCompleted = _progressRepo.isLessonCompleted(lesson.id);
            
            // Get actual progress percentage from repository
            final progress = _progressRepo.getCompletionPercentage(lesson.id);

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _lessons.length - 1 ? AppSizes.s16 : 0,
              ),
              child: _LessonCard(
                lesson: lesson,
                lessonNumber: index + 1,
                isCompleted: isCompleted,
                progress: progress,
                topicColor: _parseColor(_topic!.colorHex),
                onTap: () {
                  // Resume from last incomplete module or start from beginning
                  final startIndex = _getStartingModuleIndex(lesson);
                  context.push('/lessons/${lesson.id}/module/$startIndex');
                },
              ),
            );
          },
          childCount: _lessons.length,
        ),
      ),
    );
  }

  /// Error State
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.grey300,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              'Topic Not Found',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              'The topic you\'re looking for doesn\'t exist',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s24),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Topics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
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
              'No Lessons Yet',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              'Lessons for this topic are coming soon!',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Parse hex color
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

  /// Calculate which module index to start from based on progress
  /// Returns 0 for new lessons or completed lessons (restart)
  /// Returns index of first incomplete module for in-progress lessons
  int _getStartingModuleIndex(LessonModel lesson) {
    final progress = _progressRepo.getProgress(lesson.id);
    
    // If no progress or lesson is completed, start from beginning
    if (progress == null || progress.isCompleted) {
      return 0;
    }
    
    // Find first incomplete module
    for (int i = 0; i < lesson.modules.length; i++) {
      if (!progress.isModuleCompleted(lesson.modules[i].id)) {
        return i;
      }
    }
    
    // Fallback to first module (shouldn't happen)
    return 0;
  }
}

/// Lesson Card Widget
class _LessonCard extends StatelessWidget {
  final LessonModel lesson;
  final int lessonNumber;
  final bool isCompleted;
  final double progress; // 0.0 to 1.0
  final Color topicColor;
  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.lessonNumber,
    required this.isCompleted,
    required this.progress,
    required this.topicColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        side: isCompleted
            ? BorderSide(color: AppColors.success, width: 2)
            : BorderSide.none,
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
                  // Lesson Number Badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success
                          : topicColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.white,
                              size: 28,
                            )
                          : Text(
                              '$lessonNumber',
                              style: AppTextStyles.headingSmall.copyWith(
                                color: topicColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.s12),

                  // Title and Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSizes.s4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppColors.grey600,
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Text(
                              '${lesson.estimatedMinutes} min',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.grey600,
                              ),
                            ),
                            const SizedBox(width: AppSizes.s12),
                            Icon(
                              Icons.list_alt,
                              size: 14,
                              color: AppColors.grey600,
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Text(
                              '${lesson.modules.length} modules',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status Icon
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.play_circle_outline,
                    color: isCompleted ? AppColors.success : topicColor,
                    size: 28,
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.s12),

              // Description
              Text(
                lesson.description,
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
                        '${(progress * 100).toInt()}%',
                        style: AppTextStyles.caption.copyWith(
                          color: topicColor,
                          fontWeight: FontWeight.w600,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted ? AppColors.success : topicColor,
                      ),
                      minHeight: 6,
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