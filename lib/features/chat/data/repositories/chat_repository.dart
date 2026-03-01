import 'dart:async';
import 'dart:convert';
import '../../../../shared/models/chat_message_extended.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../shared/models/scenario_model.dart';
import '../../../../services/ai/openai_service.dart';
import '../../../../services/ai/prompts/aristotle_prompts.dart';
import '../../../../services/storage/hive_service.dart';
import '../services/context_service.dart';


/// Chat Repository - SINGLETON
/// Manages chat messages, AI interactions, and message history.
///
/// Phase 1 Refactor: Scenario-based storage replaces character-based storage.
/// Each scenario (screen context + character) has completely isolated history.
/// Messages never bleed across different scenarios.
class ChatRepository {
  // Singleton
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal();

  /// Maps each expert to other experts they can recommend for out-of-scope questions
  static const Map<String, List<Map<String, String>>> _relatedExperts = {
    'herophilus': [
      {
        'id': 'mendel',
        'name': 'Gregor Mendel',
        'expertise': 'heredity and variation',
        'topic': 'Heredity and Variation',
      },
      {
        'id': 'odum',
        'name': 'Eugene Odum',
        'expertise': 'energy and ecosystems',
        'topic': 'Energy in Ecosystems',
      },
    ],
    'mendel': [
      {
        'id': 'herophilus',
        'name': 'Herophilus',
        'expertise': 'circulation and gas exchange',
        'topic': 'Body Systems',
      },
      {
        'id': 'odum',
        'name': 'Eugene Odum',
        'expertise': 'energy and ecosystems',
        'topic': 'Energy in Ecosystems',
      },
    ],
    'odum': [
      {
        'id': 'herophilus',
        'name': 'Herophilus',
        'expertise': 'circulation and gas exchange',
        'topic': 'Body Systems',
      },
      {
        'id': 'mendel',
        'name': 'Gregor Mendel',
        'expertise': 'heredity and variation',
        'topic': 'Heredity and Variation',
      },
    ],
    'aristotle': [], // General guide has no specific redirects
  };

  // Async mutex to prevent concurrent message history corruption
  Completer<void>? _lock;

  Future<void> _acquireLock() async {
    while (_lock != null && !_lock!.isCompleted) {
      await _lock!.future;
    }
    _lock = Completer<void>();
  }

  void _releaseLock() {
    if (_lock != null && !_lock!.isCompleted) {
      _lock!.complete();
    }
  }

  final _openAI = OpenAIService();
  final _contextService = ContextService();

  // ---------------------------------------------------------------------------
  // Scenario-based storage (replaces _characterHistories)
  // ---------------------------------------------------------------------------

  /// Message histories keyed by scenario ID.
  final _scenarioHistories = <String, List<ChatMessage>>{};

  /// Tracks which scenarios have already received a session-return greeting
  /// this app launch. Cleared on restart because this is in-memory only.
  final _sessionGreetedScenarios = <String>{};

  /// Return greeting pools per character — injected on app restart when
  /// existing history is loaded. NOT saved to Hive (ephemeral per session).
  static const Map<String, List<String>> _returnGreetings = {
    'aristotle': [
      "Welcome back, scholar! Ready to pick up where we left off?",
      "Good to have you back! What shall we explore today?",
      "You're back! Science waits for no one — let's dive in.",
    ],
    'herophilus': [
      "Welcome back! The heart never stops — and neither does learning.",
      "Good to see you again! Ready to explore more of the body's mysteries?",
      "You've returned! Shall we continue our journey through circulation?",
    ],
    'mendel': [
      "Welcome back! Heredity holds many more secrets to discover.",
      "Good to see you again! Ready to unravel more patterns of inheritance?",
      "You've returned! The laws of genetics are waiting to be explored.",
    ],
    'odum': [
      "Welcome back! The ecosystem kept thriving while you were away.",
      "Good to see you again! Ready to explore more energy flow dynamics?",
      "You've returned! Nature's web of life has much more to reveal.",
    ],
  };

  /// Currently active scenario.
  ChatScenario? _currentScenario;

  /// Paused scenarios (for Chat tab navigation from modules).
  /// Key = scenario ID, Value = the paused scenario object.
  final _pausedScenarios = <String, ChatScenario>{};

  /// Current character (derived from active scenario).
  AiCharacter _currentCharacter = AiCharacter.aristotle;

