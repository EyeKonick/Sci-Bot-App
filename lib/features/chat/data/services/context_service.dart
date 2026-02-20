import '../../../../shared/models/models.dart';
import '../../../../services/storage/hive_service.dart';
import '../../../lessons/data/repositories/progress_repository.dart';

/// Context Detection Service
/// Detects user's current location in the app and provides context for AI
/// 
/// Week 3 Day 2 Implementation
class ContextService {
  final _progressRepo = ProgressRepository();

  /// Get current app context for AI chat
  Future<ChatContext> getCurrentContext() async {
    // Get progress data
    final completedCount = _progressRepo.getCompletedLessonsCount();
    final totalLessons = 8; // Total lessons in app
    final progressPercentage = (completedCount / totalLessons * 100).round();

    return ChatContext(
      location: 'home', // Default to home, will be enhanced with navigation state
      currentModule: null,
      currentLesson: null,
      currentTopic: null,
      completedLessons: completedCount,
      totalLessons: totalLessons,
      progressPercentage: progressPercentage,
    );
  }

  /// Get context when user is in a specific lesson
  Future<ChatContext> getLessonContext(String lessonId) async {
    final box = HiveService.lessonsBox;
    final lesson = box.get(lessonId);

    if (lesson == null) {
      return getCurrentContext();
    }

    final completedCount = _progressRepo.getCompletedLessonsCount();
    final lessonProgress = _progressRepo.getCompletionPercentage(lessonId);

    return ChatContext(
      location: 'lesson',
      currentModule: null,
      currentLesson: lesson.title,
      currentTopic: lesson.topicId,
      completedLessons: completedCount,
      totalLessons: 8,
      progressPercentage: (completedCount / 8 * 100).round(),
      lessonProgress: lessonProgress,
    );
  }

  /// Get context when user is in a specific module
  Future<ChatContext> getModuleContext(
    String lessonId,
    int moduleIndex,
  ) async {
    final box = HiveService.lessonsBox;
    final lesson = box.get(lessonId);

    if (lesson == null) {
      return getCurrentContext();
    }

    final module = lesson.modules[moduleIndex];
    final completedCount = _progressRepo.getCompletedLessonsCount();
    final lessonProgress = _progressRepo.getCompletionPercentage(lessonId);

    return ChatContext(
      location: 'module',
      currentModule: module.title,
      currentModuleType: module.type.name,
      currentLesson: lesson.title,
      currentTopic: lesson.topicId,
      completedLessons: completedCount,
      totalLessons: 8,
      progressPercentage: (completedCount / 8 * 100).round(),
      lessonProgress: lessonProgress,
      moduleIndex: moduleIndex,
      totalModules: lesson.modules.length,
    );
  }

  /// Get milestone context for celebrations
  String? getMilestoneContext(int progressPercentage) {
    if (progressPercentage == 25) {
      return 'milestone_25';
    } else if (progressPercentage == 50) {
      return 'milestone_50';
    } else if (progressPercentage == 75) {
      return 'milestone_75';
    } else if (progressPercentage == 100) {
      return 'milestone_100';
    }
    return null;
  }
}

/// Chat Context Data Class
class ChatContext {
  final String location; // 'home', 'lesson', 'module', 'topic'
  final String? currentModule;
  final String? currentModuleType;
  final String? currentLesson;
  final String? currentTopic;
  final int completedLessons;
  final int totalLessons;
  final int progressPercentage;
  final double? lessonProgress;
  final int? moduleIndex;
  final int? totalModules;

  ChatContext({
    required this.location,
    this.currentModule,
    this.currentModuleType,
    this.currentLesson,
    this.currentTopic,
    required this.completedLessons,
    required this.totalLessons,
    required this.progressPercentage,
    this.lessonProgress,
    this.moduleIndex,
    this.totalModules,
  });

  /// Convert to context string for AI prompt
  String toPromptContext() {
    final buffer = StringBuffer();
    buffer.writeln('User is currently: $location');

    if (currentTopic != null) {
      buffer.writeln('Topic: $currentTopic');
    }

    if (currentLesson != null) {
      buffer.writeln('Lesson: $currentLesson');
    }

    if (currentModule != null) {
      buffer.writeln('Module: $currentModule ($currentModuleType)');
      if (moduleIndex != null && totalModules != null) {
        buffer.writeln('Part ${moduleIndex! + 1} of $totalModules');
      }
    }

    buffer.writeln('Progress: $completedLessons/$totalLessons lessons ($progressPercentage%)');

    if (lessonProgress != null) {
      buffer.writeln('Current lesson progress: ${(lessonProgress! * 100).toInt()}%');
    }

    return buffer.toString();
  }
}