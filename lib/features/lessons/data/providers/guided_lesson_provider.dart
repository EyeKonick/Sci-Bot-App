import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/module_phase.dart';

/// State for the scripted lesson conversation flow
class GuidedLessonState {
  final ModulePhase currentPhase;
  final bool waitingForUser;

  const GuidedLessonState({
    this.currentPhase = ModulePhase.inProgress,
    this.waitingForUser = false,
  });

  bool get canProceed => currentPhase == ModulePhase.completed;

  GuidedLessonState copyWith({
    ModulePhase? currentPhase,
    bool? waitingForUser,
  }) {
    return GuidedLessonState(
      currentPhase: currentPhase ?? this.currentPhase,
      waitingForUser: waitingForUser ?? this.waitingForUser,
    );
  }
}

/// Manages guided lesson phase transitions
class GuidedLessonNotifier extends StateNotifier<GuidedLessonState> {
  GuidedLessonNotifier() : super(const GuidedLessonState());

  /// Start a new module script
  void startModule() {
    state = const GuidedLessonState(
      currentPhase: ModulePhase.inProgress,
      waitingForUser: false,
    );
  }

  /// Bot is now waiting for student input
  void setWaitingForUser() {
    state = state.copyWith(waitingForUser: true);
  }

  /// Student responded, bot will continue
  void clearWaiting() {
    state = state.copyWith(waitingForUser: false);
  }

  /// All script steps done, module complete
  void completeModule() {
    state = state.copyWith(
      currentPhase: ModulePhase.completed,
      waitingForUser: false,
    );
  }

  /// Offline mode - skip all phases
  void setOfflineMode() {
    state = const GuidedLessonState(
      currentPhase: ModulePhase.completed,
      waitingForUser: false,
    );
  }
}

/// Provider for guided lesson state
final guidedLessonProvider =
    StateNotifierProvider<GuidedLessonNotifier, GuidedLessonState>(
  (ref) => GuidedLessonNotifier(),
);
