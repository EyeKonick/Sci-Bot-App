import 'dart:io';
import '../../features/topics/data/repositories/topic_repository.dart';
import '../../features/lessons/data/repositories/lesson_repository.dart';

/// Test data seeding functionality
void testDataSeeding() {
  stdout.writeln('\n📊 === TESTING DATA SEEDING ===\n');

  final topicRepo = TopicRepository();
  final lessonRepo = LessonRepository();

  // Test 1: Check if topics loaded
  stdout.writeln('Test 1: Topics in Hive');
  final topics = topicRepo.getAllTopics();
  stdout.writeln('Topics found: ${topics.length}');
  
  for (var topic in topics) {
    stdout.writeln('  ✓ ${topic.name}');
    stdout.writeln('    - ID: ${topic.id}');
    stdout.writeln('    - Lessons: ${topic.lessonIds.length}');
    stdout.writeln('    - Color: ${topic.colorHex}');
    stdout.writeln('    - Icon: ${topic.iconName}');
  }
  stdout.writeln('');

  // Test 2: Check if lessons loaded
  stdout.writeln('Test 2: Lessons in Hive');
  final lessons = lessonRepo.getAllLessons();
  stdout.writeln('Lessons found: ${lessons.length}');
  
  for (var lesson in lessons) {
    stdout.writeln('  ✓ ${lesson.title}');
    stdout.writeln('    - ID: ${lesson.id}');
    stdout.writeln('    - Modules: ${lesson.modules.length}');
    stdout.writeln('    - Duration: ${lesson.estimatedMinutes} min');
  }
  stdout.writeln('');

  // Test 3: Check module details
  if (lessons.isNotEmpty) {
    stdout.writeln('Test 3: Module Details (First Lesson)');
    final firstLesson = lessons.first;
    stdout.writeln('Lesson: ${firstLesson.title}');
    
    for (var module in firstLesson.modules) {
      stdout.writeln('  Module ${module.order}: ${module.title}');
      stdout.writeln('    - Type: ${module.type.displayName}');
      stdout.writeln('    - Duration: ${module.estimatedMinutes} min');
      stdout.writeln('    - Content length: ${module.content.length} chars');
    }
  }
  stdout.writeln('');

  // Test 4: Summary
  stdout.writeln('Test 4: Summary');
  stdout.writeln('✅ Topics loaded: ${topics.length}');
  stdout.writeln('✅ Lessons loaded: ${lessons.length}');
  stdout.writeln('✅ Total modules: ${lessons.fold(0, (sum, l) => sum + l.modules.length)}');
  
  stdout.writeln('\n📊 === ALL TESTS COMPLETE ===\n');
}