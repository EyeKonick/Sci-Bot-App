import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../features/topics/data/repositories/topic_repository.dart';
import '../../../features/lessons/data/repositories/lesson_repository.dart';
import '../../../features/lessons/data/repositories/progress_repository.dart';
import '../../../features/lessons/data/repositories/bookmark_repository.dart';
import '../../../shared/models/models.dart';
import 'widgets/greeting_header.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/topic_card.dart';
import 'widgets/quick_stats_card.dart';
import 'widgets/inline_search_suggestions.dart';
import 'widgets/streak_tracker_card.dart';
import 'widgets/daily_tip_card.dart';
import '../../../services/storage/hive_service.dart';
import '../../../services/data/data_seeder_service.dart';
import '../../chat/presentation/widgets/floating_chat_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _topicRepo = TopicRepository();
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();
  final _bookmarkRepo = BookmarkRepository();
  
  // Search functionality
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchActive = false;
  List<LessonModel> _searchSuggestions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    
    if (query.length >= 3) {
      // Perform search
      setState(() {
        _isSearchActive = true;
        _searchSuggestions = _searchLessons(query);
      });
    } else {
      // Clear suggestions
      setState(() {
        _searchSuggestions = [];
        if (query.isEmpty) {
          _isSearchActive = false;
        }
      });
    }
  }

  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() {
        _isSearchActive = false;
      });
    }
  }

  List<LessonModel> _searchLessons(String query) {
    final allLessons = _lessonRepo.getAllLessons();
    final lowerQuery = query.toLowerCase();
    final results = <LessonModel>[];

    for (final lesson in allLessons) {
      // Check title match
      if (lesson.title.toLowerCase().contains(lowerQuery)) {
        results.add(lesson);
      }
      // Check description match
      else if (lesson.description.toLowerCase().contains(lowerQuery)) {
        results.add(lesson);
      }
    }

    // Return top 3 results
    return results.take(3).toList();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchSuggestions = [];
      _isSearchActive = false;
    });
    _searchFocusNode.unfocus();
  }

  void _onSuggestionTap(LessonModel lesson) {
    // Clear search
    _clearSearch();
    
    // Navigate to lesson
    final startIndex = _getStartingModuleIndex(lesson.id);
    context.push('/lessons/${lesson.id}/module/$startIndex');
  }

  int _getStartingModuleIndex(String lessonId) {
    final progress = _progressRepo.getProgress(lessonId);
    if (progress == null || progress.isCompleted) {
      return 0;
    }
    
    // Find first incomplete module
    // Simplified - in real implementation would check actual modules
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Get real data from Hive
    final topics = _topicRepo.getAllTopics();
    final completedLessonsCount = _progressRepo.getCompletedLessonsCount();
    
    return GestureDetector(
      onTap: () {
        // Dismiss search when tapping outside
        if (_isSearchActive) {
          _clearSearch();
        }
      },
      child: Stack(
        children: [
          Scaffold(
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
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, 0),
              child: Column(
                children: [
                  // Search Bar
                  SearchBarWidget(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    readOnly: false,
                    onChanged: (_) {}, // Handled by controller listener
                    onClear: _clearSearch,
                  ),
                  
                  // Inline Search Suggestions
                  if (_isSearchActive && _searchController.text.length >= 3)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.s8),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: InlineSearchSuggestions(
                          suggestions: _searchSuggestions,
                          query: _searchController.text,
                          onTap: _onSuggestionTap,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: AppSizes.s20),
                ],
              ),
            ),
          ),

          // Quick Stats (progress circle only)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s16),
              child: QuickStatsCard(
                lessonsCompleted: completedLessonsCount,
                totalLessons: _lessonRepo.getLessonsCount(),
                currentStreak: 0, // TODO: Calculate streak
              ),
            ),
          ),

          // Streak Tracker Card (Separate)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s16),
              child: StreakTrackerCard(
                currentStreak: 0, // TODO: Calculate real streak
                last7Days: const [false, false, false, false, false, false, false],
              ),
            ),
          ),

          // Daily Science Tip Card
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s16),
              child: DailyTipCard(),
            ),
          ),

          // My Bookmarks Quick Access
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, 0, AppSizes.s20, AppSizes.s24),
              child: Card(
                elevation: AppSizes.cardElevation,
                color: AppColors.surface,
                child: InkWell(
                  onTap: () => context.push('/bookmarks'),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.s16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          ),
                          child: const Icon(
                            Icons.bookmark,
                            color: AppColors.warning,
                            size: AppSizes.iconM,
                          ),
                        ),
                        const SizedBox(width: AppSizes.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Bookmarks',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSizes.s4),
                              Text(
                                '${_bookmarkRepo.getBookmarksCount()} saved lessons',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.grey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.grey600,
                        ),
                      ],
                    ),
                  ),
                ),
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
                  
                  // Gradient colors per topic (NEW)
                  List<Color> gradientColors;
                  if (topic.id == 'topic_body_systems') {
                    // Circulation: Pink gradient
                    gradientColors = [const Color(0xFFE91E63), const Color(0xFFF06292)];
                  } else if (topic.id == 'topic_heredity') {
                    // Heredity: Purple gradient
                    gradientColors = [const Color(0xFF9C27B0), const Color(0xFFBA68C8)];
                  } else if (topic.id == 'topic_energy') {
                    // Energy: Green gradient
                    gradientColors = [const Color(0xFF4CAF50), const Color(0xFF81C784)];
                  } else {
                    // Default gradient
                    gradientColors = [const Color(0xFF4DB8C4), const Color(0xFF7BC9A4)];
                  }
                  
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < topics.length - 1 ? AppSizes.s16 : 0,
                    ),
                    child: TopicCard(
                      title: topic.name,
                      description: topic.description,
                      icon: Icons.school,
                      imageAsset: topic.imageAsset,
                      iconColor: _parseColor(topic.colorHex),
                      gradientColors: gradientColors, // NEW: Pass gradient
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
          ), // Close Scaffold
          
          // Floating Aristotle Button
          const FloatingChatButton(),
        ], // Close Stack children
      ), // Close Stack
      ); // Close GestureDetector
    
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