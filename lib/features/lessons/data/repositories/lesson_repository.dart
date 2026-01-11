import '../../../../shared/models/lesson_model.dart';
import '../../../../services/storage/hive_service.dart';

/// Repository for Lesson CRUD operations
class LessonRepository {
  /// Get all lessons
  List<LessonModel> getAllLessons() {
    return HiveService.lessonsBox.values.toList();
  }

  /// Get lesson by ID
  LessonModel? getLessonById(String id) {
    return HiveService.lessonsBox.get(id);
  }

  /// Get lessons by topic ID
  List<LessonModel> getLessonsByTopicId(String topicId) {
    return HiveService.lessonsBox.values
        .where((lesson) => lesson.topicId == topicId)
        .toList();
  }

  /// Save lesson
  Future<void> saveLesson(LessonModel lesson) async {
    await HiveService.lessonsBox.put(lesson.id, lesson);
  }

  /// Save multiple lessons
  Future<void> saveLessons(List<LessonModel> lessons) async {
    final map = {for (var lesson in lessons) lesson.id: lesson};
    await HiveService.lessonsBox.putAll(map);
  }

  /// Delete lesson
  Future<void> deleteLesson(String id) async {
    await HiveService.lessonsBox.delete(id);
  }

  /// Check if lessons exist
  bool hasLessons() {
    return HiveService.lessonsBox.isNotEmpty;
  }

  /// Get lessons count
  int getLessonsCount() {
    return HiveService.lessonsBox.length;
  }

  /// Clear all lessons
  Future<void> clearAll() async {
    await HiveService.lessonsBox.clear();
  }
}