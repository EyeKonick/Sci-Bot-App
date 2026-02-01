import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/bookmark_repository.dart';
import '../data/repositories/lesson_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../../topics/data/repositories/topic_repository.dart';

/// Bookmarks Screen - Shows all bookmarked lessons
/// Week 2 Day 6 Implementation
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _bookmarkRepo = BookmarkRepository();
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();
  final _topicRepo = TopicRepository();

  @override
  Widget build(BuildContext context) {
    final bookmarks = _bookmarkRepo.getAllBookmarks();

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
                'My Bookmarks',
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
          if (bookmarks.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            ),

          // Bookmarks Count Header
          if (bookmarks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.s16,
                  AppSizes.s20,
                  AppSizes.s16,
                  AppSizes.s12,
                ),
                child: Text(
                  '${bookmarks.length} ${bookmarks.length == 1 ? 'Bookmark' : 'Bookmarks'}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Bookmarks List
          if (bookmarks.isNotEmpty)
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
                    final bookmark = bookmarks[index];
                    final lesson = _lessonRepo.getLessonById(bookmark.lessonId);
                    
                    if (lesson == null) {
                      // Lesson not found, remove bookmark
                      _bookmarkRepo.removeBookmark(bookmark.lessonId);
                      return const SizedBox.shrink();
                    }

                    final topic = _topicRepo.getTopicById(bookmark.topicId);
                    final progress = _progressRepo.getCompletionPercentage(lesson.id);
                    final isCompleted = _progressRepo.isLessonCompleted(lesson.id);

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < bookmarks.length - 1 ? AppSizes.s16 : 0,
                      ),
                      child: _BookmarkedLessonCard(
                        lesson: lesson,
                        topicName: topic?.name ?? 'Unknown Topic',
                        topicColor: topic != null ? _parseColor(topic.colorHex) : AppColors.primary,
                        progress: progress,
                        isCompleted: isCompleted,
                        bookmarkedAt: bookmark.bookmarkedAt,
                        onTap: () {
                          // Calculate starting module for resume
                          final startIndex = _getStartingModuleIndex(lesson);
                          context.push('/lessons/${lesson.id}/module/$startIndex');
                        },
                        onRemove: () async {
                          await _bookmarkRepo.removeBookmark(lesson.id);
                          setState(() {}); // Refresh list
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Bookmark removed',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.white,
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: AppColors.grey900,
                                action: SnackBarAction(
                                  label: 'Undo',
                                  textColor: AppColors.primary,
                                  onPressed: () async {
                                    await _bookmarkRepo.addBookmark(
                                      lessonId: lesson.id,
                                      topicId: bookmark.topicId,
                                    );
                                    setState(() {});
                                  },
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  childCount: bookmarks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Empty state when no bookmarks
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: AppSizes.iconXL * 2,
              color: AppColors.grey300,
            ),
            const SizedBox(height: AppSizes.s24),
            Text(
              'No Bookmarks Yet',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              'Bookmark lessons to save them for later.\nTap the bookmark icon while viewing a lesson.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s32),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.explore),
              label: Text(
                'Explore Lessons',
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

  /// Calculate starting module index (same logic as lessons screen)
  int _getStartingModuleIndex(LessonModel lesson) {
    final progress = _progressRepo.getProgress(lesson.id);
    
    if (progress == null || progress.isCompleted) {
      return 0;
    }
    
    for (int i = 0; i < lesson.modules.length; i++) {
      if (!progress.isModuleCompleted(lesson.modules[i].id)) {
        return i;
      }
    }
    
    return 0;
  }
}

/// Bookmarked Lesson Card Widget
class _BookmarkedLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final String topicName;
  final Color topicColor;
  final double progress;
  final bool isCompleted;
  final DateTime bookmarkedAt;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BookmarkedLessonCard({
    required this.lesson,
    required this.topicName,
    required this.topicColor,
    required this.progress,
    required this.isCompleted,
    required this.bookmarkedAt,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final daysSince = DateTime.now().difference(bookmarkedAt).inDays;
    final bookmarkedText = daysSince == 0
        ? 'Today'
        : daysSince == 1
            ? 'Yesterday'
            : '$daysSince days ago';

    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
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
              // Header Row
              Row(
                children: [
                  // Topic Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s12,
                      vertical: AppSizes.s4,
                    ),
                    decoration: BoxDecoration(
                      color: topicColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
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
                  
                  // Remove Bookmark Button
                  IconButton(
                    icon: const Icon(Icons.bookmark, color: AppColors.warning),
                    iconSize: AppSizes.iconM,
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.s12),

              // Lesson Title
              Text(
                lesson.title,
                style: AppTextStyles.lessonCardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSizes.s8),

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

              // Info Row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: AppSizes.iconXS,
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
                    size: AppSizes.iconXS,
                    color: AppColors.grey600,
                  ),
                  const SizedBox(width: AppSizes.s4),
                  Text(
                    '${lesson.modules.length} modules',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.bookmark,
                    size: AppSizes.iconXS,
                    color: AppColors.grey600,
                  ),
                  const SizedBox(width: AppSizes.s4),
                  Text(
                    bookmarkedText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey600,
                    ),
                  ),
                ],
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