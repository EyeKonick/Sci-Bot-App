import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../shared/models/channel_message.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import 'guided_lesson_provider.dart';

// Re-export MessageChannel and NarrationMessage for consumers
export '../../../../shared/models/channel_message.dart';

// ---------------------------------------------------------------------------
// Bubble Mode — explicit state for FloatingChatButton speech bubble behavior
// ---------------------------------------------------------------------------

/// Controls what the FloatingChatButton's speech bubble displays.
/// Changes only at well-defined transition points (entering/leaving modules,
/// narrative start), NOT on every sub-state change like message index advances.
enum BubbleMode {
  /// Show contextual character greetings (Home, Topics, Lessons screens)
  greeting,

  /// Module is loading — suppress ALL bubbles (no greetings, no narrative yet)
  waitingForNarrative,

  /// Lesson narrative is active — show script messages from lessonNarrativeBubbleProvider
  narrative,
}

/// Provider for the current bubble mode. Set by ModuleViewerScreen and
/// LessonChatNotifier at well-defined transition points.
final bubbleModeProvider = StateProvider<BubbleMode>((ref) => BubbleMode.greeting);

// ---------------------------------------------------------------------------
// Script Step Model
// ---------------------------------------------------------------------------

/// A single step in the scripted lesson conversation.
/// Each step has bot messages to display, and optionally waits for user input.
class ScriptStep {
  /// Messages the bot sends (each becomes a separate chat bubble)
  final List<String> botMessages;

  /// Channel designation: narration (speech bubble) or interaction (main chat)
  final MessageChannel channel;

  /// Whether to pause and wait for student input after sending messages
  final bool waitForUser;

  /// If set, AI evaluates the student's answer using this context.
  /// Only relevant when waitForUser is true.
  final String? aiEvalContext;

  /// If true, completing this step marks the module as done
  final bool isModuleComplete;

  /// Phase 5: Pacing hint for speech bubble timing (narration channel only)
  final PacingHint pacingHint;

  /// Optional transition bubble shown before interaction messages.
  /// Creates smooth narration → interaction transitions.
  /// Example: "I like how you think. Here's another question."
  final String? transitionBubble;

  const ScriptStep({
    required this.botMessages,
    required this.channel,
    this.waitForUser = false,
    this.aiEvalContext,
    this.isModuleComplete = false,
    this.pacingHint = PacingHint.normal,
    this.transitionBubble,
  });
}

// ---------------------------------------------------------------------------
// Lesson Chat Message
// ---------------------------------------------------------------------------

/// A single message in the guided lesson chat (separate from global chat).
///
/// Each message has a [channel] indicating whether it belongs to the
/// narration channel (speech bubbles) or the interaction channel (main chat).
/// User messages are always [MessageChannel.interaction].
class LessonChatMessage {
  final String id;
  final String role; // 'assistant' or 'user'
  final String content;
  final MessageChannel? channel; // null for legacy; user messages are always interaction
  final bool isStreaming;
  final DateTime timestamp;

  const LessonChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.channel,
    this.isStreaming = false,
    required this.timestamp,
  });

  LessonChatMessage copyWith({
    String? content,
    bool? isStreaming,
    MessageChannel? channel,
  }) {
    return LessonChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      channel: channel ?? this.channel,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp,
    );
  }
}

// ---------------------------------------------------------------------------
// Lesson Chat State
// ---------------------------------------------------------------------------

class LessonChatState {
  final List<LessonChatMessage> messages;
  final bool isStreaming;
  final bool isChecking; // Phase 3: "checking answer" state before evaluation
  final int currentStepIndex;

