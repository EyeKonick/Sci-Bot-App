import 'dart:convert';
import 'package:flutter/services.dart';
import '../../shared/models/models.dart';
import '../../features/topics/data/repositories/topic_repository.dart';
import '../../features/lessons/data/repositories/lesson_repository.dart';
import '../preferences/shared_prefs_service.dart';

/// Service to seed initial lesson data from JSON assets into Hive
/// NEW: Optimized to load split JSON files (topics + individual lessons)
class DataSeederService {
  final TopicRepository _topicRepo;
  final LessonRepository _lessonRepo;

  DataSeederService({
    TopicRepository? topicRepo,
    LessonRepository? lessonRepo,
  })  : _topicRepo = topicRepo ?? TopicRepository(),
        _lessonRepo = lessonRepo ?? LessonRepository();

  /// Check if data has been seeded before
  static bool get isDataSeeded {
    return SharedPrefsService.isDataSeeded;
  }

  /// Mark data as seeded
  static Future<void> markDataSeeded() async {
    await SharedPrefsService.setDataSeeded();
  }

  /// Reset seeded flag (for testing)
  static Future<void> resetSeededFlag() async {
    await SharedPrefsService.resetDataSeeded();
  }

  /// Load and seed all lesson data
  Future<void> seedAllData() async {
    try {
      print('🌱 Starting data seeding...');

      // STEP 1: Load all topics from topics.json
      await _loadAllTopics();

      // STEP 2: Load lessons for each topic
      await _loadAllLessons();

      // Mark as seeded
      await markDataSeeded();

      print('✅ Data seeding complete!');
    } catch (e) {
      print('❌ Error seeding data: $e');
      rethrow;
    }
  }

  /// Load all topics from topics.json
  Future<void> _loadAllTopics() async {
    try {
      print('📚 Loading topics from topics.json...');

      // Load topics.json
      final String jsonString = await rootBundle.loadString(
        'assets/data/topics.json',
      );

      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> topicsData = data['topics'] as List;

      // Save each topic
      for (var topicData in topicsData) {
        final topic = TopicModel.fromJson(topicData as Map<String, dynamic>);
        await _topicRepo.saveTopic(topic);
        print('  ✓ Loaded topic: ${topic.name} (${topic.lessonIds.length} lessons)');
      }

      print('  ✓ Total topics loaded: ${topicsData.length}');
    } catch (e) {
      print('  ❌ Error loading topics: $e');
      rethrow;
    }
  }

  /// Load all lessons for all topics
  Future<void> _loadAllLessons() async {
    try {
      print('📖 Loading lessons...');

      // Get all topics
      final topics = _topicRepo.getAllTopics();
      int totalLessonsLoaded = 0;

      // For each topic, load its lessons
      for (var topic in topics) {
        for (var lessonId in topic.lessonIds) {
          await _loadLesson(topic.id, lessonId);
          totalLessonsLoaded++;
        }
      }

      print('  ✓ Total lessons loaded: $totalLessonsLoaded');
    } catch (e) {
      print('  ❌ Error loading lessons: $e');
      rethrow;
    }
  }

  /// Load a single lesson file
  Future<void> _loadLesson(String topicId, String lessonId) async {
    try {
      // Build path: assets/data/lessons/{topicId}/{lessonId}.json
      final path = 'assets/data/lessons/$topicId/$lessonId.json';

      // Load JSON file
      final String jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> lessonData = json.decode(jsonString);

      // Create lesson model
      final lesson = LessonModel.fromJson(lessonData);

      // Save to Hive
      await _lessonRepo.saveLesson(lesson);

      print('    ✓ Loaded: ${lesson.title} (${lesson.modules.length} modules)');
    } catch (e) {
      print('    ❌ Error loading lesson $lessonId: $e');
      // Continue with other lessons even if one fails
    }
  }

  /// Get seeding statistics
  Future<Map<String, int>> getSeedingStats() async {
    return {
      'topics': _topicRepo.getTopicsCount(),
      'lessons': _lessonRepo.getLessonsCount(),
    };
  }

  /// Helper: Load lessons for a specific topic (for future use)
  Future<void> loadTopicLessons(String topicId) async {
    try {
      final topic = _topicRepo.getTopicById(topicId);
      if (topic == null) {
        print('Topic $topicId not found');
        return;
      }

      print('Loading lessons for: ${topic.name}');

      for (var lessonId in topic.lessonIds) {
        await _loadLesson(topicId, lessonId);
      }
    } catch (e) {
      print('Error loading lessons for topic $topicId: $e');
      rethrow;
    }
  }
}