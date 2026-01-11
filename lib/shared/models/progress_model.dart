/// User's progress for a specific lesson
/// Tracks which modules completed and overall percentage
class ProgressModel {
  final String lessonId;
  final Set<String> completedModuleIds; // IDs of completed modules
  final DateTime lastAccessed;
  final DateTime? completedAt; // Null if not fully completed

  const ProgressModel({
    required this.lessonId,
    required this.completedModuleIds,
    required this.lastAccessed,
    this.completedAt,
  });

  /// Create from JSON
  factory ProgressModel.fromJson(Map<String, dynamic> json) {
    return ProgressModel(
      lessonId: json['lesson_id'] as String,
      completedModuleIds: (json['completed_module_ids'] as List<dynamic>)
          .map((id) => id as String)
          .toSet(),
      lastAccessed: DateTime.parse(json['last_accessed'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'lesson_id': lessonId,
      'completed_module_ids': completedModuleIds.toList(),
      'last_accessed': lastAccessed.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  /// Calculate completion percentage (0.0 to 1.0)
  /// Assumes 6 modules per lesson
  double get completionPercentage {
    return completedModuleIds.length / 6.0;
  }

  /// Check if lesson is fully completed
  bool get isCompleted => completedAt != null;

  /// Check if specific module is completed
  bool isModuleCompleted(String moduleId) {
    return completedModuleIds.contains(moduleId);
  }

  /// Mark a module as completed
  ProgressModel markModuleCompleted(String moduleId) {
    final updatedModuleIds = Set<String>.from(completedModuleIds)
      ..add(moduleId);

    // Check if all 6 modules are now complete
    final allComplete = updatedModuleIds.length >= 6;

    return ProgressModel(
      lessonId: lessonId,
      completedModuleIds: updatedModuleIds,
      lastAccessed: DateTime.now(),
      completedAt: allComplete ? (completedAt ?? DateTime.now()) : completedAt,
    );
  }

  /// Update last accessed time
  ProgressModel updateLastAccessed() {
    return ProgressModel(
      lessonId: lessonId,
      completedModuleIds: completedModuleIds,
      lastAccessed: DateTime.now(),
      completedAt: completedAt,
    );
  }

  /// Create a copy with modified fields
  ProgressModel copyWith({
    String? lessonId,
    Set<String>? completedModuleIds,
    DateTime? lastAccessed,
    DateTime? completedAt,
  }) {
    return ProgressModel(
      lessonId: lessonId ?? this.lessonId,
      completedModuleIds: completedModuleIds ?? this.completedModuleIds,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  String toString() {
    return 'ProgressModel(lessonId: $lessonId, completed: ${completedModuleIds.length}/6, ${(completionPercentage * 100).toInt()}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProgressModel && other.lessonId == lessonId;
  }

  @override
  int get hashCode => lessonId.hashCode;
}