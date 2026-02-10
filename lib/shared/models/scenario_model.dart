/// Chat Scenario Model
/// Represents a unique conversation context in SCI-Bot.
///
/// A scenario is a unique combination of screen context + AI character
/// that maintains its own isolated conversation history.
///
/// Three scenario types:
/// 1. General (Aristotle) - home, topics, general navigation
/// 2. Lesson Menu (Expert) - topic lesson selection screens
/// 3. Module (Expert) - inside a specific module
///
/// Phase 1: Scenario-Based Chatbot Architecture
library;

/// The type of scenario context.
enum ScenarioType {
  /// Aristotle's general guidance across home/topics/navigation.
  general,

  /// Expert character on a topic's lesson selection screen.
  lessonMenu,

  /// Expert character inside a specific lesson module.
  module,
}

class ChatScenario {
  /// Unique identifier for this scenario instance.
  /// Format examples:
  /// - `aristotle_general`
  /// - `herophilus_lesson_menu_circulation`
  /// - `herophilus_module_circulation_lesson1_module1`
  final String id;

  /// Which AI character is active (aristotle, herophilus, mendel, odum).
  final String characterId;

  /// The type of scenario.
  final ScenarioType type;

  /// Additional context (topicId, lessonId, moduleId).
  final Map<String, String> context;

  const ChatScenario({
    required this.id,
    required this.characterId,
    required this.type,
    this.context = const {},
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Aristotle's shared scenario for home, topics, and general navigation.
  factory ChatScenario.aristotleGeneral() {
    return const ChatScenario(
      id: 'aristotle_general',
      characterId: 'aristotle',
      type: ScenarioType.general,
    );
  }

  /// Expert character on a topic's lesson menu screen.
  factory ChatScenario.expertLessonMenu({
    required String expertId,
    required String topicId,
  }) {
    return ChatScenario(
      id: '${expertId}_lesson_menu_$topicId',
      characterId: expertId,
      type: ScenarioType.lessonMenu,
      context: {'topicId': topicId},
    );
  }

  /// Expert character inside a specific lesson module.
  factory ChatScenario.expertModule({
    required String expertId,
    required String topicId,
    required String lessonId,
    required String moduleId,
  }) {
    return ChatScenario(
      id: '${expertId}_module_${topicId}_${lessonId}_$moduleId',
      characterId: expertId,
      type: ScenarioType.module,
      context: {
        'topicId': topicId,
        'lessonId': lessonId,
        'moduleId': moduleId,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Equality
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatScenario &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ChatScenario(id: $id, character: $characterId, type: $type)';
}
