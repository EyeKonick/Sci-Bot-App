import 'dart:async';
import '../../../../shared/models/chat_message_extended.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../services/ai/openai_service.dart';
import '../../../../services/ai/prompts/aristotle_prompts.dart';
import '../services/context_service.dart';

/// Chat Repository - SINGLETON
/// Manages chat messages, AI interactions, and message history
/// Ensures all chat interfaces (messenger window + full screen) share same data
///
/// Week 3 Day 1-2 Implementation + Singleton Pattern Fix
/// Phase 0: Added async mutex for concurrent access safety
class ChatRepository {
  // ✅ SINGLETON PATTERN - Critical fix for syncing messenger and full chat
  static final ChatRepository _instance = ChatRepository._internal();

  // ✅ Factory constructor always returns the same instance
  factory ChatRepository() {
    return _instance;
  }

  // ✅ Private constructor
  ChatRepository._internal();

  // Phase 0: Async mutex to prevent concurrent message history corruption
  Completer<void>? _lock;

  /// Acquire async lock. Waits if another operation is in progress.
  Future<void> _acquireLock() async {
    while (_lock != null && !_lock!.isCompleted) {
      await _lock!.future;
    }
    _lock = Completer<void>();
  }

  /// Release async lock.
  void _releaseLock() {
    if (_lock != null && !_lock!.isCompleted) {
      _lock!.complete();
    }
  }

  // Shared state across ALL chat interfaces
  final _openAI = OpenAIService();

  // ✅ PHASE 3.1: Character-scoped conversation histories
  // Each AI character has its own isolated chat history
  final _characterHistories = <String, List<ChatMessage>>{
    'aristotle': [],
    'herophilus': [],
    'mendel': [],
    'odum': [],
  };

  final _contextService = ContextService();

  // Character context (will be set by provider)
  AiCharacter _currentCharacter = AiCharacter.aristotle;

  // Scenario-based architecture: generation ID to prevent chat leaking
  // When navigation changes character, _scenarioId increments to invalidate
  // any in-flight API responses from the previous scenario.
  int _scenarioId = 0;

  // ✅ Broadcast stream for real-time updates across interfaces
  final _messageStreamController = StreamController<List<ChatMessage>>.broadcast();
  
  /// Stream that notifies all listeners when messages change
  Stream<List<ChatMessage>> get messageStream => _messageStreamController.stream;
  
  /// Initialize repository
  /// Session-only: no Hive loading. In-memory histories start empty.
  Future<void> initialize() async {
    _notifyListeners();
  }

  /// Start a fresh scenario. Increments ID to invalidate in-flight requests.
  /// Clears current character's history for a clean slate.
  void startNewScenario() {
    _scenarioId++;
    _getCurrentHistory().clear();
    _notifyListeners();
  }

  /// Get current scenario ID (for external checks)
  int get scenarioId => _scenarioId;

