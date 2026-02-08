/// Module Phase - Tracks whether the scripted conversation is still in progress or done
enum ModulePhase {
  /// Scripted conversation is active, student interacting with bot
  inProgress,

  /// All script steps completed, student can proceed to next module
  completed,
}
