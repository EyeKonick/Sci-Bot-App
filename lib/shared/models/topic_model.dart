/// Science topic containing multiple lessons
/// Example: "Heredity & Variation", "Ecosystems"
class TopicModel {
  final String id;
  final String name;
  final String description;
  final String iconName; // Store as string, convert to IconData in UI
  final String colorHex; // Store as hex string like "#4DB8C4"
  final List<String> lessonIds; // IDs of lessons in this topic
  final int order; // Display order

  const TopicModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.colorHex,
    required this.lessonIds,
    required this.order,
  });

  /// Create from JSON
  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      iconName: json['icon_name'] as String,
      colorHex: json['color_hex'] as String,
      lessonIds: (json['lesson_ids'] as List<dynamic>)
          .map((id) => id as String)
          .toList(),
      order: json['order'] as int,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'color_hex': colorHex,
      'lesson_ids': lessonIds,
      'order': order,
    };
  }

  /// Get total number of lessons in this topic
  int get lessonCount => lessonIds.length;

  /// Create a copy with modified fields
  TopicModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    String? colorHex,
    List<String>? lessonIds,
    int? order,
  }) {
    return TopicModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      lessonIds: lessonIds ?? this.lessonIds,
      order: order ?? this.order,
    );
  }

  @override
  String toString() {
    return 'TopicModel(id: $id, name: $name, lessons: ${lessonIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TopicModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}