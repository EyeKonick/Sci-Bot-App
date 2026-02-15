import 'dart:math';
import '../../../../services/ai/openai_service.dart';
import '../../../../shared/models/channel_message.dart';
import '../../../../shared/models/ai_character_model.dart';

/// Service for generating dynamic AI-powered greetings for expert characters
/// on lesson menu screens (Phase 2: Topic Menu Expert Scenarios).
///
/// Follows the same pattern as [AristotleGreetingService]:
/// - OpenAI API for dynamic, contextual greetings
/// - Offline fallbacks with randomized greeting sets
/// - Cached greeting per scenario for display in chathead bubbles
///
/// Unlike Aristotle's service (singleton), this service is keyed by scenario ID
/// so each expert lesson menu gets its own greeting state.
class ExpertGreetingService {
  static final ExpertGreetingService _instance =
      ExpertGreetingService._internal();
  factory ExpertGreetingService() => _instance;
  ExpertGreetingService._internal();

  final _openAI = OpenAIService();

  /// Cached greetings keyed by scenario ID.
  /// Each lesson menu scenario gets its own cached greeting.
  final Map<String, List<NarrationMessage>> _cachedGreetings = {};

  /// Track previous greetings per character to avoid repetition.
  final Map<String, List<String>> _previousGreetings = {};

  /// Get cached greeting for a specific scenario (synchronous).
  List<NarrationMessage>? getCachedGreeting(String scenarioId) =>
      _cachedGreetings[scenarioId];

  /// Whether a greeting has been fetched for a scenario.
  bool hasGreeting(String scenarioId) =>
      _cachedGreetings.containsKey(scenarioId) &&
      _cachedGreetings[scenarioId]!.isNotEmpty;

