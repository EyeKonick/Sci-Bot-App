import 'dart:async';
import '../../../../shared/models/chat_message_extended.dart';
import '../../../../shared/models/models.dart';
import '../../../../services/storage/hive_service.dart';
import '../../../../services/ai/openai_service.dart';
import '../../../../services/ai/prompts/aristotle_prompts.dart';
import '../services/context_service.dart';

/// Chat Repository - SINGLETON
/// Manages chat messages, AI interactions, and message history
/// Ensures all chat interfaces (messenger window + full screen) share same data
/// 
/// Week 3 Day 1-2 Implementation + Singleton Pattern Fix
class ChatRepository {
  // ✅ SINGLETON PATTERN - Critical fix for syncing messenger and full chat
  static final ChatRepository _instance = ChatRepository._internal();
  
  // ✅ Factory constructor always returns the same instance
  factory ChatRepository() {
    return _instance;
  }
  
  // ✅ Private constructor
  ChatRepository._internal();
  
  // Shared state across ALL chat interfaces
  final _openAI = OpenAIService();
  final _conversationHistory = <ChatMessage>[];
  final _contextService = ContextService();
  
  // Character context
  String _currentCharacter = 'Aristotle';
  String _currentContext = 'home';
  
  // ✅ Broadcast stream for real-time updates across interfaces
  final _messageStreamController = StreamController<List<ChatMessage>>.broadcast();
  
  /// Stream that notifies all listeners when messages change
  Stream<List<ChatMessage>> get messageStream => _messageStreamController.stream;
  
  /// Initialize repository
  Future<void> initialize() async {
    try {
      // OpenAI service is already initialized in main.dart
      // So we just need to load history here
      await _loadHistory();
      print('✅ ChatRepository initialized (Singleton)');
    } catch (e) {
      print('⚠️ Error loading chat history: $e');
      // Don't throw error, just log it - we can still chat without history
    }
  }

  /// Load chat history from Hive
  Future<void> _loadHistory() async {
    final box = HiveService.chatHistoryBox;
    _conversationHistory.clear();
    
    // Load last 20 messages for context
    final hiveMessages = box.values.toList();
    
    // Convert ChatMessageModel to ChatMessage (extended)
    for (final hiveMsg in hiveMessages) {
      final extendedMsg = ChatMessage(
        id: hiveMsg.id,
        role: hiveMsg.sender == MessageSender.user ? 'user' : 'assistant',
        content: hiveMsg.text,
        timestamp: hiveMsg.timestamp,
        characterName: _currentCharacter,
      );
      _conversationHistory.add(extendedMsg);
    }
    
    // Keep only last 20
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }
    