  /// Student's name for personalized responses (null if not set).
  String? _userName;

  /// Generation counter to invalidate in-flight API responses when
  /// the scenario changes mid-stream.
  int _scenarioGeneration = 0;

  // Broadcast stream for real-time updates across interfaces
  final _messageStreamController =
      StreamController<List<ChatMessage>>.broadcast();

  /// Stream that notifies all listeners when messages change.
  Stream<List<ChatMessage>> get messageStream =>
      _messageStreamController.stream;

  /// The currently active scenario (read-only).
  ChatScenario? get currentScenario => _currentScenario;

  /// Current character (read-only).
  AiCharacter get currentCharacter => _currentCharacter;

  /// Whether OpenAI is configured.
  bool get isConfigured => _openAI.isConfigured;

  /// Current scenario generation (for external stale-check).
  int get scenarioId => _scenarioGeneration;

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  /// Returns true if this scenario's history should be persisted to Hive.
  /// Only general (Aristotle) and lessonMenu (expert topic screens) qualify.
  bool _shouldPersist(ChatScenario? scenario) {
    return scenario?.type == ScenarioType.general ||
        scenario?.type == ScenarioType.lessonMenu;
  }

  /// Serialize and write a scenario's history to Hive as a JSON string.
  /// session_return greetings are ephemeral — filtered out before saving so
  /// they are freshly regenerated on every app launch.
  Future<void> _saveHistoryToHive(
      String scenarioId, List<ChatMessage> messages) async {
    try {
      final toSave =
          messages.where((m) => m.context != 'session_return').toList();
      final jsonList = toSave.map((m) => m.toJson()).toList();
      await HiveService.scenarioChatJsonBox.put(scenarioId, jsonEncode(jsonList));
    } catch (e) {
      print('⚠️ Failed to persist chat history for $scenarioId: $e');
    }
  }

  /// Load and deserialize a scenario's history from Hive.
  /// Returns an empty list if nothing is stored or on parse error.
  Future<List<ChatMessage>> _loadHistoryFromHive(String scenarioId) async {
    try {
      final raw = HiveService.scenarioChatJsonBox.get(scenarioId);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => ChatMessage.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('⚠️ Failed to load chat history for $scenarioId: $e');
      return [];
    }
  }

