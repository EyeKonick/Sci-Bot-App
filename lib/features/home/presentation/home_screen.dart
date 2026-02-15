import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_feedback.dart';
import '../../../shared/widgets/feedback_toast.dart';
import '../../../features/topics/data/repositories/topic_repository.dart';
import '../../../features/lessons/data/repositories/lesson_repository.dart';
import '../../../features/lessons/data/repositories/progress_repository.dart';
import '../../../features/lessons/data/repositories/bookmark_repository.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/scenario_model.dart';
import '../../../shared/models/ai_character_model.dart';
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
import '../../chat/data/providers/character_provider.dart';
import '../../chat/data/repositories/chat_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _topicRepo = TopicRepository();
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();
  final _bookmarkRepo = BookmarkRepository();
  
  // Search functionality
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchActive = false;
  List<LessonModel> _searchSuggestions = [];
  Timer? _searchDebounce; // Phase 0: Debounce search to prevent UI blocking

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    
    // Update navigation context to home and activate aristotle_general scenario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(characterContextManagerProvider).navigateToHome();
      final scenario = ChatScenario.aristotleGeneral();
      ref.read(characterContextManagerProvider).setScenario(scenario);
      ChatRepository().setScenario(scenario);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Phase 0: Debounced search - waits 300ms after last keystroke before searching
  void _onSearchChanged() {
    _searchDebounce?.cancel();

    final query = _searchController.text;

    if (query.length < 3) {
      // Clear suggestions immediately (no debounce needed for clearing)
      setState(() {
        _searchSuggestions = [];
        if (query.isEmpty) {
          _isSearchActive = false;
        }
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isSearchActive = true;
        _searchSuggestions = _searchLessons(query);
      });
    });
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

  void _onSuggestionTap(LessonModel lesson) async {
    // Clear search
    _clearSearch();

    // Navigate to lesson
    final startIndex = _getStartingModuleIndex(lesson.id);
    await context.push('/lessons/${lesson.id}/module/$startIndex');
    // Reset character to Aristotle when returning
    if (mounted) {
      ref.read(characterContextManagerProvider).navigateToHome();
    }
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
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmation();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: GestureDetector(
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
            child: GreetingHeader(),
          ),

          

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.s20, AppSizes.s12, AppSizes.s20, 0),
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
         const SliverToBoxAdapter(
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
                    onPressed: () async {
                      // Navigate to Topics screen
                      await context.push('/topics');
                      // Reset character to Aristotle when returning
                      if (mounted) {
                        ref.read(characterContextManagerProvider).navigateToHome();
                      }
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
                      onTap: () async {
                        // Navigate to topic lessons
                        await context.push('/topics/${topic.id}/lessons');
                        // Reset character to Aristotle when returning
                        if (mounted) {
                          ref.read(characterContextManagerProvider).navigateToHome();
                        }
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
        ], // Close Stack children
      ), // Close Stack
      ), // Close GestureDetector
    ); // Close PopScope
  }

  /// Show exit confirmation dialog with Aristotle's personality
  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Image.asset(
                AiCharacter.aristotle.avatarAsset,
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Text(
              'Exit SCI-Bot?',
              style: AppTextStyles.headingSmall,
            ),
          ],
        ),
        content: Text(
          "Leaving so soon? Your learning journey awaits! "
          "I'll be here when you return, my friend.",
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.grey600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Stay',
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Exit App',
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
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
                FeedbackToast.showSnackBar(
                  context,
                  type: FeedbackType.warning,
                  message: 'Data cleared! Restart app to reseed.',
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