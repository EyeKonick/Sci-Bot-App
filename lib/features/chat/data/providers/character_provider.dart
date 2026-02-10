import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../shared/models/navigation_context_model.dart';
import '../../../../shared/models/scenario_model.dart';

/// AI Character Provider
/// Manages which AI character is currently active based on navigation context
/// Week 3, Day 3 Implementation + Phase 1 Scenario Architecture

/// Current navigation context provider
final navigationContextProvider = StateProvider<NavigationContext>((ref) {
  return NavigationContext.home();
});

/// Current active scenario provider.
/// Tracks which ChatScenario is currently active across the app.
final currentScenarioProvider = StateProvider<ChatScenario?>((ref) {
  return null;
});

/// Active AI character provider
/// Automatically updates when navigation context changes
final activeCharacterProvider = Provider<AiCharacter>((ref) {
  final context = ref.watch(navigationContextProvider);
  
  // If user is in a topic, get topic-specific expert
  if (context.currentTopicId != null) {
    return AiCharacter.getCharacterForTopic(context.currentTopicId!);
  }
  
  // Otherwise, default to Aristotle
  return AiCharacter.aristotle;
});

/// Previous context provider
/// Stores the last non-home context for personalized greetings
final previousContextProvider = StateProvider<NavigationContext?>((ref) {
  return null;
});

/// Character Context Manager
/// Helper class to manage character switching and context updates
class CharacterContextManager {
  final Ref ref;

  CharacterContextManager(this.ref);

  /// Update navigation context
  void updateContext(NavigationContext newContext) {
    final currentContext = ref.read(navigationContextProvider);
    
    // If moving from topic to home, save previous context
    if (currentContext.isInTopic && !newContext.isInTopic) {
      ref.read(previousContextProvider.notifier).state = currentContext;
    }
    
    // Update current context
    ref.read(navigationContextProvider.notifier).state = newContext;
  }

  /// Navigate to home
  void navigateToHome() {
    updateContext(NavigationContext.home());
  }

  /// Navigate to topic
  void navigateToTopic(String topicId) {
    updateContext(NavigationContext.topic(topicId));
  }

  /// Navigate to lesson
  void navigateToLesson({
    required String topicId,
    required String lessonId,
  }) {
    updateContext(NavigationContext.lesson(
      topicId: topicId,
      lessonId: lessonId,
    ));
  }

  /// Navigate to module
  void navigateToModule({
    required String topicId,
    required String lessonId,
    required String moduleIndex,
  }) {
    updateContext(NavigationContext.module(
      topicId: topicId,
      lessonId: lessonId,
      moduleIndex: moduleIndex,
    ));
  }

  /// Get personalized greeting based on navigation context
  /// Provides context-aware small talk that references the student's learning journey
  String getPersonalizedGreeting() {
    final prevContext = ref.read(previousContextProvider);
    final currentCharacter = ref.read(activeCharacterProvider);

    // If no previous context, use default greeting
    if (prevContext == null || !prevContext.isInTopic) {
      return currentCharacter.greeting;
    }

    final previousTopicId = prevContext.currentTopicId;
    final previousCharacter = previousTopicId != null
        ? AiCharacter.getCharacterForTopic(previousTopicId)
        : null;
    final cameFromLesson = prevContext.currentLessonId != null;

    // Generate context-aware greeting based on current character
    // Use time-based variation to avoid repetitive greetings
    final variation = DateTime.now().second % 3;

    switch (currentCharacter.id) {
      case 'aristotle':
        if (cameFromLesson && previousCharacter != null) {
          final options = [
            'Welcome back! I hope your session with ${previousCharacter.name} went well. What would you like to explore next?',
            'Ah, you return from studying with ${previousCharacter.name}! Tell me, what did you discover about ${previousCharacter.specialization.toLowerCase()}?',
            'Good to see you! How was your lesson on ${previousCharacter.specialization.toLowerCase()}? Ready to continue your science journey?',
          ];
          return options[variation];
        } else if (previousTopicId != null && previousCharacter != null) {
          final options = [
            'Good to see you again! How was your time studying ${previousCharacter.specialization.toLowerCase()}?',
            'Welcome back from ${previousCharacter.name}\'s class! What caught your attention about ${previousCharacter.specialization.toLowerCase()}?',
            'Ah, returning from exploring ${previousCharacter.specialization.toLowerCase()}! What questions do you have now?',
          ];
          return options[variation];
        }
        return currentCharacter.greeting;

      case 'herophilus':
        if (previousCharacter != null && previousCharacter.id != 'herophilus') {
          final options = [
            'Welcome! I see you were just learning about ${previousCharacter.specialization.toLowerCase()} with ${previousCharacter.name}. Ready to dive into the circulatory system?',
            'Ah, coming from ${previousCharacter.name}\'s lesson! Let me show you how the circulatory system connects to what you just learned.',
            'Good to have you here! After studying ${previousCharacter.specialization.toLowerCase()}, let us explore how blood flows through the body.',
          ];
          return options[variation];
        }
        return currentCharacter.greeting;

      case 'mendel':
        if (previousCharacter != null && previousCharacter.id != 'mendel') {
          final options = [
            'Hello there! Coming from ${previousCharacter.specialization.toLowerCase()}? Wonderful. Let us see how heredity connects to what you have been learning!',
            'Welcome! ${previousCharacter.name} has been teaching you well. Now, shall we discover the patterns of inheritance together?',
            'Ah, fresh from studying ${previousCharacter.specialization.toLowerCase()}! Ready to explore how traits pass from parents to offspring?',
          ];
          return options[variation];
        }
        return currentCharacter.greeting;

      case 'odum':
        if (previousCharacter != null && previousCharacter.id != 'odum') {
          final options = [
            'Welcome! I hear you were exploring ${previousCharacter.specialization.toLowerCase()} with ${previousCharacter.name}. Ready to see how energy flows through ecosystems?',
            'Great timing! After learning about ${previousCharacter.specialization.toLowerCase()}, let us discover how all living things are connected through energy.',
            'Hello! Coming from ${previousCharacter.name}\'s class? Perfect. Let me show you the bigger picture of how ecosystems work!',
          ];
          return options[variation];
        }
        return currentCharacter.greeting;

      default:
        return currentCharacter.greeting;
    }
  }

  /// Get current active character
  AiCharacter getCurrentCharacter() {
    return ref.read(activeCharacterProvider);
  }

  /// Get current context
  NavigationContext getCurrentContext() {
    return ref.read(navigationContextProvider);
  }

  // ---------------------------------------------------------------------------
  // Scenario-aware navigation (Phase 1)
  // ---------------------------------------------------------------------------

  /// Set the active scenario in the provider state.
  void setScenario(ChatScenario scenario) {
    ref.read(currentScenarioProvider.notifier).state = scenario;
  }

  /// Get the current active scenario.
  ChatScenario? getScenario() {
    return ref.read(currentScenarioProvider);
  }
}

/// Provider for CharacterContextManager
final characterContextManagerProvider = Provider<CharacterContextManager>((ref) {
  return CharacterContextManager(ref);
});
