/// Single message in AI chat conversation
class ChatMessageModel {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final String? lessonContext; // Optional: lesson ID if context-aware chat

  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.lessonContext,
  });

  /// Create from JSON
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      sender: MessageSender.values.byName(json['sender'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      lessonContext: json['lesson_context'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'lesson_context': lessonContext,
    };
  }

  /// Check if message is from user
  bool get isUser => sender == MessageSender.user;

  /// Check if message is from AI
  bool get isAI => sender == MessageSender.ai;

  /// Check if message has lesson context
  bool get hasContext => lessonContext != null;

  /// Create a copy with modified fields
  ChatMessageModel copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    String? lessonContext,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      lessonContext: lessonContext ?? this.lessonContext,
    );
  }

  @override
  String toString() {
    return 'ChatMessageModel(sender: $sender, text: ${text.substring(0, text.length > 30 ? 30 : text.length)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Who sent the message
enum MessageSender {
  user,
  ai,
}