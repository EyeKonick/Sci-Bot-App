import 'module_model.dart';

/// Complete lesson containing 6 modules
/// Each lesson belongs to a topic
class LessonModel {
  final String id;
  final String topicId;
  final String title;
  final String description;
  final List<ModuleModel> modules;
  final int estimatedMinutes;
  final String imageUrl; // Optional cover image

  const LessonModel({
    required this.id,
    required this.topicId,
    required this.title,
    required this.description,
    required this.modules,
    required this.estimatedMinutes,
    this.imageUrl = '',
  });

  /// Create from JSON
  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      modules: (json['modules'] as List<dynamic>)
          .map((m) => ModuleModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      estimatedMinutes: json['estimated_minutes'] as int,
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_id': topicId,
      'title': title,
      'description': description,
      'modules': modules.map((m) => m.toJson()).toList(),
      'estimated_minutes': estimatedMinutes,
      'image_url': imageUrl,
    };
  }

  /// Get total number of modules (should always be 6)
  int get moduleCount => modules.length;

  /// Check if lesson is complete (all modules viewed)
  bool isComplete(Set<String> completedModuleIds) {
    return modules.every((module) => completedModuleIds.contains(module.id));
  }

  /// Get module by ID
  ModuleModel? getModuleById(String moduleId) {
    try {
      return modules.firstWhere((m) => m.id == moduleId);
    } catch (e) {
      return null;
    }
  }

  /// Create a copy with modified fields
  LessonModel copyWith({
    String? id,
    String? topicId,
    String? title,
    String? description,
    List<ModuleModel>? modules,
    int? estimatedMinutes,
    String? imageUrl,
  }) {
    return LessonModel(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      description: description ?? this.description,
      modules: modules ?? this.modules,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() {
    return 'LessonModel(id: $id, title: $title, modules: ${modules.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}