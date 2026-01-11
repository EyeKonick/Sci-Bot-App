/// The six types of modules in each lesson
/// Based on SCI-Bot educational philosophy
enum ModuleType {
  /// Pre-SCI-ntation: Pre-assessment and prior knowledge
  preScintation('Pre-SCI-ntation', 'pre_scintation'),
  
  /// Fa-SCI-nate: Engage students with interesting content
  faScinate('Fa-SCI-nate', 'fa_scinate'),
  
  /// Inve-SCI-tigation: Deep dive into the topic
  inveScitigation('Inve-SCI-tigation', 'inve_scitigation'),
  
  /// Goal SCI-tting: Learning objectives and targets
  goalScitting('Goal SCI-tting', 'goal_scitting'),
  
  /// Self-A-SCI-ssment: Check understanding
  selfAScissment('Self-A-SCI-ssment', 'self_a_scissment'),
  
  /// SCI-pplementary: Additional resources and practice
  scipplementary('SCI-pplementary', 'scipplementary');

  const ModuleType(this.displayName, this.jsonKey);

  final String displayName;
  final String jsonKey;

  /// Convert from JSON string to enum
  static ModuleType fromJson(String json) {
    return ModuleType.values.firstWhere(
      (type) => type.jsonKey == json,
      orElse: () => ModuleType.preScintation,
    );
  }

  /// Convert enum to JSON string
  String toJson() => jsonKey;
}