import 'dart:io';
import '../../shared/models/models.dart';
import '../../features/topics/data/repositories/topic_repository.dart';
import '../../features/lessons/data/repositories/lesson_repository.dart';
import '../../features/lessons/data/repositories/progress_repository.dart';

/// Test Hive storage functionality
void testHiveStorage() {
  print('\n╔════════════════════════════════════╗');
  print('║   Testing Hive Storage             ║');
  print('╚════════════════════════════════════╝\n');

  final topicRepo = TopicRepository();
  final lessonRepo = LessonRepository();
  final progressRepo = ProgressRepository();

  // Test 1: Save and retrieve Topic
  print('📋 Test 1: Topic Storage');
  print('─' * 40);
  final testTopic = TopicModel(
    id: 'test_topic_1',
    name: 'Test Topic - Heredity',
    description: 'Test topic for Hive storage',
    iconName: 'biotech',
    colorHex: '#4DB8C4',
    lessonIds: ['test_lesson_1'],
    order: 1,
  );

  topicRepo.saveTopic(testTopic);
  final retrievedTopic = topicRepo.getTopicById('test_topic_1');
  
  if (retrievedTopic != null) {
    print('  ✅ Topic saved and retrieved successfully!');
    print('     Name: ${retrievedTopic.name}');
    print('     Description: ${retrievedTopic.description}');
    print('     Color: ${retrievedTopic.colorHex}');
  } else {
    print('  ❌ Failed to retrieve topic');
  }
  print('');

  // Test 2: Save and retrieve Lesson
  print('📋 Test 2: Lesson Storage');
  print('─' * 40);
  final testModule = ModuleModel(
    id: 'test_module_1',
    type: ModuleType.fa_scinate,
    title: 'Test Module',
    content: 'Test content for module',
    order: 1,
  );

  final testLesson = LessonModel(
    id: 'test_lesson_1',
    topicId: 'test_topic_1',
    title: 'Test Lesson',
    description: 'Test lesson for Hive',
    modules: [testModule],
    estimatedMinutes: 10,
  );

  lessonRepo.saveLesson(testLesson);
  final retrievedLesson = lessonRepo.getLessonById('test_lesson_1');
  
  if (retrievedLesson != null) {
    print('  ✅ Lesson saved and retrieved successfully!');
    print('     Title: ${retrievedLesson.title}');
    print('     Modules: ${retrievedLesson.modules.length}');
    print('     Topic ID: ${retrievedLesson.topicId}');
  } else {
    print('  ❌ Failed to retrieve lesson');
  }
  print('');

  // Test 3: Progress tracking
  print('📋 Test 3: Progress Tracking');
  print('─' * 40);
  progressRepo.markModuleCompleted('test_lesson_1', 'test_module_1');
  
  final progress = progressRepo.getProgress('test_lesson_1');
  if (progress != null) {
    print('  ✅ Progress saved successfully!');
    print('     Lesson ID: ${progress.lessonId}');
    print('     Completion: ${(progress.completionPercentage * 100).toInt()}%');
    print('     Modules completed: ${progress.completedModuleIds.length}');
    print('     Last accessed: ${progress.lastAccessed}');
  } else {
    print('  ❌ Failed to track progress');
  }
  print('');

  // Test 4: Data persistence check
  print('📋 Test 4: Data Counts');
  print('─' * 40);
  print('  Topics in storage: ${topicRepo.getTopicsCount()}');
  print('  Lessons in storage: ${lessonRepo.getLessonsCount()}');
  print('  Progress records: ${progressRepo.getAllProgress().length}');
  print('');

  // Test 5: Query operations
  print('📋 Test 5: Query Operations');
  print('─' * 40);
  final allTopics = topicRepo.getAllTopics();
  print('  Retrieved ${allTopics.length} topics from storage');
  
  final lessonsByTopic = lessonRepo.getLessonsByTopicId('test_topic_1');
  print('  Found ${lessonsByTopic.length} lessons for test_topic_1');
  
  final completedCount = progressRepo.getCompletedLessonsCount();
  print('  Completed lessons: $completedCount');
  print('');

  print('╔════════════════════════════════════╗');
  print('║   Hive Storage Tests Complete! ✨   ║');
  print('╚════════════════════════════════════╝\n');
  
  print('⚠️  IMPORTANT: Data persists across app restarts!');
  print('    Try these commands in terminal:');
  print('    • Press "R" to hot restart');
  print('    • Check if data counts remain the same');
  print('    • If yes, persistence works! ✅\n');
  
  print('💡 TIP: To clear test data, uncomment clearAll() in repositories\n');
}