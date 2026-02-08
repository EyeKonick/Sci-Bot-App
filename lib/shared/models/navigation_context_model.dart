/// Navigation Context Model
/// Tracks where the user is in the app for context-aware AI
/// Week 3, Day 3 Implementation

class NavigationContext {
  final String? currentTopicId;
  final String? currentLessonId;
  final String? currentModuleIndex;
  final String screenName;
  final DateTime lastUpdated;

  const NavigationContext({
    this.currentTopicId,
    this.currentLessonId,
    this.currentModuleIndex,
    required this.screenName,
    required this.lastUpdated,
  });

  /// Create default context (home screen, no topic)
  factory NavigationContext.home() {
    return NavigationContext(
      screenName: 'home',
      lastUpdated: DateTime.now(),
    );
  }

  /// Create context for topic screen
  factory NavigationContext.topic(String topicId) {
    return NavigationContext(
      currentTopicId: topicId,
      screenName: 'topics',
      lastUpdated: DateTime.now(),
    );
  }

  /// Create context for lesson screen
  factory NavigationContext.lesson({
    required String topicId,
    required String lessonId,
  }) {
    return NavigationContext(
      currentTopicId: topicId,
      currentLessonId: lessonId,
      screenName: 'lessons',
      lastUpdated: DateTime.now(),
    );
  }

  /// Create context for module viewer
  factory NavigationContext.module({
    required String topicId,
    required String lessonId,
    required String moduleIndex,
  }) {
    return NavigationContext(
      currentTopicId: topicId,
      currentLessonId: lessonId,
      currentModuleIndex: moduleIndex,
      screenName: 'module',
      lastUpdated: DateTime.now(),
    );
  }

  /// Check if user is currently in a specific topic
  bool get isInTopic => currentTopicId != null;

  /// Check if user is in a lesson
  bool get isInLesson => currentLessonId != null;

  /// Check if user is viewing a module
  bool get isInModule => currentModuleIndex != null;

  /// Copy with new values
  NavigationContext copyWith({
    String? currentTopicId,
    String? currentLessonId,
    String? currentModuleIndex,
    String? screenName,
    DateTime? lastUpdated,
  }) {
    return NavigationContext(
      currentTopicId: currentTopicId ?? this.currentTopicId,
      currentLessonId: currentLessonId ?? this.currentLessonId,
      currentModuleIndex: currentModuleIndex ?? this.currentModuleIndex,
      screenName: screenName ?? this.screenName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'NavigationContext(screen: $screenName, topic: $currentTopicId, lesson: $currentLessonId, module: $currentModuleIndex)';
  }
}