  /// Generate contextual greeting for an expert's lesson menu chathead.
  /// Returns 2-3 short NarrationMessages.
  Future<List<NarrationMessage>> generateGreeting({
    required String scenarioId,
    required AiCharacter character,
    required String topicName,
  }) async {
    // Return cached if already generated for this scenario
    if (hasGreeting(scenarioId)) {
      return _cachedGreetings[scenarioId]!;
    }

    if (!_openAI.isConfigured) {
      final fallback = _offlineFallback(character, topicName);
      _cachedGreetings[scenarioId] = fallback;
      return fallback;
    }

    try {
      final systemPrompt = _buildGreetingPrompt(
        character: character,
        topicName: topicName,
      );

      final response = await _openAI.chatCompletion(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': 'Generate greeting now.'},
        ],
        temperature: 1.0,
        maxTokens: 200,
      );

      // Parse: each line is one bubble message
      final lines = response
          .split('\n')
          .map((l) => l.trim())
          .where((l) =>
              l.isNotEmpty &&
              !l.startsWith('-') &&
              !RegExp(r'^\d+[.)]').hasMatch(l))
          .take(3)
          .toList();

      if (lines.isEmpty) {
        final fallback = _offlineFallback(character, topicName);
        _cachedGreetings[scenarioId] = fallback;
        return fallback;
      }

      final messages = lines
          .map((line) => NarrationMessage(
                content: line,
                characterId: character.id,
                pacingHint: PacingHint.slow,
              ))
          .toList();

      // Track greetings to avoid repetition
      final prevList = _previousGreetings[character.id] ??= [];
      prevList.addAll(lines);
      while (prevList.length > 9) {
        prevList.removeAt(0);
      }

      _cachedGreetings[scenarioId] = messages;
      return messages;
    } catch (e) {
      print('⚠️ Expert greeting failed for ${character.name}, using fallback: $e');
      final fallback = _offlineFallback(character, topicName);
      _cachedGreetings[scenarioId] = fallback;
      return fallback;
    }
  }

  /// Invalidate greeting for a specific scenario.
  void invalidateScenario(String scenarioId) {
    _cachedGreetings.remove(scenarioId);
  }

  /// Invalidate all cached greetings (e.g., on app restart).
  void invalidateAll() {
    _cachedGreetings.clear();
    _previousGreetings.clear();
  }

  /// Build system prompt for expert greeting generation.
  String _buildGreetingPrompt({
    required AiCharacter character,
    required String topicName,
  }) {
    final prevList = _previousGreetings[character.id];
    final avoidLine = (prevList != null && prevList.isNotEmpty)
        ? '\n\nDO NOT use any of these phrases (already used):\n${prevList.map((g) => '- "$g"').join('\n')}'
        : '';

    return '''You are ${character.name}, an expert in ${character.specialization}. You are an AI chatbot in SCI-Bot, a Grade 9 Science app for Filipino students. You are introducing yourself to a student.

TASK: Generate exactly 3 short speech bubble messages to greet a student who just entered the "$topicName" lesson menu. One message per line. Speak in first person as if YOU are the expert talking directly to the student.

RULES:
- Each message MUST be under 80 characters
- No numbering, no quotes, no bullets, no formatting
- Just plain text, one message per line
- The FIRST message: Greet the student and introduce yourself by name and title, and briefly mention what you are famous for or known for
- The SECOND message: Tell the student you are their AI chatbot companion for $topicName and express what fascinates you about the subject
- The THIRD message: Encourage them to pick a lesson so you can guide them through it
- Use "Kamusta" or "Hello" or "Welcome" to start - vary each time

PERSONALITY:
${_getPersonalityHint(character.id)}$avoidLine

Be warm, enthusiastic, and speak naturally as yourself. Every greeting must feel personal and fresh.''';
  }

  /// Get personality hint for the system prompt.
  String _getPersonalityHint(String characterId) {
    switch (characterId) {
      case 'herophilus':
        return '- You are Herophilus, the Father of Anatomy\n- You are known for your discoveries about Circulatory and Respiratory systems\n- Speak as yourself introducing yourself to a student\n- Mention your fascination with how the body works\n- Be precise yet warm and encouraging';
      case 'mendel':
        return '- You are Gregor Mendel, the Father of Genetics\n- You are known for discovering the law of inheritance through your pea plant experiments\n- Speak as yourself introducing yourself to a student\n- Mention your curiosity about how traits pass from parents to offspring\n- Be gentle and encouraging about discovery';
      case 'odum':
        return '- You are Eugene Odum, the Father of Ecosystem Ecology\n- You are known for showing how ecosystems work as interconnected systems\n- Speak as yourself introducing yourself to a student\n- Mention your passion for understanding how energy flows through nature\n- Be enthusiastic about how everything is connected';
      default:
        return '- Be warm and encouraging';
    }
  }

  /// Offline fallback with randomized greeting sets per character.
  List<NarrationMessage> _offlineFallback(
      AiCharacter character, String topicName) {
    final rng = Random();

    final sets = _getOfflineSets(character, topicName);
    final chosen = sets[rng.nextInt(sets.length)];

    return chosen
        .map((t) => NarrationMessage(
              content: t,
              characterId: character.id,
              pacingHint: PacingHint.slow,
            ))
        .toList();
  }

  /// Get offline greeting sets for each expert character.
  List<List<String>> _getOfflineSets(AiCharacter character, String topicName) {
    switch (character.id) {
      case 'herophilus':
        return [
          [
            "Kamusta! I'm Herophilus, the Father of Anatomy.",
            "I'm your AI chatbot companion for $topicName. I'm fascinated by how our body works!",
            'Pick a lesson and let me guide you through it!',
          ],
          [
            "Hello! I'm Herophilus. I'm known for my discoveries about the Circulatory and Respiratory systems.",
            "I'll be your AI companion as we explore $topicName together!",
            'Choose a lesson and let\'s start learning!',
          ],
          [
            "Welcome! I am Herophilus, the first to study the human body through dissection.",
            "I'm here as your AI chatbot guide for $topicName. Let me share what I know!",
            'Select a lesson and let\'s dive in together!',
          ],
        ];
      case 'mendel':
        return [
          [
            "Kamusta! I'm Gregor Mendel, the Father of Genetics.",
            "I'm your AI chatbot companion for $topicName. I discovered the law of inheritance!",
            'Pick a lesson and let me guide you through it!',
          ],
          [
            "Hello! I'm Gregor Mendel. I studied over 28,000 pea plants to unlock how traits are passed on.",
            "I'll be your AI companion as we explore $topicName together!",
            'Choose a lesson and let\'s discover inheritance patterns!',
          ],
          [
            "Welcome! I am Gregor Mendel, known for discovering how traits pass from parents to offspring.",
            "I'm here as your AI chatbot guide for $topicName. Let me share my discoveries!",
            'Select a lesson and let\'s begin your journey!',
          ],
        ];
      case 'odum':
        return [
          [
            "Kamusta! I'm Eugene Odum, the Father of Ecosystem Ecology.",
            "I'm your AI chatbot companion for $topicName. I showed the world how ecosystems are connected!",
            'Pick a lesson and let me guide you through it!',
          ],
          [
            "Hello! I'm Eugene Odum. I'm known for showing how energy flows through every living thing.",
            "I'll be your AI companion as we explore $topicName together!",
            'Choose a lesson and let\'s see how nature works!',
          ],
          [
            "Welcome! I am Eugene Odum, pioneer of modern ecosystem ecology.",
            "I'm here as your AI chatbot guide for $topicName. Everything in nature is connected!",
            'Select a lesson and let\'s explore ecosystems together!',
          ],
        ];
      default:
        return [
          [
            'Hello! I\'m ${character.name}, your expert in $topicName.',
            "I'm your AI chatbot companion. Let me guide you through this topic!",
            'Choose a lesson to begin!',
          ],
        ];
    }
  }
}
