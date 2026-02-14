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

  const ScriptStep({
    required this.botMessages,
    required this.channel,
    this.waitForUser = false,
    this.aiEvalContext,
    this.isModuleComplete = false,
    this.pacingHint = PacingHint.normal,
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

      // Load script for this module (or generate a generic one)
      _script = _getScriptForModule(module.id);

      // Reset guided lesson state
      _ref.read(guidedLessonProvider.notifier).startModule();

      // Send first step
      await _executeStep(0);
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

  /// Execute a script step: send bot messages, then wait if needed
  Future<void> _executeStep(int stepIndex) async {
    if (stepIndex >= _script.length) return;

    // Capture request ID to detect if module changed during async gaps
    final requestId = _currentRequestId;

    final step = _script[stepIndex];
    state = state.copyWith(currentStepIndex: stepIndex);

    // Check if module is complete
    if (step.isModuleComplete) {
      _ref.read(guidedLessonProvider.notifier).completeModule();
      return;
    }

    if (step.botMessages.isEmpty) {
      // No messages - just advance if not waiting
      if (!step.waitForUser) {
        _advanceStep();
      }
      return;
    }

    // Set bubble mode based on channel to keep FloatingChatButton in sync
    if (step.channel == MessageChannel.narration) {
      _ref.read(bubbleModeProvider.notifier).state = BubbleMode.narrative;
    } else if (_ref.read(bubbleModeProvider) != BubbleMode.greeting) {
      // Suppress bubbles during interaction steps (don't revert to greeting mid-lesson)
      _ref.read(bubbleModeProvider.notifier).state = BubbleMode.waitingForNarrative;
    }

    // Route messages based on channel
    if (step.channel == MessageChannel.narration) {
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
        totalDisplayMs += (wordCount * 300).clamp(2000, 8000);

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
      // MessageChannel.interaction: Add to central chat as usual
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
    print('📝 _getScriptForModule called with moduleId: $moduleId');
    switch (moduleId) {
      // LESSON 1: The Circulatory System (6 modules)
      case 'module_circ_fascinate':
        print('✅ Loading circulation Fa-SCI-nate script (${_scriptFascinate().length} steps)');
        return _scriptFascinate();
      case 'module_circ_goal':
        print('✅ Loading circulation Goal SCI-tting script (${_scriptGoalScitting().length} steps)');
        return _scriptGoalScitting();
      case 'module_circ_pre':
        print('✅ Loading circulation Pre-SCI-ntation script (${_scriptPreScintation().length} steps)');
        return _scriptPreScintation();
      case 'module_circ_investigation':
        print('✅ Loading circulation Inve-SCI-tigation script (${_scriptInveScitigation().length} steps)');
        return _scriptInveScitigation();
      case 'module_circ_assessment':
        print('✅ Loading circulation Self-A-SCI-ssment script (${_scriptSelfAScissment().length} steps)');
        return _scriptSelfAScissment();
      case 'module_circ_supplementary':
        print('✅ Loading circulation SCI-pplementary script (${_scriptScipplementary().length} steps)');
        return _scriptScipplementary();

      // LESSON 3: The Respiratory System
      case 'module_resp_fascinate':
        print('✅ Loading respiratory script (${_scriptRespiratoryFascinate().length} steps)');
        return _scriptRespiratoryFascinate();

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
        pacingHint: PacingHint.fast, // Excitement - welcoming energy
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
            '- If correct: "Excellent thinking!" or "Ang galing! That\'s exactly right!"\n'
            '- If partially correct: "You\'re on the right track! [add what\'s missing]"\n'
            '- If wrong: "Good try! Think about what muscles need when you exercise."\n'
            'Keep response to 2-3 sentences.',
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
            '- If they say "blood": "Perfect! Blood is the correct answer!"\n'
            '- If they mention "red blood cells" or "hemoglobin": "Excellent! You know the details!"\n'
            '- If wrong: "Think about the red liquid flowing through your body."\n'
            'Keep response to 2-3 sentences.',
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
        pacingHint: PacingHint.fast, // Celebration - positive energy
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
        pacingHint: PacingHint.fast,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// LESSON 3, MODULE 1: Fa-SCI-nate (The Respiratory System)
  /// Script follows the PDF: "CIRCULATION AND GAS EXCHANGE - LESSON 3"
  /// Only covers the Fa-SCI-nate section (Introduction + Scenario + First Question)
  /// -----------------------------------------------------------------------
  List<ScriptStep> _scriptRespiratoryFascinate() {
    return [
      // Step 0: Initial Greeting (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Welcome back to your science adventure here in Roxas City, Capiz.',
          'The air is fresh and the sea breeze keeps us energized.',
          'Have you ever noticed how your breathing changes when you walk along Baybay Roxas, climb stairs at school, or play basketball with friends?',
          'Today, we\'ll explore the **Respiratory System** — the system that allows your body to breathe, exchange gases, and release energy.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast, // Excitement - welcoming energy
        waitForUser: false,
      ),

      // Step 1: First Prompt (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to take a deep breath and begin?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Scenario (NARRATIVE - Speech Bubble)
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

      // Step 3: Scenario Question (INTERACTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Why do you think breathing becomes faster during exercise?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why does breathing become faster during exercise?"\n'
            'Correct answer concept: Your body needs more oxygen to release energy from food. '
            'Breathing speeds up because your cells need more oxygen and must remove carbon dioxide faster.\n'
            'Response guidelines:\n'
            '- If correct (mentions oxygen/energy/CO2): "Correct! Your body needs more oxygen to release energy from food."\n'
            '- If partially correct: "You\'re on the right track! [explain what\'s missing]"\n'
            '- If wrong or unsure: "Not quite. Breathing speeds up because your cells need more oxygen and must remove carbon dioxide faster."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 4: Conclusion (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Excellent! You\'ve completed the Fa-SCI-nate module.',
          'Tap **Next** to continue to the next module where we\'ll set our learning goals!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast, // Celebration
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
      // Step 0: Greeting with Transition Acknowledgment (NARRATION)
      const ScriptStep(
        botMessages: [
          'Excellent work on Fa-SCI-nate! You learned about how your heart beats faster when you move.',
          'Now let\'s set our learning goals for this entire lesson.',
          'Welcome to **Goal SCI-tting**!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast, // Excitement
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Ready to see what you\'ll master today?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Present 3 Learning Objectives (NARRATION)
      const ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:',
          '**1.** Compare the two types of circulatory systems and understand why humans have the system we do',
          '**2.** Describe the parts of the circulatory system and their functions—the heart, blood vessels, and more',
          '**3.** Explain the components of blood and how they help maintain homeostasis in your body',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 3: Reflection Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Which of these goals are you most excited to learn about?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is sharing which learning goal they are most excited about.\n'
            'This is a personal reflection question. ANY response is valid.\n'
            'Response guidelines:\n'
            '- Acknowledge their choice positively\n'
            '- Briefly explain why that goal is important (1-2 sentences)\n'
            '- Show enthusiasm for their curiosity\n'
            'Examples:\n'
            '- If they choose goal 1 (circulatory types): "Great choice! Understanding why our system works the way it does helps us appreciate how amazing our bodies are!"\n'
            '- If they choose goal 2 (parts and functions): "Excellent! Knowing how your heart and blood vessels work will blow your mind!"\n'
            '- If they choose goal 3 (blood components): "Perfect! Blood is like a delivery service—each component has a special job!"\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 4: Motivation Message (NARRATION)
      const ScriptStep(
        botMessages: [
          'Remember: Learning is a journey, not a race.',
          'Take your time, ask questions, and enjoy discovering how amazing your body really is!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Reflection
        waitForUser: false,
      ),

      // Step 5: Transition (NARRATION)
      const ScriptStep(
        botMessages: [
          'Think of these goals as your science destination—let\'s get there step by step!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // Step 6: Mandatory End-of-Module Q&A (INTERACTION)
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
            'The student is either asking a question about the learning goals or signaling readiness to proceed.\n'
            '\n'
            'If they ask a question: Answer it clearly (2-3 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If they say "ready", "ok", "no questions", "let\'s go", or similar: '
            'Say "Excellent! You\'ve completed Goal SCI-tting. Tap Next to build your foundation!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness to proceed.',
        pacingHint: PacingHint.normal,
      ),

      // Step 7: Completion (NARRATION)
      const ScriptStep(
        botMessages: [
          'Great! You\'re ready to move forward.',
          'Tap **Next** when you\'re ready to explore!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
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
      // Step 0: Greeting with Transition (NARRATION)
      const ScriptStep(
        botMessages: [
          'Great job setting your learning goals!',
          'Now let\'s build the foundation you need to understand circulation.',
          'Welcome to **Pre-SCI-ntation** — let\'s start with the basics!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // Step 1: Homeostasis Introduction (NARRATION)
      const ScriptStep(
        botMessages: [
          'Your body needs balance to survive.',
          'This balance is called **homeostasis**.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 2: Homeostasis Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**What do you think homeostasis means?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "What is homeostasis?"\n'
            'Correct concept: Homeostasis is the body maintaining stable internal conditions/balance.\n'
            'Key points: balance, stable conditions, regulation.\n'
            'Response guidelines:\n'
            '- If correct (mentions balance/stability/regulation): "Exactly right! Homeostasis means your body maintains stable conditions."\n'
            '- If partially correct: "You\'re on the right track! [add missing concept]"\n'
            '- If wrong: "Good try! Think about what your body needs to stay balanced."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 3: Homeostasis Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          'Homeostasis means your body maintains stable conditions by:',
          '• **Delivering nutrients** to cells',
          '• **Supplying oxygen** where it\'s needed',
          '• **Removing wastes** like carbon dioxide',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 4: Small Organisms Comparison (NARRATION)
      const ScriptStep(
        botMessages: [
          'Small organisms like bacteria can rely on simple **diffusion** to get what they need.',
          'But humans, like active students in Roxas City who swim, bike, and play basketball, need something faster and stronger!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 5: Why Circulatory System Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Why do you think we need a circulatory system?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why do we need a circulatory system?"\n'
            'Correct concepts: humans are too large for diffusion alone, need quick delivery, '
            'have trillions of cells to feed, active lifestyle requires fast oxygen transport.\n'
            'Response guidelines:\n'
            '- If correct (mentions size/complexity/speed/activity): "Perfect! Our bodies are too large and active for simple diffusion!"\n'
            '- If partially correct: "Good thinking! [add what\'s missing]"\n'
            '- If wrong: "Think about how big and active your body is compared to a tiny bacterium."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 6: Circulatory System Components (NARRATION)
      const ScriptStep(
        botMessages: [
          'That\'s why we have a **circulatory system** powered by:',
          '❤️ The **heart** (your pump)',
          '🩸 **Blood** (the transport medium)',
          '🛣️ **Blood vessels** (the highways and roads)',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 7: Analogy with Roxas City (NARRATION)
      const ScriptStep(
        botMessages: [
          'Think of it this way:',
          'If your body were Roxas City, the circulatory system would be the roads, vehicles, and cargo delivering everything from the port to every barangay.',
          'Without it, nothing would get where it needs to go!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Let them visualize
        waitForUser: false,
      ),

      // Step 8: Transition (NARRATION)
      const ScriptStep(
        botMessages: [
          'Ready to explore each part in detail?',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // Step 9: Mandatory End-of-Module Q&A (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Before we investigate deeper, do you have any questions about homeostasis or why we need a circulatory system?',
          'Type your question, or type "ready" to continue.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about homeostasis/circulatory system basics or signaling readiness.\n'
            '\n'
            'If question: Answer clearly (2-4 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If ready: Say "Excellent! You\'ve completed Pre-SCI-ntation. Tap Next to investigate!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness.',
        pacingHint: PacingHint.normal,
      ),

      // Step 10: Completion (NARRATION)
      const ScriptStep(
        botMessages: [
          'Great foundation! You\'re ready to investigate.',
          'Tap **Next** when you\'re ready!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
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
        pacingHint: PacingHint.fast, // Celebration
        waitForUser: false,
      ),

      // Step 1: Ready Prompt (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Want to learn more?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      // Step 2: Extension Activities Intro (NARRATION)
      const ScriptStep(
        botMessages: [
          'Here are some ways to deepen your understanding:',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 3: Pulse Experiment Instructions (NARRATION)
      const ScriptStep(
        botMessages: [
          '**Try this at home!**',
          '**Experiment: Feel Your Pulse**',
          '1. Place two fingers on your wrist (below your thumb)',
          '2. Count beats for 15 seconds',
          '3. Multiply by 4 to get beats per minute',
          '4. Do jumping jacks for 1 minute',
          '5. Check pulse again — what changed?',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 4: Engagement Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Have you ever tried feeling your pulse? What did you notice?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Student sharing pulse experiment experience.\n'
            'This is engagement/sharing question. ANY response is valid.\n'
            'Response guidelines:\n'
            '- Acknowledge their experience positively\n'
            '- If they haven\'t tried: "That\'s okay! Try it now or later. You\'ll be amazed!"\n'
            '- If they have: "Great observation! [Explain why pulse changes: during activity, '
            'your heart beats faster to pump more oxygen-rich blood to your muscles]"\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 5: Health Tips Presentation (NARRATION)
      const ScriptStep(
        botMessages: [
          'Here are some tips to keep your circulatory system healthy:',
          '✅ **Exercise regularly** — At least 30 minutes daily',
          '✅ **Eat nutritious food** — Fruits, vegetables, lean protein (like bangus from Roxas!)',
          '✅ **Stay hydrated** — Drink 8 glasses of water daily',
          '✅ **Get enough sleep** — 8-10 hours for teenagers',
          '✅ **Avoid smoking** — It damages blood vessels',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 6: Application Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Which of these health tips will you try first?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Student choosing which health tip to try.\n'
            'This is application/commitment question. ANY tip choice is valid.\n'
            'Response guidelines:\n'
            '- Affirm their choice enthusiastically\n'
            '- Explain why that tip is beneficial (1-2 sentences)\n'
            '- Examples:\n'
            '  - Exercise: "Excellent! Regular exercise strengthens your heart and blood vessels!"\n'
            '  - Nutrition: "Great choice! Healthy food gives your blood the nutrients it needs to deliver to cells!"\n'
            '  - Hydration: "Perfect! Water helps maintain blood volume and keeps circulation smooth!"\n'
            '  - Sleep: "Smart! During sleep, your heart rate slows and your body repairs blood vessels!"\n'
            '- Encourage them to start small and build the habit\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 7: Celebration Summary (NARRATION)
      const ScriptStep(
        botMessages: [
          'You\'ve completed the lesson on **The Circulation System**!',
          'You now understand:',
          '✅ How your heart pumps blood',
          '✅ The role of blood vessels',
          '✅ What blood contains and why',
          '✅ Why this system is essential for life',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast, // Celebration
        waitForUser: false,
      ),

      // Step 8: Mandatory End-of-Module Q&A (INTERACTION)
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

      // Step 9: Final Completion (NARRATION)
      const ScriptStep(
        botMessages: [
          'Keep exploring, keep questioning, and keep learning!',
          'Tap **Next** to complete this lesson!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
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

      // Step 5: Assessment Question 4 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Question 4: What is the main function of red blood cells?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 4: Main function of red blood cells?\n'
            'Correct answer: Carry oxygen from lungs to body cells (and carry carbon dioxide back).\n'
            'Response guidelines:\n'
            '- If mentions oxygen transport: "Perfect! Red blood cells are oxygen carriers with hemoglobin!"\n'
            '- If wrong: "Red blood cells carry oxygen from lungs to cells using hemoglobin, and carry CO₂ back!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 6: Assessment Question 5 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Question 5: Name the three types of blood vessels and their main functions.**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment Question 5: Three blood vessels and functions?\n'
            'Correct answer:\n'
            '- Arteries: carry blood away from heart (thick walls, high pressure)\n'
            '- Veins: bring blood back to heart (thinner walls, have valves)\n'
            '- Capillaries: exchange oxygen/nutrients/waste with cells (one cell thick)\n'
            'Response guidelines:\n'
            '- If all 3 correct: "Outstanding! You know all three vessel types and their jobs perfectly!"\n'
            '- If 2 correct: "Good! You got [X] right. [Explain missing one]."\n'
            '- If 1 or none: "The three are: arteries (away from heart), veins (back to heart), capillaries (exchange with cells)."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 7: Reflection Questions Intro (NARRATION)
      const ScriptStep(
        botMessages: [
          'Great work on those knowledge checks!',
          'Now let\'s reflect deeper on what you\'ve learned.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 8: Reflection Question 1 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Reflection: How does your circulatory system support you during Sinadya Festival dancing?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Reflection question about circulatory system during festival dancing.\n'
            'This is open-ended reflection. Accept any thoughtful response.\n'
            'Correct concepts: heart beats faster, pumps more oxygen-rich blood to dancing muscles, removes CO₂ from muscles.\n'
            'Response guidelines:\n'
            '- Acknowledge their thinking positively\n'
            '- Add educational insight: "During dancing, your heart pumps faster to deliver oxygen to your leg and arm muscles, and removes CO₂ so you can keep going!"\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 9: Reflection Question 2 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Reflection: What would happen if your heart valves didn\'t work properly?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Reflection question about valve malfunction.\n'
            'Correct concept: Blood would flow backward, heart wouldn\'t pump efficiently, could cause fatigue/weakness.\n'
            'Response guidelines:\n'
            '- If mentions backflow/inefficiency: "Exactly! Valves prevent backflow to keep blood moving forward efficiently!"\n'
            '- If unsure: "Good thinking! Valves prevent blood from flowing backward. If they fail, the heart can\'t pump efficiently, causing fatigue."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 10: Reflection Question 3 (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Reflection: Why is it important to keep your circulatory system healthy?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Reflection question about importance of heart health.\n'
            'Accept any thoughtful response about health, longevity, disease prevention, quality of life.\n'
            'Response guidelines:\n'
            '- Affirm their understanding positively\n'
            '- Add practical tip: "Exactly! A healthy circulatory system helps you live longer and stay active. Exercise, good diet, and avoiding smoking keep your heart strong!"\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 11: Encouragement (NARRATION)
      const ScriptStep(
        botMessages: [
          'If you can answer these questions, you\'re doing SCI-mazing!',
          'Remember: It\'s okay if you need to review. Learning takes time, and every question helps you understand better!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Encouraging reflection
        waitForUser: false,
      ),

      // Step 12: Mandatory End-of-Module Q&A (INTERACTION)
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

      // Step 13: Completion (NARRATION)
      const ScriptStep(
        botMessages: [
          'You\'ve completed your assessment! Well done!',
          'Tap **Next** for bonus activities!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
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
      // ========== PART 1: CIRCULATORY SYSTEM TYPES (4 steps) ==========

      // Step 0: Greeting with Transition (NARRATION)
      const ScriptStep(
        botMessages: [
          'You now have a solid foundation! Time to investigate deeper.',
          'In this module, we\'ll explore the heart, blood vessels, and blood itself.',
          'Welcome to **Inve-SCI-tigation** — let\'s discover the details!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // Step 1: Circulatory System Types Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          'There are **two types** of circulatory systems in the animal kingdom:',
          '🦗 **Open Circulatory System** (insects, crabs) - Blood flows freely through body cavities. Slow and indirect.',
          '👤 **Closed Circulatory System** (humans, mammals) - Blood stays inside vessels at all times. Fast and efficient!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 2: Circulatory Type Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Which type of circulatory system do humans have, and why is it better for us?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which circulatory system do humans have and why?"\n'
            'Correct answer: Humans have a closed circulatory system. It\'s better because blood stays in vessels, '
            'flow is fast and efficient, can deliver oxygen quickly to active tissues like muscles during exercise.\n'
            'Response guidelines:\n'
            '- If correct (mentions closed + efficiency/speed/activity): "Excellent! Closed systems are perfect for our active lifestyles!"\n'
            '- If partially correct (only says closed): "Correct! Can you explain why it\'s better for active humans?"\n'
            '- If wrong: "Think about which system keeps blood in vessels at all times for fast delivery."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 3: Transition to Heart (NARRATION)
      const ScriptStep(
        botMessages: [
          'Perfect! Now let\'s explore the heart — the amazing pump at the center of your closed circulatory system.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // ========== PART 2: THE HEART (10 steps) ==========

      // Step 4: Heart Size and Beats (NARRATION)
      const ScriptStep(
        botMessages: [
          'Your heart is about the **size of your clenched fist** ✊',
          'It beats over **100,000 times a day** — even while you sleep!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 5: Atria Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          'The heart has 4 chambers. Let\'s start with the upper chambers:',
          '**Atria (Upper Chambers)**',
          '• Right atrium ← receives deoxygenated blood from body',
          '• Left atrium ← receives oxygenated blood from lungs',
          'Their job: **Receive** blood returning to the heart.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 6: Ventricles Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          'Now the lower chambers:',
          '**Ventricles (Lower Chambers)**',
          '• Right ventricle → pumps blood to lungs (to get oxygen)',
          '• Left ventricle → pumps blood to entire body (the hardest worker!)',
          'Their job: **Pump** blood OUT of the heart.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 7: Chamber Thickness Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Which chamber do you think has thicker walls — the atria or ventricles? Why?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Which chamber has thicker walls and why?"\n'
            'Correct answer: Ventricles have thicker walls, especially the left ventricle, because they pump blood out of the heart (requires more force). '
            'The left ventricle works hardest pumping to the entire body.\n'
            'Response guidelines:\n'
            '- If fully correct (ventricles + pumping/force reason): "Perfect answer! Ventricles need strong walls to pump blood far!"\n'
            '- If partially correct (only ventricles): "Right! Can you explain why they need thicker walls?"\n'
            '- If wrong: "Think about which chambers do the heavy lifting of pumping blood out."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 8: Valves Introduction (NARRATION)
      const ScriptStep(
        botMessages: [
          'The heart also has **valves** — like one-way doors.',
          'They open to let blood through, then close to **prevent backflow**.',
          'This ensures blood moves in only ONE direction!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 9: Septum Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          'Finally, the **septum** is a wall that separates the left and right sides of your heart.',
          'It keeps oxygenated and deoxygenated blood from mixing.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 10: Heart Summary (NARRATION)
      const ScriptStep(
        botMessages: [
          'So the heart has:',
          '• 4 chambers (2 atria, 2 ventricles)',
          '• Valves (prevent backflow)',
          '• Septum (separates left and right)',
          'All working together to pump blood 24/7!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // Step 11: Transition to Vessels (NARRATION)
      const ScriptStep(
        botMessages: [
          'Now that blood is pumped by the heart, where does it go?',
          'It travels through **blood vessels** — the highways of your body!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // ========== PART 3: BLOOD VESSELS (10 steps) ==========

      // Step 12: Arteries Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          'Think of blood vessels like roads connecting barangays in Roxas City.',
          'There are three types:',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 13: Arteries Details (NARRATION)
      const ScriptStep(
        botMessages: [
          '**1. Arteries** 🔴',
          '• Carry blood AWAY from the heart',
          '• Thick, elastic walls (handle high pressure)',
          '• Mostly carry oxygenated blood',
          '• Exception: Pulmonary artery (carries deoxygenated blood to lungs)',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 14: Veins Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          '**2. Veins** 🔵',
          '• Bring blood BACK to the heart',
          '• Thinner walls (lower pressure)',
          '• Have valves to prevent backflow',
          '• Mostly carry deoxygenated blood',
          '• Exception: Pulmonary veins (carry oxygenated blood from lungs)',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 15: Capillaries Introduction (NARRATION)
      const ScriptStep(
        botMessages: [
          '**3. Capillaries** 🟣',
          '• Tiny paths where the real action happens!',
          '• Walls are only **ONE cell thick**',
          '• Where oxygen and nutrients are exchanged with body cells',
          '• Where carbon dioxide and wastes are picked up',
          '• Connect arteries to veins',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 16: Capillary Thickness Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Why do you think capillaries are only one cell thick?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is answering: "Why are capillaries only one cell thick?"\n'
            'Correct answer: Thin walls allow easy exchange/diffusion of oxygen, nutrients, and wastes between blood and body cells.\n'
            'Response guidelines:\n'
            '- If mentions exchange/diffusion/thin for passing substances: "Excellent! Thin walls make it easy for oxygen and nutrients to pass through!"\n'
            '- If partially correct: "You\'re on the right track! Think about what needs to pass through the capillary wall."\n'
            '- If wrong: "Thin walls allow oxygen and nutrients to easily diffuse from blood into cells, and wastes to move back into blood."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 17: Blood Vessels Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**Can you name the three types of blood vessels and their main jobs?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'The student is naming the three blood vessels and functions.\n'
            'Correct:\n'
            '- Arteries: carry blood away from heart\n'
            '- Veins: bring blood back to heart\n'
            '- Capillaries: exchange oxygen/nutrients/waste with cells\n'
            'Response guidelines:\n'
            '- If all 3 correct: "Perfect! You understand the three vessel types and their roles!"\n'
            '- If 2 correct: "Good job! You got [X]. [Explain missing one]."\n'
            '- If 1 or wrong: "Arteries take blood away from heart, veins bring it back, and capillaries exchange with cells."\n'
            'Keep response to 2-3 sentences.',
      ),

      // Step 18: Vessels Summary (NARRATION)
      const ScriptStep(
        botMessages: [
          'Without these "roads," cells would never receive what they need to survive!',
          'Arteries → Capillaries → Veins → back to Heart. The cycle continues!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // Step 19: Transition to Blood (NARRATION)
      const ScriptStep(
        botMessages: [
          'Now we know HOW blood travels. But what IS blood made of?',
          'Let\'s explore the four components!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // ========== PART 4: BLOOD COMPONENTS (10 steps) ==========

      // Step 20: Blood Composition Intro (NARRATION)
      const ScriptStep(
        botMessages: [
          'Blood makes up about **7-8% of your body weight**.',
          'It has FOUR main components:',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 21: Plasma Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          '**1. Plasma** 💧 (55% of blood)',
          '• Mostly water (90%)',
          '• Contains proteins, salts, nutrients',
          '• Carries nutrients (glucose, amino acids, fats)',
          '• Transports hormones',
          '• Carries waste products (urea, CO₂)',
          '• Helps regulate body temperature',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 22: Red Blood Cells Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          '**2. Red Blood Cells** 🔴 (Erythrocytes)',
          '• Disc-shaped, no nucleus',
          '• Contain **hemoglobin** (iron-rich protein)',
          '• Give blood its red color',
          'Fun fact: You have about **25 trillion** red blood cells!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 23: Red Blood Cell Function Question (INTERACTION)
      const ScriptStep(
        botMessages: [
          '**What is the main function of red blood cells?**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'Assessment: Main function of red blood cells?\n'
            'Correct answer: Carry oxygen from lungs to body cells using hemoglobin (and carry CO₂ back to lungs).\n'
            'Response guidelines:\n'
            '- If mentions oxygen transport/hemoglobin: "Perfect! Red blood cells are oxygen carriers using hemoglobin!"\n'
            '- If vague: "Think about what your cells need from the air you breathe."\n'
            '- If wrong: "Red blood cells carry oxygen from lungs to cells using hemoglobin, and bring CO₂ back to lungs!"\n'
            'Keep response to 2 sentences.',
      ),

      // Step 24: White Blood Cells Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          '**3. White Blood Cells** ⚪ (Leukocytes)',
          '• Defend against infection',
          '• Fight bacteria, viruses, and foreign invaders',
          '• Part of your immune system',
          '• Several types, each with specific defense roles',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 25: Platelets Explanation (NARRATION)
      const ScriptStep(
        botMessages: [
          '**4. Platelets** 🩹 (Thrombocytes)',
          '• Help blood clot when you get a wound',
          '• Form a "plug" to stop bleeding',
          '• Prevent excessive blood loss',
          'Process: Cut → Platelets rush → Stick together → Clot forms → Scab heals!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      // Step 26: Blood Components Summary (NARRATION)
      const ScriptStep(
        botMessages: [
          'Every drop of blood plays a role in keeping you healthy and active!',
          '• Plasma carries nutrients and wastes',
          '• Red blood cells deliver oxygen',
          '• White blood cells fight infection',
          '• Platelets stop bleeding',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
        waitForUser: false,
      ),

      // Step 27: Complete Summary (NARRATION)
      const ScriptStep(
        botMessages: [
          'Your circulatory system works 24/7 to:',
          '• Deliver oxygen and nutrients',
          '• Remove waste products',
          '• Fight infections',
          '• Regulate temperature',
          '• Maintain homeostasis',
          'All without you even thinking about it! Amazing, right? 🤩',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Reflection on the entire system
        waitForUser: false,
      ),

      // ========== FINAL: END-OF-MODULE Q&A (2 steps) ==========

      // Step 28: Mandatory End-of-Module Q&A (INTERACTION)
      const ScriptStep(
        botMessages: [
          'Before we finish this investigation, any questions about the heart, blood vessels, or blood?',
          'Type your question, or type "ready" to complete this module.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
        aiEvalContext:
            'CONTEXT: This is a LOOPING Q&A session. The student can ask multiple questions.\n'
            '\n'
            'The student is either asking a question about heart/vessels/blood or signaling readiness.\n'
            '\n'
            'If question: Answer thoroughly (3-5 sentences). '
            'DO NOT say "Tap Next" and DO NOT ask "Do you have another question?" - the system handles this.\n'
            '\n'
            'If ready: Say "Amazing work! You\'ve completed Inve-SCI-tigation. Tap Next to assess your understanding!"\n'
            '\n'
            'IMPORTANT: Only say "Tap Next" if they explicitly signal readiness.',
        pacingHint: PacingHint.normal,
      ),

      // Step 29: Completion (NARRATION)
      const ScriptStep(
        botMessages: [
          'You\'ve mastered the investigation! Well done!',
          'Tap **Next** to test your knowledge!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.fast,
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
