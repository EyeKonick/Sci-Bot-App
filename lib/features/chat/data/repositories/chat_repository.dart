import 'dart:async';
import '../../../../shared/models/chat_message_extended.dart';
import '../../../../shared/models/models.dart';
import '../../../../services/storage/hive_service.dart';
import '../../../../services/ai/openai_service.dart';
import '../../../../services/ai/prompts/aristotle_prompts.dart';

/// Chat Repository
/// Manages chat messages, AI interactions, and message history
/// 
/// Week 3 Day 1 Implementation
class ChatRepository {
  final _openAI = OpenAIService();
  final _conversationHistory = <ChatMessage>[];
  
  // Character context
  String _currentCharacter = 'Aristotle';
  String _currentContext = 'home';
  
  /// Initialize repository
  Future<void> initialize() async {
    await _openAI.initialize();
    await _loadHistory();
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
  }

  /// Send message and get streaming response
  Stream<ChatMessage> sendMessageStream(String userMessage, {
    String? context,
    int? progressPercentage,
  }) async* {
    // Update context
    if (context != null) _currentContext = context;

    // Create user message
    final userMsg = ChatMessage.user(userMessage, context: _currentContext);
    _conversationHistory.add(userMsg);
    await _saveMessage(userMsg);
    
    yield userMsg;

    // Prepare messages for API
    final apiMessages = _prepareAPIMessages(
      context: _currentContext,
      progressPercentage: progressPercentage,
    );

    // Stream response from OpenAI
    String fullResponse = '';
    
    try {
      await for (final chunk in _openAI.streamChatCompletion(messages: apiMessages)) {
        fullResponse += chunk;
        
        // Yield streaming message
        yield ChatMessage.assistant(
          fullResponse,
          characterName: _currentCharacter,
          context: _currentContext,
          isStreaming: true,
        );
      }

      // Save final complete message
      final finalMsg = ChatMessage.assistant(
        fullResponse,
        characterName: _currentCharacter,
        context: _currentContext,
        isStreaming: false,
      );
      
      _conversationHistory.add(finalMsg);
      await _saveMessage(finalMsg);
      
      yield finalMsg;
      
    } catch (e) {
      // Error handling
      final errorMsg = ChatMessage.assistant(
        "I'm having trouble connecting right now. Please check your internet connection and try again. 🔌",
        characterName: _currentCharacter,
        context: _currentContext,
      );
      
      yield errorMsg;
    }
  }

  /// Prepare messages for API call
  List<Map<String, dynamic>> _prepareAPIMessages({
    required String context,
    int? progressPercentage,
  }) {
    final messages = <Map<String, dynamic>>[];

    // Add system prompt
    final systemPrompt = AristotlePrompts.getContextPrompt(
      context: context,
      progressPercentage: progressPercentage,
    );
    messages.add({'role': 'system', 'content': systemPrompt});

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
  }

  /// Get conversation history
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
}