  /// Send message and get streaming response
  /// Phase 0: Protected with async mutex to prevent concurrent corruption
  Stream<ChatMessage> sendMessageStream(String userMessage, {
    String? context,
    int? progressPercentage,
    String? lessonId,
    int? moduleIndex,
    AiCharacter? character,
  }) async* {
    await _acquireLock();
    // Capture scenario at start - if it changes mid-stream, discard results
    final capturedScenario = _scenarioId;
    try {
      // Update character if provided
      if (character != null) _currentCharacter = character;

      // Get current context from service
      ChatContext appContext;
      if (lessonId != null && moduleIndex != null) {
        appContext = await _contextService.getModuleContext(lessonId, moduleIndex);
      } else if (lessonId != null) {
        appContext = await _contextService.getLessonContext(lessonId);
      } else {
        appContext = await _contextService.getCurrentContext();
      }

      // Scenario changed while awaiting context - discard
      if (capturedScenario != _scenarioId) return;

      // Create user message with character ID
      final userMsg = ChatMessage.user(
        userMessage,
        context: appContext.location,
        characterId: _currentCharacter.id,
      );

      // Add to character-specific history
      _getCurrentHistory().add(userMsg);

      // Notify all listeners (messenger + full chat)
      _notifyListeners();

      yield userMsg;

      // Prepare messages for API
      final apiMessages = _prepareAPIMessages(
        context: appContext.location,
        progressPercentage: appContext.progressPercentage,
        contextDetails: appContext.toPromptContext(),
      );

      // Stream response from OpenAI
      String fullResponse = '';
      ChatMessage? streamingMessage;

      try {
        await for (final chunk in _openAI.streamChatCompletion(messages: apiMessages)) {
          // Scenario changed mid-stream - discard remaining chunks
          if (capturedScenario != _scenarioId) return;

          fullResponse += chunk;

          // Create/update streaming message
          streamingMessage = ChatMessage.assistant(
            fullResponse,
            characterName: _currentCharacter.name,
            context: appContext.location,
            isStreaming: true,
            characterId: _currentCharacter.id,
          );

          // Update in character-specific history (replace or add)
          final currentHistory = _getCurrentHistory();
          if (currentHistory.isNotEmpty &&
              currentHistory.last.role == 'assistant' &&
              currentHistory.last.isStreaming) {
            currentHistory[currentHistory.length - 1] = streamingMessage;
          } else {
            currentHistory.add(streamingMessage);
          }

          // Notify listeners with each chunk
          _notifyListeners();

          yield streamingMessage;
        }

        // Scenario changed - discard final message
        if (capturedScenario != _scenarioId) return;

        // Save final complete message
        final finalMsg = ChatMessage.assistant(
          fullResponse,
          characterName: _currentCharacter.name,
          context: appContext.location,
          isStreaming: false,
          characterId: _currentCharacter.id,
        );

        // Replace streaming message with final
        final currentHistory = _getCurrentHistory();
        if (currentHistory.isNotEmpty &&
            currentHistory.last.role == 'assistant') {
          currentHistory[currentHistory.length - 1] = finalMsg;
        } else {
          currentHistory.add(finalMsg);
        }

        // Final notification
        _notifyListeners();

        yield finalMsg;

      } catch (e) {
        // Scenario changed - don't show error for stale request
        if (capturedScenario != _scenarioId) return;

        // Error handling
        final errorMsg = ChatMessage.assistant(
          "I'm having trouble connecting right now. Please check your internet connection and try again.",
          characterName: _currentCharacter.name,
          context: appContext.location,
          characterId: _currentCharacter.id,
          isError: true,
        );

        _getCurrentHistory().add(errorMsg);
        _notifyListeners();

        yield errorMsg;
      }
    } finally {
      _releaseLock();
    }
  }

  /// Get current character's conversation history
  List<ChatMessage> _getCurrentHistory() {
    return _characterHistories[_currentCharacter.id] ?? [];
  }

  /// ✅ Notify all listeners of conversation changes
  /// Sends only the current character's messages
  void _notifyListeners() {
    if (!_messageStreamController.isClosed) {
      _messageStreamController.add(List.unmodifiable(_getCurrentHistory()));
    }
  }

  /// Prepare messages for API call
  List<Map<String, dynamic>> _prepareAPIMessages({
    required String context,
    int? progressPercentage,
    String? contextDetails,
  }) {
    final messages = <Map<String, dynamic>>[];

    // Use character's system prompt
    String systemPrompt = _currentCharacter.systemPrompt;
    
    // For Aristotle, can still use context-aware prompts
    if (_currentCharacter.id == 'aristotle' && contextDetails != null) {
      systemPrompt = '$systemPrompt\n\nADDITIONAL CONTEXT:\n$contextDetails';
    } else if (contextDetails != null) {
      // For expert characters, append context
      systemPrompt = '$systemPrompt\n\nCURRENT CONTEXT:\n$contextDetails';
    }
    
    messages.add({'role': 'system', 'content': systemPrompt});

    // Add conversation history (last 10 messages for context)
    // ✅ Use current character's history only
    final currentHistory = _getCurrentHistory();
    final recentHistory = currentHistory.length > 10
        ? currentHistory.sublist(currentHistory.length - 10)
        : currentHistory;

    for (final msg in recentHistory) {
      if (msg.role != 'system') {
        messages.add(msg.toOpenAIFormat());
      }
    }

    return messages;
  }


