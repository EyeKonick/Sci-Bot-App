import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../shared/models/channel_message.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import 'guided_lesson_provider.dart';
import '../../../../core/utils/reading_time.dart';
import 'narration_variations.dart';

export '../../../../shared/models/channel_message.dart';


enum BubbleMode {
  greeting,

  waitingForNarrative,

  narrative,
}

final bubbleModeProvider = StateProvider<BubbleMode>((ref) => BubbleMode.greeting);


class ScriptStep {
  final List<String> botMessages;

  final MessageChannel channel;

  final bool waitForUser;

  final String? aiEvalContext;

  final bool isModuleComplete;

  final PacingHint pacingHint;

  final String? transitionBubble;

  final String? imageAssetPath;

 ScriptStep({
    required this.botMessages,
    required this.channel,
    this.waitForUser = false,
    this.aiEvalContext,
    this.isModuleComplete = false,
    this.pacingHint = PacingHint.normal,
    this.transitionBubble,
    this.imageAssetPath,
  });
}


class LessonChatMessage {
  final String id;
  final String role; // 'assistant' or 'user'
  final String content;
  final MessageChannel? channel; // null for legacy; user messages are always interaction
  final bool isStreaming;
  final DateTime timestamp;
  final String? imageAssetPath; // Optional image to display with message

  const LessonChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.channel,
    this.isStreaming = false,
    required this.timestamp,
    this.imageAssetPath,
  });

  LessonChatMessage copyWith({
    String? content,
    bool? isStreaming,
    MessageChannel? channel,
    String? imageAssetPath,
  }) {
    return LessonChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      channel: channel ?? this.channel,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp,
      imageAssetPath: imageAssetPath ?? this.imageAssetPath,
    );
  }
}


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


class LessonNarrativeBubbleState {
  final List<NarrationMessage> messages;

  final int currentIndex;

  final bool isActive;

  final bool isPaused;

  final bool isThinking;

