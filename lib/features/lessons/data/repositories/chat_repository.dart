import '../../../../shared/models/chat_message_model.dart';
import '../../../../services/storage/hive_service.dart';

/// Repository for Chat History
class ChatRepository {
  /// Get all chat messages
  List<ChatMessageModel> getAllMessages() {
    return HiveService.chatHistoryBox.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get messages by lesson context
  List<ChatMessageModel> getMessagesByLesson(String lessonId) {
    return HiveService.chatHistoryBox.values
        .where((msg) => msg.lessonContext == lessonId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Save message
  Future<void> saveMessage(ChatMessageModel message) async {
    await HiveService.chatHistoryBox.put(message.id, message);
  }

  /// Delete message
  Future<void> deleteMessage(String id) async {
    await HiveService.chatHistoryBox.delete(id);
  }

  /// Clear all messages
  Future<void> clearAll() async {
    await HiveService.chatHistoryBox.clear();
  }

  /// Clear messages for specific lesson
  Future<void> clearLessonMessages(String lessonId) async {
    final messages = getMessagesByLesson(lessonId);
    for (var message in messages) {
      await deleteMessage(message.id);
    }
  }

  /// Get messages count
  int getMessagesCount() {
    return HiveService.chatHistoryBox.length;
  }
}