import 'module_type.dart';

/// Individual module within a lesson
/// Each lesson has 6 modules (one of each type)
class ModuleModel {
  final String id;
  final ModuleType type;
  final String title;
  final String content;
  final int order; // 1-6, order within lesson
  final int estimatedMinutes;

  const ModuleModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.order,
    this.estimatedMinutes = 5,
  });

  /// Create from JSON
  factory ModuleModel.fromJson(Map<String, dynamic> json) {
    return ModuleModel(
      id: json['id'] as String,
      type: ModuleType.fromJson(json['type'] as String),
      title: json['title'] as String,
      content: json['content'] as String,
      order: json['order'] as int,
      estimatedMinutes: json['estimated_minutes'] as int? ?? 5,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toJson(),
      'title': title,
      'content': content,
      'order': order,
      'estimated_minutes': estimatedMinutes,
    };
  }

  /// Create a copy with modified fields
  ModuleModel copyWith({
    String? id,
    ModuleType? type,
    String? title,
    String? content,
    int? order,
    int? estimatedMinutes,
  }) {
    return ModuleModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      order: order ?? this.order,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }

  @override
  String toString() {
    return 'ModuleModel(id: $id, type: ${type.displayName}, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModuleModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}