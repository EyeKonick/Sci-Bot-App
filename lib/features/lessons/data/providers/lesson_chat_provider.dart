import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import 'guided_lesson_provider.dart';

// ---------------------------------------------------------------------------
// Message Type Enum
// ---------------------------------------------------------------------------

/// Distinguishes narrative content from interactive Q&A
enum MessageType {
  /// Narrative content shown in speech bubble next to floating avatar
  narrative,

  /// Interactive question shown in central chat area
  question,
}

// ---------------------------------------------------------------------------
// Script Step Model
// ---------------------------------------------------------------------------

/// A single step in the scripted lesson conversation.
/// Each step has bot messages to display, and optionally waits for user input.
class ScriptStep {
  /// Messages the bot sends (each becomes a separate chat bubble)
  final List<String> botMessages;

  /// Type of message: narrative (speech bubble) or question (central chat)
  final MessageType messageType;

  /// Whether to pause and wait for student input after sending messages
  final bool waitForUser;

  /// If set, AI evaluates the student's answer using this context.
  /// Only relevant when waitForUser is true.
  final String? aiEvalContext;

  /// If true, completing this step marks the module as done
  final bool isModuleComplete;

  const ScriptStep({
    required this.botMessages,
    required this.messageType,
    this.waitForUser = false,
    this.aiEvalContext,
    this.isModuleComplete = false,
  });
}

// ---------------------------------------------------------------------------
// Lesson Chat Message
// ---------------------------------------------------------------------------

/// A single message in the guided lesson chat (separate from global chat)
class LessonChatMessage {
  final String id;
  final String role; // 'assistant' or 'user'
  final String content;
  final MessageType? messageType; // null for user messages
  final bool isStreaming;
  final DateTime timestamp;