  /// Remove a scenario's persisted history from Hive.
  Future<void> _clearHistoryFromHive(String scenarioId) async {
    try {
      await HiveService.scenarioChatJsonBox.delete(scenarioId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Scenario lifecycle
  // ---------------------------------------------------------------------------

  /// Initialize repository. Session-only: in-memory histories start empty.
  Future<void> initialize() async {
    _notifyListeners();
  }

  /// Switch to a new scenario or reactivate an existing one.
  /// If the scenario is new, initialises empty history and generates a greeting.
  /// If the scenario ID matches the current one, this is a no-op.
  Future<void> setScenario(ChatScenario scenario) async {
    // Same scenario already active - no-op
    if (_currentScenario != null && _currentScenario!.id == scenario.id) {
      return;
    }

    final previousId = _currentScenario?.id;
    _currentScenario = scenario;
    _currentCharacter = AiCharacter.getCharacterById(scenario.characterId);

    // Increment generation to invalidate in-flight API responses
    _scenarioGeneration++;

    print('🎬 Scenario switch: $previousId → ${scenario.id} '
        '(gen $_scenarioGeneration)');

    // Initialise history for this scenario if never seen this session.
    // For qualifying scenarios, try loading persisted history from Hive first.
    if (!_scenarioHistories.containsKey(scenario.id)) {
      if (_shouldPersist(scenario)) {
        _scenarioHistories[scenario.id] = await _loadHistoryFromHive(scenario.id);

        // If we loaded existing history, inject a one-time session-return
        // greeting so the app feels alive on every relaunch.
        if (_scenarioHistories[scenario.id]!.isNotEmpty &&
            !_sessionGreetedScenarios.contains(scenario.id)) {
          _sessionGreetedScenarios.add(scenario.id);
          final pool =
              _returnGreetings[scenario.characterId] ?? _returnGreetings['aristotle']!;
          final text = pool[DateTime.now().second % pool.length];
          _scenarioHistories[scenario.id]!.add(ChatMessage.assistant(
            text,
            characterName: _currentCharacter.name,
            context: 'session_return',
            characterId: _currentCharacter.id,
            scenarioId: scenario.id,
          ));
        }
      } else {
        _scenarioHistories[scenario.id] = [];
      }
    }

    // If history is still empty, generate a contextual greeting and persist it.
    if (_scenarioHistories[scenario.id]!.isEmpty) {
      await _generateScenarioGreeting(scenario);
      if (_shouldPersist(scenario)) {
        await _saveHistoryToHive(scenario.id, _scenarioHistories[scenario.id]!);
      }
    }

    _notifyListeners();
  }

  /// Pause the current scenario (e.g. when Chat tab is tapped from a module).
  /// The history is preserved and can be resumed later.
  void pauseCurrentScenario() {
    if (_currentScenario == null) return;
    _pausedScenarios[_currentScenario!.id] = _currentScenario!;
    print('⏸️ Scenario paused: ${_currentScenario!.id}');
  }

  /// Resume a previously paused scenario by its ID.
  /// Returns true if the scenario was found and resumed.
  bool resumeScenario(String scenarioId) {
    final paused = _pausedScenarios.remove(scenarioId);
    if (paused == null) return false;

    _currentScenario = paused;
    _currentCharacter = AiCharacter.getCharacterById(paused.characterId);
    _scenarioGeneration++;

    print('▶️ Scenario resumed: ${paused.id} (gen $_scenarioGeneration)');
    _notifyListeners();
    return true;
  }

  /// Terminate and clean up the current scenario.
  /// Removes its history from memory to prevent leaks.
  void clearCurrentScenario() {
    if (_currentScenario == null) return;
    final id = _currentScenario!.id;
    _scenarioHistories.remove(id);
    _pausedScenarios.remove(id);
    _currentScenario = null;
    _scenarioGeneration++;
    print('🧹 Scenario cleared: $id');
    _notifyListeners();
  }

  /// Terminate a specific scenario by ID (e.g. when exiting a module).
  void clearScenario(String scenarioId) {
    _scenarioHistories.remove(scenarioId);
    _pausedScenarios.remove(scenarioId);
    if (_currentScenario?.id == scenarioId) {
      _currentScenario = null;
      _scenarioGeneration++;
    }
    print('🧹 Scenario cleared: $scenarioId');
  }

  /// Legacy compatibility: start a fresh scenario by incrementing generation
  /// and clearing current history. Used by old character-switching code paths.
  void startNewScenario() {
    _scenarioGeneration++;
    _getCurrentHistory().clear();
    _notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Greeting generation
  // ---------------------------------------------------------------------------

  /// Generate a contextual greeting when a new scenario is created.
  Future<void> _generateScenarioGreeting(ChatScenario scenario) async {
    switch (scenario.type) {
      case ScenarioType.general:
        // Aristotle general: use AristotleGreetingService for chathead bubbles.
        // For the main chat greeting, use a simple welcome message.
        final greetingMsg = ChatMessage.assistant(
          _currentCharacter.greeting,
          characterName: _currentCharacter.name,
          context: 'greeting',
          characterId: _currentCharacter.id,
          scenarioId: scenario.id,
        );
        _scenarioHistories[scenario.id]!.add(greetingMsg);

      case ScenarioType.lessonMenu:
        // Expert character greeting for topic lesson menu.
        // Main chat gets a simple greeting; chathead bubbles are handled
        // by ExpertGreetingService in FloatingChatButton.
        final topicName = scenario.context['topicId'] ?? 'this topic';
        final expertGreeting = ChatMessage.assistant(
          _currentCharacter.greeting,
          characterName: _currentCharacter.name,
          context: 'lesson_menu_$topicName',
          characterId: _currentCharacter.id,
          scenarioId: scenario.id,
        );
        _scenarioHistories[scenario.id]!.add(expertGreeting);

      case ScenarioType.module:
        // Will be implemented in Phase 3
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Message access
  // ---------------------------------------------------------------------------

  /// Get the current scenario's conversation history (internal, mutable).
  List<ChatMessage> _getCurrentHistory() {
    if (_currentScenario == null) return [];
    return _scenarioHistories[_currentScenario!.id] ?? [];
  }

  /// Get conversation history (unmodifiable, public).
  List<ChatMessage> get conversationHistory =>
      List.unmodifiable(_getCurrentHistory());

  /// Notify all listeners with current scenario's messages.
  void _notifyListeners() {
    if (!_messageStreamController.isClosed) {
      _messageStreamController.add(List.unmodifiable(_getCurrentHistory()));
    }
  }

  // ---------------------------------------------------------------------------
  // Sending messages
  // ---------------------------------------------------------------------------

  /// Send message and get streaming response.
  /// Protected with async mutex to prevent concurrent corruption.
  Stream<ChatMessage> sendMessageStream(
    String userMessage, {
    String? context,
    int? progressPercentage,
    String? lessonId,
    int? moduleIndex,
    AiCharacter? character,
  }) async* {
    await _acquireLock();
    final capturedGeneration = _scenarioGeneration;
    try {
      if (character != null) _currentCharacter = character;

      // Get current context from service
      ChatContext appContext;
      if (lessonId != null && moduleIndex != null) {
        appContext =
            await _contextService.getModuleContext(lessonId, moduleIndex);
      } else if (lessonId != null) {
        appContext = await _contextService.getLessonContext(lessonId);
      } else {
        appContext = await _contextService.getCurrentContext();
      }

      // Scenario changed while awaiting context - discard
      if (capturedGeneration != _scenarioGeneration) return;

      // Create user message tagged with scenario
      final userMsg = ChatMessage.user(
        userMessage,
        context: appContext.location,
        characterId: _currentCharacter.id,
        scenarioId: _currentScenario?.id,
      );

      _getCurrentHistory().add(userMsg);
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
        await for (final chunk
            in _openAI.streamChatCompletion(messages: apiMessages)) {
          if (capturedGeneration != _scenarioGeneration) return;

          fullResponse += chunk;

          streamingMessage = ChatMessage.assistant(
            fullResponse,
            characterName: _currentCharacter.name,
            context: appContext.location,
            isStreaming: true,
            characterId: _currentCharacter.id,
            scenarioId: _currentScenario?.id,
          );

          final currentHistory = _getCurrentHistory();
          if (currentHistory.isNotEmpty &&
              currentHistory.last.role == 'assistant' &&
              currentHistory.last.isStreaming) {
            currentHistory[currentHistory.length - 1] = streamingMessage;
          } else {
            currentHistory.add(streamingMessage);
          }

          _notifyListeners();
          yield streamingMessage;
        }

        if (capturedGeneration != _scenarioGeneration) return;

        // Final complete message
        final finalMsg = ChatMessage.assistant(
          fullResponse,
          characterName: _currentCharacter.name,
          context: appContext.location,
          isStreaming: false,
          characterId: _currentCharacter.id,
          scenarioId: _currentScenario?.id,
        );

        final currentHistory = _getCurrentHistory();
        if (currentHistory.isNotEmpty &&
            currentHistory.last.role == 'assistant') {
          currentHistory[currentHistory.length - 1] = finalMsg;
        } else {
          currentHistory.add(finalMsg);
        }

        _notifyListeners();
        yield finalMsg;

        // Persist history to Hive for qualifying scenarios
        if (_shouldPersist(_currentScenario)) {
          await _saveHistoryToHive(_currentScenario!.id, _getCurrentHistory());
        }
      } catch (e) {
        if (capturedGeneration != _scenarioGeneration) return;

        final errorMsg = ChatMessage.assistant(
          "I'm having trouble connecting right now. Please check your internet connection and try again.",
          characterName: _currentCharacter.name,
          context: appContext.location,
          characterId: _currentCharacter.id,
          scenarioId: _currentScenario?.id,
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

  /// Builds an enhanced system prompt with cross-expert recommendations.
  /// Only applies to expert characters in lesson menu scenarios.
  String _buildEnhancedSystemPrompt() {
    String prompt = _currentCharacter.systemPrompt;

    // Add student's name for personalized responses
    if (_userName != null && _userName!.isNotEmpty) {
      prompt += "\n\nThe student's name is $_userName. "
          "Use their name naturally when encouraging or complimenting them, "
          "but not in every message - keep it natural and varied.";
    }

    // Add expert recommendations for lesson menu contexts
    if (_currentScenario?.type == ScenarioType.lessonMenu &&
        _currentCharacter.id != 'aristotle') {
      final related = _relatedExperts[_currentCharacter.id] ?? [];
      if (related.isNotEmpty) {
        final recommendations = related
            .map((expert) =>
                "  - For questions about ${expert['expertise']}, politely redirect: "
                "\"That's a great question for ${expert['name']}! You can find them "
                "in the '${expert['topic']}' topic from the Topics screen.\"")
            .join('\n');

        prompt += "\n\n### CROSS-TOPIC GUIDANCE ###\n"
            "If a student asks about topics outside your expertise:\n"
            "$recommendations\n"
            "Always be encouraging and help them navigate to the right expert.";
      }
    }

    return prompt;
  }

  /// Prepare messages for API call.
  List<Map<String, dynamic>> _prepareAPIMessages({
    required String context,
    int? progressPercentage,
    String? contextDetails,
  }) {
    final messages = <Map<String, dynamic>>[];

    String systemPrompt = _buildEnhancedSystemPrompt();

    if (_currentCharacter.id == 'aristotle' && contextDetails != null) {
      systemPrompt = '$systemPrompt\n\nADDITIONAL CONTEXT:\n$contextDetails';
    } else if (contextDetails != null) {
      systemPrompt = '$systemPrompt\n\nCURRENT CONTEXT:\n$contextDetails';
    }

    messages.add({'role': 'system', 'content': systemPrompt});

    // Last 10 messages from current scenario only
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

  // ---------------------------------------------------------------------------
  // Greeting helpers (legacy compatibility)
  // ---------------------------------------------------------------------------

  /// Get greeting message for display in chat interfaces.
  ChatMessage getGreeting({
    int completedLessons = 0,
    int totalLessons = 8,
    double progressPercentage = 0.0,
    AiCharacter? character,
    String? personalizedGreeting,
  }) {
    final activeChar = character ?? _currentCharacter;
    final greeting = personalizedGreeting ?? activeChar.greeting;

    return ChatMessage.assistant(
      greeting,
      characterName: activeChar.name,
      context: 'home',
      characterId: activeChar.id,
      scenarioId: _currentScenario?.id,
    );
  }

  /// Get random feature tip.
  ChatMessage getFeatureTip() {
    final tips = AristotlePrompts.featureTips;
    final randomTip = tips[DateTime.now().millisecond % tips.length];

    return ChatMessage.assistant(
      randomTip,
      characterName: 'Aristotle',
      context: 'home',
    );
  }

  // ---------------------------------------------------------------------------
  // History management
  // ---------------------------------------------------------------------------

  /// Clear current scenario's chat history (memory and Hive for qualifying scenarios).
  Future<void> clearHistory() async {
    await _acquireLock();
    try {
      _getCurrentHistory().clear();
      if (_shouldPersist(_currentScenario)) {
        await _clearHistoryFromHive(_currentScenario!.id);
      }
      _notifyListeners();
    } finally {
      _releaseLock();
    }
  }

  /// Set the student's name for personalized AI responses.
  void setUserName(String? name) {
    _userName = name;
  }

  /// Legacy: set current character. Now creates/switches to the
  /// aristotle_general scenario or preserves existing scenario.
  void setCharacter(AiCharacter character, {String? contextGreeting}) {
    if (_currentCharacter.id != character.id) {
      _currentCharacter = character;
      startNewScenario();

      if (contextGreeting != null) {
        final greetingMsg = ChatMessage.assistant(
          contextGreeting,
          characterName: character.name,
          context: 'greeting',
          characterId: character.id,
          scenarioId: _currentScenario?.id,
        );
        _getCurrentHistory().add(greetingMsg);
        _notifyListeners();
      }
    }
  }

  /// Retry: remove last error message and re-send the last user message.
  Stream<ChatMessage>? retryLastMessage({AiCharacter? character}) {
    final history = _getCurrentHistory();

    while (history.isNotEmpty &&
        history.last.role == 'assistant' &&
        history.last.isError) {
      history.removeLast();
    }

    String? lastUserText;
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i].role == 'user') {
        lastUserText = history[i].content;
        history.removeAt(i);
        break;
      }
    }

    _notifyListeners();

    if (lastUserText == null) return null;

    return sendMessageStream(lastUserText,
        character: character ?? _currentCharacter);
  }

  // ---------------------------------------------------------------------------
  // Guided lesson streams (unchanged, separate from scenario history)
  // ---------------------------------------------------------------------------

  /// Send a guided lesson message with a custom system prompt.
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

  /// Send a guided lesson message with conversation history.
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

  /// Cleanup - call this when app is disposing.
  void dispose() {
    _messageStreamController.close();
  }
}
