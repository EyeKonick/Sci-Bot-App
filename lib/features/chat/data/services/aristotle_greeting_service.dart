import '../../../../services/ai/openai_service.dart';
import '../../../../shared/models/channel_message.dart';

/// Service for generating dynamic AI-powered greetings and idle bubbles
/// for Aristotle's chathead speech bubbles.
///
/// Uses OpenAI to generate contextual, varied messages instead of
/// hardcoded static greetings. Every greeting is unique and time-aware.
class AristotleGreetingService {
  static final AristotleGreetingService _instance =
      AristotleGreetingService._internal();
  factory AristotleGreetingService() => _instance;
  AristotleGreetingService._internal();

  final _openAI = OpenAIService();

  // Cached greeting for current session display
  List<NarrationMessage>? _cachedGreeting;

  // Pre-generated idle bubble queue (batch-fetched for efficiency)
  final List<NarrationMessage> _idleBubbleQueue = [];
  int _idleFetchCount = 0;
  static const int _maxIdleFetches = 3;

  // Track previously generated greetings to avoid repetition
  final List<String> _previousGreetings = [];

  /// Get cached greeting (synchronous, for use in build methods)
  List<NarrationMessage>? get cachedGreeting => _cachedGreeting;

  /// Whether a greeting has been fetched and is ready
  bool get hasGreeting => _cachedGreeting != null && _cachedGreeting!.isNotEmpty;

