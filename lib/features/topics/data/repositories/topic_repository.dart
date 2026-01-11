import '../../../../shared/models/topic_model.dart';
import '../../../../services/storage/hive_service.dart';

/// Repository for Topic CRUD operations
class TopicRepository {
  /// Get all topics
  List<TopicModel> getAllTopics() {
    return HiveService.topicsBox.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Get topic by ID
  TopicModel? getTopicById(String id) {
    return HiveService.topicsBox.get(id);
  }

  /// Save topic
  Future<void> saveTopic(TopicModel topic) async {
    await HiveService.topicsBox.put(topic.id, topic);
  }

  /// Save multiple topics
  Future<void> saveTopics(List<TopicModel> topics) async {
    final map = {for (var topic in topics) topic.id: topic};
    await HiveService.topicsBox.putAll(map);
  }

  /// Delete topic
  Future<void> deleteTopic(String id) async {
    await HiveService.topicsBox.delete(id);
  }

  /// Check if topics exist
  bool hasTopics() {
    return HiveService.topicsBox.isNotEmpty;
  }

  /// Get topics count
  int getTopicsCount() {
    return HiveService.topicsBox.length;
  }

  /// Clear all topics
  Future<void> clearAll() async {
    await HiveService.topicsBox.clear();
  }
}