    // ✅ Notify listeners of initial state
    _notifyListeners();
  }

  /// Send message and get streaming response
  Stream<ChatMessage> sendMessageStream(String userMessage, {
    String? context,
    int? progressPercentage,
    String? lessonId,
    int? moduleIndex,
  }) async* {
    // Update context
    if (context != null) _currentContext = context;

    // Get current context from service
    ChatContext appContext;
    if (lessonId != null && moduleIndex != null) {
      appContext = await _contextService.getModuleContext(lessonId, moduleIndex);
    } else if (lessonId != null) {
      appContext = await _contextService.getLessonContext(lessonId);
    } else {
      appContext = await _contextService.getCurrentContext();
    }

    // Create user message
    final userMsg = ChatMessage.user(userMessage, context: appContext.location);
    
    // ✅ Add to shared history
    _conversationHistory.add(userMsg);
    await _saveMessage(userMsg);
    
    // ✅ Notify all listeners (messenger + full chat)
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
        fullResponse += chunk;
        
        // Create/update streaming message
        streamingMessage = ChatMessage.assistant(
          fullResponse,
          characterName: _currentCharacter,
          context: appContext.location,
          isStreaming: true,
        );
        
        // ✅ Update in shared history (replace or add)
        if (_conversationHistory.isNotEmpty && 
            _conversationHistory.last.role == 'assistant' && 
            _conversationHistory.last.isStreaming) {
          // Replace last streaming message
          _conversationHistory[_conversationHistory.length - 1] = streamingMessage;
        } else {
          // Add new streaming message
          _conversationHistory.add(streamingMessage);
        }
        
        // ✅ Notify listeners with each chunk
        _notifyListeners();
        
        yield streamingMessage;
      }

      // Save final complete message
      final finalMsg = ChatMessage.assistant(
        fullResponse,
        characterName: _currentCharacter,
        context: appContext.location,
        isStreaming: false,
      );
      
      // ✅ Replace streaming message with final
      if (_conversationHistory.isNotEmpty && 
          _conversationHistory.last.role == 'assistant') {
        _conversationHistory[_conversationHistory.length - 1] = finalMsg;
      } else {
        _conversationHistory.add(finalMsg);
      }
      
      await _saveMessage(finalMsg);
      
      // ✅ Final notification
      _notifyListeners();
      
      yield finalMsg;
      
    } catch (e) {
      // Error handling
      final errorMsg = ChatMessage.assistant(
        "I'm having trouble connecting right now. Please check your internet connection and try again. 🔌",
        characterName: _currentCharacter,
        context: appContext.location,
      );
      
      // ✅ Add error to shared history
      _conversationHistory.add(errorMsg);
      _notifyListeners();
      
      yield errorMsg;
    }
  }

  /// ✅ Notify all listeners of conversation changes
  void _notifyListeners() {
    if (!_messageStreamController.isClosed) {
      _messageStreamController.add(List.unmodifiable(_conversationHistory));
    }
  }

  /// Prepare messages for API call
  List<Map<String, dynamic>> _prepareAPIMessages({
    required String context,
    int? progressPercentage,
    String? contextDetails,
  }) {
    final messages = <Map<String, dynamic>>[];

    // Add system prompt with context
    final systemPrompt = AristotlePrompts.getContextPrompt(
      context: context,
      progressPercentage: progressPercentage,
    );
    
    // Append additional context details if provided
    final fullPrompt = contextDetails != null
        ? '$systemPrompt\n\nADDITIONAL CONTEXT:\n$contextDetails'
        : systemPrompt;
    
    messages.add({'role': 'system', 'content': fullPrompt});

    // Add conversation history (last 10 messages for context)
    final recentHistory = _conversationHistory.length > 10
        ? _conversationHistory.sublist(_conversationHistory.length - 10)
        : _conversationHistory;

    for (final msg in recentHistory) {
      if (msg.role != 'system') {
        messages.add(msg.toOpenAIFormat());
      }
    }

    return messages;
  }

  /// Save message to Hive (convert to ChatMessageModel)
  Future<void> _saveMessage(ChatMessage message) async {
    final box = HiveService.chatHistoryBox;
    
    // Convert ChatMessage to ChatMessageModel for Hive storage
    final hiveMessage = ChatMessageModel(
      id: message.id,
      sender: message.role == 'user' ? MessageSender.user : MessageSender.ai,
      text: message.content,
      timestamp: message.timestamp,
    );
    
    await box.add(hiveMessage);
    
    // Keep only last 100 messages in storage
    if (box.length > 100) {
      await box.deleteAt(0);
    }
  }

  /// Get greeting message
  ChatMessage getGreeting({
    int completedLessons = 0,
    int totalLessons = 8,
    double progressPercentage = 0.0,
  }) {
    final greeting = AristotlePrompts.getProgressGreeting(
      completedLessons: completedLessons,
      totalLessons: totalLessons,
      progressPercentage: progressPercentage,
    );

    return ChatMessage.assistant(
      greeting,
      characterName: 'Aristotle',
      context: 'home',
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

  /// Clear chat history
  Future<void> clearHistory() async {
    _conversationHistory.clear();
    await HiveService.chatHistoryBox.clear();
    
    // ✅ Notify all listeners
    _notifyListeners();
  }

  /// Get conversation history (unmodifiable)
  List<ChatMessage> get conversationHistory => 
      List.unmodifiable(_conversationHistory);

  /// Check if OpenAI is configured
  bool get isConfigured => _openAI.isConfigured;

  /// Set current character
  void setCharacter(String characterName) {
    _currentCharacter = characterName;
  }

  /// Set current context
  void setContext(String context) {
    _currentContext = context;
  }
  
  /// ✅ Cleanup - call this when app is disposing
  void dispose() {
    _messageStreamController.close();
  }
}