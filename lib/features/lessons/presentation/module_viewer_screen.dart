import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_feedback.dart';
import '../../../shared/widgets/feedback_toast.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/ai_character_model.dart';
import '../data/repositories/lesson_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/bookmark_repository.dart';
import '../../topics/data/repositories/topic_repository.dart';
import '../../chat/data/providers/character_provider.dart';
import '../../../shared/models/scenario_model.dart';
import '../../chat/data/repositories/chat_repository.dart';
import '../../chat/presentation/widgets/typing_indicator.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../data/providers/guided_lesson_provider.dart';
import '../data/providers/lesson_chat_provider.dart';
import '../presentation/widgets/chat_image_message.dart';
import '../../../shared/widgets/image_modal.dart';

/// Module Viewer Screen - AI-Guided Learning
/// Replaces static text with chatbot-guided two-phase learning flow
/// Phase 1: Learning (AI teaches) → Phase 2: Asking (student questions)
/// Falls back to static markdown when offline
class ModuleViewerScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final int moduleIndex;

  const ModuleViewerScreen({
    super.key,
    required this.lessonId,
    this.moduleIndex = 0,
  });

  @override
  ConsumerState<ModuleViewerScreen> createState() => _ModuleViewerScreenState();
}

class _ModuleViewerScreenState extends ConsumerState<ModuleViewerScreen>
    with TickerProviderStateMixin {
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();
  final _bookmarkRepo = BookmarkRepository();
  final _chatRepo = ChatRepository();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  // Phase 2: Input pulse animation when input becomes available
  late AnimationController _inputPulseController;
  late Animation<double> _inputPulseAnimation;
  bool _wasWaitingForUser = false;

  // Phase 3: Next button success pulse when module completes
  late AnimationController _nextButtonPulseController;
  late Animation<double> _nextButtonPulseAnimation;
  bool _wasModuleComplete = false;

  // Phase 7: Animated progress bar
  late AnimationController _progressBarController;
  late Animation<double> _progressBarAnimation;
  double _animatedProgress = 0.0;

  LessonModel? _lesson;
  late int _currentModuleIndex;
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _currentModuleIndex = widget.moduleIndex;

    // Phase 2: Input pulse animation controller
    _inputPulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _inputPulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _inputPulseController, curve: Curves.easeOut),
    );

    // Phase 3: Next button success pulse controller
    _nextButtonPulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _nextButtonPulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _nextButtonPulseController, curve: Curves.easeOut),
    );

    // Phase 7: Progress bar smooth fill animation (300ms)
    _progressBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressBarAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressBarController, curve: Curves.easeOut),
    );

    // ✅ FIX: Clear any previous module state to ensure fresh start
    // Suppress greetings immediately — narrative will start after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bubbleModeProvider.notifier).state = BubbleMode.waitingForNarrative;
      ref.read(lessonChatProvider.notifier).reset();
      ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();
    });

    _loadLesson();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lesson != null) {
        ref.read(characterContextManagerProvider).navigateToModule(
          topicId: _lesson!.topicId,
          lessonId: widget.lessonId,
          moduleIndex: _currentModuleIndex.toString(),
        );

        // Set module scenario to block messenger chat —
        // chat head is narration-only inside modules
        final expert = AiCharacter.getCharacterForTopic(_lesson!.topicId);
        final scenario = ChatScenario.expertModule(
          expertId: expert.id,
          topicId: _lesson!.topicId,
          lessonId: widget.lessonId,
          moduleId: _currentModuleIndex.toString(),
        );
        ref.read(currentScenarioProvider.notifier).state = scenario;
      }
    });
  }

  Future<void> _loadLesson() async {
    setState(() => _isLoading = true);

    _lesson = _lessonRepo.getLessonById(widget.lessonId);

    if (_lesson != null) {
      await _progressRepo.updateLastAccessed(widget.lessonId);
    }

    // Check if AI is available
    _isOffline = !_chatRepo.isConfigured;

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      // Phase 7: Initialize animated progress to current value
      _animatedProgress = _currentProgress;
      _progressBarAnimation = Tween<double>(
        begin: _animatedProgress,
        end: _animatedProgress,
      ).animate(CurvedAnimation(
        parent: _progressBarController,
        curve: Curves.easeOut,
      ));

      setState(() => _isLoading = false);

      // Start guided lesson if online
      if (!_isOffline && _lesson != null && _currentModule != null) {
        _startGuidedModule();
      } else if (_isOffline) {
        ref.read(guidedLessonProvider.notifier).setOfflineMode();
      }
    }
  }

  /// Start the scripted conversation for the current module
  void _startGuidedModule() {
    final module = _currentModule;
    if (module == null || _lesson == null) return;

    final character = ref.read(activeCharacterProvider);

    // Start scripted module flow
    ref.read(lessonChatProvider.notifier).startModule(
      module: module,
      lesson: _lesson!,
      character: character,
    );
  }

  ModuleModel? get _currentModule {
    if (_lesson == null || _currentModuleIndex >= _lesson!.modules.length) {
      return null;
    }
    return _lesson!.modules[_currentModuleIndex];
  }

  bool get _isFirstModule => _currentModuleIndex == 0;
  bool get _isLastModule =>
      _currentModuleIndex == (_lesson?.modules.length ?? 0) - 1;

  double get _currentProgress {
    if (_lesson == null) return 0.0;
    final progress = _progressRepo.getProgress(widget.lessonId);
    return progress?.completionPercentage ?? 0.0;
  }

  bool _isModuleCompleted(String moduleId) {
    final progress = _progressRepo.getProgress(widget.lessonId);
    return progress?.isModuleCompleted(moduleId) ?? false;
  }

  Color _getModuleColor(ModuleModel module) {
    switch (module.type) {
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

  void _goToPreviousModule() {
    if (!_isFirstModule) {
      setState(() {
        _currentModuleIndex--;
      });

      if (_lesson != null) {
        ref.read(characterContextManagerProvider).navigateToModule(
          topicId: _lesson!.topicId,
          lessonId: widget.lessonId,
          moduleIndex: _currentModuleIndex.toString(),
        );
      }

      // Suppress bubbles during module switch, then restart guided lesson
      if (!_isOffline) {
        ref.read(bubbleModeProvider.notifier).state = BubbleMode.waitingForNarrative;
        _startGuidedModule();
      }
    }
  }

  Future<void> _goToNextModule() async {
    if (_currentModule != null) {
      await _progressRepo.markModuleCompleted(
        widget.lessonId,
        _currentModule!.id,
      );

      // Phase 7: Animate progress bar smooth fill
      _animateProgressBar();

      // Phase 3: Show subtle toast for module completion (not last module)
      if (!_isLastModule && mounted) {
        FeedbackToast.show(
          context,
          type: FeedbackType.success,
          message: 'Module ${_currentModuleIndex + 1} complete!',
        );
      }
    }

    if (!_isLastModule) {
      // Reset pulse state for next module
      _wasModuleComplete = false;

      setState(() {
        _currentModuleIndex++;
      });

      if (_lesson != null) {
        ref.read(characterContextManagerProvider).navigateToModule(
          topicId: _lesson!.topicId,
          lessonId: widget.lessonId,
          moduleIndex: _currentModuleIndex.toString(),
        );
      }

      // Suppress bubbles during module switch, then start guided lesson
      if (!_isOffline) {
        ref.read(bubbleModeProvider.notifier).state = BubbleMode.waitingForNarrative;
        _startGuidedModule();
      } else {
        ref.read(guidedLessonProvider.notifier).setOfflineMode();
      }
    } else {
      // Phase 7: Check if all lessons in topic are now complete
      final isTopicComplete = _checkTopicCompletion();
      _showLessonCompleteDialog(topicComplete: isTopicComplete);
    }
  }

  /// Phase 7: Animate progress bar from old value to new value
  void _animateProgressBar() {
    final newProgress = _currentProgress;
    _progressBarAnimation = Tween<double>(
      begin: _animatedProgress,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressBarController,
      curve: Curves.easeOut,
    ));
    _progressBarController.forward(from: 0.0);
    _animatedProgress = newProgress;
  }

  /// Phase 7: Check if all lessons in the current topic are completed
  bool _checkTopicCompletion() {
    if (_lesson == null) return false;
    final topicId = _lesson!.topicId;
    final topicRepo = TopicRepository();
    final topic = topicRepo.getTopicById(topicId);
    if (topic == null) return false;

    // Check if every lesson in this topic is completed
    for (final lessonId in topic.lessonIds) {
      if (!_progressRepo.isLessonCompleted(lessonId)) {
        return false;
      }
    }
    return true;
  }

  /// Send student message during asking phase
  Future<void> _sendStudentMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();

    await ref.read(lessonChatProvider.notifier).sendStudentMessage(text);

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showLessonCompleteDialog({bool topicComplete = false}) {
    final progress = _progressRepo.getProgress(widget.lessonId);
    final completedModules = progress?.completedModuleIds.length ?? 0;
    final totalModules = _lesson?.modules.length ?? 6;

    // Phase 7: Show confetti overlay if topic is complete
    if (topicComplete) {
      _showConfettiCelebration();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: topicComplete
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                topicComplete ? Icons.emoji_events : Icons.celebration,
                color: topicComplete ? AppColors.primary : AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              topicComplete ? 'Topic Mastered!' : 'Lesson Complete!',
              style: AppTextStyles.headingMedium.copyWith(
                color: topicComplete ? AppColors.primary : AppColors.success,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve mastered "${_lesson?.title}"! $completedModules modules completed.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (topicComplete) ...[
              const SizedBox(height: AppSizes.s8),
              Text(
                'All lessons in this topic are complete!',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSizes.s16),
            Container(
              padding: const EdgeInsets.all(AppSizes.s16),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    Icons.check_circle,
                    'Modules Completed',
                    '$completedModules/$totalModules',
                  ),
                  const SizedBox(height: AppSizes.s8),
                  _buildStatRow(
                    Icons.access_time,
                    'Time Invested',
                    '~${_lesson?.estimatedMinutes ?? 0} min',
                  ),
                ],
              ),
            ),
            // Phase 7: Share your progress prompt
            const SizedBox(height: AppSizes.s16),
            _buildShareProgressPrompt(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) context.pop();
            },
            child: Text(
              'Back to Lessons',
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
            child: const Text('Continue Learning'),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppSizes.s16),
      ),
    );
  }

  /// Phase 7: Share progress prompt with achievement preview
  Widget _buildShareProgressPrompt() {
    final completedLessonsCount = _progressRepo.getCompletedLessonsCount();
    final character = ref.read(activeCharacterProvider);

    return InkWell(
      onTap: () {
        // Show preview toast - actual sharing not implemented per scope
        FeedbackToast.show(
          context,
          type: FeedbackType.info,
          message: 'Sharing coming soon!',
        );
      },
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s12),
        decoration: BoxDecoration(
          color: character.themeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(
            color: character.themeColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.share_rounded,
              size: 20,
              color: character.themeColor,
            ),
            const SizedBox(width: AppSizes.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share your progress',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: character.themeColor,
                    ),
                  ),
                  Text(
                    '$completedLessonsCount lesson${completedLessonsCount == 1 ? '' : 's'} mastered in Grade 9 Science',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: character.themeColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 7: Show confetti celebration overlay for topic completion (1 second)
  void _showConfettiCelebration() {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ConfettiOverlay(
        onComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.success),
        const SizedBox(width: AppSizes.s8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Clear all module state when leaving.
    // reset() handles: incrementing requestId (cancels async chains),
    // hiding narrative bubbles, and setting bubble mode back to greeting.
    try {
      ref.read(lessonChatProvider.notifier).reset();
      // Restore lessonMenu scenario so messenger works on lessons screen
      if (_lesson != null) {
        final expert = AiCharacter.getCharacterForTopic(_lesson!.topicId);
        ref.read(currentScenarioProvider.notifier).state = ChatScenario.expertLessonMenu(
          expertId: expert.id,
          topicId: _lesson!.topicId,
        );
      } else {
        ref.read(currentScenarioProvider.notifier).state = null;
      }
    } catch (e) {
      // Ignore error if ref is already invalid during disposal
    }

    _inputPulseController.dispose();
    _nextButtonPulseController.dispose();
    _progressBarController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Show educational exit confirmation dialog with character avatar
  Future<bool> _showLessonExitConfirmation(AiCharacter character) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              backgroundColor: character.themeColor.withValues(alpha: 0.15),
              child: Image.asset(
                character.avatarAsset,
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Text(
              'End the Lesson?',
              style: AppTextStyles.headingSmall,
            ),
          ],
        ),
        content: Text(
          "You're making great progress, ${character.name} is proud! "
          "Are you sure you want to end this lesson now?",
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.s4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text('End Lesson', style: AppTextStyles.buttonLabel)),
                  ),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: character.themeColor,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text('Keep Learning', style: AppTextStyles.buttonLabel)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Phase 8: Contextual loading spinner instead of bare spinner
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        body: const LoadingSpinner(message: 'Loading lesson...'),
      );
    }

    if (_lesson == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: isDark ? AppColors.darkBorder : AppColors.border),
                const SizedBox(height: AppSizes.s16),
                Text(
                  'Lesson Not Found',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.s8),
                Text(
                  'This lesson may have been removed or is temporarily unavailable.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.s24),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Lessons'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final module = _currentModule;
    if (module == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: isDark ? AppColors.darkBorder : AppColors.border),
                const SizedBox(height: AppSizes.s16),
                Text(
                  'Module Not Found',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.s8),
                Text(
                  'This module could not be loaded.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.s24),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Lessons'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final moduleColor = _getModuleColor(module);
    final guidedState = ref.watch(guidedLessonProvider);
    final activeCharacter = ref.watch(activeCharacterProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        debugPrint('🔙 [POPSCOPE] Back button pressed - pausing script');
        // Pause script execution while dialog is showing
        if (mounted) {
          try {
            ref.read(lessonChatProvider.notifier).pause();
            debugPrint('🔙 [POPSCOPE] pause() called successfully');
          } catch (e) {
            debugPrint('🔙 [POPSCOPE] ERROR calling pause(): $e');
          }
        } else {
          debugPrint('🔙 [POPSCOPE] Widget not mounted, skipping pause()');
        }

        debugPrint('🔙 [POPSCOPE] Showing exit confirmation dialog');
        final shouldExit = await _showLessonExitConfirmation(activeCharacter);
        debugPrint('🔙 [POPSCOPE] Dialog result: shouldExit=$shouldExit');

        if (!mounted) {
          debugPrint('🔙 [POPSCOPE] Widget unmounted after dialog, aborting');
          return;
        }

        if (shouldExit) {
          if (!context.mounted) {
            debugPrint('🔙 [POPSCOPE] Context unmounted, aborting navigation');
            return;
          }
          debugPrint('🔙 [POPSCOPE] User chose "End Lesson" - clearing state and popping screen');
          // Restore lessonMenu scenario and reset state BEFORE popping
          try {
            ref.read(lessonChatProvider.notifier).reset();
            if (_lesson != null) {
              final expert = AiCharacter.getCharacterForTopic(_lesson!.topicId);
              ref.read(currentScenarioProvider.notifier).state = ChatScenario.expertLessonMenu(
                expertId: expert.id,
                topicId: _lesson!.topicId,
              );
            } else {
              ref.read(currentScenarioProvider.notifier).state = null;
            }
            debugPrint('🔙 [POPSCOPE] Scenario restored to lessonMenu');
          } catch (e) {
            debugPrint('🔙 [POPSCOPE] ERROR clearing scenario: $e');
          }
          // User confirmed exit - state is already cleared above
          context.pop();
        } else {
          debugPrint('🔙 [POPSCOPE] User chose "Keep Learning" - resuming script');
          // User clicked "Keep Learning" - resume where they left off
          try {
            ref.read(lessonChatProvider.notifier).resume();
            debugPrint('🔙 [POPSCOPE] resume() called successfully');
          } catch (e) {
            debugPrint('🔙 [POPSCOPE] ERROR calling resume(): $e');
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          backgroundColor: moduleColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.white),
            onPressed: () async {
              debugPrint('❌ [CLOSE BUTTON] Pressed - pausing script');
              // Pause script execution while dialog is showing
              if (mounted) {
                try {
                  ref.read(lessonChatProvider.notifier).pause();
                  debugPrint('❌ [CLOSE BUTTON] pause() called successfully');
                } catch (e) {
                  debugPrint('❌ [CLOSE BUTTON] ERROR calling pause(): $e');
                }
              }

              final shouldExit = await _showLessonExitConfirmation(activeCharacter);
              debugPrint('❌ [CLOSE BUTTON] Dialog result: shouldExit=$shouldExit');

              if (!mounted) {
                debugPrint('❌ [CLOSE BUTTON] Widget unmounted after dialog, aborting');
                return;
              }

              if (shouldExit) {
                if (!context.mounted) {
                  debugPrint('❌ [CLOSE BUTTON] Context unmounted, aborting navigation');
                  return;
                }
                debugPrint('❌ [CLOSE BUTTON] User chose "End Lesson" - clearing state and popping');
                // Restore lessonMenu scenario and reset state BEFORE popping
                try {
                  ref.read(lessonChatProvider.notifier).reset();
                  if (_lesson != null) {
                    final expert = AiCharacter.getCharacterForTopic(_lesson!.topicId);
                    ref.read(currentScenarioProvider.notifier).state = ChatScenario.expertLessonMenu(
                      expertId: expert.id,
                      topicId: _lesson!.topicId,
                    );
                  } else {
                    ref.read(currentScenarioProvider.notifier).state = null;
                  }
                  debugPrint('❌ [CLOSE BUTTON] Scenario restored to lessonMenu');
                } catch (e) {
                  debugPrint('❌ [CLOSE BUTTON] ERROR clearing scenario: $e');
                }
                context.pop();
              } else {
                debugPrint('❌ [CLOSE BUTTON] User chose "Keep Learning" - resuming');
                // User clicked "Keep Learning" - resume
                try {
                  ref.read(lessonChatProvider.notifier).resume();
                  debugPrint('❌ [CLOSE BUTTON] resume() called successfully');
                } catch (e) {
                  debugPrint('❌ [CLOSE BUTTON] ERROR calling resume(): $e');
                }
              }
            },
          ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lesson!.title,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Part ${_currentModuleIndex + 1} of ${_lesson!.modules.length}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarkRepo.isBookmarked(widget.lessonId)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: AppColors.white,
            ),
            onPressed: () async {
              final topicId = _lesson!.topicId;
              await _bookmarkRepo.toggleBookmark(
                lessonId: widget.lessonId,
                topicId: topicId,
              );
              setState(() {});
              if (mounted) {
                FeedbackToast.showSnackBar(
                  context,
                  type: _bookmarkRepo.isBookmarked(widget.lessonId)
                      ? FeedbackType.success
                      : FeedbackType.info,
                  message: _bookmarkRepo.isBookmarked(widget.lessonId)
                      ? 'Lesson bookmarked!'
                      : 'Bookmark removed',
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Module Header with phase indicator
          _buildModuleHeader(module, moduleColor, guidedState),

          // Content area: chat (online) or markdown (offline)
          Expanded(
            child: _isOffline
                ? _buildOfflineContent(module)
                : _buildGuidedChatContent(module, guidedState),
          ),

          // Input area: always visible when online, with contextual state
          if (!_isOffline)
            _buildInputArea(moduleColor),

          // Navigation Buttons
          _buildNavigationButtons(moduleColor, guidedState),
        ],
      ),
      ), // Scaffold
    ); // PopScope
  }

  /// Module Header - compact design with module icon
  Widget _buildModuleHeader(
    ModuleModel module,
    Color moduleColor,
    GuidedLessonState guidedState,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
      decoration: BoxDecoration(
        color: moduleColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Module icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                child: Image.asset(
                  module.type.iconAsset,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(module.type.icon, size: 24, color: AppColors.white);
                  },
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s12),

            // Title, type badge, and progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Module title
                  Text(
                    'Part ${module.order}: ${module.type.displayName}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.s4),

                  // Time + status
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${module.estimatedMinutes} min',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                      if (!_isOffline) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.s8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: guidedState.canProceed
                                ? AppColors.success
                                : AppColors.warning,
                            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Text(
                            guidedState.canProceed ? 'Complete' : 'In Progress',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSizes.s4),

                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressBarAnimation,
                    builder: (context, child) {
                      final displayProgress = _progressBarController.isAnimating
                          ? _progressBarAnimation.value
                          : _animatedProgress;
                      return Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                              child: LinearProgressIndicator(
                                value: displayProgress,
                                backgroundColor: AppColors.white.withValues(alpha: 0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.s8),
                          Text(
                            '${(displayProgress * 100).toInt()}%',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AI-guided chat content (online mode)
  Widget _buildGuidedChatContent(
    ModuleModel module,
    GuidedLessonState guidedState,
  ) {
    final chatState = ref.watch(lessonChatProvider);
    final character = ref.watch(activeCharacterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phase 1 Channel Enforcement: Only interaction-channel messages
    // appear in the main chat area. Narration messages go to speech bubbles.
    final qaMessages = chatState.messages.where((msg) {
      return msg.role == 'user' || msg.channel == MessageChannel.interaction;
    }).toList();

    // Phase 1: Assert no narration messages leaked into the main chat
    assert(() {
      for (final msg in qaMessages) {
        if (msg.channel == MessageChannel.narration) {
          debugPrint(
            '⚠️ CHANNEL VIOLATION: Narration message in main chat: '
            '"${msg.content.substring(0, msg.content.length.clamp(0, 60))}"',
          );
          return false;
        }
      }
      return true;
    }(), 'Narration messages must not appear in the interaction channel (main chat)');

    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.background,
      child: qaMessages.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: character.themeColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppSizes.s12),
                    Text(
                      '${character.name} is preparing your lesson',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.s4),
                    Text(
                      'Questions and answers will appear here.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s4,
                vertical: AppSizes.s8,
              ),
              itemCount: qaMessages.length +
                  (chatState.isStreaming || chatState.isChecking ? 1 : 0),
              itemBuilder: (context, index) {
                // Phase 3: Show "checking" state or typing indicator
                if (index == qaMessages.length &&
                    (chatState.isStreaming || chatState.isChecking)) {
                  if (chatState.isChecking) {
                    return _buildCheckingIndicator(character);
                  }
                  return TypingIndicator(
                    color: character.themeColor,
                    characterName: character.name,
                    avatarAsset: character.avatarAsset,
                  );
                }

                final msg = qaMessages[index];
                return _buildLessonChatBubble(msg, character);
              },
            ),
    );
  }

  /// Build a chat bubble for lesson messages
  Widget _buildLessonChatBubble(LessonChatMessage msg, AiCharacter character) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Handle image messages
    // Handle image messages WITH avatar (same pattern as text messages)
    if (msg.imageAssetPath != null && msg.imageAssetPath!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.s12,
          vertical: AppSizes.s4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start, // Align avatar at top
          children: [
            // Character avatar (same as text messages)
            _buildCharacterAvatar(character),
            const SizedBox(width: AppSizes.s8),

            // Image
            Flexible(
              child: ChatImageMessage(
                imageAssetPath: msg.imageAssetPath!,
                onTap: () => ImageModal.show(context, msg.imageAssetPath!),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s12,
        vertical: AppSizes.s4,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (assistant only, first message)
          if (!isUser) ...[
            _buildCharacterAvatar(character),
            const SizedBox(width: AppSizes.s8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s12,
                vertical: AppSizes.s8,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? character.themeColor
                    : (isDark ? AppColors.darkSurface : AppColors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: isUser
                    ? null
                    : Border.all(
                        color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.5),
                        width: 0.5,
                      ),
              ),
              child: _buildBubbleContent(msg, isUser, character, isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Build bubble text content with bold support
  Widget _buildBubbleContent(
    LessonChatMessage msg,
    bool isUser,
    AiCharacter character,
    bool isDark,
  ) {
    final textColor = isUser
        ? AppColors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);
    final spans = _parseBoldText(msg.content, textColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Character name (assistant only)
        if (!isUser) ...[
          Text(
            character.name,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: character.themeColor,
              fontSize: 11,
              decoration: TextDecoration.none,
              backgroundColor: Colors.transparent,
            ),
          ),
          const SizedBox(height: 4),
        ],

        // Message content
        RichText(
          text: TextSpan(
            style: AppTextStyles.chatMessage.copyWith(
              color: textColor,
              height: 1.45,
              backgroundColor: Colors.transparent,
              decoration: TextDecoration.none,
            ),
            children: spans,
          ),
        ),

        // Streaming cursor
        if (msg.isStreaming) ...[
          const SizedBox(height: 4),
          _BlinkingCursor(color: character.themeColor),
        ],
      ],
    );
  }

  /// Parse **bold** markers in text
  List<TextSpan> _parseBoldText(String text, Color baseColor) {
    final spans = <TextSpan>[];
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            backgroundColor: Colors.transparent,
            decoration: TextDecoration.none,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: baseColor,
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: const TextStyle(
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
      ));
    }

    return spans;
  }

  /// Character avatar widget
  Widget _buildCharacterAvatar(AiCharacter character) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: character.themeColor.withValues(alpha:0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          character.avatarAsset,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 28,
              height: 28,
              color: character.themeColor.withValues(alpha:0.15),
              child: Center(
                child: Text(
                  character.name.substring(0, 1),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: character.themeColor,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Phase 3: "Checking your answer..." indicator before AI evaluation
  Widget _buildCheckingIndicator(AiCharacter character) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s12,
        vertical: AppSizes.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildCharacterAvatar(character),
          const SizedBox(width: AppSizes.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s12,
              vertical: AppSizes.s8,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.5),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: character.themeColor,
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  'Checking your answer...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Offline fallback: static markdown content
  Widget _buildOfflineContent(ModuleModel module) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Offline banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.s16,
            vertical: AppSizes.s8,
          ),
          color: AppColors.warning.withValues(alpha:0.1),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, size: 16, color: AppColors.warning),
              const SizedBox(width: AppSizes.s8),
              Expanded(
                child: Text(
                  'Lessons work offline! Connect to internet for AI tutor guidance.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Static markdown content
        Expanded(
          child: Container(
            color: isDark ? AppColors.darkBackground : AppColors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.s20),
              child: MarkdownBody(
                data: module.content,
                styleSheet: MarkdownStyleSheet(
                  h1: AppTextStyles.headingLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  h2: AppTextStyles.headingMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  h3: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  p: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                  strong: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  em: AppTextStyles.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  listBullet: AppTextStyles.bodyMedium,
                  code: AppTextStyles.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceTint,
                  ),
                  blockquote: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Text input area - always visible with contextual state indicators
  /// Phase 2: Shows disabled reason, pulse on enable, character context
  Widget _buildInputArea(Color moduleColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final character = ref.watch(activeCharacterProvider);
    final chatState = ref.watch(lessonChatProvider);
    final guidedState = ref.watch(guidedLessonProvider);
    final narrativeState = ref.watch(lessonNarrativeBubbleProvider);

    final bool isWaitingForUser = guidedState.waitingForUser;
    final bool isStreaming = chatState.isStreaming;
    final bool isNarrating = narrativeState.isActive;
    final bool isEnabled = isWaitingForUser && !isStreaming;

    // Phase 2: Detect transition from disabled to enabled and trigger pulse
    if (isEnabled && !_wasWaitingForUser) {
      _inputPulseController.forward(from: 0.0);
    }
    _wasWaitingForUser = isEnabled;

    // Contextual hint text based on state
    final bool isChecking = chatState.isChecking;
    String hintText;
    if (isChecking) {
      hintText = 'Checking your answer...';
    } else if (isStreaming) {
      hintText = '${character.name} is thinking...';
    } else if (isNarrating) {
      hintText = 'Listen to ${character.name} first';
    } else if (!isWaitingForUser && !guidedState.canProceed) {
      hintText = 'Lesson in progress...';
    } else if (guidedState.canProceed) {
      hintText = 'Module complete! Tap Next to continue';
    } else {
      hintText = 'Type your answer...';
    }

    return AnimatedBuilder(
      animation: _inputPulseAnimation,
      builder: (context, child) {
        // Pulse glow effect when input just became enabled
        final pulseValue = _inputPulseAnimation.value;
        final glowOpacity = isEnabled && pulseValue > 0 && pulseValue < 1.0
            ? (1.0 - pulseValue) * 0.3
            : 0.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            border: Border(
              top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            boxShadow: glowOpacity > 0
                ? [
                    BoxShadow(
                      color: character.themeColor.withValues(alpha: glowOpacity),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? (isDark ? AppColors.darkSurfaceElevated : AppColors.white)
                        : (isDark ? AppColors.darkSurface : AppColors.surfaceTint),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isEnabled
                          ? character.themeColor.withValues(alpha: 0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.border),
                      width: isEnabled ? 1.5 : 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _inputController,
                    enabled: isEnabled,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: isEnabled
                            ? AppColors.textSecondary
                            : isStreaming
                                ? character.themeColor.withValues(alpha: 0.5)
                                : AppColors.textSecondary.withValues(alpha: 0.6),
                        fontStyle: isEnabled ? FontStyle.normal : FontStyle.italic,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      height: 1.4,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onSubmitted: (_) => _sendStudentMessage(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: (_inputController.text.trim().isEmpty || !isEnabled)
                      ? null
                      : character.themeGradient,
                  color: (_inputController.text.trim().isEmpty || !isEnabled)
                      ? (isDark ? AppColors.darkBorder : AppColors.border)
                      : null,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_inputController.text.trim().isEmpty || !isEnabled)
                        ? null
                        : _sendStudentMessage,
                    customBorder: const CircleBorder(),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Navigation Buttons with phase-aware locking
  Widget _buildNavigationButtons(
    Color moduleColor,
    GuidedLessonState guidedState,
  ) {
    final canProceed = _isOffline || guidedState.canProceed;

    // Phase 3: Detect module completion transition and trigger pulse
    if (canProceed && !_wasModuleComplete) {
      _nextButtonPulseController.forward(from: 0.0);
    }
    _wasModuleComplete = canProceed;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSizes.s20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModuleProgressDots(),
            const SizedBox(height: AppSizes.s16),
            Row(
              children: [
                if (!_isFirstModule)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goToPreviousModule,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                        side: BorderSide(color: isDark ? AppColors.darkPrimary : AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.s16,
                        ),
                      ),
                    ),
                  ),
                if (!_isFirstModule) const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _nextButtonPulseAnimation,
                    builder: (context, child) {
                      final pulseValue = _nextButtonPulseAnimation.value;
                      final glowOpacity = canProceed && pulseValue > 0 && pulseValue < 1.0
                          ? (1.0 - pulseValue) * 0.5
                          : 0.0;

                      return Container(
                        decoration: glowOpacity > 0
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withValues(alpha: glowOpacity),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              )
                            : null,
                        child: child,
                      );
                    },
                    child: ElevatedButton.icon(
                      onPressed: canProceed ? _goToNextModule : null,
                      icon: Icon(
                        canProceed
                            ? (_isLastModule ? Icons.check_circle_rounded : Icons.check_circle_rounded)
                            : (_isLastModule ? Icons.check : Icons.arrow_forward),
                      ),
                      label: Text(
                        canProceed
                            ? (_isLastModule ? 'Complete' : 'Next')
                            : _getLockedButtonLabel(guidedState),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canProceed ? moduleColor : AppColors.border,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.s16,
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getLockedButtonLabel(GuidedLessonState guidedState) {
    if (guidedState.waitingForUser) {
      return 'Reply first';
    }
    return 'In progress...';
  }

  Widget _buildModuleProgressDots() {
    if (_lesson == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _lesson!.modules.length,
        (index) {
          final module = _lesson!.modules[index];
          final isCurrent = index == _currentModuleIndex;
          final isCompleted = _isModuleCompleted(module.id);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 32 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success
                    : isCurrent
                        ? _getModuleColor(module)
                        : (isDark ? AppColors.darkBorder : AppColors.border),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Blinking cursor animation for streaming messages
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// Phase 7: Confetti celebration overlay for topic completion.
/// Shows falling confetti particles for 1 second, then auto-removes.
class _ConfettiOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _ConfettiOverlay({required this.onComplete});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;

  static const int _particleCount = 40;
  static const List<Color> _colors = [
    AppColors.success,
    AppColors.primary,
    AppColors.warning,
    AppColors.info,
    Color(0xFF9C27B0),
    Color(0xFFFF5722),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Generate random confetti particles
    _particles = List.generate(_particleCount, (i) {
      final random = i / _particleCount;
      return _ConfettiParticle(
        x: (random * 1.2) - 0.1, // -0.1 to 1.1 horizontal spread
        delay: (i % 5) * 0.05, // stagger start times
        speed: 0.6 + (i % 3) * 0.2, // variable fall speed
        wobble: (i % 2 == 0 ? 1 : -1) * (0.02 + (i % 4) * 0.01),
        size: 6.0 + (i % 3) * 2.0,
        color: _colors[i % _colors.length],
        isSquare: i % 3 != 0,
      );
    });

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;

            return CustomPaint(
              size: size,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: t,
                screenHeight: size.height,
                screenWidth: size.width,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final double x; // 0-1 horizontal position
  final double delay; // stagger delay (0-0.25)
  final double speed; // fall speed multiplier
  final double wobble; // horizontal oscillation
  final double size;
  final Color color;
  final bool isSquare; // square vs circle shape

  const _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.wobble,
    required this.size,
    required this.color,
    required this.isSquare,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  final double screenHeight;
  final double screenWidth;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.screenHeight,
    required this.screenWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Adjust progress for stagger delay
      final adjustedT = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (adjustedT <= 0) continue;

      // Fade out in last 30%
      final opacity = adjustedT > 0.7
          ? ((1.0 - adjustedT) / 0.3).clamp(0.0, 1.0)
          : 1.0;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Position: fall from top with horizontal wobble
      final x = p.x * screenWidth +
          (adjustedT * 30 * p.wobble * screenWidth).clamp(-50.0, screenWidth + 50);
      final y = -20 + (adjustedT * p.speed * screenHeight * 1.2);

      if (p.isSquare) {
        // Rotating square effect via skewed rect
        final rotation = adjustedT * 3.14 * 2 * (p.wobble > 0 ? 1 : -1);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(Offset(x, y), p.size / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