  const LessonChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.isChecking = false,
    this.currentStepIndex = 0,
  });

  LessonChatState copyWith({
    List<LessonChatMessage>? messages,
    bool? isStreaming,
    bool? isChecking,
    int? currentStepIndex,
  }) {
    return LessonChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isChecking: isChecking ?? this.isChecking,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// Lesson Narrative Bubble State (for Speech Bubbles)
// ---------------------------------------------------------------------------

/// State for narrative speech bubbles shown by floating avatar.
///
/// Uses [NarrationMessage] to enforce that only narration-channel
/// content appears in the chathead speech bubbles.
class LessonNarrativeBubbleState {
  /// Current narrative messages to display in speech bubble.
  /// Typed as [NarrationMessage] to prevent interaction content from leaking.
  final List<NarrationMessage> messages;

  /// Index of currently displayed message
  final int currentIndex;

  /// Whether narrative is active
  final bool isActive;

  /// Whether narrative is paused (e.g., during exit confirmation dialog)
  final bool isPaused;

  /// Whether AI is thinking/generating a response
  final bool isThinking;

  /// Associated lesson ID (for context)
  final String? lessonId;

  /// Whether to instantly hide bubble without animation (prevents flash during channel transitions)
  final bool isInstantHide;

  const LessonNarrativeBubbleState({
    this.messages = const [],
    this.currentIndex = 0,
    this.isActive = false,
    this.isPaused = false,
    this.isThinking = false,
    this.lessonId,
    this.isInstantHide = false,
  });

  LessonNarrativeBubbleState copyWith({
    List<NarrationMessage>? messages,
    int? currentIndex,
    bool? isActive,
    bool? isPaused,
    bool? isThinking,
    String? lessonId,
    bool? isInstantHide,
  }) {
    return LessonNarrativeBubbleState(
      messages: messages ?? this.messages,
      currentIndex: currentIndex ?? this.currentIndex,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      isThinking: isThinking ?? this.isThinking,
      lessonId: lessonId ?? this.lessonId,
      isInstantHide: isInstantHide ?? this.isInstantHide,
    );
  }
}

/// Manages narrative messages for speech bubbles.
///
/// Only accepts [NarrationMessage] objects, ensuring that questions
/// and evaluative content never appear in the chathead speech bubbles.
class LessonNarrativeBubbleNotifier
    extends StateNotifier<LessonNarrativeBubbleState> {
  LessonNarrativeBubbleNotifier() : super(const LessonNarrativeBubbleState());

  /// Start showing narrative messages in the speech bubble.
  ///
  /// Accepts [NarrationMessage] list to enforce channel separation.
  /// In debug mode, asserts that no message content contains
  /// question-like patterns that belong in the interaction channel.
  void showNarrative(List<NarrationMessage> messages, String lessonId) {
    // Phase 1: Assert narration messages don't contain question prompts
    // that should be in the interaction channel
    assert(() {
      for (final msg in messages) {
        if (msg.content.contains('Type your answer') ||
            msg.content.contains('ASK QUESTION or TYPE')) {
          debugPrint(
            '⚠️ CHANNEL VIOLATION: Narration message contains interaction '
            'prompt: "${msg.content.substring(0, msg.content.length.clamp(0, 60))}"',
          );
        }
      }
      return true;
    }());

    // Phase 5: Semantic splitting - split long messages at sentence boundaries
    final splitMessages = NarrationMessage.semanticSplit(messages);

    debugPrint('📢 showNarrative: ${messages.length} NarrationMessages → ${splitMessages.length} after semantic split for lesson $lessonId');

    state = LessonNarrativeBubbleState(
      messages: splitMessages,
      currentIndex: 0,
      isActive: true,
      lessonId: lessonId,
      isInstantHide: false, // Reset flag when showing new narrative
    );
  }

  /// Move to next message in sequence
  void nextMessage() {
    if (!state.isActive || state.currentIndex >= state.messages.length - 1) {
      debugPrint('⏭️ nextMessage: Already at end or inactive');
      return;
    }
    final nextIndex = state.currentIndex + 1;
    debugPrint('⏭️ nextMessage: Advancing from ${state.currentIndex} to $nextIndex');
    state = state.copyWith(currentIndex: nextIndex);
  }

  /// Hide narrative bubble and trigger contextual greeting restart
  /// If [instant] is true, suppresses bubble immediately without animation (prevents flash)
  void hideNarrative({bool instant = false}) {
    state = LessonNarrativeBubbleState(
      isActive: false,
      messages: const [],
      isInstantHide: instant,
    );
  }

  /// Pause narrative bubble progression (e.g., during exit confirmation)
  void pause() {
    state = state.copyWith(isPaused: true);
  }

  /// Resume narrative bubble progression
  void resume() {
    state = state.copyWith(isPaused: false);
  }

  /// Set thinking state (show "Thinking..." in bubble)
  void setThinking(bool isThinking) {
    state = state.copyWith(isThinking: isThinking);
  }

  /// Reset to beginning of sequence
  void reset() {
    state = state.copyWith(currentIndex: 0, isActive: true);
  }
}

// ---------------------------------------------------------------------------
// Lesson Chat Notifier
// ---------------------------------------------------------------------------

class LessonChatNotifier extends StateNotifier<LessonChatState> {
  final ChatRepository _chatRepo;
  final Ref _ref;

  /// The script for the current module
  List<ScriptStep> _script = [];

  /// Conversation history for AI follow-up context
  final List<Map<String, dynamic>> _conversationHistory = [];

  /// Current character
  AiCharacter? _currentCharacter;

  /// Current module info for scope checking
  ModuleModel? _currentModule;
  LessonModel? _currentLesson;

  /// Request ID to track current module context
  /// Incremented each time startModule() is called
  /// Used to discard responses from previous modules
  int _currentRequestId = 0;

  /// Prevent simultaneous calls to startModule()
  bool _isStarting = false;

  /// Track wrong answer attempts per step index (for graduated hints)
  final Map<int, int> _attemptsByStep = {};

  LessonChatNotifier(this._chatRepo, this._ref)
      : super(const LessonChatState());

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Start a module - loads script and sends first step's messages
  Future<void> startModule({
    required ModuleModel module,
    required LessonModel lesson,
    required AiCharacter character,
  }) async {
    // ✅ Prevent simultaneous calls
    if (_isStarting) {
      print('⚠️ startModule() called while already starting - ignoring duplicate call');
      return;
    }

    _isStarting = true;

    try {
      // ✅ Increment request ID to invalidate any in-flight AI requests
      // This prevents messages from previous modules bleeding into new ones
      _currentRequestId++;

      print('🚀 Starting module: ${module.title} (Request ID: $_currentRequestId)');

      // ✅ FIX: Clear narrative bubble state COMPLETELY before starting new module
      // This prevents old messages from bleeding into new module
      _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();

      // ✅ FIX: Longer delay to ensure floating button stops all animations
      await Future.delayed(const Duration(milliseconds: 300));

      // Reset everything
      _conversationHistory.clear();
      _currentCharacter = character;
      _currentModule = module;
      _currentLesson = lesson;
      state = const LessonChatState();

      print('📝 DEBUG - Module ID: "${module.id}"');
      print('📝 DEBUG - Lesson ID: "${lesson.id}"');
      print('📝 DEBUG - Character: "${character.name}"');

      // Load script for this module (or generate a generic one)
      _script = _getScriptForModule(module.id);

      print('📝 DEBUG - Script loaded with ${_script.length} steps');
      if (_script.isNotEmpty) {
        print('📝 DEBUG - First step channel: ${_script[0].channel}');
        print('📝 DEBUG - First step messages: ${_script[0].botMessages.length} messages');
      } else {
        print('⚠️ WARNING - Script is EMPTY!');
      }

      // Reset guided lesson state
      _ref.read(guidedLessonProvider.notifier).startModule();

      // Send first step
      print('📝 DEBUG - Calling _executeStep(0)...');
      await _executeStep(0);
      print('📝 DEBUG - _executeStep(0) completed');
    } finally {
      _isStarting = false;
    }
  }

  /// Student sends a message (response to a wait point)
  Future<void> sendStudentMessage(String text) async {
    if (state.isStreaming) return;

    final currentStep = _getCurrentStep();
    if (currentStep == null) return;

    final requestId = _currentRequestId;

    // DON'T clear waiting state yet - wait until we know if advancing or looping

    // If current step is narration and waiting for user acknowledgment
    if (currentStep.channel == MessageChannel.narration &&
        currentStep.waitForUser) {
      // User acknowledged narrative (e.g., typed "Yes I notice")
      // DON'T add to main chat - keep it for Q&A only
      _conversationHistory.add({'role': 'user', 'content': text});

      // Hide narrative bubble and advance to next step
      _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();

      // Small delay then advance
      await Future.delayed(const Duration(milliseconds: 500));
      if (requestId != _currentRequestId) return;
      _advanceStep();
      return;
    }

    // For question messages: Add to chat and get AI response
    _addUserMessage(text);
    _conversationHistory.add({'role': 'user', 'content': text});

    // Show immediate acknowledgment bubble for user engagement
    if (_currentCharacter != null) {
      _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
        [NarrationMessage(
          content: _getAcknowledgmentPhrase(),
          characterId: _currentCharacter?.id,
          pacingHint: PacingHint.fast,
        )],
        _currentLesson?.id ?? 'unknown',
      );

      // Brief pause to let acknowledgment show
      await Future.delayed(const Duration(milliseconds: 1200));
      if (requestId != _currentRequestId) return;
    }

    // Call AI to respond and check if we can proceed
    bool canProceed = true; // Default to proceeding for non-evaluated steps

    if (currentStep.aiEvalContext != null && _currentCharacter != null) {
      // Evaluate specific answer → FEEDBACK GOES TO BUBBLE
      canProceed = await _sendAIEvaluation(text, currentStep.aiEvalContext!);
    } else if (_currentCharacter != null) {
      // General acknowledgment (e.g., "ready", "ok") → GOES TO MAIN CHAT
      canProceed = await _sendGeneralResponse(text);
    }

    if (requestId != _currentRequestId) return;

    // Only advance to next step if AI approves
    if (canProceed) {
      // Show encouragement if advanced due to max attempts (not correctness)
      final attemptCount = _attemptsByStep[state.currentStepIndex] ?? 1;
      final isEndOfModuleQA = currentStep.aiEvalContext?.toLowerCase().contains('tap next') ?? false;

      if (attemptCount >= 3 && !isEndOfModuleQA && currentStep.aiEvalContext != null) {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (requestId != _currentRequestId) return;

        _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
          [NarrationMessage(
            content: 'That was a tough question! Let\'s move forward—you\'re doing great!',
            characterId: _currentCharacter?.id,
            pacingHint: PacingHint.normal,
          )],
          _currentLesson?.id ?? 'unknown',
        );

        await Future.delayed(const Duration(milliseconds: 3000));
        if (requestId != _currentRequestId) return;
      }

      // Only clear waiting when advancing to next step
      _ref.read(guidedLessonProvider.notifier).clearWaiting();
      final nextIndex = state.currentStepIndex + 1;
      if (nextIndex < _script.length) {
        // Show contextual transition bubble before next question
        // (only if next step is interaction and doesn't have its own transition)
        final nextStep = _script[nextIndex];
        if (nextStep.channel == MessageChannel.interaction &&
            nextStep.transitionBubble == null &&
            attemptCount < 3) { // Only for correct answers, not max attempts
          _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
            [NarrationMessage(
              content: _getTransitionPhrase(),
              characterId: _currentCharacter?.id,
              pacingHint: PacingHint.fast,
            )],
            _currentLesson?.id ?? 'unknown',
          );

          await Future.delayed(const Duration(milliseconds: 2000));
          if (requestId != _currentRequestId) return;

          // Hide transition bubble before showing next question
          _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative(instant: true);
        }

        // Small delay so AI response and next step don't blend together
        await Future.delayed(const Duration(milliseconds: 800));
        if (requestId != _currentRequestId) return;
        await _executeStep(nextIndex);
      }
    } else {
      // Staying on same step for retry
      // Only show follow-up prompt for end-of-module Q&A (not for regular questions)
      final isEndOfModuleQA = currentStep.aiEvalContext?.toLowerCase().contains('tap next') ?? false;

      if (isEndOfModuleQA) {
        // End-of-module Q&A: show follow-up prompt to ask if they have more questions
        print('⏸️ End-of-module Q&A - showing follow-up prompt');
        await _showFollowUpPrompt(requestId);
      } else {
        // Regular question: just stay on same step, input remains enabled for retry
        print('⏸️ Staying on step ${state.currentStepIndex} - waiting for retry (attempt ${_attemptsByStep[state.currentStepIndex] ?? 1}/3)');
        // Input is already enabled because we didn't call clearWaiting()
        // User can just type another answer to retry
      }
    }
  }

  /// Clear all state and cancel any in-flight async operations.
  /// Also clears narrative bubble and resets bubble mode to prevent
  /// narration from leaking to other screens after navigation.
  void reset() {
    _currentRequestId++; // Invalidate any running async chains
    _isStarting = false; // Allow startModule() to be called again
    _conversationHistory.clear();
    _script = [];
    _currentCharacter = null;
    _currentModule = null;
    _currentLesson = null;
    _attemptsByStep.clear(); // Clear attempt tracking
    state = const LessonChatState();

    // Clear narrative state to prevent speech bubble leaks on back navigation
    _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();
    _ref.read(bubbleModeProvider.notifier).state = BubbleMode.greeting;
  }

  /// Pause narrative bubble progression (delegates to narrative provider)
  void pause() {
    _ref.read(lessonNarrativeBubbleProvider.notifier).pause();
  }

  /// Resume narrative bubble progression (delegates to narrative provider)
  void resume() {
    _ref.read(lessonNarrativeBubbleProvider.notifier).resume();
  }

  // -------------------------------------------------------------------------
  // Internal: Step Execution
  // -------------------------------------------------------------------------

  ScriptStep? _getCurrentStep() {
    if (state.currentStepIndex >= _script.length) return null;
    return _script[state.currentStepIndex];
  }

  /// Returns a varied acknowledgment phrase for immediate user feedback.
  /// Creates natural, conversational flow instead of robotic repetition.
  String _getAcknowledgmentPhrase() {
    final phrases = [
      'I like how you think!',
      'Interesting answer!',
      'Let me check that...',
      'Hmm, let me see...',
      'Great effort!',
      'Nice thinking!',
      'Good response!',
      'Let me evaluate this...',
      'Alright, let\'s see...',
      'I appreciate your answer!',
      'Thoughtful response!',
      'Let me think about that...',
    ];

    // Use timestamp-based pseudo-randomness for variety
    final index = DateTime.now().millisecondsSinceEpoch % phrases.length;
    return phrases[index];
  }

  /// Returns a varied transition phrase for moving to next question.
  /// Creates smooth flow from correct answer to next topic.
  String _getTransitionPhrase() {
    final phrases = [
      'Excellent! Here\'s another question.',
      'Great job! Let\'s continue.',
      'Well done! Moving forward.',
      'Perfect! Here\'s the next one.',
      'Nice work! Let\'s explore more.',
      'Fantastic! Ready for another?',
      'Good thinking! Next question.',
      'You\'re doing great! Let\'s proceed.',
      'Awesome! Here comes another.',
      'Terrific! Let\'s keep going.',
      'Brilliant! Next up.',
      'Wonderful! Let\'s continue learning.',
    ];

    // Use timestamp-based pseudo-randomness for variety
    final index = DateTime.now().millisecondsSinceEpoch % phrases.length;
    return phrases[index];
  }

  /// Execute a script step: send bot messages, then wait if needed
  Future<void> _executeStep(int stepIndex) async {
    try {
      print('📝 DEBUG - _executeStep($stepIndex) called');
      print('📝 DEBUG - _script.length: ${_script.length}');

      if (stepIndex >= _script.length) {
        print('⚠️ WARNING - stepIndex ($stepIndex) >= _script.length (${_script.length})');
        return;
      }

      // Capture request ID to detect if module changed during async gaps
      final requestId = _currentRequestId;

      final step = _script[stepIndex];
      state = state.copyWith(currentStepIndex: stepIndex);

      print('📝 DEBUG - Step $stepIndex: channel=${step.channel}, messages=${step.botMessages.length}, waitForUser=${step.waitForUser}, isComplete=${step.isModuleComplete}');

      // Check if module is complete
      if (step.isModuleComplete) {
        print('✅ Module marked as complete at step $stepIndex');
        _ref.read(guidedLessonProvider.notifier).completeModule();
        return;
      }

      if (step.botMessages.isEmpty) {
        print('⚠️ Step $stepIndex has no messages');
        // No messages - just advance if not waiting
        if (!step.waitForUser) {
          _advanceStep();
        }
        return;
      }

      print('📝 DEBUG - Step $stepIndex first message: "${step.botMessages[0].substring(0, step.botMessages[0].length > 50 ? 50 : step.botMessages[0].length)}..."');

      // Set bubble mode based on channel to keep FloatingChatButton in sync
      final currentBubbleMode = _ref.read(bubbleModeProvider);
      print('📝 DEBUG - Current bubble mode: $currentBubbleMode');

      if (step.channel == MessageChannel.narration) {
        print('📝 DEBUG - Setting bubble mode to NARRATIVE');
        _ref.read(bubbleModeProvider.notifier).state = BubbleMode.narrative;
      } else if (_ref.read(bubbleModeProvider) != BubbleMode.greeting) {
        print('📝 DEBUG - Setting bubble mode to WAITING_FOR_NARRATIVE');
        // Suppress bubbles during interaction steps (don't revert to greeting mid-lesson)
        _ref.read(bubbleModeProvider.notifier).state = BubbleMode.waitingForNarrative;
      }

    // Route messages based on channel
    if (step.channel == MessageChannel.narration) {
      print('📝 DEBUG - Routing to NARRATION channel - showing speech bubbles');
      // Send to speech bubble (NOT central chat) - wrap as NarrationMessage
      _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
        step.botMessages.map((msg) => NarrationMessage(
          content: msg,
          characterId: _currentCharacter?.id,
          pacingHint: step.pacingHint,
        )).toList(),
        _currentLesson?.id ?? 'unknown',
      );

      // Store in conversation history for AI context
      for (final msg in step.botMessages) {
        _conversationHistory.add({'role': 'assistant', 'content': msg});
      }

      // If waitForUser, pause here until user responds
      if (step.waitForUser) {
        _ref.read(guidedLessonProvider.notifier).setWaitingForUser();
        // Execution continues when sendMessage() advances currentStepIndex
        return;
      }

      // Auto-advance if not waiting
      // Phase 5: Variable timing based on message content length
      int totalDisplayMs = 0;
      for (int i = 0; i < step.botMessages.length; i++) {
        final msg = step.botMessages[i];
        final wordCount = msg.split(RegExp(r'\s+')).length;
        final isLastBubble = (i == step.botMessages.length - 1);

        // ~300ms per word, min 2s, max 8s per message
        totalDisplayMs += (wordCount * 300).clamp(2000, 8000).toInt();

        // Add inter-bubble gap based on message length
        final length = msg.length;
        totalDisplayMs += length < 50 ? 800 : (length < 120 ? 1200 : 1800);

        // Add extra reading time for the LAST bubble before transition
        if (isLastBubble) {
          totalDisplayMs += 2000; // Extra 2 seconds to ensure last bubble is fully readable
        }
      }

      // Wait for all bubbles to display + extra buffer
      await Future.delayed(Duration(milliseconds: totalDisplayMs + 500));
      if (requestId != _currentRequestId) return; // Module changed, stop

      // Check if next step is interaction channel - if so, hide bubble before transitioning
      final nextIndex = state.currentStepIndex + 1;
      if (nextIndex < _script.length && _script[nextIndex].channel == MessageChannel.interaction) {
        // Hide narration bubble INSTANTLY (no animation delay) to prevent leak
        _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative(instant: true);
        // Brief pause for clean transition (reduced from 1500ms to 200ms)
        await Future.delayed(const Duration(milliseconds: 200));
        if (requestId != _currentRequestId) return; // Module changed, stop
      }

      _advanceStep();
    } else {
      // MessageChannel.interaction: Add to central chat

      // Show transition bubble BEFORE interaction messages for smooth flow
      if (step.transitionBubble != null) {
        _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
          [NarrationMessage(
            content: step.transitionBubble!,
            characterId: _currentCharacter?.id,
            pacingHint: PacingHint.fast, // Quick, excited transition
          )],
          _currentLesson?.id ?? 'unknown',
        );

        // Calculate dynamic transition bubble timing
        final wordCount = step.transitionBubble!.split(RegExp(r'\s+')).length;
        final displayMs = (wordCount * 300).clamp(2000, 4000); // Shorter for transitions
        final gapMs = 800; // Fast pacing for transitions

        await Future.delayed(Duration(milliseconds: displayMs + gapMs));
        if (requestId != _currentRequestId) return;

        // Hide transition bubble before showing question
        _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative(instant: true);
        await Future.delayed(const Duration(milliseconds: 200));
        if (requestId != _currentRequestId) return;
      }

      // Add interaction messages to central chat
      for (int i = 0; i < step.botMessages.length; i++) {
        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (requestId != _currentRequestId) return; // Module changed, stop
        }
        final message = LessonChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: step.botMessages[i],
          channel: MessageChannel.interaction,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, message],
        );
      }

      // Store in conversation history
      for (final msg in step.botMessages) {
        _conversationHistory.add({'role': 'assistant', 'content': msg});
      }

      // If waiting for user, enable input; otherwise advance
      if (step.waitForUser) {
        _ref.read(guidedLessonProvider.notifier).setWaitingForUser();
      } else {
        _advanceStep();
      }
    }
    } catch (e, stackTrace) {
      print('❌ ERROR in _executeStep($stepIndex): $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Advance to next step in script
  void _advanceStep() {
    final nextIndex = state.currentStepIndex + 1;
    if (nextIndex < _script.length) {
      // Clear attempt counter when advancing to new step
      _attemptsByStep.remove(state.currentStepIndex);
      _executeStep(nextIndex);
    }
  }

  // -------------------------------------------------------------------------
  // Internal: AI Evaluation
  // -------------------------------------------------------------------------

  /// Call AI to evaluate a student's answer
  /// ✅ TWO-TIER FEEDBACK SYSTEM:
  ///   1. Quick bubble response (1-2 words)
  ///   2. Full explanation in main chat (2-3 sentences)
  Future<bool> _sendAIEvaluation(String studentAnswer, String evalContext) async {
    final character = _currentCharacter;
    if (character == null) return true; // Default to proceeding if no character

    // ✅ Capture request ID at start to validate response is still relevant
    final requestId = _currentRequestId;
    final currentStepIndex = state.currentStepIndex;

    // Track and increment attempt counter
    final attemptNumber = (_attemptsByStep[currentStepIndex] ?? 0) + 1;
    _attemptsByStep[currentStepIndex] = attemptNumber;

    print('📊 Attempt $attemptNumber of 3 for step $currentStepIndex');

    // Phase 3: Show "checking" state for minimum 300ms before evaluation
    state = state.copyWith(isChecking: true);
    await Future.delayed(const Duration(milliseconds: 300));

    // Validate context hasn't changed during checking delay
    if (requestId != _currentRequestId) {
      state = state.copyWith(isChecking: false);
      return false; // Context changed, don't proceed
    }
    state = state.copyWith(isChecking: false);

    // Build module context for scope checking
    final moduleContext = _currentModule != null && _currentLesson != null
        ? 'Current Lesson: ${_currentLesson!.title}\nCurrent Module: ${_currentModule!.title} (${_currentModule!.type.displayName})'
        : 'Current topic: Circulation and Gas Exchange';

    // ✅ STEP 1: Quick bubble feedback (DYNAMIC - not pre-scripted)
    final bubblePrompt = '''You are ${character.name}, evaluating a student's answer.

$moduleContext

EVALUATION CONTEXT:
$evalContext

Student's answer: "$studentAnswer"
Attempt number: $attemptNumber of 3 maximum

GRADUATED RESPONSE RULES:
- Attempt 1 (gentle hint): Use encouraging phrases like "Malapit na!", "Try again!", "Kulang pa!"
- Attempt 2 (specific hint): Use guiding phrases like "Think about...", "Almost there!"
- Attempt 3 (reveal answer): Use supportive phrases even if wrong: "Great effort!", "Nice try!"

Respond with ONLY a brief dynamic Tagalog phrase (1-5 words):
- Generate a contextual phrase based on the specific answer quality AND attempt number
- NEVER use the same phrase repeatedly - be creative and natural
- Use conversational Grade 9 Filipino expressions
- Match the phrase to the student's effort and reasoning
🟡 Partial: "Malapit na!", "May tama ka dyan!", "Kulang pa!"

Generate a UNIQUE phrase that fits THIS specific answer.''';

    String bubbleResponse = '';
    try {
      await for (final chunk in _chatRepo.sendGuidedLessonStream(
        userMessage: studentAnswer,
        systemPrompt: bubblePrompt,
        maxTokens: 15, // Allow for dynamic Filipino phrases
      )) {
        bubbleResponse += chunk;
      }
    } catch (e) {
      bubbleResponse = 'Subukan pa!';
    }

    // ✅ VALIDATION: Check if module context is still the same after bubble
    if (requestId != _currentRequestId) {
      print('⚠️ Discarding AI response - module context changed (old: $requestId, current: $_currentRequestId)');
      state = state.copyWith(isStreaming: false);
      return false; // Context changed, don't proceed
    }

    // ✅ Show quick response in speech bubble (as NarrationMessage)
    print('💬 [AI EVAL] Bubble response: "$bubbleResponse"');
    _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
      [NarrationMessage(content: bubbleResponse, characterId: _currentCharacter?.id)],
      _currentLesson?.id ?? 'unknown',
    );

    // Small delay before explanation
    await Future.delayed(const Duration(milliseconds: 1500));

    // Check context again after delay
    if (requestId != _currentRequestId) {
      return false; // Context changed during delay
    }

    print('💬 [AI EVAL] Starting full explanation...');

    // ✅ STEP 2: Full explanation in main chat
    final explanationPrompt = '''You are ${character.name}, a friendly science tutor for Grade 9 Filipino students in Roxas City.

$moduleContext

EVALUATION CONTEXT:
$evalContext

Student's answer: "$studentAnswer"
Attempt number: $attemptNumber of 3 maximum

GRADUATED HINT SYSTEM (for wrong answers):
- Attempt 1: Give a GENTLE hint. Don't reveal the answer. Guide them to think about the concept.
  Example: "You're on the right track! Think about what your muscles need when you exercise."

- Attempt 2: Give a SPECIFIC hint. Narrow down the answer without fully revealing it.
  Example: "Good effort! Remember that muscles need oxygen to release energy. What part of your body carries oxygen?"

- Attempt 3: REVEAL the answer and explain why. Be supportive and encouraging.
  Example: "Great try! The answer is: Blood carries oxygen from your lungs to your muscles via red blood cells. You showed real effort in thinking this through!"

ENCOURAGEMENT RULES:
- ALWAYS include encouraging words regardless of correctness
- Attempt 1-2: "Keep going!", "You're learning!", "Good thinking!"
- Attempt 3: "Excellent effort!", "You tried your best!", "Great perseverance!"

CRITICAL FORMAT REQUIREMENT:
Structure your response as: [Dynamic Tagalog phrase] [Complete English explanation]

TAGALOG PHRASE (First sentence only):
- Generate a unique, contextual Tagalog phrase based on THIS specific answer
- NEVER repeat the same phrase - vary based on answer quality and effort
- Use natural Grade 9 Filipino conversational language
- Keep it brief (1-5 words)
- The phrase you used in the bubble was: "$bubbleResponse"

ENGLISH EXPLANATION (Rest of response):
✅ If correct: Start with "Correct!" or "Tama!" then affirm why it's right + add educational details
❌ If wrong: Follow graduated hint system above based on attempt number (do NOT say "Correct!")
🤷 If vague/IDK: Assure them + preview what they'll learn (do NOT say "Correct!")
🟡 If partial: Start with "Partially correct!" then affirm what's right + clarify what's missing

CRITICAL KEYWORD REQUIREMENT:
- MUST include "Correct!" or "Tama!" in your response if the answer is fully correct
- MUST include "Partially correct!" if the answer is partially right
- DO NOT include "Correct!" if the answer is wrong, vague, or needs improvement
- These keywords are used by the system to determine if the student can proceed

REQUIREMENTS:
- First phrase is Tagalog, rest is English
- Encouraging tone regardless of correctness
- Use Roxas City, Capiz examples when relevant
- 2-3 sentences of explanation (4-5 sentences for attempt 3 when revealing answer)
- Age-appropriate for 14-15 year olds
- Focus on learning, not judging
- DO NOT ask "Do you have another question?" - the system handles this automatically
- Just provide your explanation/answer and stop - don't add follow-up questions

THIS MESSAGE APPEARS IN MAIN CHAT AREA.''';

    state = state.copyWith(isStreaming: true);
    String fullExplanation = '';
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add streaming placeholder to main chat
    final streamingMsg = LessonChatMessage(
      id: msgId,
      role: 'assistant',
      content: '',
      channel: MessageChannel.interaction, // Ensure it appears in main chat
      isStreaming: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, streamingMsg],
    );

    try {
      await for (final chunk in _chatRepo.sendGuidedLessonStream(
        userMessage: studentAnswer,
        systemPrompt: explanationPrompt,
        maxTokens: 300,
      )) {
        // Check if context changed during streaming
        if (requestId != _currentRequestId) {
          print('⚠️ Discarding explanation stream - module context changed');
          state = state.copyWith(isStreaming: false);
          final messages = state.messages.where((m) => m.id != msgId).toList();
          state = state.copyWith(messages: messages);
          return false; // Context changed, don't proceed
        }

        fullExplanation += chunk;
        _updateLastMessage(fullExplanation, true);
      }
    } catch (e) {
      fullExplanation = 'Let\'s keep exploring this topic together!';
    }

    // Final validation
    if (requestId != _currentRequestId) {
      print('⚠️ Discarding final explanation - module context changed');
      state = state.copyWith(isStreaming: false);
      final messages = state.messages.where((m) => m.id != msgId).toList();
      state = state.copyWith(messages: messages);
      return false; // Context changed, don't proceed
    }

    // Finalize main chat message
    print('✅ [AI EVAL] Full explanation complete (${fullExplanation.length} chars)');
    print('💬 [AI EVAL] Explanation: "${fullExplanation.substring(0, fullExplanation.length.clamp(0, 100))}..."');
    _updateLastMessage(fullExplanation, false);
    state = state.copyWith(isStreaming: false);
    _conversationHistory.add({'role': 'assistant', 'content': fullExplanation});

    // ✅ ANSWER QUALITY GATING: Different behavior for regular vs end-of-module Q&A
    // Check if this is an end-of-module Q&A question (context mentions "Tap Next")
    final isEndOfModuleQA = evalContext.toLowerCase().contains('tap next') ||
                            evalContext.toLowerCase().contains('click next');

    bool canProceed;
    if (isEndOfModuleQA) {
      // For end-of-module Q&A: only proceed if AI says "Tap Next" (student is ready)
      canProceed = fullExplanation.toLowerCase().contains('tap next') ||
                   fullExplanation.toLowerCase().contains('click next');
      print(canProceed
          ? '✅ AI says Tap Next - student is ready to proceed'
          : '⏸️ End-of-module Q&A - waiting for student to say "ready" or ask more questions');
    } else {
      // For regular questions: proceed after evaluation OR after 3 attempts
      if (attemptNumber >= 3) {
        canProceed = true;
        print('✅ Max attempts reached (3/3) - auto-advancing with encouragement');
      } else {
        // Check if answer is correct or partially correct
        final isCorrect = fullExplanation.toLowerCase().contains('correct!') ||
                         fullExplanation.toLowerCase().contains('tama!') ||
                         fullExplanation.toLowerCase().contains('partially correct');

        canProceed = isCorrect;
        print(canProceed
            ? '✅ Answer correct/partial - proceeding to next step'
            : '⏸️ Attempt $attemptNumber/3 - staying for retry');
      }
    }

    // Small delay before returning result
    await Future.delayed(const Duration(milliseconds: 2000));

    return canProceed;
  }

  /// General response for steps without specific evaluation context
  /// Handles acknowledgments and scope checking for off-topic questions
  Future<bool> _sendGeneralResponse(String studentInput) async {
    final character = _currentCharacter;
    if (character == null) return true; // Default to proceeding

    // ✅ Capture request ID at start to validate response is still relevant
    final requestId = _currentRequestId;

    // Build module context for scope checking
    final moduleContext = _currentModule != null && _currentLesson != null
        ? 'Current Lesson: ${_currentLesson!.title}\nCurrent Module: ${_currentModule!.title} (${_currentModule!.type.displayName})'
        : 'Current topic: Circulation and Gas Exchange';

    final systemPrompt = '''You are ${character.name}, a friendly science tutor for Grade 9 Filipino students in Roxas City.

$moduleContext

CONTEXT:
The student just sent a message during the lesson. This is NOT an answer to a specific question, but rather:
- An acknowledgment (e.g., "ok", "ready", "yes", "let's go")
- A question about the current topic
- OR a question about a different topic (off-topic)

SCOPE CHECKING - CRITICAL:
- If the student is asking about a DIFFERENT topic/module (heredity, ecosystems, genes, DNA, food chains, etc.), you MUST redirect them:
  "We can learn about that in another module. Let's continue with our current topic for now!"
- If the student is asking about the CURRENT topic (circulation, blood, heart, oxygen, etc.), answer warmly in 2-3 sentences
- If the student is just acknowledging (ok, ready, yes), give a brief encouraging response (1 sentence)

RESPONSE RULES:
- Keep response to 1-2 sentences maximum
- Be warm and encouraging
- Use simple language appropriate for 14-15 year olds
- You may use Filipino expressions naturally (e.g., "Tama!", "Sige!")
- DO NOT give long explanations - keep it brief''';

    state = state.copyWith(isStreaming: true);

    String fullResponse = '';
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add streaming placeholder
    final streamingMsg = LessonChatMessage(
      id: msgId,
      role: 'assistant',
      content: '',
      channel: MessageChannel.interaction, // Ensure it appears in main chat
      isStreaming: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, streamingMsg],
    );

    try {
      await for (final chunk in _chatRepo.sendGuidedLessonStream(
        userMessage: studentInput,
        systemPrompt: systemPrompt,
        maxTokens: 150, // Keep responses short
      )) {
        // ✅ Check if context changed during streaming
        if (requestId != _currentRequestId) {
          print('⚠️ Discarding streaming response - module context changed');
          state = state.copyWith(isStreaming: false);
          // Remove the placeholder message
          final messages = state.messages.where((m) => m.id != msgId).toList();
          state = state.copyWith(messages: messages);
          return false; // Context changed, don't proceed
        }

        fullResponse += chunk;
        _updateLastMessage(fullResponse, true);
      }
    } catch (e) {
      fullResponse = 'Sige! Let\'s continue.';
    }

    // ✅ Final validation before saving
    if (requestId != _currentRequestId) {
      print('⚠️ Discarding final response - module context changed');
      state = state.copyWith(isStreaming: false);
      final messages = state.messages.where((m) => m.id != msgId).toList();
      state = state.copyWith(messages: messages);
      return false; // Context changed, don't proceed
    }

    // Finalize
    _updateLastMessage(fullResponse, false);
    state = state.copyWith(isStreaming: false);
    _conversationHistory.add({'role': 'assistant', 'content': fullResponse});

    // For general responses (acknowledgments), always proceed
    // These are typically "ok", "ready", "yes" - not questions requiring answers
    return true;
  }

  /// Show follow-up prompt after AI answers end-of-module Q&A question
  /// Re-enables input and asks if student has more questions or is ready to proceed
  Future<void> _showFollowUpPrompt(int requestId) async {
    // Small delay so AI's answer and follow-up prompt don't blend together
    await Future.delayed(const Duration(milliseconds: 1000));
    if (requestId != _currentRequestId) return; // Context changed, abort

    // Add follow-up prompt to main chat
    final followUpMsg = LessonChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: 'Do you have another question, or are you ready to continue? '
               'Type your question or type "ready".',
      channel: MessageChannel.interaction,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, followUpMsg],
    );

    // Keep waitingForUser = true by NOT calling clearWaiting()
    // The guidedLessonProvider already has waitingForUser = true from initial step setup
  }

  // -------------------------------------------------------------------------
  // Internal: Message Helpers
  // -------------------------------------------------------------------------

  void _addBotMessage(String content) {
    final msg = LessonChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: content,
      channel: MessageChannel.interaction, // Ensure it appears in main chat
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _addUserMessage(String content) {
    final msg = LessonChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
      channel: MessageChannel.interaction, // User messages always in main chat
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _updateLastMessage(String content, bool isStreaming) {
    final messages = List<LessonChatMessage>.from(state.messages);
    if (messages.isNotEmpty) {
      messages[messages.length - 1] = messages.last.copyWith(
        content: content,
        isStreaming: isStreaming,
      );
      state = state.copyWith(messages: messages);
    }
  }

  // -------------------------------------------------------------------------
  // Script Definitions
  // -------------------------------------------------------------------------

  /// Get the conversation script for a specific module.
  /// Returns a custom script if one exists, or a generic fallback.
  List<ScriptStep> _getScriptForModule(String moduleId) {
    print('📝 _getScriptForModule called with moduleId: "$moduleId" (length: ${moduleId.length})');

    switch (moduleId) {
      // LESSON 1: The Circulatory System (6 modules)
      case 'module_circ_fascinate':
        print('✅ MATCHED: Lesson 1 - Fa-SCI-nate');
        return _scriptFascinate();
      case 'module_circ_goal':
        print('✅ MATCHED: Lesson 1 - Goal SCI-tting');
        return _scriptGoalScitting();
      case 'module_circ_pre':
        print('✅ MATCHED: Lesson 1 - Pre-SCI-ntation');
        return _scriptPreScintation();
      case 'module_circ_investigation':
        print('✅ MATCHED: Lesson 1 - Inve-SCI-tigation');
        return _scriptInveScitigation();
      case 'module_circ_assessment':
        print('✅ MATCHED: Lesson 1 - Self-A-SCI-ssment');
        return _scriptSelfAScissment();
      case 'module_circ_supplementary':
        print('✅ MATCHED: Lesson 1 - SCI-pplementary');
        return _scriptScipplementary();

      // LESSON 2: Blood Circulation Pathways (6 modules)
      case 'module_circ2_fascinate':
        print('✅ MATCHED: Lesson 2 - Fa-SCI-nate (module_circ2_fascinate)');
        final script = _scriptCirc2Fascinate();
        print('✅ Script returned with ${script.length} steps');
        return script;
      case 'module_circ2_goal':
        print('✅ MATCHED: Lesson 2 - Goal SCI-tting (module_circ2_goal)');
        return _scriptCirc2GoalScitting();
      case 'module_circ2_pre':
        print('✅ MATCHED: Lesson 2 - Pre-SCI-ntation (module_circ2_pre)');
        return _scriptCirc2PreScintation();
      case 'module_circ2_investigation':
        print('✅ MATCHED: Lesson 2 - Inve-SCI-tigation (module_circ2_investigation)');
        return _scriptCirc2InveScitigation();
      case 'module_circ2_assessment':
        print('✅ MATCHED: Lesson 2 - Self-A-SCI-ssment (module_circ2_assessment)');
        return _scriptCirc2SelfAScissment();
      case 'module_circ2_supplementary':
        print('✅ MATCHED: Lesson 2 - SCI-pplementary (module_circ2_supplementary)');
        return _scriptCirc2Scipplementary();

      // LESSON 3: The Respiratory System (6 modules)
      case 'module_resp_fascinate':
        print('✅ Loading respiratory Fa-SCI-nate script (${_scriptRespFascinate().length} steps)');
        return _scriptRespFascinate();
      case 'module_resp_goal':
        print('✅ Loading respiratory Goal SCI-tting script (${_scriptRespGoalScitting().length} steps)');
        return _scriptRespGoalScitting();
      case 'module_resp_pre':
        print('✅ Loading respiratory Pre-SCI-ntation script (${_scriptRespPreScintation().length} steps)');
        return _scriptRespPreScintation();
      case 'module_resp_investigation':
        print('✅ Loading respiratory Inve-SCI-tigation script (${_scriptRespInveScitigation().length} steps)');
        return _scriptRespInveScitigation();
      case 'module_resp_assessment':
        print('✅ Loading respiratory Self-A-SCI-ssment script (${_scriptRespSelfAScissment().length} steps)');
        return _scriptRespSelfAScissment();
      case 'module_resp_supplementary':
        print('✅ Loading respiratory SCI-pplementary script (${_scriptRespScipplementary().length} steps)');
        return _scriptRespScipplementary();

      // TOPIC 2: HEREDITY AND VARIATION
      // LESSON 1: Genes and Chromosomes (6 modules)
      case 'module_genetics1_fascinate':
        print('✅ MATCHED: Topic 2 L1 - Fa-SCI-nate (module_genetics1_fascinate)');
        return _scriptGenetics1Fascinate();
      case 'module_genetics1_goal':
        print('✅ MATCHED: Topic 2 L1 - Goal SCI-tting (module_genetics1_goal)');
        return _scriptGenetics1GoalScitting();
      case 'module_genetics1_pre':
        print('✅ MATCHED: Topic 2 L1 - Pre-SCI-ntation (module_genetics1_pre)');
        return _scriptGenetics1PreScintation();
      case 'module_genetics1_investigation':
        print('✅ MATCHED: Topic 2 L1 - Inve-SCI-tigation (module_genetics1_investigation)');
        return _scriptGenetics1InveScitigation();
      case 'module_genetics1_assessment':
        print('✅ MATCHED: Topic 2 L1 - Self-A-SCI-ssment (module_genetics1_assessment)');
        return _scriptGenetics1SelfAScissment();
      case 'module_genetics1_supplementary':
        print('✅ MATCHED: Topic 2 L1 - SCI-pplementary (module_genetics1_supplementary)');
        return _scriptGenetics1Scipplementary();

      // LESSON 2: Non-Mendelian Inheritance (6 modules)
      case 'module_inherit_fascinate':
        print('✅ MATCHED: Topic 2 L2 - Fa-SCI-nate (module_inherit_fascinate)');
        return _scriptInheritFascinate();
      case 'module_inherit_goal':
        print('✅ MATCHED: Topic 2 L2 - Goal SCI-tting (module_inherit_goal)');
        return _scriptInheritGoalScitting();
      case 'module_inherit_pre':
        print('✅ MATCHED: Topic 2 L2 - Pre-SCI-ntation (module_inherit_pre)');
        return _scriptInheritPreScintation();
      case 'module_inherit_investigation':
        print('✅ MATCHED: Topic 2 L2 - Inve-SCI-tigation (module_inherit_investigation)');
        return _scriptInheritInveScitigation();
      case 'module_inherit_assessment':
        print('✅ MATCHED: Topic 2 L2 - Self-A-SCI-ssment (module_inherit_assessment)');
        return _scriptInheritSelfAScissment();
      case 'module_inherit_supplementary':
        print('✅ MATCHED: Topic 2 L2 - SCI-pplementary (module_inherit_supplementary)');
        return _scriptInheritScipplementary();

      // TOPIC 3: ENERGY IN THE ECOSYSTEM
      // LESSON 1: Plant Photosynthesis (6 modules)
      case 'module_photo_fascinate':
        print('✅ MATCHED: Topic 3 L1 - Fa-SCI-nate (module_photo_fascinate)');
        return _scriptPhotoFascinate();
      case 'module_photo_goal':
        print('✅ MATCHED: Topic 3 L1 - Goal SCI-tting (module_photo_goal)');
        return _scriptPhotoGoalScitting();
      case 'module_photo_pre':
        print('✅ MATCHED: Topic 3 L1 - Pre-SCI-ntation (module_photo_pre)');
        return _scriptPhotoPreScintation();
      case 'module_photo_investigation':
        print('✅ MATCHED: Topic 3 L1 - Inve-SCI-tigation (module_photo_investigation)');
        return _scriptPhotoInveScitigation();
      case 'module_photo_assessment':
        print('✅ MATCHED: Topic 3 L1 - Self-A-SCI-ssment (module_photo_assessment)');
        return _scriptPhotoSelfAScissment();
      case 'module_photo_supplementary':
        print('✅ MATCHED: Topic 3 L1 - SCI-pplementary (module_photo_supplementary)');
        return _scriptPhotoScipplementary();

      // LESSON 2: Metabolism (6 modules)
      case 'module_metab_fascinate':
        print('✅ MATCHED: Topic 3 L2 - Fa-SCI-nate (module_metab_fascinate)');
        return _scriptMetabFascinate();
      case 'module_metab_goal':
        print('✅ MATCHED: Topic 3 L2 - Goal SCI-tting (module_metab_goal)');
        return _scriptMetabGoalScitting();
      case 'module_metab_pre':
        print('✅ MATCHED: Topic 3 L2 - Pre-SCI-ntation (module_metab_pre)');
        return _scriptMetabPreScintation();
      case 'module_metab_investigation':
        print('✅ MATCHED: Topic 3 L2 - Inve-SCI-tigation (module_metab_investigation)');
        return _scriptMetabInveScitigation();
      case 'module_metab_assessment':
        print('✅ MATCHED: Topic 3 L2 - Self-A-SCI-ssment (module_metab_assessment)');
        return _scriptMetabSelfAScissment();
      case 'module_metab_supplementary':
        print('✅ MATCHED: Topic 3 L2 - SCI-pplementary (module_metab_supplementary)');
        return _scriptMetabScipplementary();

      default:
        print('⚠️ No custom script found for $moduleId, using generic fallback');
        return _scriptGenericFallback();
    }
  }

  /// -----------------------------------------------------------------------
  /// LESSON 1, MODULE 1: Fa-SCI-nate (The Circulatory System)
  /// Script follows the PDF: "CIRCULATION AND GAS EXCHANGE - LESSON 1"
  /// Updated to match user's exact interaction flow requirements
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptFascinate() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      // Each string is a separate bubble - no \n\n to avoid semanticSplit issues
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Kumusta! Welcome to today\'s science journey here in Roxas City.',
          'Today, we\'ll explore how your body moves blood and exchanges gases.',
          'Just like boats carry goods from Culasi fish port to different barangays, your body has a transport system too!',
          'This lesson is all about **Circulation and Gas Exchange** — your body\'s very own delivery network.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Excitement - welcoming energy
        waitForUser: false, // Auto-continue to next step
      ),

      // Step 1: First Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to dive in? Let\'s get **Fa-SCI-nated**!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true, // Wait for user acknowledgment
      ),

      // Step 2: Scenario (NARRATIVE - Speech Bubble) - includes engagement statement
      const ScriptStep(
        botMessages: [
          'Imagine this...',
          'You\'re biking along Roxas Boulevard during sunset or dancing energetically during Sinadya Festival.',
          'Have you noticed your heart beating faster?',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Reflection - let student imagine
        waitForUser: false, // Auto-continue to first question
      ),

      // Step 3: Question 1 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Why do you think your heart beats faster when you move?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why does your heart beat faster when you move?"\n'
            'Correct answer concept: When you exercise or move actively, your muscles '
            'need more oxygen and energy. The heart beats faster to pump more blood '
            'carrying oxygen to the active muscles. It is the body\'s way of meeting '
            'increased demand for oxygen and nutrients.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 4: Transition to Question 2 (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Here\'s another question:',
        ],
        channel: MessageChannel.narration,
        waitForUser: false, // Auto-continue to question
      ),

      // Step 5: Question 2 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**What do you think carries oxygen from your lungs to your muscles?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What carries oxygen from lungs to muscles?"\n'
            'Correct answer: Blood carries oxygen. Specifically, red blood cells contain '
            'hemoglobin which binds to oxygen in the lungs and transports it through '
            'blood vessels to the muscles and other body tissues.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Perfect!", "You got it!", "Exactly right!", "Spot on!") + brief explanation about blood/red blood cells\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Think about it this way...", "Let me give you a hint...", "Give it another shot!") + hint about red liquid flowing through body\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 8: Explanation (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Just like how delivery trucks distribute seafood from the port to the '
              'markets around Capiz, your body has a system that delivers oxygen, '
              'nutrients, and energy to every cell.',
          'That amazing system is called the **circulatory system**!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false, // Auto-continue to conclusion
      ),

      // Step 9: Transition to Q&A (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve completed the Fa-SCI-nate module.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration - positive energy
        waitForUser: false,
      ),

      // Step 10: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about what we covered—your heart, blood, or the circulatory system?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about the circulatory system basics '
            '(heart beating faster, blood carrying oxygen, circulatory system purpose) or '
            'signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 '
            'appropriate language and Roxas City context. '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Fa-SCI-nate. Tap Next to set your learning goals!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed (e.g., "ready", "no questions", "let\'s continue").',
        pacingHint: PacingHint.normal,
      ),

      // Step 11: Completion Marker (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 2, MODULE 1: Fa-SCI-nate (Blood Circulation Pathways)
  /// Script follows the PDF: "CIRCULATION AND GAS EXCHANGE - LESSON 2"
  /// Duration: ~5 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2Fascinate() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Hello again, SCI-learner!',
          'Welcome back to your science journey here in Roxas City, Capiz, where life flows—just like your blood!',
          'In the last lesson, you learned about the heart, blood, and blood vessels.',
          'Today, we\'ll focus on how blood moves in specific pathways, just like jeepneys and tricycles following routes around the city.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false,
      ),

      // Step 1: Lesson Title (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'This lesson is called **Circulation**.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 2: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to follow the path of your blood?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 3: Scenario Setup (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Imagine this...',
          'You jog along Baybay Roxas early in the morning.',
          'You breathe faster, and your heart beats harder.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Reflection - let student imagine
        waitForUser: false,
      ),

      // Step 4: Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Where do you think your blood goes first to get oxygen?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Where does your blood go first to get oxygen?"\n'
            'Correct answer: To the lungs. Blood must go to the lungs first to pick up oxygen before it can deliver oxygen to muscles.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Correct!", "Excellent!", "You got it!", "Perfect!") + explanation about blood traveling to lungs\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!") + hint that blood must go to lungs first\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 5: Transition to Q&A (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Great job! You\'ve completed Fa-SCI-nate!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 6: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about blood pathways or where blood goes to get oxygen?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Fa-SCI-nate. Tap Next to set your learning goals!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 7: Completion Marker (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 2, MODULE 2: Goal SCI-tting (Blood Circulation Pathways)
  /// Sets learning objectives for the lesson
  /// Duration: ~3 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2GoalScitting() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
          'Welcome to **Goal SCI-tting**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to see what you\'ll master today?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Learning Objectives (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:',
          '**1.** Differentiate between the pulmonary and systemic circuits',
          '**2.** Explain how blood transports oxygen, nutrients, and wastes',
          'These goals are like your travel map—let\'s follow them step by step!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Analogy (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Think of your circulatory system as Roxas City\'s transportation network.',
          'Just like jeepneys have specific routes, your blood follows specific pathways.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 4: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great! You\'ve completed Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 5: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about our learning goals?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Goal SCI-tting. Tap Next to explore Pre-SCI-ntation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 6: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to build the foundation!',
          'Tap **Next** to explore Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 2, MODULE 3: Pre-SCI-ntation (Blood Circulation Pathways)
  /// Introduction to blood circuits
  /// Duration: ~7 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2PreScintation() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Now let\'s build the foundation!',
          'Welcome to **Pre-SCI-ntation**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Foundation Concept (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Blood does not move randomly inside your body.',
          'Instead, it follows **specific pathways** called **blood circuits**.',
          'Just like how public transport in Roxas City has routes, blood also has two main routes:',
          '**1. Pulmonary Circuit**\n• Pathway between heart and lungs\n• Relatively short route',
          '**2. Systemic Circuit**\n• Pathway from heart to entire body\n• Much longer route',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 2: Why Two Circuits (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Why does your body need two circuits?',
          '**Your body needs:**\n• A way to refresh blood with oxygen (pulmonary)\n• A way to deliver oxygen to all cells (systemic)',
          '**Think of it like this:**\n• Pulmonary circuit = Gas station (refuel with oxygen)\n• Systemic circuit = Delivery service (bring oxygen everywhere)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Understanding these circuits helps you understand how your body keeps every cell alive!',
          'You\'ve completed Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 4: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we investigate deeper, do you have any questions about blood circuits?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Pre-SCI-ntation. Tap Next to start Inve-SCI-tigation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 5: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to investigate!',
          'Tap **Next** to explore Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 2, MODULE 4: Inve-SCI-tigation (Blood Circulation Pathways)
  /// Deep dive into pulmonary and systemic circuits
  /// Duration: ~20 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2InveScitigation() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate deeper!',
          'Welcome to **Inve-SCI-tigation**!',
          'Let\'s explore how blood travels through your body using two distinct circuits.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Part 1 - Pulmonary Circuit Introduction (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 1: Pulmonary Circuit**',
          'The pulmonary circuit is the pathway between the heart and the lungs.',
          '**Its main job is to:**\n• Remove carbon dioxide\n• Refill blood with oxygen',
          'Blood flows from the **right ventricle → lungs → left atrium**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 2: Pulmonary Circuit Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Which gas is removed in the lungs?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which gas is removed in the lungs?"\n'
            'Correct answer: Carbon dioxide is released/removed from the blood in the lungs. Oxygen is absorbed.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Correct!", "Excellent!", "You got it!", "Perfect!") + explanation about carbon dioxide being released\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!") + hint that oxygen is absorbed not removed\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 3: Part 2 - Systemic Circuit Introduction (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 2: Systemic Circuit**',
          'The systemic circuit carries blood from the heart to the rest of the body.',
          '**It delivers:**\n• Oxygen\n• Nutrients\n• Hormones',
          'It also collects waste materials.',
          'Blood flows from the **left ventricle → body tissues → right atrium**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 4: Systemic Circuit Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Which circuit do you think is larger?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which circuit is larger?"\n'
            'Correct answer: The systemic circuit is larger because it supplies the entire body, while the pulmonary circuit only goes to the lungs.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Correct!", "Excellent!", "You got it!", "Perfect!") + explanation about systemic circuit supplying entire body\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!") + hint that pulmonary only goes to lungs while systemic goes everywhere\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 5: Mini Investigation - Conceptual (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Mini Investigation:**',
          'Think of blood vessels like straws of different sizes.',
          '**If water flows faster in a wider straw, what does that represent in your body?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "If water flows faster in a wider straw, what does that represent?"\n'
            'Correct concept: Larger blood vessels allow faster blood flow, helping circulation stay continuous and efficient.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "You got it!", "Perfect!", "Spot on!") + explanation about larger vessels allowing faster flow\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Think about it this way...", "Let me give you a hint...", "Give it another shot!") + hint about wider vessels like arteries\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 6: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Amazing work, investigator!',
          'You\'ve completed Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 7: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about the pulmonary circuit, systemic circuit, or blood flow?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Inve-SCI-tigation. Tap Next to test your knowledge in Self-A-SCI-ssment!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 8: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to test your knowledge!',
          'Tap **Next** to take the Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 2, MODULE 5: Self-A-SCI-ssment (Blood Circulation Pathways)
  /// Assessment questions to check understanding
  /// Duration: ~10 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2SelfAScissment() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'ve learned so much about blood circuits!',
          'Now it\'s time to test your understanding.',
          'Welcome to **Self-A-SCI-ssment**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to check your knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Question 1 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Question 1: Which circuit removes carbon dioxide from the blood?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 1: Which circuit removes carbon dioxide?\n'
            'Correct answer: Pulmonary circuit (the circuit between heart and lungs).\n'
            'Response guidelines:\n'
            '- If correct: "Correct! The pulmonary circuit removes carbon dioxide in the lungs!"\n'
            '- If wrong: "The correct answer is the pulmonary circuit. It carries blood to the lungs where carbon dioxide is released!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 3: Question 2 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Question 2: Which circuit supplies oxygen to body tissues?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 2: Which circuit supplies oxygen to body tissues?\n'
            'Correct answer: Systemic circuit (the circuit from heart to entire body).\n'
            'Response guidelines:\n'
            '- If correct: "Excellent! The systemic circuit delivers oxygen to all body tissues!"\n'
            '- If wrong: "The correct answer is the systemic circuit. It carries oxygen-rich blood from the heart to your entire body!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 4: Question 3 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Question 3: Where does blood entering the left atrium come from?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 3: Where does blood entering the left atrium come from?\n'
            'Correct answer: From the lungs (via pulmonary veins). Blood entering the left atrium is oxygen-rich.\n'
            'Response guidelines:\n'
            '- If correct (lungs/pulmonary veins): "Correct! Blood entering the left atrium comes from the lungs and is oxygen-rich!"\n'
            '- If wrong (body tissues): "Not quite. Blood from body tissues enters the right atrium, not the left. The left atrium receives oxygen-rich blood from the lungs!"\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 5: Encouragement (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'If you can answer these questions, you\'re doing SCI-mazing!',
          'Remember: Learning takes time, and every question helps you understand better!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Encouraging reflection
        waitForUser: false,
      ),

      // Step 6: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Any final questions about what we\'ve covered in this assessment?',
          'Type your question, or type "ready" to move to the bonus content!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If question: Answer thoroughly (2-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If ready: Say "Excellent assessment work! Tap Next for bonus content!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness.',
        pacingHint: PacingHint.normal,
      ),

      // Step 7: Completion (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'ve completed your assessment! Well done!',
          'Tap **Next** for bonus activities!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 2, MODULE 6: SCI-pplementary (Blood Circulation Pathways)
  /// Extension activities and health tips
  /// Duration: ~5 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2Scipplementary() {
    return [
      // Step 0: Congratulations (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed the core lesson on blood circulation pathways!',
          'Ready for some bonus content?',
          'Welcome to **SCI-pplementary**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready for bonus content and health tips?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Did You Know (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Did you know?**',
          'The first stethoscope was made of wood over 170 years ago!',
          '• Invented by René Laennec in 1816\n• It was a simple wooden tube\n• Today\'s stethoscopes are much more advanced',
          '**Fun Fact:** Your blood travels about 19,000 kilometers of blood vessels in your body—that\'s almost halfway around the Earth!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Health Tips (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**To keep your circulation healthy here in Roxas City:**',
          '✅ **Stay active** (walk, bike, dance!)\n✅ **Eat nutritious food** (fresh fish helps!)\n✅ **Avoid smoking** and too much fatty food',
          'A healthy heart means a healthy life!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 4: Closing Celebration (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner!',
          'You\'ve successfully followed the path of blood through the pulmonary and systemic circuits!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 5: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Any final questions before we finish this lesson?',
          'Type your question, or type "done" to complete the lesson!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If question: Answer thoroughly (2-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If done/finished/ready: Say "Congratulations! You\'ve mastered Blood Circulation Pathways! Tap Next to complete the lesson!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal they are finished.',
        pacingHint: PacingHint.normal,
      ),

      // Step 6: Final Completion (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Next up: how circulation and gas exchange work together to keep your body alive and energized!',
          'Padayon sa pagtukib sa SCI-ensiya!',
          'Tap **Next** to complete this lesson!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 3, MODULE 1: Fa-SCI-nate (The Respiratory System)
  /// Script follows the PDF: "CIRCULATION AND GAS EXCHANGE - LESSON 3"
  /// Duration: ~5 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptRespFascinate() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Welcome back to your science adventure here in Roxas City, Capiz!',
          'The air is fresh and the sea breeze keeps us energized.',
          'Have you ever noticed how your breathing changes when you walk along Baybay Roxas, climb stairs at school, or play basketball with friends?',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false,
      ),

      // Step 1: Lesson Introduction (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Today, we\'ll explore the **Respiratory System**—the system that allows your body to breathe, exchange gases, and release energy.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 2: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to take a deep breath and begin?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 3: Scenario Setup (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Imagine this...',
          'You\'re jogging early in the morning along the roads of Pueblo de Panay.',
          'You inhale deeply and feel the cool air fill your lungs.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Reflection - let student imagine
        waitForUser: false,
      ),

      // Step 4: Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Why do you think breathing becomes faster during exercise?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why does breathing become faster during exercise?"\n'
            'Correct answer: Body needs more oxygen to release energy from food. Breathing speeds up because cells need more oxygen and must remove carbon dioxide faster.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 5: Transition to Q&A (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Excellent! You\'ve completed Fa-SCI-nate!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 6: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about breathing or the respiratory system?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Fa-SCI-nate. Tap Next to set your learning goals!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 7: Completion Marker (NARRATION - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 3, MODULE 2: Goal SCI-tting (The Respiratory System)
  /// Sets learning objectives for the lesson
  /// Duration: ~3 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptRespGoalScitting() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
          'Welcome to **Goal SCI-tting**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to see what you\'ll master today?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Learning Objectives (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:',
          '**1.** Describe the three main events of respiration',
          '**2.** Identify the parts of the respiratory system and their functions',
          '**3.** Trace the path of oxygen from the air to the alveoli',
          'Think of these goals as your learning checkpoints!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great! You\'ve completed Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 4: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about our learning goals?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Goal SCI-tting. Tap Next to explore Pre-SCI-ntation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 5: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to build the foundation!',
          'Tap **Next** to explore Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 3, MODULE 3: Pre-SCI-ntation (The Respiratory System)
  /// Introduction to respiration and its three main events
  /// Duration: ~7 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptRespPreScintation() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Now let\'s build the foundation!',
          'Welcome to **Pre-SCI-ntation**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Respiration Concept (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Many people think respiration is just breathing.',
          'But respiration is actually a **complex process of gas exchange** that allows your body to produce energy.',
          'Without oxygen, your body—just like a boat without fuel—cannot function properly.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 2: Three Main Events (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Respiration involves three main events:',
          '**1. Breathing** – air enters and leaves the lungs\n**2. Diffusion** – oxygen and carbon dioxide move across membranes\n**3. Transport of gases** – oxygen is delivered to cells, carbon dioxide is removed',
          'All three must work together for respiration to succeed!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'ve completed Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 4: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we investigate deeper, do you have any questions about respiration or the three main events?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Pre-SCI-ntation. Tap Next to start Inve-SCI-tigation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 5: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to investigate!',
          'Tap **Next** to explore Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 3, MODULE 4: Inve-SCI-tigation (The Respiratory System)
  /// Deep dive into respiratory system parts, path of air, and alveoli
  /// Duration: ~25 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptRespInveScitigation() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate deeper!',
          'Welcome to **Inve-SCI-tigation**!',
          'Let\'s explore how air travels through your body and how gas exchange keeps you alive!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Part 1 - Three Main Events Review (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 1: Three Main Events of Respiration**',
          'Here are the three main events:',
          '**1. Breathing** – air enters and leaves the lungs\n**2. Diffusion** – oxygen and carbon dioxide move across membranes\n**3. Transport of gases** – oxygen is delivered to cells, carbon dioxide is removed',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 2: Question - Which event happens in alveoli? (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Which event happens in the alveoli?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which event happens in the alveoli?"\n'
            'Correct answer: Diffusion. Gas exchange happens through diffusion in the alveoli.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 3: Part 2 - Path of Air (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 2: Path of Air**',
          'Let\'s trace the path of air when you inhale:',
          '**Nose → Nasal cavity → Pharynx → Larynx → Trachea → Bronchi → Bronchioles → Alveoli**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 4: Question - Where is air warmed? (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Where is air warmed and moistened?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Where is air warmed and moistened?"\n'
            'Correct answer: Nasal cavity. The nasal cavity warms, moistens, and filters air.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 5: Part 3 - Parts of Respiratory System (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 3: Parts of the Respiratory System**',
          'Each part has a special role:',
          '**Nasal cavity** – filters air\n**Pharynx** – shared passageway for air and food\n**Larynx** – produces sound (voice box)\n**Epiglottis** – prevents food from entering lungs',
          '**Trachea** – windpipe\n**Bronchi & bronchioles** – air pathways\n**Alveoli** – gas exchange\n**Diaphragm** – helps breathing',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 6: Question - What prevents food from entering lungs? (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**What prevents food from entering the lungs?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What prevents food from entering the lungs?"\n'
            'Correct answer: Epiglottis. It\'s a flap that covers the trachea when you swallow.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Correct!", "Excellent!", "You got it!", "Perfect!") + explanation about epiglottis protecting lungs\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!") + hint that it\'s a flap covering the trachea\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 7: Part 4 - Alveoli (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 4: Alveoli – Site of Gas Exchange**',
          'The alveoli are tiny, balloon-like air sacs.',
          'They have:\n• Thin walls\n• Moist surfaces\n• Many capillaries',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 8: Question - Why millions of alveoli? (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Why do you think having millions of alveoli is important?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why is having millions of alveoli important?"\n'
            'Correct answer: More alveoli mean more surface area for gas exchange. Larger surface area allows more efficient oxygen and CO2 exchange.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 9: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Amazing work, investigator!',
          'You\'ve completed Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 10: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about the respiratory system parts, the path of air, or the alveoli?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Inve-SCI-tigation. Tap Next to test your knowledge in Self-A-SCI-ssment!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 11: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to test your knowledge!',
          'Tap **Next** to take the Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 3, MODULE 5: Self-A-SCI-ssment (The Respiratory System)
  /// Assessment questions to check understanding
  /// Duration: ~10 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptRespSelfAScissment() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'ve learned so much about the respiratory system!',
          'Now it\'s time to test your understanding.',
          'Welcome to **Self-A-SCI-ssment**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to check your knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Question 1 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Question 1: What gas do we need to release energy from food?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 1: What gas do we need to release energy from food?\n'
            'Correct answer: Oxygen (O2).\n'
            'Response guidelines:\n'
            '- If correct: "Correct! Oxygen is essential for releasing energy from food through cellular respiration!"\n'
            '- If wrong: "The correct answer is oxygen. Your cells need oxygen to break down food and release energy!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 3: Question 2 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Question 2: What gas is removed from the body during respiration?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 2: What gas is removed from the body during respiration?\n'
            'Correct answer: Carbon dioxide (CO2).\n'
            'Response guidelines:\n'
            '- If correct: "Excellent! Carbon dioxide is the waste gas that must be removed from your body!"\n'
            '- If wrong: "The correct answer is carbon dioxide. It\'s a waste product that your cells produce and must be exhaled!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 4: Question 3 (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Question 3: Where does gas exchange take place?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 3: Where does gas exchange take place?\n'
            'Correct answer: Alveoli. Gas exchange occurs in the alveoli, not in the air passages like bronchi or trachea.\n'
            'Response guidelines:\n'
            '- If correct (alveoli): "Excellent! Gas exchange happens in the alveoli!"\n'
            '- If wrong (bronchi/trachea): "Not quite. Gas exchange occurs in the alveoli, not the air passages. The alveoli have thin walls perfect for diffusion!"\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 5: Encouragement (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'If you can answer these questions, you\'re doing SCI-mazing!',
          'Remember: Learning takes time, and every question helps you understand better!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Encouraging reflection
        waitForUser: false,
      ),

      // Step 6: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Any final questions about what we\'ve covered in this assessment?',
          'Type your question, or type "ready" to move to the bonus content!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If question: Answer thoroughly (2-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If ready: Say "Excellent assessment work! Tap Next for bonus content!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness.',
        pacingHint: PacingHint.normal,
      ),

      // Step 7: Completion (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'ve completed your assessment! Well done!',
          'Tap **Next** for bonus activities!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 3, MODULE 6: SCI-pplementary (The Respiratory System)
  /// Extension activities and health tips
  /// Duration: ~5 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptRespScipplementary() {
    return [
      // Step 0: Congratulations (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed the core lesson on the respiratory system!',
          'Ready for some bonus content?',
          'Welcome to **SCI-pplementary**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready for bonus content and health tips?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Did You Know (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Did you know?**',
          'Difficulty in breathing is called **dyspnea**. It may happen after heavy exercise or due to health conditions.',
          '**Amazing fact:** You take about 20,000 breaths per day!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Health Tips (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**To keep your respiratory system healthy in Roxas City:**',
          '✅ **Avoid smoking**\n✅ **Exercise regularly**\n✅ **Breathe clean air**\n✅ **Eat nutritious food**',
          'Healthy lungs mean more energy for learning and fun!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 4: Closing Celebration (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner!',
          'You\'ve learned how the respiratory system helps your body breathe and exchange gases!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 5: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Any final questions before we finish this lesson?',
          'Type your question, or type "done" to complete the lesson!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'If question: Answer thoroughly (2-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If done/finished/ready: Say "Congratulations! You\'ve mastered The Respiratory System! Tap Next to complete the lesson!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal they are finished.',
        pacingHint: PacingHint.normal,
      ),

      // Step 6: Final Completion (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Next, you\'ll discover how the respiratory and circulatory systems work together to keep you alive!',
          'Padayon sa pagtuon sa SCI-ensiya!',
          'Tap **Next** to complete this lesson!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 1, MODULE 2: Goal SCI-tting (The Circulatory System)
  /// Sets learning objectives for the entire lesson
  /// Duration: ~3 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptGoalScitting() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Now that you\'re Fa-SCI-nated, let\'s set our learning goals!',
          'Welcome to **Goal SCI-tting**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false, // Auto-continue
      ),

      // Step 1: First Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to see what you\'ll master today?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true, // Acknowledgment
      ),

      // Step 2: Present Learning Objectives (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:',
          '**1.** Compare the two types of circulatory systems and understand why humans have the system we do',
          '**2.** Describe the parts of the circulatory system and their functions—the heart, blood vessels, and more',
          '**3.** Explain the components of blood and how they help maintain homeostasis in your body',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false, // Auto-continue after displaying
      ),

      // Step 3: Motivation Message (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Think of these goals as your science destination—let\'s get there step by step!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 4: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great! You\'ve completed Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 5: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about our learning goals?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about the learning goals '
            '(circulatory system types, parts and functions, blood components and homeostasis) '
            'or signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 appropriate language and Roxas City context. '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Goal SCI-tting. Tap Next to explore Pre-SCI-ntation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed (e.g., "ready", "no questions", "let\'s continue").',
        pacingHint: PacingHint.normal,
      ),

      // Step 6: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 1, MODULE 3: Pre-SCI-ntation (The Circulatory System)
  /// Builds foundational understanding of homeostasis and why we need circulation
  /// Duration: ~7 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptPreScintation() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great job setting your learning goals!',
          'Now let\'s build the foundation.',
          'Welcome to **Pre-SCI-ntation** — let\'s start with the basics!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Homeostasis Introduction (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Let\'s start with the basics.',
          'Your body needs balance to survive—this balance is called **homeostasis**.',
          '**Homeostasis means:**\n• Nutrients are delivered to cells\n• Oxygen is supplied\n• Wastes like carbon dioxide are removed',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 2: Why We Need Circulatory System (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Small organisms rely on **diffusion**, but humans, like active students in Roxas City, need something faster and stronger.',
          'That\'s why we have a **circulatory system** powered by the heart, blood, and blood vessels.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Great! You\'ve completed Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 4: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we investigate deeper, do you have any questions about homeostasis or the circulatory system?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about homeostasis (nutrients delivered, oxygen supplied, wastes removed) '
            'or the circulatory system basics (heart, blood, blood vessels) or signaling readiness.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 appropriate language and Roxas City context. '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Pre-SCI-ntation. Tap Next to start Inve-SCI-tigation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 4: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to investigate!',
          'Tap **Next** to explore Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 1, MODULE 6: SCI-pplementary (The Circulatory System)
  /// Extension activities, health tips, and celebration
  /// Duration: ~5 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptScipplementary() {
    return [
      // Step 0: Congratulations Greeting (NARRATION)
      const ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed the core lesson on the circulatory system.',
          'Ready for some bonus content and fun activities?',
          'Welcome to **SCI-pplementary** — let\'s extend your learning!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Ready for bonus content?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Health Tips and Experiment (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Tips to Keep Your Circulatory System Healthy:**',
          '✅ **Exercise regularly** — At least 30 minutes daily\n✅ **Eat nutritious food** — Fruits, vegetables, lean protein (like bangus from Roxas!)\n✅ **Stay hydrated** — Drink 8 glasses of water daily\n✅ **Get enough sleep** — 8-10 hours for teenagers\n✅ **Avoid smoking** — It damages blood vessels',
          '**Try This Experiment:**',
          '**Feel Your Pulse!**\n1. Place two fingers on your wrist (below your thumb)\n2. Count beats for 15 seconds\n3. Multiply by 4 to get beats per minute\n4. Do jumping jacks for 1 minute\n5. Check pulse again — what changed?',
          'Your pulse rate increases during exercise because your muscles need more oxygen!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false, // Auto-continue after displaying
      ),

      // Step 3: Celebration Summary (NARRATION)
      const ScriptStep(
        botMessages: [
          'You\'ve completed the lesson on **The Circulation System**!',
          'You now understand how your heart pumps blood, the role of blood vessels, and why this system is essential for life.',
          'Keep taking care of your circulatory system!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

      // Step 4: Mandatory End-of-Module Q&A (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Any final questions before we finish this lesson?',
          'Type your question, or type "done" to complete the lesson!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'Final Q&A before lesson completion.\n'
            '\n'
            'If question: Answer thoroughly (2-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If done/finished/ready/complete: Say "Congratulations! You\'ve mastered The Circulation System! Tap Next to complete the lesson!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal they are finished.',
        pacingHint: PacingHint.normal,
      ),

      // Step 5: Final Completion (NARRATION)
      const ScriptStep(
        botMessages: [
          'Keep exploring, keep questioning, and keep learning!',
          'Tap **Next** to complete this lesson!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 1, MODULE 5: Self-A-SCI-ssment (The Circulatory System)
  /// Assessment questions to check understanding
  /// Duration: ~10 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptSelfAScissment() {
    return [
      // Step 0: Greeting with Assessment Context (NARRATION)
      const ScriptStep(
        botMessages: [
          'Wow, you\'ve learned so much about the circulatory system!',
          'Now it\'s time to test your understanding.',
          'Don\'t worry — this is to help you learn, not to stress you out.',
          'Welcome to **Self-A-SCI-ssment**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Ready to check your knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Assessment Question 1 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Question 1: What system transports oxygen and nutrients in the body?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 1: What system transports oxygen and nutrients?\n'
            'Correct answer: The circulatory system (or cardiovascular system).\n'
            'Response guidelines:\n'
            '- If correct: "Correct! The circulatory system is your body\'s delivery network!"\n'
            '- If wrong: "The correct answer is the circulatory system. Remember, it delivers oxygen and nutrients to every cell!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 3: Assessment Question 2 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Question 2: Which blood component helps fight infection?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 2: Which blood component fights infection?\n'
            'Correct answer: White blood cells (or leukocytes).\n'
            'Response guidelines:\n'
            '- If correct: "Excellent! White blood cells are your immune system warriors!"\n'
            '- If wrong: "The correct answer is white blood cells. They defend against bacteria and viruses!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 4: Assessment Question 3 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Question 3: Why is a closed circulatory system efficient for humans?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 3: Why is a closed circulatory system efficient?\n'
            'Correct concepts: Blood stays in vessels, flow is fast and directed, can deliver oxygen quickly to active muscles.\n'
            'Response guidelines:\n'
            '- If mentions speed/efficiency/vessels/fast delivery: "Great reasoning! Closed systems keep blood flowing fast in vessels for quick delivery!"\n'
            '- If vague: "Think about how blood stays in vessels and flows quickly to where it\'s needed."\n'
            '- If wrong: "A closed system is efficient because blood stays in vessels and flows quickly, delivering oxygen fast to active tissues!"\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 5: Encouragement (NARRATION)
      const ScriptStep(
        botMessages: [
          'If you can answer these questions, you\'re doing SCI-mazing!',
          'Remember: It\'s okay if you need to review. Learning takes time, and every question helps you understand better!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Encouraging reflection
        waitForUser: false,
      ),

      // Step 6: Mandatory End-of-Module Q&A (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Any final questions about what we\'ve covered in this assessment?',
          'Type your question, or type "ready" to move to the bonus content!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'Final Q&A for assessment module.\n'
            '\n'
            'If question: Answer thoroughly (2-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If ready: Say "Excellent assessment work! Tap Next for bonus content!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness.',
        pacingHint: PacingHint.normal,
      ),

      // Step 7: Completion (NARRATION)
      const ScriptStep(
        botMessages: [
          'You\'ve completed your assessment! Well done!',
          'Tap **Next** for bonus activities!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 1, MODULE 4: Inve-SCI-tigation (The Circulatory System)
  /// Deep dive into circulatory system types, heart, vessels, and blood
  /// Duration: ~20 minutes (longest module)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptInveScitigation() {
    return [
      // Step 0: Greeting (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You now have a solid foundation!',
          'Time to Inve-SCI-tigate deeper!',
          'Welcome to **Inve-SCI-tigation** — let\'s discover the details!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Part 1 - Types of Circulatory Systems (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 1: Types of Circulatory Systems**',
          'There are two types of circulatory systems:',
          '**1. Open Circulatory System**\n• Found in insects like crabs and grasshoppers\n• Blood flows freely and slowly\n• Best for small, less active animals',
          '**2. Closed Circulatory System (Humans!)**\n• Blood stays inside vessels\n• Pumped by the heart\n• Faster and more efficient—perfect for active lifestyles like swimming in Baybay or playing basketball after school',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 2: Part 2 - The Heart (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 2: The Heart – Your Body\'s Pump**',
          'Your heart is about the size of your clenched fist ✊',
          'It beats over 100,000 times a day—even while you sleep!',
          '**Key parts of the heart:**\n• **Atria** – receive blood\n• **Ventricles** – pump blood out\n• **Valves** – prevent backflow\n• **Septum** – separates left and right sides',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 3: Quick Check Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Quick Check:** Which chamber do you think has thicker walls—the atria or ventricles?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which chamber has thicker walls—atria or ventricles?"\n'
            'Correct answer: Ventricles have thicker walls because they need to pump blood out of the heart with more force.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 4: Part 3 - Blood Vessels (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 3: Blood Vessels – The Body\'s Roads**',
          'Think of blood vessels like the roads connecting barangays in Roxas City:',
          '**Arteries** – carry blood away from the heart\n**Veins** – bring blood back to the heart\n**Capillaries** – tiny paths where oxygen and nutrients are exchanged',
          'Without these "roads," cells would never receive what they need to survive.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 5: Part 4 - Blood Components (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 4: Blood – The Transport Medium**',
          'Blood makes up about 7–8% of your body weight.',
          '**Plasma (55%)**\n• Mostly water\n• Carries nutrients, hormones, and wastes',
          '**Red Blood Cells** – carry oxygen using hemoglobin\n**White Blood Cells** – defend against infection\n**Platelets** – help blood clot when you get a wound',
          'Every drop of blood plays a role in keeping you healthy and active!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 6: Transition to Q&A (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'Amazing work, investigator!',
          'You\'ve completed Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 7: Mandatory End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about circulatory systems, the heart, blood vessels, or blood?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about circulatory system types, heart parts, blood vessels, or blood components '
            'or signaling readiness.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 appropriate language and Roxas City context. '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Inve-SCI-tigation. Tap Next to test your knowledge in Self-A-SCI-ssment!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 8: Completion Marker (NARRATION - Speech Bubbles)
      const ScriptStep(
        botMessages: [
          'You\'re ready to test your knowledge!',
          'Tap **Next** to take the Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Generic fallback script for modules without a custom script.
  /// Sends the module content as bot messages and completes immediately.
  List<ScriptStep> _scriptGenericFallback() {
    return [
      const ScriptStep(
        botMessages: [
          'Let\'s explore this module together! Read through the content below, '
              'and tap **Next** when you\'re ready to continue.',
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 2: HEREDITY AND VARIATION
  /// LESSON 1: Genes and Chromosomes - Gregor Mendel
  /// -----------------------------------------------------------------------

  /// Module 1: Fa-SCI-nate
  List<ScriptStep> _scriptGenetics1Fascinate() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Welcome to another science adventure here in Roxas City!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Introduction (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Where family traits like smiles, dimples, or curly hair are often noticed during reunions and fiestas.',
          'Have you ever wondered why you look like your parents or why you share similar traits with your siblings?',
          '\nToday, we will explore **Genes and Chromosomes**—the tiny structures inside your cells that carry instructions making you YOU.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Ready to discover your biological blueprint?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      // Step 2: Scenario (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Imagine this... During a family gathering in Roxas City, someone says:',
          '"Ka-itsura mo guid imo iloy!" (You really look like your mother!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Why do you think family members look alike?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why do family members look alike?"\n'
            'Correct answer: Because of genes passed from parents to children.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 3: Module Complete & Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Great! You\'ve completed Fa-SCI-nate!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about genes or family traits?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session.\n'
            'If they ask a question: Answer thoroughly (3-4 sentences). '
            'DO NOT say "Tap Next".\n'
            'If they say "ready" or similar: '
            'Say "Excellent! You\'ve completed Fa-SCI-nate. Tap Next to set your learning goals!"\n',
        pacingHint: PacingHint.normal,
      ),
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Goal SCI-tting!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 2: Goal SCI-tting
  List<ScriptStep> _scriptGenetics1GoalScitting() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Welcome to **Goal SCI-tting**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Ready to unlock the secrets of your genetic code?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      const ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:\n\n'
          '1. Describe where genes are located in chromosomes\n'
          '2. Explain how genes determine traits\n'
          '3. Identify phenotypes as expressions of inherited traits\n\n'
          'These goals will help you understand why everyone in Capiz—and the world—is **unique**!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Do you have any questions about these learning goals?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session about the learning goals.\n'
            'If they ask a question: Answer thoroughly (2-3 sentences). '
            'DO NOT say "Tap Next".\n'
            'If they say "ready", "ok", "no", "let\'s go", or similar: '
            'Say "Excellent! You understand the goals. Tap Next to explore Pre-SCI-ntation!"\n',
        pacingHint: PacingHint.normal,
      ),
      const ScriptStep(
        botMessages: [
          'Perfect! Tap **Next** to explore Pre-SCI-ntation!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 3: Pre-SCI-ntation
  List<ScriptStep> _scriptGenetics1PreScintation() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Welcome to **Pre-SCI-ntation**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to dive into the details?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      const ScriptStep(
        botMessages: [
          'Let\'s build your foundation!',
          'For a long time, people had different ideas about heredity.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Some believed traits came from blood. Others believed traits were blended from parents.',
          'But science has shown us that traits are passed through **genes**, not blood.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'These genes are found in **DNA**, which is packed inside **chromosomes**.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Think of it like this:\n',
          '📖 DNA = The instruction manual',
          '📝 Genes = Individual instructions',
          '📚 Chromosomes = Chapters organizing the instructions',
          '🏛️ Nucleus = The library storing all manuals',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
       const ScriptStep(
        botMessages: [
          'Do you have any questions about these learning goals?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session about the learning goals.\n'
            'If they ask a question: Answer thoroughly (2-3 sentences). '
            'DO NOT say "Tap Next".\n'
            'If they say "ready", "ok", "no", "let\'s go", or similar: '
            'Say "Excellent! You understand the goals. Tap Next to explore Inve-SCI-tigation!"\n',
        pacingHint: PacingHint.normal,
      ),
      const ScriptStep(
        botMessages: [
          'Perfect! Tap **Next** to explore Inve-SCI-tigation!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 4: Inve-SCI-tigation
  List<ScriptStep> _scriptGenetics1InveScitigation() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Part 1 Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Let\'s explore genes and chromosomes in detail.',
          '\n**Part 1: Genes and Chromosomes**',
          'Genes are segments of DNA.',
          'Chromosomes are threadlike structures that carry genes.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Where are chromosomes found in most human cells?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Where are chromosomes found?"\n'
            'Correct answer: Nucleus.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 2: Part 2 Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 2: Human Chromosomes**',
          'Each human body cell has **46 chromosomes**, arranged in **23 pairs**.',
          'One set comes from your mother, and one from your father.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**What do we call cells with two sets of chromosomes?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What are cells with two sets of chromosomes called?"\n'
            'Correct answer: Diploid.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 3: Part 3 Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 3: DNA and the Genetic Code**',
          'DNA looks like a twisted ladder, called a **double helix**.',
          'It is made of four bases: A (Adenine), T (Thymine), G (Guanine), C (Cytosine).',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Which bases pair together?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which DNA bases pair together?"\n'
            'Correct answer: A-T and G-C.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 4: Part 4 Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 4: Genotype and Phenotype**',
          'Your **genotype** is the set of genes you inherit.',
          'Your **phenotype** is what you can observe, like hair texture or eye color.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Which of these is a phenotype?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which is a phenotype?"\n'
            'Correct answer: Curly hair (observable trait).\n'
            'Incorrect: DNA sequence (that\'s genotype).\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Correct!", "Excellent!", "You got it!", "Perfect!") + explanation that curly hair is observable phenotype\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!") + hint that phenotypes are observable traits not DNA\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 5: Part 5 Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Part 5: Heredity and Environment**',
          'Genes are important—but the environment matters too!',
          'For example, many people in Roxas City get darker skin after spending time under the sun.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Which affects traits like skin color?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What affects traits like skin color?"\n'
            'Correct answer: Both heredity and environment.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 6: Module Complete & Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Amazing work! You\'ve investigated the world of genes and chromosomes!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about genes, chromosomes, or DNA?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session.\n'
            'If they ask a question: Answer thoroughly. DO NOT say "Tap Next".\n'
            'If they say "ready": Say "Excellent! Tap Next to test your knowledge!"\n',
      ),
      const ScriptStep(
        botMessages: [
          'You\'re ready for the assessment!',
          'Tap **Next** to explore Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 5: Self-A-SCI-ssment
  List<ScriptStep> _scriptGenetics1SelfAScissment() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Time for Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Assessment Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Let\'s check what you\'ve learned!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Question 1: What carries genes—DNA or blood?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What carries genes?"\n'
            'Correct answer: DNA.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Question 2: What is the difference between genotype and phenotype?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Difference between genotype and phenotype?"\n'
            'Correct answer: Genotype is the set of genes, phenotype is the observable traits.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Question 3: Why must sex cells be haploid?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why must sex cells be haploid?"\n'
            'Correct answer: Because chromosome number must stay constant after fertilization.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 2: Module Complete & Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Excellent work on the assessment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Any final questions before we wrap up?',
          'Type your question, or type "done" if you\'re ready to finish.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: Final Q&A for the module.\n'
            'If they ask: Answer thoroughly.\n'
            'If they say "done" or "ready": Say "Great job! Tap Next for interesting facts!"\n',
      ),
      const ScriptStep(
        botMessages: [
          'You\'re doing great!',
          'Tap **Next** for SCI-pplementary facts!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 6: SCI-pplementary
  List<ScriptStep> _scriptGenetics1Scipplementary() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'SCI-pplementary facts!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Supplementary Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Humans have around **20,000–25,000 genes**!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Traits like height, weight, and even talents are shaped by genes **and** environment.',
          'Celebrate your uniqueness—because no one else has your exact genetic combination!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner!',
          'You\'ve explored the world of genes and chromosomes—the foundation of heredity.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'In the next lesson, we\'ll learn how traits are passed on from parents to offspring.',
          '**Padayon sa tu-on sa SCI-ensiya!** (Continue learning science!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      // Step 2: Module Complete (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed Genes and Chromosomes!',
          'Tap **Next** to continue your learning journey!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 2: Non-Mendelian Inheritance - Gregor Mendel
  /// -----------------------------------------------------------------------

  /// Module 1: Fa-SCI-nate
  List<ScriptStep> _scriptInheritFascinate() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Welcome back to our science journey here in Roxas City, Capiz!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Introduction (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Where family resemblances are often noticed during fiestas, reunions, and even at the streets.',
          '\nYou already know that traits are passed from parents to children.',
          'But did you know that not all traits follow Mendel\'s simple rules?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Today, we\'ll explore **Non-Mendelian Inheritance**!',
          'Patterns that explain why traits like blood type, skin color, and some diseases don\'t follow the usual dominant–recessive pattern.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Ready to level up your genetics knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      // Step 2: Scenario (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Imagine this...',
          'In a family from Roxas City, one child has blood type AB, while the parents have type A and type B.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**How is that possible?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "How can parents with A and B blood have an AB child?"\n'
            'Correct answer: Because of multiple alleles or codominance.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 3: Module Complete & Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Great! You\'ve completed Fa-SCI-nate!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about non-Mendelian inheritance?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session.\n'
            'If they ask: Answer thoroughly. DO NOT say "Tap Next".\n'
            'If they say "ready": Say "Excellent! Tap Next to set your learning goals!"\n',
      ),
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Goal SCI-tting!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 2: Goal SCI-tting
  List<ScriptStep> _scriptInheritGoalScitting() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Welcome to **Goal SCI-tting**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Ready to explore these complex patterns?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      const ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:\n\n'
          '1. Explain different patterns of non-Mendelian inheritance\n'
          '2. Differentiate multiple alleles and polygenic traits\n'
          '3. Explain why sex-linked traits are more common in males\n\n'
          'These goals will help you understand complex traits in real life!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Do you have any questions about these learning goals?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session about the learning goals.\n'
            'If they ask a question: Answer thoroughly (2-3 sentences). '
            'DO NOT say "Tap Next".\n'
            'If they say "ready", "ok", "no", "let\'s go", or similar: '
            'Say "Excellent! You understand the goals. Tap Next to explore Pre-SCI-ntation!"\n',
        pacingHint: PacingHint.normal,
      ),
      const ScriptStep(
        botMessages: [
          'Perfect! Tap **Next** to explore Pre-SCI-ntation!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 3: Pre-SCI-ntation
  List<ScriptStep> _scriptInheritPreScintation() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Welcome to Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Let\'s build your foundation!',
          'Gregor Mendel discovered basic rules of inheritance using pea plants.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'However, scientists later found that many traits do **not** follow Mendel\'s rules.',
          'These traits follow **Non-Mendelian inheritance**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'In Non-Mendelian inheritance:',
          '• Traits may blend',
          '• Both alleles may be expressed',
          '• More than two alleles may exist',
          '• Traits may depend on many genes',
          '• Traits may be linked to sex chromosomes',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Ready to dive into the details?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      const ScriptStep(
        botMessages: [
          'Excellent! Tap **Next** to begin Inve-SCI-tigation!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 4: Inve-SCI-tigation
  List<ScriptStep> _scriptInheritInveScitigation() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Welcome to Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate!',
          'Let\'s explore the different patterns of non-Mendelian inheritance.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Part 1: Incomplete Dominance**',
          'In incomplete dominance, neither allele is fully dominant.',
          'The heterozygous individual shows a **blended or intermediate** trait.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Example: Red flower + White flower → **Pink flower**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**What phenotype appears in a heterozygous individual?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What phenotype in incomplete dominance?"\n'
            'Correct answer: A blended trait.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Part 2: Codominance**',
          'In codominance, both alleles are **equally expressed**.',
          'Example: Blood type AB shows both A and B antigens.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Is there a recessive allele in codominance?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Is there a recessive allele in codominance?"\n'
            'Correct answer: No.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Correct!", "Excellent!", "You got it!", "Perfect!") + explanation that both alleles are equally expressed\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!") + hint that codominance means both alleles expressed equally\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Part 3: Multiple Alleles**',
          'Multiple alleles mean that **more than two alleles** exist for a trait.',
          'Example: ABO blood group system has alleles A, B, and O.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Even though there are three alleles, a person only gets **two**—one from each parent.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Which blood type is recessive?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which blood type is recessive?"\n'
            'Correct answer: O.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Part 4: Polygenic Traits**',
          'Some traits are controlled by **many genes** working together.',
          'These are called polygenic traits.',
          'Examples: Height, skin color, hair color.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Why do people in Roxas City have different skin shades?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why different skin shades?"\n'
            'Correct answer: Because of many genes and environment.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Part 5: Sex-linked Traits**',
          'Some genes are found on the **X chromosome**.',
          'These traits are called sex-linked traits.',
          'They are more common in **males** because males have only one X chromosome.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Which condition is a sex-linked trait?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which is a sex-linked trait?"\n'
            'Correct answer: Hemophilia.\n'
            'Incorrect: Height or blood type (not sex-linked).\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          'Amazing work! You\'ve investigated all the non-Mendelian patterns!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Before we move on, any questions about these inheritance patterns?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session.\n'
            'If they ask: Answer thoroughly. DO NOT say "Tap Next".\n'
            'If they say "ready": Say "Excellent! Tap Next to test your knowledge!"\n',
      ),
      const ScriptStep(
        botMessages: [
          'You\'re ready for the assessment!',
          'Tap **Next** to explore Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 5: Self-A-SCI-ssment
  List<ScriptStep> _scriptInheritSelfAScissment() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Welcome to Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Let\'s check your understanding!',
          'Time for Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          '**Question 1: What is the difference between incomplete dominance and codominance?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Difference between incomplete dominance and codominance?"\n'
            'Correct answer: Incomplete dominance = blended, Codominance = both expressed.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Question 2: Why are polygenic traits more varied?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why are polygenic traits varied?"\n'
            'Correct answer: Because many genes contribute.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          '**Question 3: Why are sex-linked traits more common in males?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why are sex-linked traits more common in males?"\n'
            'Correct answer: Because males have only one X chromosome.\n'
            'Response guidelines:\n'
            '- If CORRECT: Start with enthusiastic encouragement ("Excellent!", "Perfect!", "You got it!", "Spot on!", "Absolutely right!") + brief explanation\n'
            '- If PARTIALLY CORRECT: Start with gentle encouragement ("You\'re on the right track!", "Almost there!", "Good thinking, but...", "Not quite, but close!") + clarification\n'
            '- If WRONG: Start with supportive encouragement ("Let\'s try again!", "Think about it this way...", "Give it another shot!", "Let me help you...") + hint or explanation\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      const ScriptStep(
        botMessages: [
          'Excellent work on the assessment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Any final questions before we wrap up?',
          'Type your question, or type "done" if you\'re ready to finish.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: Final Q&A.\n'
            'If they ask: Answer thoroughly.\n'
            'If they say "done": Say "Great job! Tap Next for interesting facts!"\n',
      ),
      const ScriptStep(
        botMessages: [
          'You\'re doing great!',
          'Tap **Next** for SCI-pplementary facts!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// Module 6: SCI-pplementary
  List<ScriptStep> _scriptInheritScipplementary() {
    return [
      // Step 0: Initial Greeting (NARRATION - Speech Bubble ONLY)
      const ScriptStep(
        botMessages: [
          'Welcome to SCI-pplementary!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
      // Step 1: Module Content (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Did you know?**',
          'About 5% of Asian males have some form of **color blindness**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Today, special eyeglasses can help people with color blindness see better.',
          'Understanding genetics helps families make informed health decisions.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner!',
          'You\'ve learned how traits can be inherited in more complex ways than Mendel first discovered.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'In the next lesson, we\'ll explore probability and inheritance patterns.',
          '**Padayon sa pagtu-on sa SCI-ensiya!** (Continue learning science!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
      const ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      const ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed Non-Mendelian Inheritance!',
          'Tap **Next** to continue your learning journey!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 1: Fa-SCI-nate (Plant Photosynthesis)
  /// Script follows PDF: "ENERGY IN THE ECOSYSTEM - LESSON 1"
  /// Duration: ~5 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoFascinate() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner!',
          'Welcome to another science adventure here in Roxas City, where rice fields, mangroves, and backyard plants turn sunlight into life-sustaining energy.',
          'Have you ever wondered how plants grow tall even though they don\'t eat like humans do?',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Lesson Introduction (NARRATIVE)
      const ScriptStep(
        botMessages: [
          'Today\'s lesson is about **photosynthesis**, the process that powers plants and supports all life in the ecosystem, including us.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 2: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to follow the path of energy from the Sun to living things?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 3: Scenario Setup (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Imagine this...',
          'You walk past a rice field in Capiz at noon. The Sun is bright, and the leaves are wide open.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 4: First Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**What do you think plants are doing under the sunlight?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What do plants do under sunlight?"\n'
            'Correct answer concept: Plants use sunlight to make their own food through photosynthesis. '
            'They convert light energy into chemical energy stored in glucose.\n'
            'Response guidelines:\n'
            '- If CORRECT (mentions making food, photosynthesis, or producing energy): '
            'Start with "Correct!" or "Exactly!" + brief explanation\n'
            '- If PARTIALLY CORRECT (mentions absorbing light but not making food): '
            'Start with "You\'re on the right track!" + clarification\n'
            '- If WRONG (says resting or just absorbing heat): '
            'Start with "Not quite." + hint that plants use light energy to produce food\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 5: Explanation (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Plants use sunlight to **make their own food** through photosynthesis.',
          'Plants don\'t just absorb heat—they use **light energy to produce food**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 6: Transition (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve completed the Fa-SCI-nate module.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 7: End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about photosynthesis or how plants make food?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about photosynthesis basics '
            '(how plants make food, sunlight, energy) or signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 '
            'appropriate language and Roxas City context (rice fields, mangroves, etc). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Fa-SCI-nate. Tap Next to set your learning goals!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 8: Completion Marker (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 2: Goal SCI-tting (Plant Photosynthesis)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoGoalScitting() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Learning Goals (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '## 🎯 By the end of this lesson, you will be able to:',
          '✅ **Describe the cell structures involved in photosynthesis**',
          '✅ **Differentiate light-dependent and light-independent reactions**',
          '✅ **Explain how some plants adapt to hot and dry environments**',
          '✅ **Explain why photosynthesis is important to other organisms**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'These goals will help you understand **where energy in the ecosystem begins**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to learn about photosynthesis?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 4: End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about these learning goals or photosynthesis basics?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about the learning goals or photosynthesis basics '
            '(cell structures, reactions, adaptations, importance to other organisms) or signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 '
            'appropriate language and Roxas City context (rice fields, mangroves, etc). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Fantastic! You\'re ready to explore photosynthesis. Tap Next to start Pre-SCI-ntation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 5: Completion Marker (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Fantastic! Let\'s explore how plants capture sunlight and turn it into energy!',
          'Tap **Next** to continue!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 3: Pre-SCI-ntation (Plant Photosynthesis)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoPreScintation() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Foundation (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Not all organisms get energy the same way.**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Autotrophs** (like plants) make their own food.',
          '**Heterotrophs** (like humans and animals) depend on other organisms.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Photosynthesis happens only in **photoautotrophs**, such as green plants.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Without photosynthesis, there would be no food and no oxygen for life on Earth.**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to explore how this amazing process works?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 7: End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about autotrophs, heterotrophs, or why photosynthesis is important?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about autotrophs (organisms that make their own food), '
            'heterotrophs (organisms that depend on others), photoautotrophs (green plants), or the importance '
            'of photosynthesis to life on Earth, OR signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 '
            'appropriate language and Roxas City context (rice fields, mangroves, etc). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Great! You understand the foundation. Tap Next to investigate photosynthesis in detail!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 8: Completion Marker (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Great! You now understand the foundation.',
          'Tap **Next** to investigate photosynthesis in detail!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 4: Inve-SCI-tigation (Plant Photosynthesis)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoInveScitigation() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Inve-SCI-tigation!',
          'Let\'s discover where and how photosynthesis happens!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Part 1 - Where Photosynthesis Happens (INTERACTION)
      const ScriptStep(
        botMessages: [
          '## Part 1: Where Photosynthesis Happens',
          'Photosynthesis mainly occurs in the **leaves** of plants.',
          'Inside leaf cells are organelles called **chloroplasts**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Which structure is the site of photosynthesis?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which structure is the site of photosynthesis?"\n'
            'Correct answer: Chloroplast (or chloroplasts)\n'
            'Response guidelines:\n'
            '- If CORRECT (mentions chloroplast): "Correct! Chloroplasts are the site of photosynthesis."\n'
            '- If says mitochondria: "Not quite. Mitochondria do cellular respiration. The correct answer is chloroplasts."\n'
            '- If says nucleus: "Not quite. The nucleus contains DNA. The correct answer is chloroplasts."\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 2: Part 2 - Chloroplast Structure (INTERACTION)
      const ScriptStep(
        botMessages: [
          '## Part 2: Chloroplast Structure',
          'Inside the chloroplast are important parts:',
          '• **Thylakoids** – where light-dependent reactions occur',
          '• **Grana** – stacks of thylakoids',
          '• **Stroma** – where light-independent reactions occur',
          '• **Chlorophyll** – the green pigment that traps sunlight',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Where do light-dependent reactions occur?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Where do light-dependent reactions occur?"\n'
            'Correct answer: Thylakoids (or thylakoid membranes)\n'
            'Response guidelines:\n'
            '- If CORRECT (mentions thylakoid/thylakoids): "Correct! Light-dependent reactions occur in the thylakoids."\n'
            '- If says stroma: "Not quite. The stroma is where light-independent reactions occur. Light-dependent reactions happen in thylakoids."\n'
            'Keep response to 2 sentences maximum.',
      ),

      // Step 3: Part 3 - Two Stages (INTERACTION)
      const ScriptStep(
        botMessages: [
          '## Part 3: Two Stages of Photosynthesis',
          'Photosynthesis has **two stages**:',
          '**1️⃣ Light-dependent reactions** – Require sunlight, produce ATP, NADPH, and oxygen',
          '**2️⃣ Light-independent reactions (Calvin Cycle)** – Occur in the stroma, use ATP and NADPH to produce glucose',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Which stage produces glucose?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which stage produces glucose?"\n'
            'Correct answer: Light-independent reactions (or Calvin Cycle, or dark reactions)\n'
            'Response guidelines:\n'
            '- If CORRECT: "Correct! Glucose is produced in the light-independent reactions (Calvin Cycle)."\n'
            '- If says light-dependent: "Not quite. Light-dependent reactions produce ATP and oxygen. Glucose is made in light-independent reactions."\n'
            'Keep response to 2 sentences maximum.',
      ),

      // Step 4: Part 4 - Light and Pigments (INTERACTION)
      const ScriptStep(
        botMessages: [
          '## Part 4: Light and Pigments',
          'Chlorophyll **absorbs** red and blue/violet light and **reflects** green light.',
          'This is why leaves look green!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Why do leaves appear green?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why do leaves appear green?"\n'
            'Correct answer: Because they reflect green light (chlorophyll reflects green)\n'
            'Response guidelines:\n'
            '- If CORRECT (mentions reflecting green light): "Correct! Leaves appear green because they reflect green light."\n'
            '- If says they absorb green: "Not quite. Chlorophyll absorbs red and blue light, but reflects green. That\'s why we see green!"\n'
            'Keep response to 2 sentences maximum.',
      ),

      // Step 5: Part 5 - Plant Adaptations (INTERACTION)
      const ScriptStep(
        botMessages: [
          '## Part 5: Plant Adaptations (C₄ and CAM)',
          'In hot and dry places, plants may lose too much water.',
          'Some plants adapt using special pathways:',
          '• **C₄ plants** (corn, sugarcane)',
          '• **CAM plants** (cactus, pineapple)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'CAM plants open their stomata during the **night** to conserve water.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Which plants open stomata at night?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which plants open stomata at night?"\n'
            'Correct answer: CAM plants\n'
            'Response guidelines:\n'
            '- If CORRECT (mentions CAM plants): "Correct! CAM plants open stomata at night to conserve water."\n'
            '- If says C₄ plants: "Not quite. C₄ plants open during the day. CAM plants open stomata at night."\n'
            'Keep response to 2 sentences maximum.',
      ),

      // Step 6: Conclusion (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Excellent work! You\'ve explored how photosynthesis works inside plant cells.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 7: End-of-Module Q&A (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Do you have any questions about chloroplasts, the stages of photosynthesis, or plant adaptations?',
          'Type your question, or type "ready" to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session.\n'
            '\n'
            'The student is either asking a question about photosynthesis details '
            '(chloroplasts, thylakoids, stroma, light reactions, Calvin cycle, C4/CAM plants) '
            'or signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences) using Grade 9 language and Roxas City context. '
            'DO NOT say "Tap Next".\n'
            '\n'
            'If they say "ready", "ok", "no questions", etc: '
            'Say "Excellent! You\'ve completed Inve-SCI-tigation. Tap Next to test your knowledge!"',
        pacingHint: PacingHint.normal,
      ),

      // Step 8: Completion (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'You\'re ready to test your knowledge!',
          'Tap **Next** for the Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 5: Self-A-SCI-ssment (Plant Photosynthesis)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoSelfAScissment() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Assessment Introduction (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Let\'s check your understanding of photosynthesis!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Question 1
      const ScriptStep(
        botMessages: [
          '**Question 1:** What are the two stages of photosynthesis?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student should identify: (1) Light-dependent reactions and (2) Light-independent reactions (Calvin Cycle).\n'
            'If CORRECT: Praise + brief confirmation.\n'
            'If INCORRECT/PARTIAL: Provide gentle correction with the answer.\n'
            'Keep to 2-3 sentences.',
      ),

      // Question 2
      const ScriptStep(
        botMessages: [
          '**Question 2:** What is the role of chlorophyll?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student should mention: Chlorophyll absorbs light energy and captures sunlight for photosynthesis.\n'
            'If CORRECT: Praise + confirmation.\n'
            'If INCORRECT: Provide correction.\n'
            'Keep to 2-3 sentences.',
      ),

      // Question 3
      const ScriptStep(
        botMessages: [
          '**Question 3:** Why are C₄ and CAM plants adapted to hot environments?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student should mention: To reduce water loss in hot/dry conditions.\n'
            'If CORRECT: "Correct! These adaptations help plants reduce water loss."\n'
            'If INCORRECT: Provide correction.\n'
            'Keep to 2-3 sentences.',
      ),

      // Conclusion
      const ScriptStep(
        botMessages: [
          'Great job completing the assessment!',
          'You now understand the key concepts of photosynthesis.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to explore supplementary content?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      const ScriptStep(
        botMessages: [
          'Excellent work, SCI-learner!',
          'Tap **Next** for SCI-pplementary content!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 6: SCI-pplementary (Plant Photosynthesis)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoScipplementary() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to SCI-pplementary!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Did You Know (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Did you know?**',
          'Photosynthesis is the foundation of all food chains.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'The rice you eat, the fish you enjoy, and even the oxygen you breathe—all depend on photosynthesis.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Protecting plants means protecting life in Roxas City and beyond!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve learned how plants capture sunlight and turn it into energy.',
          'Next, we\'ll explore how organisms release that energy through cellular respiration.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Padayon sa pagtu-on sa SCI-ensiya!** (Continue learning science!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      const ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed Plant Photosynthesis!',
          'Tap **Next** to continue your learning journey!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 1: Fa-SCI-nate (Metabolism)
  /// Script follows PDF: "ENERGY IN THE ECOSYSTEM - LESSON 2"
  /// Duration: ~5 minutes
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptMetabFascinate() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Welcome back to our science journey here in Roxas City.',
          'Walking to school, playing basketball, and helping at home all require energy.',
          'You learned in the previous lesson how plants store energy through photosynthesis.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Lesson Introduction (NARRATIVE)
      const ScriptStep(
        botMessages: [
          'Today, we\'ll discover how your body and other organisms release that stored energy through a process called **cellular respiration**.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 2: Ready Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to find out where your energy really comes from? ⚡',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 3: Scenario Setup (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Imagine this...',
          'You\'re playing basketball at the Villareal Stadium. After a few minutes, your arms feel tired and your breathing gets faster.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 4: Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**What do you think is happening inside your cells?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What is happening inside your cells during exercise?"\n'
            'Correct answer concept: Cells are breaking down food/glucose to release energy (ATP). '
            'Cellular respiration is occurring to provide energy for muscle movement.\n'
            'Response guidelines:\n'
            '- If CORRECT (mentions releasing energy, breaking down food, cellular respiration): '
            '"Correct! Your cells are breaking down food to release energy."\n'
            '- If says storing food: "Not quite. During activity, cells release energy, not store it."\n'
            '- If says resting: "Not quite. During activity, cells are actively releasing energy."\n'
            'Keep response to 2-3 sentences maximum.',
      ),

      // Step 5: Explanation (INTERACTION)
      const ScriptStep(
        botMessages: [
          'During activity, cells **release energy**, not store or rest.',
          'Your cells break down food molecules to power your movements!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Step 6: Transition (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve completed the Fa-SCI-nate module.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 7: End-of-Module Q&A (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about cellular energy or metabolism?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session.\n'
            '\n'
            'The student is either asking a question about cellular energy/metabolism basics or signaling readiness.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences) using Grade 9 language and Roxas City context. '
            'DO NOT say "Tap Next".\n'
            '\n'
            'If they say "ready", "ok", "no questions", etc: '
            'Say "Excellent! You\'ve completed Fa-SCI-nate. Tap Next to set your learning goals!"',
        pacingHint: PacingHint.normal,
      ),

      // Step 8: Completion (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'You\'re ready to move forward!',
          'Tap **Next** to explore Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 2: Goal SCI-tting (Metabolism)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptMetabGoalScitting() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Learning Goals (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '## 🎯 By the end of this lesson, you will be able to:',
          '✅ **Explain what cellular respiration is**',
          '✅ **Identify the stages of cellular respiration**',
          '✅ **Differentiate aerobic and anaerobic respiration**',
          '✅ **Compare the energy produced in each process**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'These goals will help you understand **how energy flows in living things**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to learn about cellular respiration?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 4: End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about these learning goals or cellular respiration basics?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about the learning goals or cellular respiration basics '
            '(what it is, stages, aerobic vs anaerobic, energy production) or signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 '
            'appropriate language and Roxas City context (running at Villareal Stadium, rice farming, etc). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Fantastic! You\'re ready to learn about cellular respiration. Tap Next to start Pre-SCI-ntation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 5: Completion Marker (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Fantastic! Let\'s explore how cells release energy!',
          'Tap **Next** to continue!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 3: Pre-SCI-ntation (Metabolism)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptMetabPreScintation() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Foundation (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**All living organisms need energy to survive.**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Plants store energy in food during **photosynthesis**.',
          'Animals—including humans—release that energy through **cellular respiration**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Cellular respiration is part of **metabolism**, the sum of all chemical processes in cells.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Metabolism has two parts:',
          '• **Anabolism** – building molecules',
          '• **Catabolism** – breaking down molecules to release energy',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to explore how cells release energy?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 7: End-of-Module Q&A (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Before we move on, do you have any questions about metabolism, anabolism, catabolism, or cellular respiration?',
          'Type your question, or type "ready" if you\'re ready to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about metabolism (all chemical processes in cells), '
            'anabolism (building molecules), catabolism (breaking down molecules), cellular respiration '
            '(how cells release energy), or the relationship between photosynthesis and respiration, '
            'OR signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it thoroughly (3-4 sentences) using Grade 9 '
            'appropriate language and Roxas City context (running at Villareal Stadium, rice farming, etc). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Great! You understand the foundation. Tap Next to investigate cellular respiration in detail!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 8: Completion Marker (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Great! You now understand the foundation.',
          'Tap **Next** to investigate cellular respiration in detail!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 4: Inve-SCI-tigation (Metabolism)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptMetabInveScitigation() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Inve-SCI-tigation!',
          'Let\'s discover how cells release energy!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Part 1: What is Cellular Respiration
      const ScriptStep(
        botMessages: [
          '## Part 1: What Is Cellular Respiration?',
          'Cellular respiration is a catabolic process that produces **ATP**, the energy currency of the cell.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Which molecule is the main energy carrier in cells?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which molecule is the main energy carrier?"\n'
            'Correct answer: ATP (Adenosine Triphosphate)\n'
            'Response guidelines:\n'
            '- If CORRECT: "Correct! ATP is the molecule cells use for energy."\n'
            '- If says glucose: "Not quite. Glucose stores energy, but ATP is the direct energy carrier."\n'
            '- If says oxygen: "Not quite. Oxygen helps produce ATP, but ATP itself is the energy carrier."\n'
            'Keep to 2 sentences.',
      ),

      // Part 2: Stages of Cellular Respiration
      const ScriptStep(
        botMessages: [
          '## Part 2: Stages of Cellular Respiration',
          'Cellular respiration has three main stages:',
          '**1️⃣ Glycolysis** – occurs in the cytoplasm',
          '**2️⃣ Krebs Cycle** – occurs in the mitochondrial matrix',
          '**3️⃣ Electron Transport Chain** – occurs in the inner mitochondrial membrane',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Where does glycolysis occur?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Where does glycolysis occur?"\n'
            'Correct answer: Cytoplasm\n'
            'Response guidelines:\n'
            '- If CORRECT: "Correct! Glycolysis occurs in the cytoplasm."\n'
            '- If says mitochondrion: "Not quite. Glycolysis occurs in the cytoplasm, outside the mitochondrion."\n'
            'Keep to 2 sentences.',
      ),

      // Part 3: Aerobic Respiration
      const ScriptStep(
        botMessages: [
          '## Part 3: Aerobic Respiration',
          'Aerobic respiration happens in the **presence of oxygen**.',
          'It includes oxidation of pyruvic acid, Krebs cycle, and electron transport chain.',
          'This process can produce up to **36 ATP** molecules from one glucose.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Which gas is the final electron acceptor?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which gas is the final electron acceptor?"\n'
            'Correct answer: Oxygen (O₂)\n'
            'Response guidelines:\n'
            '- If CORRECT: "Correct! Oxygen is the final electron acceptor."\n'
            '- If says carbon dioxide: "Not quite. Carbon dioxide is a product, not an acceptor. Oxygen is the final electron acceptor."\n'
            'Keep to 2 sentences.',
      ),

      // Part 4: Anaerobic Respiration
      const ScriptStep(
        botMessages: [
          '## Part 4: Anaerobic Respiration (Fermentation)',
          'When oxygen is limited, cells use anaerobic respiration or fermentation.',
          'There are two types:',
          '• **Alcoholic fermentation** – produces alcohol and CO₂',
          '• **Lactic acid fermentation** – produces lactic acid',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Which type occurs in human muscles during strenuous exercise?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which fermentation occurs in human muscles?"\n'
            'Correct answer: Lactic acid fermentation\n'
            'Response guidelines:\n'
            '- If CORRECT: "Correct! Human muscles use lactic acid fermentation during strenuous exercise."\n'
            '- If says alcoholic: "Not quite. Alcoholic fermentation occurs in yeast. Humans use lactic acid fermentation."\n'
            'Keep to 2 sentences.',
      ),

      // Part 5: Energy Comparison
      const ScriptStep(
        botMessages: [
          '## Part 5: Energy Comparison',
          'Let\'s compare energy yield:',
          '• **Aerobic respiration** – 36 ATP',
          '• **Anaerobic respiration** – 2 ATP',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          '**Which process produces more energy?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which process produces more energy?"\n'
            'Correct answer: Aerobic respiration\n'
            'Response guidelines:\n'
            '- If CORRECT: "Correct! Aerobic respiration produces much more ATP (36 vs 2)."\n'
            '- If says anaerobic: "Not quite. Anaerobic produces only 2 ATP. Aerobic produces 36 ATP."\n'
            'Keep to 2 sentences.',
      ),

      // Conclusion
      const ScriptStep(
        botMessages: [
          'Excellent work! You\'ve explored how cells release energy through cellular respiration.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // End-of-Module Q&A
      const ScriptStep(
        botMessages: [
          'Do you have any questions about cellular respiration, ATP, or the difference between aerobic and anaerobic respiration?',
          'Type your question, or type "ready" to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session.\n'
            '\n'
            'The student is either asking a question about cellular respiration details or signaling readiness.\n'
            '\n'
            'If they ask a question: Answer thoroughly (3-4 sentences) using Grade 9 language and Roxas City context. '
            'DO NOT say "Tap Next".\n'
            '\n'
            'If they say "ready", "ok", "no questions", etc: '
            'Say "Excellent! You\'ve completed Inve-SCI-tigation. Tap Next to test your knowledge!"',
        pacingHint: PacingHint.normal,
      ),

      // Completion
      const ScriptStep(
        botMessages: [
          'You\'re ready to test your knowledge!',
          'Tap **Next** for the Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 5: Self-A-SCI-ssment (Metabolism)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptMetabSelfAScissment() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Assessment Introduction (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Let\'s check your understanding!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      // Question 1
      const ScriptStep(
        botMessages: [
          '**Question 1:** What is the role of ATP?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student should mention: ATP is the energy currency of cells, used to power cellular activities.\n'
            'If CORRECT: Praise + brief confirmation.\n'
            'If INCORRECT: Provide gentle correction.\n'
            'Keep to 2-3 sentences.',
      ),

      // Question 2
      const ScriptStep(
        botMessages: [
          '**Question 2:** Why is glycolysis important?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student should mention: Glycolysis is the first step of cellular respiration and works with or without oxygen.\n'
            'If CORRECT: Praise + confirmation.\n'
            'If INCORRECT: Provide correction.\n'
            'Keep to 2-3 sentences.',
      ),

      // Question 3
      const ScriptStep(
        botMessages: [
          '**Question 3:** Why do muscles feel tired during intense exercise?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student should mention: Because lactic acid builds up when muscles use anaerobic respiration.\n'
            'If CORRECT: "Correct! Lactic acid buildup causes muscle fatigue."\n'
            'If INCORRECT: Provide correction.\n'
            'Keep to 2-3 sentences.',
      ),

      // Conclusion
      const ScriptStep(
        botMessages: [
          'Great job completing the assessment!',
          'You now understand how cells release energy.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to explore supplementary content?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      const ScriptStep(
        botMessages: [
          'Excellent work, SCI-learner!',
          'Tap **Next** for SCI-pplementary content!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 6: SCI-pplementary (Metabolism)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptMetabScipplementary() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Welcome to SCI-pplementary!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      // Step 1: Did You Know (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Did you know?**',
          'The energy from the rice you eat in Capiz fuels your cells through cellular respiration.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Photosynthesis and respiration are opposite but connected processes—together, they keep energy flowing in ecosystems.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Healthy food and regular exercise help your cells produce energy efficiently!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve learned how cells release energy through cellular respiration.',
          '**Padayon sa pagtu-on sa SCI-ensiya!** Thank you!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      const ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      const ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed Metabolism: An Overview!',
          'Tap **Next** to continue your learning journey!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final lessonChatProvider =
    StateNotifierProvider<LessonChatNotifier, LessonChatState>(
  (ref) => LessonChatNotifier(ChatRepository(), ref),
);

/// Provider for narrative bubble state
final lessonNarrativeBubbleProvider =
    StateNotifierProvider<LessonNarrativeBubbleNotifier,
        LessonNarrativeBubbleState>(
  (ref) => LessonNarrativeBubbleNotifier(),
);
