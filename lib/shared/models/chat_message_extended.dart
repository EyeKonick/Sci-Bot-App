import 'package:hive/hive.dart';

/// Extended Chat Message Model for AI conversations
/// Includes role, content, timestamp, and character info
/// 
/// Part of Week 3 Day 1 implementation
@HiveType(typeId: 4) // Using existing typeId from original implementation
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role; // 'user', 'assistant', 'system'

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? characterName; // 'Aristotle', 'Herophilus', 'Mendel', 'Wilson'

  @HiveField(5)
  final String? context; // 'home', 'module', 'topic'

  @HiveField(6)
  final bool isStreaming; // For real-time display

  @HiveField(7)
  final String? characterId; // 'aristotle', 'herophilus', 'mendel', 'odum'

  /// Scenario ID this message belongs to (e.g. 'aristotle_general',
  /// 'herophilus_lesson_menu_circulation'). Used for scenario-based isolation.
  @HiveField(8)
  final String? scenarioId;

  /// Transient flag (not persisted to Hive) indicating this message is an error.
  /// Used by chat UI to render error cards with Retry button.
  final bool isError;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.characterName,
    this.context,
    this.isStreaming = false,
    this.characterId,
    this.scenarioId,
    this.isError = false,
  });

  /// Create user message
  factory ChatMessage.user(String content, {String? context, String? characterId, String? scenarioId}) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
      context: context,
      characterId: characterId,
      scenarioId: scenarioId,
    );
  }

  /// Create assistant message
  factory ChatMessage.assistant(
    String content, {
    String characterName = 'Aristotle',
    String? context,
    bool isStreaming = false,
    String? characterId,
    String? scenarioId,
    bool isError = false,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
      characterName: characterName,
      context: context,
      isStreaming: isStreaming,
      characterId: characterId,
      scenarioId: scenarioId,
      isError: isError,
    );
  }

  /// Create system message (for prompts)
  factory ChatMessage.system(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'system',
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// Serialize to JSON for Hive storage.
  /// Transient fields (isStreaming, isError) are intentionally omitted.
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'characterName': characterName,
        'context': context,
        'characterId': characterId,
        'scenarioId': scenarioId,
      };

  /// Deserialize from Hive JSON storage.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      characterName: json['characterName'] as String?,
      context: json['context'] as String?,
      characterId: json['characterId'] as String?,
      scenarioId: json['scenarioId'] as String?,
      isStreaming: false,
      isError: false,
    );
  }

  /// Convert to OpenAI API format
  Map<String, dynamic> toOpenAIFormat() {
    return {
      'role': role,
      'content': content,
    };
  }

  /// Copy with method
  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    String? characterName,
    String? context,
    bool? isStreaming,
    String? characterId,
    String? scenarioId,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      characterName: characterName ?? this.characterName,
      context: context ?? this.context,
      isStreaming: isStreaming ?? this.isStreaming,
      characterId: characterId ?? this.characterId,
      scenarioId: scenarioId ?? this.scenarioId,
      isError: isError ?? this.isError,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(role: $role, character: $characterName, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
  }
}