  /// Generate contextual greeting for Aristotle's chathead speech bubbles.
  /// Always generates a FRESH greeting - never serves stale cached content.
  /// Returns 2-3 short NarrationMessages.
  Future<List<NarrationMessage>> generateGreeting({
    required bool isFirstLaunch,
    required String timeOfDay,
    String? lastTopicExplored,
  }) async {
    if (!_openAI.isConfigured) {
      final fallback = _offlineFallback(isFirstLaunch, timeOfDay);
      _cachedGreeting = fallback;
      return fallback;
    }

    try {
      final systemPrompt = _buildGreetingPrompt(
        isFirstLaunch: isFirstLaunch,
        timeOfDay: timeOfDay,
        lastTopicExplored: lastTopicExplored,
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
          .where((l) => l.isNotEmpty && !l.startsWith('-') && !RegExp(r'^\d+[.)]').hasMatch(l))
          .take(3)
          .toList();

      if (lines.isEmpty) {
        final fallback = _offlineFallback(isFirstLaunch, timeOfDay);
        _cachedGreeting = fallback;
        return fallback;
      }

      // Use slow pacing for greetings - feels more natural and intentional
      final messages = lines
          .map((line) => NarrationMessage(
                content: line,
                characterId: 'aristotle',
                pacingHint: PacingHint.slow,
              ))
          .toList();

      // Track these greetings so we can tell AI not to repeat them
      _previousGreetings.addAll(lines);
      // Keep only last 9 to avoid prompt bloat
      while (_previousGreetings.length > 9) {
        _previousGreetings.removeAt(0);
      }

      _cachedGreeting = messages;
      return messages;
    } catch (e) {
      final fallback = _offlineFallback(isFirstLaunch, timeOfDay);
      _cachedGreeting = fallback;
      return fallback;
    }
  }

  /// Generate a single idle encouragement bubble.
  /// Consumes from pre-fetched queue; fetches new batch when empty.
  Future<NarrationMessage?> generateIdleBubble() async {
    if (_idleBubbleQueue.isNotEmpty) {
      return _idleBubbleQueue.removeAt(0);
    }

    if (_idleFetchCount >= _maxIdleFetches || !_openAI.isConfigured) {
      return null;
    }

    try {
      _idleFetchCount++;

      final response = await _openAI.chatCompletion(
        messages: [
          {'role': 'system', 'content': _idleBubblePrompt},
          {'role': 'user', 'content': 'Generate idle messages now.'},
        ],
        temperature: 1.0,
        maxTokens: 300,
      );

      final lines = response
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('-') && !RegExp(r'^\d+[.)]').hasMatch(l))
          .take(5)
          .toList();

      for (final line in lines) {
        _idleBubbleQueue.add(NarrationMessage(
          content: line,
          characterId: 'aristotle',
          pacingHint: PacingHint.slow,
        ));
      }

      if (_idleBubbleQueue.isNotEmpty) {
        return _idleBubbleQueue.removeAt(0);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Invalidate greeting cache (call on navigation context change)
  void invalidateCache() {
    _cachedGreeting = null;
  }

  /// Build system prompt for greeting generation
  String _buildGreetingPrompt({
    required bool isFirstLaunch,
    required String timeOfDay,
    String? lastTopicExplored,
  }) {
    final topicLine = lastTopicExplored != null
        ? 'The student last explored: $lastTopicExplored'
        : 'The student has not explored any topics yet';

    final avoidLine = _previousGreetings.isNotEmpty
        ? '\n\nDO NOT use any of these phrases (already used):\n${_previousGreetings.map((g) => '- "$g"').join('\n')}'
        : '';

    return '''You are Aristotle (384-322 BC), the ancient Greek philosopher and Father of Biology. You are the main AI companion in SCI-Bot, a Grade 9 Science app for Filipino students.

TASK: Generate exactly 3 short speech bubble messages. One message per line.

RULES:
- Each message MUST be under 60 characters
- No numbering, no quotes, no bullets, no formatting
- Just plain text, one message per line
- The FIRST message MUST be a time-appropriate greeting that includes your name (e.g. "Good $timeOfDay! I'm Aristotle...")
- The SECOND message should briefly state your role as their SCI-Bot AI science companion
- The THIRD message should encourage them to start learning or continue

CONTEXT:
- Time of day: $timeOfDay (use this in your greeting!)
- First time opening app: ${isFirstLaunch ? 'YES - introduce yourself' : 'NO - welcome them back'}
- $topicLine$avoidLine

Be warm, natural, and NEVER generic. Every greeting must feel fresh and unique.''';
  }

  /// System prompt for generating idle bubble batches
  static const String _idleBubblePrompt = '''You are Aristotle (384-322 BC), the Father of Biology, AI companion in SCI-Bot for Grade 9 Filipino students.

TASK: Generate exactly 5 short speech bubble messages. One per line.

RULES:
- Each message MUST be under 80 characters
- No numbering, no quotes, no bullets, no formatting
- Just plain text, one message per line

Each message should be ONE of these (mix them up):
- A fun Grade 9 science fact about Circulation, Heredity, or Ecosystems
- A warm study encouragement from Aristotle
- A curious question that makes students want to learn more
- A reference to Aristotle's historical observations of nature

Be varied, interesting, and warm. Each message must be completely different from the others.''';

  /// Offline-only fallback - only used when OpenAI is not configured
  List<NarrationMessage> _offlineFallback(bool isFirstLaunch, String timeOfDay) {
    final greeting = timeOfDay == 'morning'
        ? 'Good morning!'
        : timeOfDay == 'afternoon'
            ? 'Good afternoon!'
            : 'Good evening!';

    if (isFirstLaunch) {
      return [
        NarrationMessage(
          content: "$greeting I'm Aristotle, your SCI-Bot guide.",
          characterId: 'aristotle',
          pacingHint: PacingHint.slow,
        ),
        const NarrationMessage(
          content: "I'll help you explore Grade 9 Science!",
          characterId: 'aristotle',
          pacingHint: PacingHint.slow,
        ),
        const NarrationMessage(
          content: 'Pick a topic and let\'s get started!',
          characterId: 'aristotle',
          pacingHint: PacingHint.slow,
        ),
      ];
    }
    return [
      NarrationMessage(
        content: '$greeting Welcome back, young scholar!',
        characterId: 'aristotle',
        pacingHint: PacingHint.slow,
      ),
      const NarrationMessage(
        content: 'Ready to continue your science journey?',
        characterId: 'aristotle',
        pacingHint: PacingHint.slow,
      ),
      const NarrationMessage(
        content: 'Tap on me if you need any help!',
        characterId: 'aristotle',
        pacingHint: PacingHint.slow,
      ),
    ];
  }
}
