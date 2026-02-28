import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/module_type.dart';
import '../../topics/data/repositories/topic_repository.dart';
import '../data/repositories/lesson_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../../chat/data/providers/character_provider.dart';
import '../../chat/data/repositories/chat_repository.dart';
import '../../chat/data/services/expert_greeting_service.dart';
import '../../../shared/models/scenario_model.dart';
import '../../../shared/models/ai_character_model.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/neumorphic_styles.dart';

/// Lesson List Screen - Shows all lessons for a selected topic
/// Week 2 Day 3 Implementation + Week 3 Day 3 Character Integration
class LessonsScreen extends ConsumerStatefulWidget {
  final String topicId;

  const LessonsScreen({
    super.key,
    required this.topicId,
  });

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
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

    // Update navigation context and activate expert scenario when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(characterContextManagerProvider).navigateToTopic(widget.topicId);
      _activateExpertScenario();
    });
  }

  /// Activate the expert's lessonMenu scenario for this topic.
  /// The expert character greets the student via chathead bubbles.
  Future<void> _activateExpertScenario() async {
    final expert = AiCharacter.getCharacterForTopic(widget.topicId);
    final scenario = ChatScenario.expertLessonMenu(
      expertId: expert.id,
      topicId: widget.topicId,
    );

    // Invalidate cached greeting so a fresh one is generated every visit
    ExpertGreetingService().invalidateScenario(scenario.id);

    // Set scenario in provider for FloatingChatButton awareness
    ref.read(currentScenarioProvider.notifier).state = scenario;

    // Activate scenario in repository (creates history + greeting if new)
    await ChatRepository().setScenario(scenario);
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Topic Info
          _buildAppBar(),

          // Loading State - Phase 8: Skeleton cards instead of bare spinner
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.all(AppSizes.s20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSizes.s16),
                    child: SkeletonLessonCard(),
                  ),
                  childCount: 3,
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
    ); // Scaffold
  }

  /// Learning competencies mapped by topic ID
  static const Map<String, String> _learningCompetencies = {
    'topic_body_systems': 'Explain how the respiratory and circulatory systems work together to transport nutrients, gases and other molecules to and from the different parts of the body (S9LT-la-b-26)',
    'topic_heredity': 'Explain the different patterns of non-Mendelian inheritance (S9LT-Id-29)',
    'topic_energy': 'Differentiate basic features and importance of photosynthesis and respiration (S9LT-lg-j-31)',
  };

  /// App Bar with gradient and topic info - FIXED LAYOUT
  Widget _buildAppBar() {
    // Per-topic-ID colors — must match home screen gradient starts exactly
    Color topicHeaderColor() {
      switch (widget.topicId) {
        case 'topic_body_systems': return const Color(0xFFD4907A); // warm peach
        case 'topic_heredity':     return const Color(0xFF6B8FA0); // muted steel blue
        case 'topic_energy':       return const Color(0xFF7BA08A); // sage green
        default:                   return AppColors.primary;
      }
    }
    final topicColor = topicHeaderColor();
    final competency = _learningCompetencies[widget.topicId];

    return SliverAppBar(
      expandedHeight: competency != null ? 185 : 140,
      floating: false,
      pinned: true,
      backgroundColor: topicColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.white),
        onPressed: () {
          // Clear expert scenario when leaving lesson menu
          final character = ref.read(activeCharacterProvider);
          final scenarioId = '${character.id}_lesson_menu_${widget.topicId}';
          ChatRepository().clearScenario(scenarioId);
          ref.read(currentScenarioProvider.notifier).state = null;
          context.pop();
        },
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
                topicColor.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.s16,
                AppSizes.s40, // Below back button
                AppSizes.s16,
                AppSizes.s12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Topic Name
                  Text(
                    _topic?.name ?? 'Lessons',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Learning Competency
                  if (competency != null) ...[
                    const SizedBox(height: AppSizes.s8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.s12,
                        vertical: AppSizes.s8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        border: Border(
                          left: BorderSide(
                            color: AppColors.white.withValues(alpha: 0.8),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Learning Competency',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: AppSizes.s4),
                          Text(
                            competency,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.white.withValues(alpha: 0.95),
                              height: 1.3,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                progressRepo: _progressRepo,
                lessonIconAsset: _getLessonIconAsset(widget.topicId, index + 1),
                onTap: () async {
                  // Resume from last incomplete module or start from beginning
                  final startIndex = _getStartingModuleIndex(lesson);

                  // Update navigation context before navigating
                  ref.read(characterContextManagerProvider).navigateToLesson(
                    topicId: widget.topicId,
                    lessonId: lesson.id,
                  );

                  await context.push('/lessons/${lesson.id}/module/$startIndex');
                  // Reset to topic context when returning from module
                  if (mounted) {
                    ref.read(characterContextManagerProvider).navigateToTopic(widget.topicId);
                  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              'Topic Not Found',
              style: AppTextStyles.headingSmall.copyWith(
                color: secondaryText,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              'The topic you\'re looking for doesn\'t exist',
              style: AppTextStyles.bodySmall.copyWith(
                color: secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s24),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Topics'),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty State - Phase 4: Forward action added
  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              'No Lessons Yet',
              style: AppTextStyles.headingSmall.copyWith(
                color: secondaryText,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              'Lessons for this topic are coming soon! Explore other topics in the meantime.',
              style: AppTextStyles.bodySmall.copyWith(
                color: secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s24),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Other Topics'),
            ),
          ],
        ),
      ),
    );
  }

  /// Get lesson icon asset path based on topic and lesson number
  String? _getLessonIconAsset(String topicId, int lessonNumber) {
    final topicNumber = switch (topicId) {
      'topic_body_systems' => 1,
      'topic_heredity' => 2,
      'topic_energy' => 3,
      _ => null,
    };
    if (topicNumber == null) return null;
    return 'assets/icons/lessons-icons/topic$topicNumber-lesson$lessonNumber-icon.png';
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
  final ProgressRepository progressRepo;
  final VoidCallback onTap;
  final String? lessonIconAsset;

  const _LessonCard({
    required this.lesson,
    required this.lessonNumber,
    required this.isCompleted,
    required this.progress,
    required this.topicColor,
    required this.progressRepo,
    required this.onTap,
    this.lessonIconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final trackColor = isDark ? AppColors.darkBorder : AppColors.border;

    BoxDecoration cardDecoration = NeumorphicStyles.raised(context);
    if (isCompleted) {
      cardDecoration = cardDecoration.copyWith(
        border: Border.all(color: AppColors.success, width: 2),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: cardDecoration,
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Lesson Icon / Number Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success
                        : topicColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                    child: isCompleted
                        ? const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: AppColors.white,
                              size: 28,
                            ),
                          )
                        : lessonIconAsset != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                                child: Image.asset(
                                  lessonIconAsset!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Text(
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
                              color: textSecondary,
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Text(
                              '${lesson.estimatedMinutes} min',
                              style: AppTextStyles.caption.copyWith(
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppSizes.s12),
                            Icon(
                              Icons.list_alt,
                              size: 14,
                              color: textSecondary,
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Text(
                              '${lesson.modules.length} modules',
                              style: AppTextStyles.caption.copyWith(
                                color: textSecondary,
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
                  color: textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSizes.s12),

              // Module Type Indicators (6 icons with completion status)
              Row(
                children: [
                  Text(
                    'Modules:',
                    style: AppTextStyles.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: Wrap(
                      spacing: AppSizes.s8,
                      children: lesson.modules.asMap().entries.map((entry) {
                        final module = entry.value;
                        final isModuleCompleted = _isModuleCompleted(lesson.id, module.id);
                        return _buildModuleIndicator(
                          module.type, 
                          topicColor,
                          isModuleCompleted,
                        );
                      }).toList(),
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
                          color: textSecondary,
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
                      backgroundColor: trackColor,
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
    );
  }

  /// Build module type indicator icon with completion status
  Widget _buildModuleIndicator(ModuleType moduleType, Color baseColor, bool isCompleted) {
    // Module type colors
    Color getModuleColor() {
      switch (moduleType) {
        case ModuleType.pre_scintation:
          return AppColors.info;
        case ModuleType.fa_scinate:
          return AppColors.secondary;
        case ModuleType.inve_scitigation:
          return AppColors.warning;
        case ModuleType.goal_scitting:
          return AppColors.success;
        case ModuleType.self_a_scissment:
          return AppColors.error;
        case ModuleType.scipplementary:
          return AppColors.primary;
      }
    }

    // Asset image path for each module type
    String getModuleAssetPath() {
      switch (moduleType) {
        case ModuleType.pre_scintation:
          return 'assets/icons/modules-icons/PreSCIntation-icon.png';
        case ModuleType.fa_scinate:
          return 'assets/icons/modules-icons/faSCInate-icon.png';
        case ModuleType.inve_scitigation:
          return 'assets/icons/modules-icons/InveSCItigation-icon.png';
        case ModuleType.goal_scitting:
          return 'assets/icons/modules-icons/GoalSCItting-Icon.png';
        case ModuleType.self_a_scissment:
          return 'assets/icons/modules-icons/SelfASCIssment-icon.png';
        case ModuleType.scipplementary:
          return 'assets/icons/modules-icons/SCIpplumentary-icon.png';
      }
    }

    final moduleColor = getModuleColor();
    final assetPath = getModuleAssetPath();

    return Stack(
      children: [
        // Main container with colored background and icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted 
                ? AppColors.success.withValues(alpha: 0.15)
                : moduleColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? AppColors.success : moduleColor,
              width: 2,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              assetPath,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.circle,
                  size: 16,
                  color: moduleColor,
                );
              },
            ),
          ),
        ),
        
        // Completion checkmark overlay
        if (isCompleted)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  /// Check if a specific module is completed
  bool _isModuleCompleted(String lessonId, String moduleId) {
    final progress = progressRepo.getProgress(lessonId);
    if (progress == null) return false;
    return progress.isModuleCompleted(moduleId);
  }
}