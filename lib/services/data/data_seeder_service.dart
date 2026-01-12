import 'dart:convert';
import 'package:flutter/services.dart';
import '../../shared/models/models.dart';
import '../../features/topics/data/repositories/topic_repository.dart';
import '../../features/lessons/data/repositories/lesson_repository.dart';
import '../preferences/shared_prefs_service.dart';

/// Service to seed initial lesson data from JSON assets into Hive
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

      // Load Topic 1: Circulation and Gas Exchange
      await _loadTopic1();

      // Mark as seeded
      await markDataSeeded();

      print('✅ Data seeding complete!');
    } catch (e) {
      print('❌ Error seeding data: $e');
      rethrow;
    }
  }

  /// Load Topic 1 from JSON
  Future<void> _loadTopic1() async {
    try {
      print('📖 Loading Topic 1: Circulation and Gas Exchange...');

      // Load JSON from assets
      final String jsonString = await rootBundle.loadString(
        'assets/data/lessons/Topic_1.json',
      );

      // Parse JSON
      final Map<String, dynamic> data = json.decode(jsonString);

      // Extract topic
      final topicData = data['topic'] as Map<String, dynamic>;
      final topic = TopicModel(
        id: topicData['id'],
        name: topicData['name'],
        description: topicData['description'],
        iconName: topicData['icon_name'],
        colorHex: topicData['color_hex'],
        lessonIds: [], // Will be populated as we add lessons
        order: topicData['order'],
      );

      // Extract lessons
      final lessonsData = data['lessons'] as List;
      final List<String> lessonIds = [];

      for (var lessonData in lessonsData) {
        final lesson = LessonModel.fromJson(lessonData);
        await _lessonRepo.saveLesson(lesson);
        lessonIds.add(lesson.id);
        print('  ✓ Loaded lesson: ${lesson.title}');
      }

      // Update topic with lesson IDs
      final updatedTopic = topic.copyWith(lessonIds: lessonIds);
      await _topicRepo.saveTopic(updatedTopic);

      print('  ✓ Saved topic: ${topic.name}');
      print('  ✓ Total lessons: ${lessonIds.length}');
    } catch (e) {
      print('  ❌ Error loading Topic 1: $e');
      rethrow;
    }
  }

  /// Get seeding statistics
  Future<Map<String, int>> getSeedingStats() async {
    return {
      'topics': _topicRepo.getTopicsCount(),
      'lessons': _lessonRepo.getLessonsCount(),
    };
  }
}