  final String? lessonId;

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

class LessonNarrativeBubbleNotifier
    extends StateNotifier<LessonNarrativeBubbleState> {
  LessonNarrativeBubbleNotifier() : super(const LessonNarrativeBubbleState());

  void showNarrative(List<NarrationMessage> messages, String lessonId) {
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

  void nextMessage() {
    if (!state.isActive || state.currentIndex >= state.messages.length - 1) {
      debugPrint('⏭️ nextMessage: Already at end or inactive');
      return;
    }
    final nextIndex = state.currentIndex + 1;
    debugPrint('⏭️ nextMessage: Advancing from ${state.currentIndex} to $nextIndex');
    state = state.copyWith(currentIndex: nextIndex);
  }

  void hideNarrative({bool instant = false}) {
    state = LessonNarrativeBubbleState(
      isActive: false,
      messages: const [],
      isInstantHide: instant,
    );
  }

  void pause() {
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    state = state.copyWith(isPaused: false);
  }

  void setThinking(bool isThinking) {
    state = state.copyWith(isThinking: isThinking);
  }

  void reset() {
    state = state.copyWith(currentIndex: 0, isActive: true);
  }
}


class LessonChatNotifier extends StateNotifier<LessonChatState> {
  final ChatRepository _chatRepo;
  final Ref _ref;

  List<ScriptStep> _script = [];

  final List<Map<String, dynamic>> _conversationHistory = [];

  AiCharacter? _currentCharacter;

  ModuleModel? _currentModule;
  LessonModel? _currentLesson;

  int _currentRequestId = 0;

  bool _isStarting = false;

  final Map<int, int> _attemptsByStep = {};

  LessonChatNotifier(this._chatRepo, this._ref)
      : super(const LessonChatState());


  Future<void> startModule({
    required ModuleModel module,
    required LessonModel lesson,
    required AiCharacter character,
  }) async {
    if (_isStarting) {
      print('⚠️ startModule() called while already starting - ignoring duplicate call');
      return;
    }

    _isStarting = true;

    try {
      _currentRequestId++;

      print('🚀 Starting module: ${module.title} (Request ID: $_currentRequestId)');

      _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();

      await Future.delayed(const Duration(milliseconds: 300));

      _conversationHistory.clear();
      _currentCharacter = character;
      _currentModule = module;
      _currentLesson = lesson;
      state = const LessonChatState();

      print('📝 DEBUG - Module ID: "${module.id}"');
      print('📝 DEBUG - Lesson ID: "${lesson.id}"');
      print('📝 DEBUG - Character: "${character.name}"');

      _script = _getScriptForModule(module.id);

      print('📝 DEBUG - Script loaded with ${_script.length} steps');
      if (_script.isNotEmpty) {
        print('📝 DEBUG - First step channel: ${_script[0].channel}');
        print('📝 DEBUG - First step messages: ${_script[0].botMessages.length} messages');
      } else {
        print('⚠️ WARNING - Script is EMPTY!');
      }

      _ref.read(guidedLessonProvider.notifier).startModule();

      print('📝 DEBUG - Calling _executeStep(0)...');
      await _executeStep(0);
      print('📝 DEBUG - _executeStep(0) completed');
    } finally {
      _isStarting = false;
    }
  }

  Future<void> sendStudentMessage(String text) async {
    if (state.isStreaming) return;

    final currentStep = _getCurrentStep();
    if (currentStep == null) return;

    final requestId = _currentRequestId;


    if (currentStep.channel == MessageChannel.narration &&
        currentStep.waitForUser) {
      _conversationHistory.add({'role': 'user', 'content': text});

      _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();

      await Future.delayed(const Duration(milliseconds: 500));
      if (requestId != _currentRequestId) return;
      _advanceStep();
      return;
    }

    _addUserMessage(text);
    _conversationHistory.add({'role': 'user', 'content': text});

    if (_currentCharacter != null) {
      _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
        [NarrationMessage(
          content: _getAcknowledgmentPhrase(),
          characterId: _currentCharacter?.id,
          pacingHint: PacingHint.fast,
        )],
        _currentLesson?.id ?? 'unknown',
      );

      await Future.delayed(const Duration(milliseconds: 1200));
      if (requestId != _currentRequestId) return;
    }

    bool canProceed = true; // Default to proceeding for non-evaluated steps

    if (currentStep.aiEvalContext != null && _currentCharacter != null) {
      canProceed = await _sendAIEvaluation(text, currentStep.aiEvalContext!);
    } else if (_currentCharacter != null) {
      canProceed = await _sendGeneralResponse(text);
    }

    if (requestId != _currentRequestId) return;

    if (canProceed) {
      final attemptCount = _attemptsByStep[state.currentStepIndex] ?? 1;
      final isEndOfModuleQA = currentStep.aiEvalContext?.toLowerCase().contains('tap next') ?? false;

      if (attemptCount >= 3 && !isEndOfModuleQA && currentStep.aiEvalContext != null) {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (requestId != _currentRequestId) return;

        _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
          [NarrationMessage(
            content: NarrationVariations.getMaxAttemptsEncouragement(),
            characterId: _currentCharacter?.id,
            pacingHint: PacingHint.normal,
          )],
          _currentLesson?.id ?? 'unknown',
        );

        await Future.delayed(const Duration(milliseconds: 3000));
        if (requestId != _currentRequestId) return;
      }

      _ref.read(guidedLessonProvider.notifier).clearWaiting();
      final nextIndex = state.currentStepIndex + 1;
      if (nextIndex < _script.length) {
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

          _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative(instant: true);
        }

        await Future.delayed(const Duration(milliseconds: 800));
        if (requestId != _currentRequestId) return;
        await _executeStep(nextIndex);
      }
    } else {
      final isEndOfModuleQA = currentStep.aiEvalContext?.toLowerCase().contains('tap next') ?? false;

      if (isEndOfModuleQA) {
        print('⏸️ End-of-module Q&A - showing follow-up prompt');
        await _showFollowUpPrompt(requestId);
      } else {
        print('⏸️ Staying on step ${state.currentStepIndex} - waiting for retry (attempt ${_attemptsByStep[state.currentStepIndex] ?? 1}/3)');
      }
    }
  }

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

    _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative();
    _ref.read(bubbleModeProvider.notifier).state = BubbleMode.greeting;
  }

  void pause() {
    _ref.read(lessonNarrativeBubbleProvider.notifier).pause();
  }

  void resume() {
    _ref.read(lessonNarrativeBubbleProvider.notifier).resume();
  }


  ScriptStep? _getCurrentStep() {
    if (state.currentStepIndex >= _script.length) return null;
    return _script[state.currentStepIndex];
  }

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

    final index = DateTime.now().millisecondsSinceEpoch % phrases.length;
    return phrases[index];
  }

  String _getTransitionPhrase() {
    return NarrationVariations.getTransition();
  }

  Future<void> _executeStep(int stepIndex) async {
    try {
      print('📝 DEBUG - _executeStep($stepIndex) called');
      print('📝 DEBUG - _script.length: ${_script.length}');

      if (stepIndex >= _script.length) {
        print('⚠️ WARNING - stepIndex ($stepIndex) >= _script.length (${_script.length})');
        return;
      }

      final requestId = _currentRequestId;

      final step = _script[stepIndex];
      state = state.copyWith(currentStepIndex: stepIndex);

      print('📝 DEBUG - Step $stepIndex: channel=${step.channel}, messages=${step.botMessages.length}, waitForUser=${step.waitForUser}, isComplete=${step.isModuleComplete}');

      if (step.isModuleComplete) {
        print('✅ Module marked as complete at step $stepIndex');
        _ref.read(guidedLessonProvider.notifier).completeModule();
        return;
      }

      if (step.botMessages.isEmpty) {
        print('⚠️ Step $stepIndex has no messages');
        if (!step.waitForUser) {
          _advanceStep();
        }
        return;
      }

      print('📝 DEBUG - Step $stepIndex first message: "${step.botMessages[0].substring(0, step.botMessages[0].length > 50 ? 50 : step.botMessages[0].length)}..."');

      final currentBubbleMode = _ref.read(bubbleModeProvider);
      print('📝 DEBUG - Current bubble mode: $currentBubbleMode');

      if (step.channel == MessageChannel.narration) {
        print('📝 DEBUG - Setting bubble mode to NARRATIVE');
        _ref.read(bubbleModeProvider.notifier).state = BubbleMode.narrative;
      } else if (_ref.read(bubbleModeProvider) != BubbleMode.greeting) {
        print('📝 DEBUG - Setting bubble mode to WAITING_FOR_NARRATIVE');
        _ref.read(bubbleModeProvider.notifier).state = BubbleMode.waitingForNarrative;
      }

    if (step.channel == MessageChannel.narration) {
      print('📝 DEBUG - Routing to NARRATION channel - showing speech bubbles');
      final narrationMessages = step.botMessages.map((msg) => NarrationMessage(
        content: msg,
        characterId: _currentCharacter?.id,
        pacingHint: step.pacingHint,
      )).toList();

      if (step.imageAssetPath != null) {
        narrationMessages.add(NarrationMessage(
          content: '', // Empty content, image-only message
          characterId: _currentCharacter?.id,
          pacingHint: step.pacingHint,
          imageAssetPath: step.imageAssetPath,
        ));
      }

      _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
        narrationMessages,
        _currentLesson?.id ?? 'unknown',
      );

      for (final msg in step.botMessages) {
        _conversationHistory.add({'role': 'assistant', 'content': msg});
      }

      if (step.waitForUser) {
        _ref.read(guidedLessonProvider.notifier).setWaitingForUser();
        return;
      }

      int totalDisplayMs = 0;
      for (int i = 0; i < step.botMessages.length; i++) {
        final msg = step.botMessages[i];
        final wordCount = msg.split(RegExp(r'\s+')).length;
        final isLastBubble = (i == step.botMessages.length - 1);

        totalDisplayMs += (wordCount * 300).clamp(2000, 8000).toInt();

        final length = msg.length;
        totalDisplayMs += length < 50 ? 800 : (length < 120 ? 1200 : 1800);

        if (isLastBubble) {
          totalDisplayMs += 2000; // Extra 2 seconds to ensure last bubble is fully readable
        }
      }

      await Future.delayed(Duration(milliseconds: totalDisplayMs + 500));
      if (requestId != _currentRequestId) return; // Module changed, stop

      final nextIndex = state.currentStepIndex + 1;
      if (nextIndex < _script.length && _script[nextIndex].channel == MessageChannel.interaction) {
        _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative(instant: true);
        await Future.delayed(const Duration(milliseconds: 200));
        if (requestId != _currentRequestId) return; // Module changed, stop
      }

      _advanceStep();
    } else {

      if (step.transitionBubble != null) {
        _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
          [NarrationMessage(
            content: step.transitionBubble!,
            characterId: _currentCharacter?.id,
            pacingHint: PacingHint.fast, // Quick, excited transition
          )],
          _currentLesson?.id ?? 'unknown',
        );

        final wordCount = step.transitionBubble!.split(RegExp(r'\s+')).length;
        final displayMs = (wordCount * 300).clamp(2000, 4000); // Shorter for transitions
        final gapMs = 800; // Fast pacing for transitions

        await Future.delayed(Duration(milliseconds: displayMs + gapMs));
        if (requestId != _currentRequestId) return;

        _ref.read(lessonNarrativeBubbleProvider.notifier).hideNarrative(instant: true);
        await Future.delayed(const Duration(milliseconds: 200));
        if (requestId != _currentRequestId) return;
      }

      for (int i = 0; i < step.botMessages.length; i++) {
        if (i > 0) {
          final previousMessage = step.botMessages[i - 1];
          final readingTime = ReadingTime.calculateTotalMs(previousMessage);

          state = state.copyWith(isStreaming: true);

          await Future.delayed(Duration(milliseconds: readingTime));
          if (requestId != _currentRequestId) return; // Module changed, stop

          state = state.copyWith(isStreaming: false);
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

      if (step.imageAssetPath != null) {
        final lastMessage = step.botMessages.isNotEmpty ? step.botMessages.last : '';
        final readingTime = ReadingTime.calculateTotalMs(lastMessage);

        state = state.copyWith(isStreaming: true);

        await Future.delayed(Duration(milliseconds: readingTime));
        if (requestId != _currentRequestId) return; // Module changed, stop

        state = state.copyWith(isStreaming: false);

        final imageMessage = LessonChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: '', // Empty content, image-only message
          channel: MessageChannel.interaction,
          timestamp: DateTime.now(),
          imageAssetPath: step.imageAssetPath,
        );
        state = state.copyWith(
          messages: [...state.messages, imageMessage],
        );

        await Future.delayed(const Duration(milliseconds: 2000)); // 2s to view image
        if (requestId != _currentRequestId) return;
      }

      for (final msg in step.botMessages) {
        _conversationHistory.add({'role': 'assistant', 'content': msg});
      }

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

  void _advanceStep() {
    final nextIndex = state.currentStepIndex + 1;
    if (nextIndex < _script.length) {
      _attemptsByStep.remove(state.currentStepIndex);
      _executeStep(nextIndex);
    }
  }


  Future<bool> _sendAIEvaluation(String studentAnswer, String evalContext) async {
    final character = _currentCharacter;
    if (character == null) return true; // Default to proceeding if no character

    final requestId = _currentRequestId;
    final currentStepIndex = state.currentStepIndex;

    final attemptNumber = (_attemptsByStep[currentStepIndex] ?? 0) + 1;
    _attemptsByStep[currentStepIndex] = attemptNumber;

    print('📊 Attempt $attemptNumber of 3 for step $currentStepIndex');

    state = state.copyWith(isChecking: true);
    await Future.delayed(const Duration(milliseconds: 300));

    if (requestId != _currentRequestId) {
      state = state.copyWith(isChecking: false);
      return false; // Context changed, don't proceed
    }
    state = state.copyWith(isChecking: false);

    final moduleContext = _currentModule != null && _currentLesson != null
        ? 'Current Lesson: ${_currentLesson!.title}\nCurrent Module: ${_currentModule!.title} (${_currentModule!.type.displayName})'
        : 'Current topic: Circulation and Gas Exchange';

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

    if (requestId != _currentRequestId) {
      print('⚠️ Discarding AI response - module context changed (old: $requestId, current: $_currentRequestId)');
      state = state.copyWith(isStreaming: false);
      return false; // Context changed, don't proceed
    }

    print('💬 [AI EVAL] Bubble response: "$bubbleResponse"');
    _ref.read(lessonNarrativeBubbleProvider.notifier).showNarrative(
      [NarrationMessage(content: bubbleResponse, characterId: _currentCharacter?.id)],
      _currentLesson?.id ?? 'unknown',
    );

    await Future.delayed(const Duration(milliseconds: 1500));

    if (requestId != _currentRequestId) {
      return false; // Context changed during delay
    }

    print('💬 [AI EVAL] Starting full explanation...');

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

    if (requestId != _currentRequestId) {
      print('⚠️ Discarding final explanation - module context changed');
      state = state.copyWith(isStreaming: false);
      final messages = state.messages.where((m) => m.id != msgId).toList();
      state = state.copyWith(messages: messages);
      return false; // Context changed, don't proceed
    }

    print('✅ [AI EVAL] Full explanation complete (${fullExplanation.length} chars)');
    print('💬 [AI EVAL] Explanation: "${fullExplanation.substring(0, fullExplanation.length.clamp(0, 100))}..."');
    _updateLastMessage(fullExplanation, false);
    state = state.copyWith(isStreaming: false);
    _conversationHistory.add({'role': 'assistant', 'content': fullExplanation});

    final isEndOfModuleQA = evalContext.toLowerCase().contains('tap next') ||
                            evalContext.toLowerCase().contains('click next');

    bool canProceed;
    if (isEndOfModuleQA) {
      canProceed = fullExplanation.toLowerCase().contains('tap next') ||
                   fullExplanation.toLowerCase().contains('click next');
      print(canProceed
          ? '✅ AI says Tap Next - student is ready to proceed'
          : '⏸️ End-of-module Q&A - waiting for student to say "ready" or ask more questions');
    } else {
      if (attemptNumber >= 3) {
        canProceed = true;
        print('✅ Max attempts reached (3/3) - auto-advancing with encouragement');
      } else {
        final isCorrect = fullExplanation.toLowerCase().contains('correct!') ||
                         fullExplanation.toLowerCase().contains('tama!');

        canProceed = isCorrect;
        print(canProceed
            ? '✅ Answer correct/partial - proceeding to next step'
            : '⏸️ Attempt $attemptNumber/3 - staying for retry');
      }
    }

    await Future.delayed(const Duration(milliseconds: 2000));

    return canProceed;
  }

  Future<bool> _sendGeneralResponse(String studentInput) async {
    final character = _currentCharacter;
    if (character == null) return true; // Default to proceeding

    final requestId = _currentRequestId;

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
        if (requestId != _currentRequestId) {
          print('⚠️ Discarding streaming response - module context changed');
          state = state.copyWith(isStreaming: false);
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

    if (requestId != _currentRequestId) {
      print('⚠️ Discarding final response - module context changed');
      state = state.copyWith(isStreaming: false);
      final messages = state.messages.where((m) => m.id != msgId).toList();
      state = state.copyWith(messages: messages);
      return false; // Context changed, don't proceed
    }

    _updateLastMessage(fullResponse, false);
    state = state.copyWith(isStreaming: false);
    _conversationHistory.add({'role': 'assistant', 'content': fullResponse});

    return true;
  }

  Future<void> _showFollowUpPrompt(int requestId) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (requestId != _currentRequestId) return; // Context changed, abort

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

  }


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


  List<ScriptStep> _getScriptForModule(String moduleId) {
    print('📝 _getScriptForModule called with moduleId: "$moduleId" (length: ${moduleId.length})');

    switch (moduleId) {
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
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 1, MODULE 1: Fa-SCI-nate
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptFascinate() {
    return [
     ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Kumusta!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Welcome to today\'s science journey here in Roxas City, where the sea breeze is fresh and our bodies are always on the move.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/1.webp', // Roxas City aerial view
      ),

     ScriptStep(
        botMessages: [
          'Today, we will explore how your body moves blood and exchanges gases, just like how boats carry goods from the Culasi fish port to different barangays.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/2.webp', // Fishing boat
      ),

     ScriptStep(
        botMessages: [
          'This lesson is all about **Circulation and Gas Exchange** — your body\'s very own delivery network.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to dive in? Let\'s get **Fa-SCI-nated**!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true, // Wait for user acknowledgment
      ),

     ScriptStep(
        botMessages: [
          'Imagine this...',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'You\'re biking along Roxas Boulevard during sunset or dancing energetically during Sinadya Festival.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/3.webp', // Biking scene
      ),

      ScriptStep(
        botMessages: [
          'Have you noticed your heart beating faster?',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Here\'s another question:',
        ],
        channel: MessageChannel.narration,
        waitForUser: false, // Auto-continue to question
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Just like how delivery trucks distribute seafood from the port to the '
              'markets around Capiz, your body has a system that delivers oxygen, '
              'nutrients, and energy to every cell.',
          'That amazing system is called the **circulatory system**!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false, // Auto-continue to conclusion
        imageAssetPath: 'assets/images/topic_1/lesson_1/4.webp', // Delivery truck
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'fascinate',
            moduleName: 'Fa-SCI-nate',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration - positive energy
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 1, MODULE 2: Goal SCI-tting
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGoalScitting() {
    return [
      ScriptStep(
        botMessages: [
          'Now that you\'re Fa-SCI-nated, let\'s set our learning goals!',
          NarrationVariations.getModuleWelcome('goal'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false, // Auto-continue
      ),

     ScriptStep(
        botMessages: [
          'Ready to see what you\'ll master today?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true, // Acknowledgment
      ),

     ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:',
          '**1.** Compare the two types of circulatory systems and understand why humans have the system we do',
          '**2.** Describe the parts of the circulatory system and their functions—the heart, blood vessels, and more',
          '**3.** Explain the components of blood and how they help maintain homeostasis in your body',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false, // Auto-continue after displaying
      ),

     ScriptStep(
        botMessages: [
          'Think of these goals as your science destination—let\'s get there step by step!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 1, MODULE 3: Pre-SCI-ntation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptPreScintation() {
    return [
      ScriptStep(
        botMessages: [
          'Great job setting your learning goals!',
          'Now let\'s build the foundation.',
          NarrationVariations.getModuleWelcome('presentation'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Let\'s start with the basics.',
          'Your body needs balance to survive—this balance is called **homeostasis**.',
          '**Homeostasis means:**\n• Nutrients are delivered to cells\n• Oxygen is supplied\n• Wastes like carbon dioxide are removed',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Small organisms rely on **diffusion**, but humans, like active students in Roxas City, need something faster and stronger.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/5.webp', 
      ),

      ScriptStep(
        botMessages: [
          'That\'s why we have a **circulatory system** powered by the heart, blood, and blood vessels.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'presentation',
            moduleName: 'Pre-SCI-ntation',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 1, MODULE 4: Inve-SCI-tigation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptInveScitigation() {
    return [
      ScriptStep(
        botMessages: [
          'You now have a solid foundation!',
          'Time to Inve-SCI-tigate deeper!',
          NarrationVariations.getModuleWelcome('investigation'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Part 1: Types of Circulatory Systems**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
     ),

     ScriptStep(
        botMessages: [
          'There are two types of circulatory systems:',
          '**1. Open Circulatory System**\n• Found in insects like crabs and grasshoppers\n• Blood flows freely and slowly\n• Best for small, less active animals',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/6.webp', // Open circulatory animals
      ),

     ScriptStep(
        botMessages: [
          '**2. Closed Circulatory System (Humans!)**\n• Blood stays inside vessels\n• Pumped by the heart\n• Faster and more efficient—perfect for active lifestyles like swimming in Baybay or playing basketball after school',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/7.webp', // Closed circulatory animals
      ),

     ScriptStep(
        botMessages: [
          '**Part 2: The Heart – Your Body\'s Pump**',
          'Your heart is about the size of your clenched fist ✊',
          'It beats over 100,000 times a day—even while you sleep!',
          '**Key parts of the heart:**\n• **Atria** – receive blood\n• **Ventricles** – pump blood out\n• **Valves** – prevent backflow\n• **Septum** – separates left and right sides',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/8.webp', // Heart anatomy diagram
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 3: Blood Vessels – The Body\'s Roads**',
          'Think of blood vessels like the roads connecting barangays in Roxas City:',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/9.webp', // Barangay roads aerial
      ),

     ScriptStep(
        botMessages: [
          '**Arteries** – carry blood away from the heart\n**Veins** – bring blood back to the heart\n**Capillaries** – tiny paths where oxygen and nutrients are exchanged',
         
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/10.webp', // Blood vessels diagram
      ),

      ScriptStep(
        botMessages:  [
          'Without these "roads," cells would never receive what they need to survive.',
          ],
          channel: MessageChannel.interaction,
          waitForUser: false,
        ),


     ScriptStep(
        botMessages: [
          '**Part 4: Blood – The Transport Medium**',
          'Blood makes up about 7–8% of your body weight.',
          '**Plasma (55%)**\n• Mostly water\n• Carries nutrients, hormones, and wastes',
          '**Red Blood Cells** – carry oxygen using hemoglobin\n**White Blood Cells** – defend against infection\n**Platelets** – help blood clot when you get a wound',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_1/11.webp', // Blood components diagram
      ),

       ScriptStep(
        botMessages: [
          'Every drop of blood plays a role in keeping you healthy and active!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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


  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 1, MODULE 5: Self-A-SCI-ssment
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptSelfAScissment() {
    return [
      ScriptStep(
        botMessages: [
          'Wow, you\'ve learned so much about the circulatory system!',
          'Now it\'s time to test your understanding.',
          'Don\'t worry — this is to help you learn, not to stress you out.',
          NarrationVariations.getModuleWelcome('assessment'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to check your knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'If you can answer these questions, you\'re doing SCI-mazing!',
          'Remember: It\'s okay if you need to review. Learning takes time, and every question helps you understand better!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Encouraging reflection
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'assessment',
            moduleName: 'Self A-SCI-ssment',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 1, MODULE 6: SCI-pplementary
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptScipplementary() {
    return [
      ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed the core lesson on the circulatory system.',
          'Ready for some bonus content and fun activities?',
          NarrationVariations.getModuleWelcome('supplementary'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready for bonus content?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'You\'ve completed the lesson on **The Circulation System**!',
          'You now understand how your heart pumps blood, the role of blood vessels, and why this system is essential for life.',
          'Keep taking care of your circulatory system!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 2, MODULE 1: Fa-SCI-nate
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2Fascinate() {
    return [
     ScriptStep(
        botMessages: [
          'Hello again, SCI-learner!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'In the last lesson, you learned about the heart, blood, and blood vessels.',
          'Today, we\'ll focus on how blood moves in specific pathways, just like jeepneys and tricycles following routes around the city.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/1.webp',
      ),

       ScriptStep(
        botMessages: [
          'In the last lesson, you learned about the heart, blood, and blood vessels.',
          'Today, we\'ll focus on how blood moves in specific pathways, just like jeepneys and tricycles following routes around the city.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/2.webp',
      ),

     ScriptStep(
        botMessages: [
          'This lesson is called **Circulation**.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.normal,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/3.webp',
      ),

     ScriptStep(
        botMessages: [
          'Ready to follow the path of your blood?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      ScriptStep(
        botMessages: [
          'Imagine this...',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, 
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'You jog along Baybay Roxas early in the morning.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow, // Reflection - let student imagine
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/4.webp', 
      ),

       ScriptStep(
        botMessages: [
          'You breathe faster, and your heart beats harder.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow, 
        waitForUser: false,

      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'fascinate',
            moduleName: 'Fa-SCI-nate',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 2, MODULE 2: Goal SCI-tting
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2GoalScitting() {
    return [
      ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
          NarrationVariations.getModuleWelcome('goal'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to see what you\'ll master today?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
        botMessages: [
          'By the end of this lesson, you will be able to:',
          '**1.** Differentiate between the pulmonary and systemic circuits',
          '**2.** Explain how blood transports oxygen, nutrients, and wastes',
          'These goals are like your travel map—let\'s follow them step by step!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Think of your circulatory system as Roxas City\'s transportation network.',
          'Just like jeepneys have specific routes, your blood follows specific pathways.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 2, MODULE 3: Pre-SCI-ntation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2PreScintation() {
    return [
      ScriptStep(
        botMessages: [
          'Now let\'s build the foundation!',
          NarrationVariations.getModuleWelcome('presentation'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Blood does not move randomly inside your body.',
          'Instead, it follows **specific pathways** called **blood circuits**.',
          'Just like how public transport in Roxas City has routes, blood also has two main routes:',
          '**1. Pulmonary Circuit**\n• Pathway between heart and lungs\n• Relatively short route',
          '**2. Systemic Circuit**\n• Pathway from heart to entire body\n• Much longer route',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/5.webp', 
      ),

       ScriptStep(
        botMessages: [
          'Let\'s Explore this one',
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Understanding these circuits helps you understand how your body keeps every cell alive!',
          'You\'ve completed Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'presentation',
            moduleName: 'Pre-SCI-ntation',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 2, MODULE 4: Inve-SCI-tigation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2InveScitigation() {
    return [
      ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate deeper!',
          NarrationVariations.getModuleWelcome('investigation'),
          'Let\'s explore how blood travels through your body using two distinct circuits.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Part 1: Pulmonary Circuit**',
          'The pulmonary circuit is the pathway between the heart and the lungs.',
          '**Its main job is to:**\n• Remove carbon dioxide\n• Refill blood with oxygen',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/6.webp',
      ),

      
     ScriptStep(
        botMessages: [
          'Blood flows from the **right ventricle → lungs → left atrium**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 2: Systemic Circuit**',
          'The systemic circuit carries blood from the heart to the rest of the body.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/7.webp',      
        ),

        ScriptStep(
        botMessages: [
          '**It delivers:**\n• Oxygen\n• Nutrients\n• Hormones',
          'It also collects waste materials.',
          'Blood flows from the **left ventricle → body tissues → right atrium**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          '**Mini Investigation:**',
          'Think of blood vessels like straws of different sizes.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/8.webp',      
      ),

     ScriptStep(
        botMessages: [
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 2, MODULE 5: Self-A-SCI-ssment
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2SelfAScissment() {
    return [
      ScriptStep(
        botMessages: [
          'You\'ve learned so much about blood circuits!',
          'Now it\'s time to test your understanding.',
          NarrationVariations.getModuleWelcome('assessment'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to check your knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'If you can answer these questions, you\'re doing SCI-mazing!',
          'Remember: Learning takes time, and every question helps you understand better!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Encouraging reflection
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'assessment',
            moduleName: 'Self A-SCI-ssment',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 2, MODULE 6: SCI-pplementary
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptCirc2Scipplementary() {
    return [
      ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed the core lesson on blood circulation pathways!',
          'Ready for some bonus content?',
          NarrationVariations.getModuleWelcome('supplementary'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready for bonus content and health tips?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
        botMessages: [
          '**Did you know?**',
          'The first stethoscope was made of wood over 170 years ago!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_2/9.webp',
      ),

     ScriptStep(
        botMessages: [
          '• Invented by René Laennec in 1816\n• It was a simple wooden tube\n• Today\'s stethoscopes are much more advanced',
          '**Fun Fact:** Your blood travels about 19,000 kilometers of blood vessels in your body—that\'s almost halfway around the Earth!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**To keep your circulation healthy here in Roxas City:**',
          '✅ **Stay active** (walk, bike, dance!)\n✅ **Eat nutritious food** (fresh fish helps!)\n✅ **Avoid smoking** and too much fatty food',
          'A healthy heart means a healthy life!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 3, MODULE 1: Fa-SCI-nate
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptRespFascinate() {
    return [
     ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Welcome back to your science adventure here in Roxas City, Capiz!',
          'The air is fresh and the sea breeze keeps us energized.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_3/1.webp',
      ),

       ScriptStep(
        botMessages: [
          'Have you ever noticed how your breathing changes when you walk along Baybay Roxas, climb stairs at school, or play basketball with friends?',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Welcoming excitement
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Today, we\'ll explore the **Respiratory System**—the system that allows your body to breathe, exchange gases, and release energy.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to take a deep breath and begin?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
        botMessages: [
          'Imagine this...',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Reflection - let student imagine
        waitForUser: false,
      ),

       ScriptStep(
        botMessages: [
          'You\'re jogging early in the morning along the roads of Pueblo de Panay.',
          'You inhale deeply and feel the cool air fill your lungs.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow, 
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_3/2.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Excellent! You\'ve completed Fa-SCI-nate!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'fascinate',
            moduleName: 'Fa-SCI-nate',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 3, MODULE 2: Goal SCI-tting
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptRespGoalScitting() {
    return [
      ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
          NarrationVariations.getModuleWelcome('goal'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to see what you\'ll master today?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Great! You\'ve completed Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 3, MODULE 3: Pre-SCI-ntation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptRespPreScintation() {
    return [
      ScriptStep(
        botMessages: [
          'Now let\'s build the foundation!',
          NarrationVariations.getModuleWelcome('presentation'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Many people think respiration is just breathing.',
          'But respiration is actually a **complex process of gas exchange** that allows your body to produce energy.',
          'Without oxygen, your body—just like a boat without fuel—cannot function properly.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_3/3.webp',
      ),

     ScriptStep(
        botMessages: [
          'Respiration involves three main events.',
          'Let’s explore them one by one.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'You\'ve completed Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'presentation',
            moduleName: 'Pre-SCI-ntation',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 3, MODULE 4: Inve-SCI-tigation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptRespInveScitigation() {
    return [
      ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate deeper!',
          NarrationVariations.getModuleWelcome('investigation'),
          'Let\'s explore how air travels through your body and how gas exchange keeps you alive!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Part 1: Three Main Events of Respiration**',
          'Here are the three main events:',
          '**1. Breathing** – air enters and leaves the lungs\n**2. Diffusion** – oxygen and carbon dioxide move across membranes\n**3. Transport of gases** – oxygen is delivered to cells, carbon dioxide is removed',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 2: Path of Air**',
          'Let\'s trace the path of air when you inhale:',
          '**Nose → Nasal cavity → Pharynx → Larynx → Trachea → Bronchi → Bronchioles → Alveoli**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_3/4.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 3: Parts of the Respiratory System**',
          'Each part has a special role:',
          '**Nasal cavity** – filters air\n**Pharynx** – shared passageway for air and food\n**Larynx** – produces sound (voice box)\n**Epiglottis** – prevents food from entering lungs',
          '**Trachea** – windpipe\n**Bronchi & bronchioles** – air pathways\n**Alveoli** – gas exchange\n**Diaphragm** – helps breathing',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 4: Alveoli – Site of Gas Exchange**',
          'The alveoli are tiny, balloon-like air sacs.',
          'They have:\n• Thin walls\n• Moist surfaces\n• Many capillaries',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_1/lesson_3/5.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Amazing work, investigator!',
          'You\'ve completed Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 3, MODULE 5: Self-A-SCI-ssment
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptRespSelfAScissment() {
    return [
      ScriptStep(
        botMessages: [
          'You\'ve learned so much about the respiratory system!',
          'Now it\'s time to test your understanding.',
          NarrationVariations.getModuleWelcome('assessment'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to check your knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'If you can answer these questions, you\'re doing SCI-mazing!',
          'Remember: Learning takes time, and every question helps you understand better!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Encouraging reflection
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'assessment',
            moduleName: 'Self A-SCI-ssment',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 1, LESSON 3, MODULE 6: SCI-pplementary
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptRespScipplementary() {
    return [
      ScriptStep(
        botMessages: [
          'Congratulations! You\'ve completed the core lesson on the respiratory system!',
          'Ready for some bonus content?',
          NarrationVariations.getModuleWelcome('supplementary'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready for bonus content and health tips?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
        botMessages: [
          '**Did you know?**',
          'Difficulty in breathing is called **dyspnea**. It may happen after heavy exercise or due to health conditions.',
          '**Amazing fact:** You take about 20,000 breaths per day!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**To keep your respiratory system healthy in Roxas City:**',
          '✅ **Avoid smoking**\n✅ **Exercise regularly**\n✅ **Breathe clean air**\n✅ **Eat nutritious food**',
          'Healthy lungs mean more energy for learning and fun!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow, // Celebration
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 1, MODULE 1: Fa-SCI-nate
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGenetics1Fascinate() {
    return [
     ScriptStep(
        botMessages: [
          'Hello, SCI-learner!'
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Welcome to another science adventure here in Roxas City!',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Where family traits like smiles, dimples, or curly hair are often noticed during reunions and fiestas.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/1.webp',
      ),
      ScriptStep(
        botMessages: [
          'Have you ever wondered why you look like your parents or why you share similar traits with your siblings?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/2.webp',
      ),

       ScriptStep(
        botMessages: [
          'Today, we will explore **Genes and Chromosomes**—the tiny structures inside your cells that carry instructions making you YOU.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Ready to discover your biological blueprint?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
     ScriptStep(
        botMessages: [
          'Imagine this... During a family gathering in Roxas City, someone says:',
          '"Ka-itsura mo guid imo iloy!" (You really look like your mother!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/3.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Great! You\'ve completed Fa-SCI-nate!',
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
      ),
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'fascinate',
            moduleName: 'Fa-SCI-nate',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 1, MODULE 2: Goal SCI-tting
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGenetics1GoalScitting() {
    return [
     ScriptStep(
        botMessages: [
          NarrationVariations.getModuleWelcome('goal'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Ready to unlock the secrets of your genetic code?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
     ScriptStep(
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
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 1, MODULE 3: Pre-SCI-ntation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGenetics1PreScintation() {
    return [
     ScriptStep(
        botMessages: [
          NarrationVariations.getModuleWelcome('presentation'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Ready to dive into the details?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
     ScriptStep(
        botMessages: [
          'Let\'s build your foundation!',
          'For a long time, people had different ideas about heredity.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Some believed traits came from blood. Others believed traits were blended from parents.',
          'But science has shown us that traits are passed through **genes**, not blood.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'These genes are found in **DNA**, which is packed inside **chromosomes**.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          'Do you you understand the “goals”?',
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'presentation',
            moduleName: 'Pre-SCI-ntation',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 1, MODULE 4: Inve-SCI-tigation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGenetics1InveScitigation() {
    return [
     ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Let\'s explore genes and chromosomes in detail.',
          '\n**Part 1: Genes and Chromosomes**',
          'Genes are segments of DNA.',
          'Chromosomes are threadlike structures that carry genes.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/4.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 2: Human Chromosomes**',
          'Each human body cell has **46 chromosomes**, arranged in **23 pairs**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/5.webp',
      ),
     ScriptStep(
        botMessages: [
          'One set comes from your mother, and one from your father.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 3: DNA and the Genetic Code**',
          'DNA looks like a twisted ladder, called a **double helix**.',
          'It is made of four bases: A (Adenine), T (Thymine), G (Guanine), C (Cytosine).',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/6.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 4: Genotype and Phenotype**',
          'Your **genotype** is the set of genes you inherit.',
          'Your **phenotype** is what you can observe, like hair texture or eye color.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/7.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 5: Heredity and Environment**',
          'Genes are important—but the environment matters too!',
          'For example, many people in Roxas City get darker skin after spending time under the sun.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_1/8.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Amazing work! You\'ve investigated the world of genes and chromosomes!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 1, MODULE 5: Self-A-SCI-ssment
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGenetics1SelfAScissment() {
    return [
     ScriptStep(
        botMessages: [
          'Time for Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Let\'s check what you\'ve learned!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Excellent work on the assessment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'assessment',
            moduleName: 'Self A-SCI-ssment',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 1, MODULE 6: SCI-pplementary
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGenetics1Scipplementary() {
    return [
     ScriptStep(
        botMessages: [
          'SCI-pplementary facts!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Humans have around **20,000–25,000 genes**!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Traits like height, weight, and even talents are shaped by genes **and** environment.',
          'Celebrate your uniqueness—because no one else has your exact genetic combination!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Great job, SCI-learner!',
          'You\'ve explored the world of genes and chromosomes—the foundation of heredity.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'In the next lesson, we\'ll learn how traits are passed on from parents to offspring.',
          '**Padayon sa tu-on sa SCI-ensiya!** (Continue learning science!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// -----------------------------------------------------------------------


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 2, MODULE 1: Fa-SCI-nate
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptInheritFascinate() {
    return [
     ScriptStep(
        botMessages: [
          'Hello, SCI-learner! Welcome back to our science journey here in Roxas City, Capiz!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Where family resemblances are often noticed during fiestas, reunions, and even at the streets.',
          '\nYou already know that traits are passed from parents to children.',
          'But did you know that not all traits follow Mendel\'s simple rules?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_2/1.webp',
      ),
     ScriptStep(
        botMessages: [
          'Today, we\'ll explore **Non-Mendelian Inheritance**!',
          'Patterns that explain why traits like blood type, skin color, and some diseases don\'t follow the usual dominant–recessive pattern.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Ready to level up your genetics knowledge?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
     ScriptStep(
        botMessages: [
          'Imagine this...',
          'In a family from Roxas City, one child has blood type AB, while the parents have type A and type B.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Great! You\'ve completed Fa-SCI-nate!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'fascinate',
            moduleName: 'Fa-SCI-nate',
          ),
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 2, MODULE 2: Goal SCI-tting
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptInheritGoalScitting() {
    return [
     ScriptStep(
        botMessages: [
          NarrationVariations.getModuleWelcome('goal'),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Great! Let\'s set your learning goals for this lesson.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Ready to explore these complex patterns?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
     ScriptStep(
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
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 2, MODULE 3: Pre-SCI-ntation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptInheritPreScintation() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Let\'s build your foundation!',
          'Gregor Mendel discovered basic rules of inheritance using pea plants.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'However, scientists later found that many traits do **not** follow Mendel\'s rules.',
          'These traits follow **Non-Mendelian inheritance**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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
     ScriptStep(
        botMessages: [
          'Ready to dive into the details?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'presentation',
            moduleName: 'Pre-SCI-ntation',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 2, MODULE 4: Inve-SCI-tigation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptInheritInveScitigation() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Inve-SCI-tigation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Time to Inve-SCI-tigate!',
          'Let\'s explore the different patterns of non-Mendelian inheritance.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          '**Part 1: Incomplete Dominance**',
          'In incomplete dominance, neither allele is fully dominant.',
          'The heterozygous individual shows a **blended or intermediate** trait.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Example: Red flower + White flower → **Pink flower**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_2/2.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 2: Codominance**',
          'In codominance, both alleles are **equally expressed**.',
          'Example: Blood type AB shows both A and B antigens.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath:  'assets/images/topic_2/lesson_2/3.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 3: Multiple Alleles**',
          'Multiple alleles mean that **more than two alleles** exist for a trait.',
          'Example: ABO blood group system has alleles A, B, and O.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Even though there are three alleles, a person only gets **two**—one from each parent.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_2/4.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 4: Polygenic Traits**',
          'Some traits are controlled by **many genes** working together.',
          'These are called polygenic traits.',
          'Examples: Height, skin color, hair color.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_2/5.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '**Part 5: Sex-linked Traits**',
          'Some genes are found on the **X chromosome**.',
          'These traits are called sex-linked traits.',
          'They are more common in **males** because males have only one X chromosome.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_2/lesson_2/6.webp',
      ),
     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Amazing work! You\'ve investigated all the non-Mendelian patterns!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 2, MODULE 5: Self-A-SCI-ssment
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptInheritSelfAScissment() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Let\'s check your understanding!',
          'Time for Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Excellent work on the assessment!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
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
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'assessment',
            moduleName: 'Self A-SCI-ssment',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }


  /// -------------------------------------------------------------------------
  /// TOPIC 2, LESSON 2, MODULE 6: SCI-pplementary
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptInheritScipplementary() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to SCI-pplementary!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          '**Did you know?**',
          'About 5% of Asian males have some form of **color blindness**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Today, special eyeglasses can help people with color blindness see better.',
          'Understanding genetics helps families make informed health decisions.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Great job, SCI-learner!',
          'You\'ve learned how traits can be inherited in more complex ways than Mendel first discovered.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'In the next lesson, we\'ll explore probability and inheritance patterns.',
          '**Padayon sa pagtu-on sa SCI-ensiya!** (Continue learning science!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),
      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 1: Fa-SCI-nate (Plant Photosynthesis)
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 1: Fa-SCI-nate
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoFascinate() {
    return [
     ScriptStep(
        botMessages: [
          'Hello, SCI-learner!',
          'Welcome to another science adventure here in Roxas City, where rice fields, mangroves, and backyard plants turn sunlight into life-sustaining energy.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),
     ScriptStep(
        botMessages: [
          'Welcome to another science adventure here in Roxas City, where rice fields, mangroves, and backyard plants turn sunlight into life-sustaining energy.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/1.webp',
      ),
     ScriptStep(
        botMessages: [
          'Have you ever wondered how plants grow tall even though they don\'t eat like humans do?',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Today\'s lesson is about **photosynthesis**, the process that powers plants and supports all life in the ecosystem, including us.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to follow the path of energy from the Sun to living things?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
        botMessages: [
          'Imagine this...',
          'You walk past a rice field in Capiz at noon. The Sun is bright, and the leaves are wide open.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/2.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Plants use sunlight to **make their own food** through photosynthesis.',
          'Plants don\'t just absorb heat—they use **light energy to produce food**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'fascinate',
            moduleName: 'Fa-SCI-nate',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
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

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 2: Goal SCI-tting
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoGoalScitting() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'These goals will help you understand **where energy in the ecosystem begins**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to learn about photosynthesis?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

     ScriptStep(
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

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 3: Pre-SCI-ntation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoPreScintation() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Not all organisms get energy the same way.**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Autotrophs** (like plants) make their own food.',
          '**Heterotrophs** (like humans and animals) depend on other organisms.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Photosynthesis happens only in **photoautotrophs**, such as green plants.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/3.webp',
      ),

     ScriptStep(
        botMessages: [
          '**Without photosynthesis, there would be no food and no oxygen for life on Earth.**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to explore how this amazing process works?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'presentation',
            moduleName: 'Pre-SCI-ntation',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 4: Inve-SCI-tigation (Plant Photosynthesis)
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 4: Inve-SCI-tigation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoInveScitigation() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Inve-SCI-tigation!',
          'Let\'s discover where and how photosynthesis happens!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '## Part 1: Where Photosynthesis Happens',
          'Photosynthesis mainly occurs in the **leaves** of plants.',
          'Inside leaf cells are organelles called **chloroplasts**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/4.webp',
      ),

     ScriptStep(
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

     ScriptStep(
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
        imageAssetPath: 'assets/images/topic_3/lesson_1/5.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '## Part 3: Two Stages of Photosynthesis',
          'Photosynthesis has **two stages**:',
          '**1️⃣ Light-dependent reactions** – Require sunlight, produce ATP, NADPH, and oxygen',
          '**2️⃣ Light-independent reactions (Calvin Cycle)** – Occur in the stroma, use ATP and NADPH to produce glucose',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/6.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '## Part 4: Light and Pigments',
          'Chlorophyll **absorbs** red and blue/violet light and **reflects** green light.',
          'This is why leaves look green!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/7.webp',
      ),

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'CAM plants open their stomata during the **night** to conserve water.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/8.webp',
      ),
     ScriptStep(
        botMessages: [
          'Here is another one.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/9.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Excellent work! You\'ve explored how photosynthesis works inside plant cells.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
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

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 5: Self-A-SCI-ssment
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoSelfAScissment() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Let\'s check your understanding of photosynthesis!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Great job completing the assessment!',
          'You now understand the key concepts of photosynthesis.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to explore supplementary content?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'assessment',
            moduleName: 'Self A-SCI-ssment',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 6: SCI-pplementary (Plant Photosynthesis)
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 1, MODULE 6: SCI-pplementary
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptPhotoScipplementary() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to SCI-pplementary!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Did you know?**',
          'Photosynthesis is the foundation of all food chains.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'The rice you eat, the fish you enjoy, and even the oxygen you breathe—all depend on photosynthesis.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Protecting plants means protecting life in Roxas City and beyond!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_1/10.webp',
      ),

     ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve learned how plants capture sunlight and turn it into energy.',
          'Next, we\'ll explore how organisms release that energy through cellular respiration.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Padayon sa pagtu-on sa SCI-ensiya!** (Continue learning science!)',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 1: Fa-SCI-nate (Metabolism)
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 1: Fa-SCI-nate
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptMetabFascinate() {
    return [
     ScriptStep(
        botMessages: [
          'Hello, SCI-learner!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          ' Welcome back to our science journey here in Roxas City. Where Walking to school, playing basketball, and helping at home all require energy.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_2/1.webp',
      ),
     ScriptStep(
        botMessages: [
          'You learned in the previous lesson how plants store energy through photosynthesis.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Today, we\'ll discover how your body and other organisms release that stored energy through a process called **cellular respiration**.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.normal,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to find out where your energy really comes from? ⚡',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
        botMessages: [
          'Imagine this...',
          'You\'re playing basketball at the Villareal Stadium. After a few minutes, your arms feel tired and your breathing gets faster.',
        ],
        channel: MessageChannel.interaction,
        pacingHint: PacingHint.slow,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_2/2.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'During activity, cells **release energy**, not store or rest.',
          'Your cells break down food molecules to power your movements!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'fascinate',
            moduleName: 'Fa-SCI-nate',
          ),
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 2: Goal SCI-tting
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptMetabGoalScitting() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Goal SCI-tting!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'These goals will help you understand **how energy flows in living things**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to learn about cellular respiration?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'goal',
            moduleName: 'Goal SCI-tting',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 3: Pre-SCI-ntation (Metabolism)
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 3: Pre-SCI-ntation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptMetabPreScintation() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Pre-SCI-ntation!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**All living organisms need energy to survive.**',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Plants store energy in food during **photosynthesis**.',
          'Animals—including humans—release that energy through **cellular respiration**.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_2/3.webp',
      ),

     ScriptStep(
        botMessages: [
          'Cellular respiration is part of **metabolism**, the sum of all chemical processes in cells.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Metabolism has two parts:',
          '• **Anabolism** – building molecules',
          '• **Catabolism** – breaking down molecules to release energy',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to explore how cells release energy?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'presentation',
            moduleName: 'Pre-SCI-ntation',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 4: Inve-SCI-tigation (Metabolism)
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 4: Inve-SCI-tigation
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptMetabInveScitigation() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Inve-SCI-tigation!',
          'Let\'s discover how cells release energy!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '## Part 1: What Is Cellular Respiration?',
          'Cellular respiration is a catabolic process that produces **ATP**, the energy currency of the cell.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '## Part 2: Stages of Cellular Respiration',
          'Cellular respiration has three main stages:',
          '**1️⃣ Glycolysis** – occurs in the cytoplasm',
          '**2️⃣ Krebs Cycle** – occurs in the mitochondrial matrix',
          '**3️⃣ Electron Transport Chain** – occurs in the inner mitochondrial membrane',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_2/4.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '## Part 3: Aerobic Respiration',
          'Aerobic respiration happens in the **presence of oxygen**.',
          'It includes oxidation of pyruvic acid, Krebs cycle, and electron transport chain.',
          'This process can produce up to **36 ATP** molecules from one glucose.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '## Part 4: Anaerobic Respiration (Fermentation)',
          'When oxygen is limited, cells use anaerobic respiration or fermentation.',
          'There are two types:',
          '• **Alcoholic fermentation** – produces alcohol and CO₂',
          '• **Lactic acid fermentation** – produces lactic acid',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
        imageAssetPath: 'assets/images/topic_3/lesson_2/5.webp',
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          '## Part 5: Energy Comparison',
          'Let\'s compare energy yield:',
          '• **Aerobic respiration** – 36 ATP',
          '• **Anaerobic respiration** – 2 ATP',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Excellent work! You\'ve explored how cells release energy through cellular respiration.',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
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

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'investigation',
            moduleName: 'Inve-SCI-tigation',
          ),
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

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 5: Self-A-SCI-ssment
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptMetabSelfAScissment() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to Self-A-SCI-ssment!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Let\'s check your understanding!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
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

     ScriptStep(
        botMessages: [
          'Great job completing the assessment!',
          'You now understand how cells release energy.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to explore supplementary content?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'assessment',
            moduleName: 'Self A-SCI-ssment',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }

  /// -----------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 6: SCI-pplementary (Metabolism)
  /// -----------------------------------------------------------------------

  /// -------------------------------------------------------------------------
  /// TOPIC 3, LESSON 2, MODULE 6: SCI-pplementary
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptMetabScipplementary() {
    return [
     ScriptStep(
        botMessages: [
          'Welcome to SCI-pplementary!',
        ],
        channel: MessageChannel.narration,
        pacingHint: PacingHint.slow,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          '**Did you know?**',
          'The energy from the rice you eat in Capiz fuels your cells through cellular respiration.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Photosynthesis and respiration are opposite but connected processes—together, they keep energy flowing in ecosystems.',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Healthy food and regular exercise help your cells produce energy efficiently!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Great job, SCI-learner! You\'ve learned how cells release energy through cellular respiration.',
          '**Padayon sa pagtu-on sa SCI-ensiya!** Thank you!',
        ],
        channel: MessageChannel.interaction,
        waitForUser: false,
      ),

     ScriptStep(
        botMessages: [
          'Ready to finish this module?',
        ],
        channel: MessageChannel.interaction,
        waitForUser: true,
      ),

      ScriptStep(
        botMessages: [
          NarrationVariations.getModuleCompletion(
            moduleType: 'supplementary',
            moduleName: 'SCI-pplementary',
          ),
        ],
        channel: MessageChannel.narration,
        waitForUser: false,
        isModuleComplete: true,
      ),
    ];
  }
}


final lessonChatProvider =
    StateNotifierProvider<LessonChatNotifier, LessonChatState>(
  (ref) => LessonChatNotifier(ChatRepository(), ref),
);

final lessonNarrativeBubbleProvider =
    StateNotifierProvider<LessonNarrativeBubbleNotifier,
        LessonNarrativeBubbleState>(
  (ref) => LessonNarrativeBubbleNotifier(),
);

  /// -------------------------------------------------------------------------
  /// -------------------------------------------------------------------------
  List<ScriptStep> _scriptGenericFallback() {
    return [
     ScriptStep(
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
  /// -----------------------------------------------------------------------