  /// Get greeting message
  ChatMessage getGreeting({
    int completedLessons = 0,
    int totalLessons = 8,
    double progressPercentage = 0.0,
    AiCharacter? character, // NEW: Accept character parameter
    String? personalizedGreeting, // NEW: Accept personalized greeting
  }) {
    final activeChar = character ?? _currentCharacter;
    
    // Use personalized greeting if provided, otherwise use character's default
    final greeting = personalizedGreeting ?? activeChar.greeting;

    return ChatMessage.assistant(
      greeting,
      characterName: activeChar.name,
      context: 'home',
      characterId: activeChar.id,
    );
  }

  /// Get random feature tip
  ChatMessage getFeatureTip() {
    final tips = AristotlePrompts.featureTips;
    final randomTip = tips[DateTime.now().millisecond % tips.length];
    
    return ChatMessage.assistant(
      randomTip,
      characterName: 'Aristotle',
      context: 'home',
    );
  }

  /// Clear chat history (in-memory only)
  Future<void> clearHistory() async {
    await _acquireLock();
    try {
      _getCurrentHistory().clear();
      _notifyListeners();
    } finally {
      _releaseLock();
    }
  }

  /// Get conversation history (unmodifiable)
  /// ✅ PHASE 3.1: Returns only current character's history
  List<ChatMessage> get conversationHistory =>
      List.unmodifiable(_getCurrentHistory());

  /// Check if OpenAI is configured
  bool get isConfigured => _openAI.isConfigured;

  /// Set current character
  /// ✅ PHASE 3.1: Switch to different character's history
  /// ✅ PHASE 3.4: Inject context-aware greeting on switch
  void setCharacter(AiCharacter character, {String? contextGreeting}) {
    if (_currentCharacter.id != character.id) {
      _currentCharacter = character;

      // Start fresh scenario - invalidates in-flight requests and clears history
      startNewScenario();

      // If there's a personalized greeting, add it as first message
      if (contextGreeting != null) {
        final greetingMsg = ChatMessage.assistant(
          contextGreeting,
          characterName: character.name,
          context: 'greeting',
          characterId: character.id,
        );
        _getCurrentHistory().add(greetingMsg);
        _notifyListeners();
      }
    }
  }
  
  /// Get current character
  AiCharacter get currentCharacter => _currentCharacter;

  /// Retry: remove last error message and re-send the last user message.
  /// Returns a stream if there is a user message to retry, or null.
  Stream<ChatMessage>? retryLastMessage({AiCharacter? character}) {
    final history = _getCurrentHistory();

    // Remove trailing error message(s)
    while (history.isNotEmpty &&
        history.last.role == 'assistant' &&
        history.last.isError) {
      history.removeLast();
    }

    // Find the last user message to re-send
    String? lastUserText;
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i].role == 'user') {
        lastUserText = history[i].content;
        // Remove it so sendMessageStream re-adds it
        history.removeAt(i);
        break;
      }
    }

    _notifyListeners();

    if (lastUserText == null) return null;

    return sendMessageStream(lastUserText, character: character ?? _currentCharacter);
  }

  /// Send a guided lesson message with a custom system prompt
  /// Used by the guided lesson flow to teach module content
  /// Keeps messages separate from character chat histories
  Stream<String> sendGuidedLessonStream({
    required String userMessage,
    required String systemPrompt,
    int? maxTokens,
  }) async* {
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ];

    try {
      await for (final chunk in _openAI.streamChatCompletion(
        messages: apiMessages,
        maxTokens: maxTokens ?? 1000,
      )) {
        yield chunk;
      }
    } catch (e) {
      yield 'I\'m having trouble connecting right now. Please check your internet connection and try again.';
    }
  }

  /// Send a guided lesson message with conversation history for follow-up questions
  Stream<String> sendGuidedFollowUpStream({
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, dynamic>> conversationHistory,
    int? maxTokens,
  }) async* {
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...conversationHistory,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      await for (final chunk in _openAI.streamChatCompletion(
        messages: apiMessages,
        maxTokens: maxTokens ?? 800,
      )) {
        yield chunk;
      }
    } catch (e) {
      yield 'I\'m having trouble connecting right now. Please check your internet connection and try again.';
    }
  }
  
  /// ✅ Cleanup - call this when app is disposing
  void dispose() {
    _messageStreamController.close();
  }
}