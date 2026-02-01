import 'package:hive/hive.dart';

/// Represents a bookmarked lesson for quick access
@HiveType(typeId: 5)
class BookmarkModel extends HiveObject {
  @HiveField(0)
  final String lessonId;

  @HiveField(1)
  final String topicId;

  @HiveField(2)
  final DateTime bookmarkedAt;

  @HiveField(3)
  final String? notes; // Optional user notes

  BookmarkModel({
    required this.lessonId,
    required this.topicId,
    required this.bookmarkedAt,
    this.notes,
  });

  /// Create from JSON
  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      lessonId: json['lesson_id'] as String,
      topicId: json['topic_id'] as String,
      bookmarkedAt: DateTime.parse(json['bookmarked_at'] as String),
      notes: json['notes'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'lesson_id': lessonId,
      'topic_id': topicId,
      'bookmarked_at': bookmarkedAt.toIso8601String(),
      'notes': notes,
    };
  }

  /// Create a copy with modified fields
  BookmarkModel copyWith({
    String? lessonId,
    String? topicId,
    DateTime? bookmarkedAt,
    String? notes,
  }) {
    return BookmarkModel(
      lessonId: lessonId ?? this.lessonId,
      topicId: topicId ?? this.topicId,
      bookmarkedAt: bookmarkedAt ?? this.bookmarkedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'BookmarkModel(lessonId: $lessonId, topicId: $topicId, bookmarkedAt: $bookmarkedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookmarkModel && other.lessonId == lessonId;
  }

  @override
  int get hashCode => lessonId.hashCode;
}