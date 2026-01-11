import '../../../../shared/models/progress_model.dart';
import '../../../../services/storage/hive_service.dart';

/// Repository for Progress tracking
class ProgressRepository {
  /// Get progress for a lesson
  ProgressModel? getProgress(String lessonId) {
    return HiveService.progressBox.get(lessonId);
  }

  /// Get all progress records
  List<ProgressModel> getAllProgress() {
    return HiveService.progressBox.values.toList();
  }

  /// Save progress
  Future<void> saveProgress(ProgressModel progress) async {
    await HiveService.progressBox.put(progress.lessonId, progress);
  }

  /// Mark module as completed
  Future<void> markModuleCompleted(String lessonId, String moduleId) async {
    var progress = getProgress(lessonId);
    
    if (progress == null) {
      // Create new progress record
      progress = ProgressModel(
        lessonId: lessonId,
        completedModuleIds: {moduleId},
        lastAccessed: DateTime.now(),
      );
    } else {
      // Update existing progress
      progress = progress.markModuleCompleted(moduleId);
    }
    
    await saveProgress(progress);
  }

  /// Update last accessed time
  Future<void> updateLastAccessed(String lessonId) async {
    var progress = getProgress(lessonId);
    
    if (progress == null) {
      progress = ProgressModel(
        lessonId: lessonId,
        completedModuleIds: {},
        lastAccessed: DateTime.now(),
      );
    } else {
      progress = progress.updateLastAccessed();
    }
    
    await saveProgress(progress);
  }

  /// Get completion percentage
  double getCompletionPercentage(String lessonId) {
    final progress = getProgress(lessonId);
    return progress?.completionPercentage ?? 0.0;
  }

  /// Check if lesson is completed
  bool isLessonCompleted(String lessonId) {
    final progress = getProgress(lessonId);
    return progress?.isCompleted ?? false;
  }

  /// Get total completed lessons count
  int getCompletedLessonsCount() {
    return HiveService.progressBox.values
        .where((p) => p.isCompleted)
        .length;
  }

  /// Clear all progress
  Future<void> clearAll() async {
    await HiveService.progressBox.clear();
  }
}