  const LessonChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.messageType,
    this.isStreaming = false,
    required this.timestamp,
  });

  LessonChatMessage copyWith({
    String? content,
    bool? isStreaming,
    MessageType? messageType,
  }) {
    return LessonChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
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
  final int currentStepIndex;

  const LessonChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.currentStepIndex = 0,
  });

  LessonChatState copyWith({
    List<LessonChatMessage>? messages,
    bool? isStreaming,
    int? currentStepIndex,
  }) {
    return LessonChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// Lesson Narrative Bubble State (for Speech Bubbles)
// ---------------------------------------------------------------------------

/// State for narrative speech bubbles shown by floating avatar
class LessonNarrativeBubbleState {
  /// Current narrative messages to display in speech bubble
  final List<String> messages;

  /// Index of currently displayed message
  final int currentIndex;

  /// Whether narrative is active
  final bool isActive;

  /// Associated lesson ID (for context)
  final String? lessonId;

  const LessonNarrativeBubbleState({
    this.messages = const [],
    this.currentIndex = 0,
    this.isActive = false,
    this.lessonId,
  });

  LessonNarrativeBubbleState copyWith({
    List<String>? messages,
    int? currentIndex,
    bool? isActive,
    String? lessonId,
  }) {
    return LessonNarrativeBubbleState(
      messages: messages ?? this.messages,
      currentIndex: currentIndex ?? this.currentIndex,
      isActive: isActive ?? this.isActive,
      lessonId: lessonId ?? this.lessonId,
    );
  }
}

/// Manages narrative messages for speech bubbles
class LessonNarrativeBubbleNotifier
    extends StateNotifier<LessonNarrativeBubbleState> {
  LessonNarrativeBubbleNotifier() : super(const LessonNarrativeBubbleState());

  /// Start showing narrative messages
  void showNarrative(List<String> messages, String lessonId) {
    print('📢 showNarrative called: ${messages.length} messages for lesson $lessonId');
    print('   First message preview: ${messages.isNotEmpty ? messages[0].substring(0, messages[0].length.clamp(0, 50)) : "empty"}...');

    state = LessonNarrativeBubbleState(
      messages: messages,
      currentIndex: 0, // Always start at the beginning
      isActive: true,
      lessonId: lessonId,
    );
  }

  /// Move to next message in sequence
  void nextMessage() {
    if (!state.isActive || state.currentIndex >= state.messages.length - 1) {
      print('⏭️ nextMessage: Already at end or inactive');
      return;
    }
    final nextIndex = state.currentIndex + 1;
    print('⏭️ nextMessage: Advancing from ${state.currentIndex} to $nextIndex');
    state = state.copyWith(currentIndex: nextIndex);
  }

  /// Hide narrative bubble and trigger contextual greeting restart
  void hideNarrative() {
    state = const LessonNarrativeBubbleState(
      isActive: false,
      messages: [], // Clear messages to trigger greeting restart
    );
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

    // Clear waiting state
    _ref.read(guidedLessonProvider.notifier).clearWaiting();

    // If current step is narrative and waiting for user acknowledgment
    if (currentStep.messageType == MessageType.narrative &&
        currentStep.waitForUser) {
      // User acknowledged narrative (e.g., typed "Yes I notice")
      // DON'T add to main chat - keep it for Q&A only
      _conversationHistory.add({'role': 'user', 'content': text});

      // Hide narrative bubble and advance to next step
      _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();

      // Small delay then advance
      await Future.delayed(const Duration(milliseconds: 500));
      _advanceStep();
      return;
    }

    // For question messages: Add to chat and get AI response
    _addUserMessage(text);
    _conversationHistory.add({'role': 'user', 'content': text});

    // Always call AI to respond (scope checking happens in both methods)
    if (currentStep.aiEvalContext != null && _currentCharacter != null) {
      // Evaluate specific answer → FEEDBACK GOES TO BUBBLE
      await _sendAIEvaluation(text, currentStep.aiEvalContext!);
    } else if (_currentCharacter != null) {
      // General acknowledgment (e.g., "ready", "ok") → GOES TO MAIN CHAT
      await _sendGeneralResponse(text);
    }

    // Advance to next step
    final nextIndex = state.currentStepIndex + 1;
    if (nextIndex < _script.length) {
      // Small delay so AI response and next step don't blend together
      await Future.delayed(const Duration(milliseconds: 800));
      await _executeStep(nextIndex);
    }
  }

  /// Clear all state
  void reset() {
    _conversationHistory.clear();
    _script = [];
    _currentCharacter = null;
    _currentModule = null;
    _currentLesson = null;
    state = const LessonChatState();
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

    // Route messages based on type
    if (step.messageType == MessageType.narrative) {
      // Send to speech bubble (NOT central chat)
      _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
        step.botMessages,
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
      // ✅ FIX: Increased timing from 4s to 6s per message for better readability
      final displayTime = step.botMessages.length * 6000;
      await Future.delayed(Duration(milliseconds: displayTime + 500));
      _advanceStep();
    } else {
      // MessageType.question: Add to central chat as usual
      for (int i = 0; i < step.botMessages.length; i++) {
        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
        final message = LessonChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: step.botMessages[i],
          messageType: MessageType.question,
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
  Future<void> _sendAIEvaluation(String studentAnswer, String evalContext) async {
    final character = _currentCharacter;
    if (character == null) return;

    // ✅ Capture request ID at start to validate response is still relevant
    final requestId = _currentRequestId;

    // Build module context for scope checking
    final moduleContext = _currentModule != null && _currentLesson != null
        ? 'Current Lesson: ${_currentLesson!.title}\nCurrent Module: ${_currentModule!.title} (${_currentModule!.type.displayName})'
        : 'Current topic: Circulation and Gas Exchange';

    // ✅ STEP 1: Quick bubble feedback (1-2 words)
    final bubblePrompt = '''You are ${character.name}, evaluating a student's answer.

$moduleContext

EVALUATION CONTEXT:
$evalContext

Student's answer: "$studentAnswer"

Respond with ONLY 1-2 words of encouragement:
- If correct: "Excellent!" or "Perfect!" or "Ang galing!" or "Tama!"
- If partially correct: "Almost!" or "Close!"
- If wrong: "Not quite..." or "Good try!"

NO explanations, ONLY the short encouragement.''';

    String bubbleResponse = '';
    try {
      await for (final chunk in _chatRepo.sendGuidedLessonStream(
        userMessage: studentAnswer,
        systemPrompt: bubblePrompt,
        maxTokens: 10, // Very short
      )) {
        bubbleResponse += chunk;
      }
    } catch (e) {
      bubbleResponse = 'Great effort!';
    }

    // ✅ VALIDATION: Check if module context is still the same
    if (requestId != _currentRequestId) {
      print('⚠️ Discarding AI response - module context changed (old: $requestId, current: $_currentRequestId)');
      state = state.copyWith(isStreaming: false);
      return;
    }

    // ✅ Show quick response in speech bubble
    _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
      [bubbleResponse],
      _currentLesson?.id ?? 'unknown',
    );

    // Small delay before explanation
    await Future.delayed(const Duration(milliseconds: 1500));

    // ✅ STEP 2: Full explanation in main chat
    final explanationPrompt = '''You are ${character.name}, a friendly science tutor for Grade 9 Filipino students in Roxas City.

$moduleContext

EVALUATION CONTEXT:
$evalContext

Student's answer: "$studentAnswer"

Provide a clear explanation (2-3 sentences):
- If correct: Confirm why it's right and add interesting details
- If partially correct: Explain what's right, then clarify what's missing
- If wrong: Explain the correct answer and why, in a supportive way

SCOPE CHECKING:
- If the student's response is clearly off-topic (asking about different topics/modules), politely redirect them
- Use simple language for 14-15 year olds
- You may use Filipino expressions naturally

THIS MESSAGE WILL APPEAR IN THE MAIN CHAT AREA.''';

    state = state.copyWith(isStreaming: true);
    String fullExplanation = '';
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add streaming placeholder to main chat
    final streamingMsg = LessonChatMessage(
      id: msgId,
      role: 'assistant',
      content: '',
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
          return;
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
      return;
    }

    // Finalize main chat message
    _updateLastMessage(fullExplanation, false);
    state = state.copyWith(isStreaming: false);
    _conversationHistory.add({'role': 'assistant', 'content': fullExplanation});

    // Small delay before next step
    await Future.delayed(const Duration(milliseconds: 2000));
  }

  /// General response for steps without specific evaluation context
  /// Handles acknowledgments and scope checking for off-topic questions
  Future<void> _sendGeneralResponse(String studentInput) async {
    final character = _currentCharacter;
    if (character == null) return;

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
          return;
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
      return;
    }

    // Finalize
    _updateLastMessage(fullResponse, false);
    state = state.copyWith(isStreaming: false);
    _conversationHistory.add({'role': 'assistant', 'content': fullResponse});
  }

  // -------------------------------------------------------------------------
  // Internal: Message Helpers
  // -------------------------------------------------------------------------

  void _addBotMessage(String content) {
    final msg = LessonChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _addUserMessage(String content) {
    final msg = LessonChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
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
    switch (moduleId) {
      case 'module_circ_fascinate':
        return _scriptFascinate();
      default:
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
      // Split into smaller, more readable chunks
      const ScriptStep(
        botMessages: [
          'Hello, SCI-learner! 👋\n\nKumusta! Welcome to today\'s science journey here in Roxas City.',
          'Today, we\'ll explore how your body moves blood and exchanges gases.',
          'Just like boats carry goods from Culasi fish port to different barangays, your body has a transport system too!',
          'This lesson is all about **Circulation and Gas Exchange** — your body\'s very own delivery network. 🫀',
        ],
        messageType: MessageType.narrative,
        waitForUser: false, // Auto-continue to next step
      ),

      // Step 1: First Prompt (QUESTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Ready to dive in? Let\'s get **Fa-SCI-nated**!',
        ],
        messageType: MessageType.question,
        waitForUser: true, // Wait for user acknowledgment
      ),

      // Step 2: Scenario (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Imagine this...\n\n'
              'You\'re biking along Roxas Boulevard during sunset or dancing '
              'energetically during Sinadya Festival.\n\n'
              'Have you noticed your heart beating faster?',
        ],
        messageType: MessageType.narrative,
        waitForUser: true, // Wait for user response (e.g., "Yes I notice")
      ),

      // Step 3: Transition to Question 1 (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'That\'s a good observation! So here\'s a question:',
        ],
        messageType: MessageType.narrative,
        waitForUser: false, // Auto-continue to question
      ),

      // Step 4: Question 1 (QUESTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**Why do you think your heart beats faster when you move?**',
        ],
        messageType: MessageType.question,
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
            'Keep response to 1-2 sentences. This feedback will appear in the speech bubble.',
      ),

      // Step 5: Transition to Question 2 (NARRATIVE - Speech Bubble)
      // This message will be dynamically generated based on answer correctness
      const ScriptStep(
        botMessages: [
          'Here\'s another question:',
        ],
        messageType: MessageType.narrative,
        waitForUser: false, // Auto-continue to question
      ),

      // Step 6: Question 2 (QUESTION - Main Chat)
      const ScriptStep(
        botMessages: [
          '**What do you think carries oxygen from your lungs to your muscles?**',
        ],
        messageType: MessageType.question,
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
            'Keep response to 1-2 sentences. This feedback will appear in the speech bubble.',
      ),

      // Step 7: Explanation (QUESTION - Main Chat)
      const ScriptStep(
        botMessages: [
          'Just like how delivery trucks distribute seafood from the port to the '
              'markets around Capiz, your body has a system that delivers oxygen, '
              'nutrients, and energy to every cell.\n\n'
              'That amazing system is called the **circulatory system**!',
        ],
        messageType: MessageType.question,
        waitForUser: false, // Auto-continue to conclusion
      ),

      // Step 8: Conclusion (NARRATIVE - Speech Bubble)
      const ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve completed this module.',
          'You\'re ready to move on to the next module where we\'ll set our learning goals.',
          'Tap **Next** when you\'re ready!',
        ],
        messageType: MessageType.narrative,
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
        messageType: MessageType.narrative,
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
