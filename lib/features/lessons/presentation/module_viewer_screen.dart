import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/ai_character_model.dart';
import '../data/repositories/lesson_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/bookmark_repository.dart';
import '../../chat/data/providers/character_provider.dart';
import '../../chat/data/repositories/chat_repository.dart';
import '../../chat/presentation/widgets/typing_indicator.dart';
import '../data/providers/guided_lesson_provider.dart';
import '../data/providers/lesson_chat_provider.dart';

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

class _ModuleViewerScreenState extends ConsumerState<ModuleViewerScreen> {
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();
  final _bookmarkRepo = BookmarkRepository();
  final _chatRepo = ChatRepository();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  LessonModel? _lesson;
  late int _currentModuleIndex;
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _currentModuleIndex = widget.moduleIndex;

    // ✅ FIX: Clear any previous module state to ensure fresh start
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        return const Color(0xFF2196F3);
      case ModuleType.fa_scinate:
        return const Color(0xFF9C27B0);
      case ModuleType.inve_scitigation:
        return const Color(0xFFFF9800);
      case ModuleType.goal_scitting:
        return const Color(0xFF4CAF50);
      case ModuleType.self_a_scissment:
        return const Color(0xFFF44336);
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

      // Restart guided lesson for the new module
      if (!_isOffline) {
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
    }

    if (!_isLastModule) {
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

      // Start guided lesson for the new module
      if (!_isOffline) {
        _startGuidedModule();
      } else {
        ref.read(guidedLessonProvider.notifier).setOfflineMode();
      }
    } else {
      _showLessonCompleteDialog();
    }
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

  void _showLessonCompleteDialog() {
    final progress = _progressRepo.getProgress(widget.lessonId);
    final completedModules = progress?.completedModuleIds.length ?? 0;
    final totalModules = _lesson?.modules.length ?? 6;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              'Lesson Complete!',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.success,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Congratulations! You\'ve finished all modules for "${_lesson?.title}".',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s16),
            Container(
              padding: const EdgeInsets.all(AppSizes.s16),
              decoration: BoxDecoration(
                color: AppColors.grey100,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
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
              Navigator.pop(context);
              context.pop();
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

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.success),
        const SizedBox(width: AppSizes.s8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.grey600,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.grey900,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // ✅ FIX: Clear all module state when leaving
    // This ensures clean restart when re-entering the same module
    ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();
    ref.read(lessonChatProvider.notifier).reset();
    // Note: guidedLessonProvider state is reset in startModule() call

    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.grey50,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_lesson == null) {
      return Scaffold(
        backgroundColor: AppColors.grey50,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: AppColors.grey300),
              const SizedBox(height: AppSizes.s16),
              Text('Lesson not found', style: AppTextStyles.headingSmall),
              const SizedBox(height: AppSizes.s24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final module = _currentModule;
    if (module == null) {
      return Scaffold(
        backgroundColor: AppColors.grey50,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: Text('Module not found')),
      );
    }

    final moduleColor = _getModuleColor(module);
    final guidedState = ref.watch(guidedLessonProvider);

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        backgroundColor: moduleColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.white),
          onPressed: () => context.pop(),
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
              'Module ${_currentModuleIndex + 1} of ${_lesson!.modules.length}',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _bookmarkRepo.isBookmarked(widget.lessonId)
                          ? 'Lesson bookmarked!'
                          : 'Bookmark removed',
                      style: AppTextStyles.bodySmall,
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
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

          // Input area: visible when bot is waiting for student response
          if (!_isOffline && guidedState.waitingForUser)
            _buildInputArea(moduleColor),

          // Navigation Buttons
          _buildNavigationButtons(moduleColor, guidedState),
        ],
      ),
    );
  }

  /// Module Header with phase badge
  Widget _buildModuleHeader(
    ModuleModel module,
    Color moduleColor,
    GuidedLessonState guidedState,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.s20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module Type + Phase Badges
            Row(
              children: [
                // Module type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.s12,
                    vertical: AppSizes.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(module.type.icon, size: 16, color: AppColors.white),
                      const SizedBox(width: AppSizes.s4),
                      Text(
                        module.type.displayName,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge (only when online)
                if (!_isOffline) ...[
                  const SizedBox(width: AppSizes.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s12,
                      vertical: AppSizes.s8,
                    ),
                    decoration: BoxDecoration(
                      color: guidedState.canProceed
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          guidedState.canProceed
                              ? Icons.check_circle
                              : Icons.school,
                          size: 14,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: AppSizes.s4),
                        Text(
                          guidedState.canProceed ? 'Complete' : 'In Progress',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.s12),

            // Module Title
            Text(
              module.title,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.s8),

            // Module Info
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSizes.s4),
                Text(
                  '${module.estimatedMinutes} min',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: AppSizes.s16),
                Icon(
                  Icons.pending_actions,
                  size: 16,
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSizes.s4),
                Text(
                  '${(_currentProgress * 100).toInt()}% Complete',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
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

    // Filter to show only Q&A messages (not narrative)
    final qaMessages = chatState.messages.where((msg) {
      return msg.role == 'user' || msg.messageType == MessageType.question;
    }).toList();

    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Container(
      color: AppColors.grey50,
      child: qaMessages.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s24),
                child: Text(
                  'Your conversation will appear here.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey600,
                  ),
                  textAlign: TextAlign.center,
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
                  (chatState.isStreaming ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == qaMessages.length && chatState.isStreaming) {
                  return TypingIndicator(color: character.themeColor);
                }

                final msg = qaMessages[index];
                return _buildLessonChatBubble(msg, character);
              },
            ),
    );
  }

  /// Build a chat bubble for lesson messages
  Widget _buildLessonChatBubble(LessonChatMessage msg, AiCharacter character) {
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
                color: isUser ? character.themeColor : AppColors.white,
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
                        color: AppColors.grey300.withValues(alpha:0.5),
                        width: 0.5,
                      ),
              ),
              child: _buildBubbleContent(msg, isUser, character),
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
  ) {
    final textColor = isUser ? AppColors.white : AppColors.grey900;
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

  /// Offline fallback: static markdown content
  Widget _buildOfflineContent(ModuleModel module) {
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
                  'AI tutor unavailable offline. Showing lesson text.',
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
            color: AppColors.white,
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
                    backgroundColor: AppColors.grey100,
                  ),
                  blockquote: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey600,
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

  /// Text input area for asking phase
  Widget _buildInputArea(Color moduleColor) {
    final character = ref.watch(activeCharacterProvider);
    final chatState = ref.watch(lessonChatProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.grey300),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 48,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.grey300),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !chatState.isStreaming,
                decoration: const InputDecoration(
                  hintText: 'ASK QUESTION or TYPE',
                  hintStyle: TextStyle(
                    color: AppColors.grey600,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _inputController.text.trim().isEmpty
                  ? null
                  : character.themeGradient,
              color: _inputController.text.trim().isEmpty
                  ? AppColors.grey300
                  : null,
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _inputController.text.trim().isEmpty || chatState.isStreaming
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
  }

  /// Navigation Buttons with phase-aware locking
  Widget _buildNavigationButtons(
    Color moduleColor,
    GuidedLessonState guidedState,
  ) {
    final canProceed = _isOffline || guidedState.canProceed;

    return Container(
      padding: const EdgeInsets.all(AppSizes.s20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.s16,
                        ),
                      ),
                    ),
                  ),
                if (!_isFirstModule) const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canProceed ? _goToNextModule : null,
                    icon: Icon(
                      _isLastModule ? Icons.check : Icons.arrow_forward,
                    ),
                    label: Text(
                      canProceed
                          ? (_isLastModule ? 'Complete' : 'Next')
                          : _getLockedButtonLabel(guidedState),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canProceed ? moduleColor : AppColors.grey300,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.s16,
                      ),
                      elevation: 0,
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
                        : AppColors.grey300,
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
