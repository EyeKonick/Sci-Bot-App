/// Two-Channel Message System for SCI-Bot
///
/// The app uses two distinct, non-overlapping communication channels:
///
/// 1. NARRATION CHANNEL (chathead + speech bubbles):
///    Uses [NarrationMessage] type.
///    Delivers greetings, storytelling, motivation, introductions, encouragement.
///    NEVER contains questions requiring user answers.
///    NEVER accepts typed input.
///
/// 2. INTERACTION CHANNEL (main chat area):
///    Uses [InteractionMessage] type.
///    Handles questions requiring user input, typed responses, answer
///    evaluation, correct/incorrect feedback, and explanations.
///    User types ONLY in this channel.
///
/// ## Rules
///
/// - If the AI needs a response from the user, the prompt MUST use
///   [InteractionMessage] and appear in the main chat.
/// - The chathead may introduce a topic or set context, but the actual
///   question always uses [InteractionMessage].
/// - Answer evaluation and feedback are ALWAYS [InteractionMessage].
/// - The chathead may optionally follow with a brief encouraging comment
///   as a [NarrationMessage] (no questions, no evaluation).

/// Pacing hint for speech bubble display timing.
///
/// Controls how long a bubble lingers and the inter-bubble gap,
/// creating natural conversational rhythm instead of mechanical timing.
enum PacingHint {
  /// Excitement, celebration - shorter gaps (800ms)
  fast,

  /// Standard explanation, narration - medium gaps (1200ms)
  normal,

  /// Reflection, thinking pause - longer gaps (1800ms)
  slow,
}

/// Designates which communication channel a message belongs to.
enum MessageChannel {
  /// Chathead speech bubbles - narration, greetings, storytelling.
  /// NEVER contains questions requiring user answers.
  narration,

  /// Main chat area - questions, user input, answer evaluation.
  /// User types ONLY in this channel.
  interaction,
}

/// A message for the NARRATION channel (chathead speech bubbles).
///
/// NarrationMessages are:
/// - Displayed in the speech bubble next to the floating avatar
/// - System-driven (appear automatically, no user input accepted)
/// - Greetings, storytelling, motivation, introductions, encouragement
/// - NEVER contain questions requiring user answers
/// - NEVER validate correctness of user responses
class NarrationMessage {
  final String content;
  final String? characterId;
  final PacingHint pacingHint;
  final String? imageAssetPath; // Optional image to display with message

  const NarrationMessage({
    required this.content,
    this.characterId,
    this.pacingHint = PacingHint.normal,
    this.imageAssetPath,
  });

  /// Calculate display duration based on word count.
  /// Uses ~200 WPM reading speed for Grade 9 students (14-15 years old).
  /// Returns milliseconds to display the bubble before starting fade-out.
  int get displayMs {
    final wordCount = content.split(RegExp(r'\s+')).length;
    // ~300ms per word, min 2s, max 8s
    return (wordCount * 300).clamp(2000, 8000);
  }

  /// Calculate inter-bubble gap (pause after fade-out before next bubble).
  /// Questions get a natural thinking pause (1500ms).
  /// Pacing hints override length-based calculation.
  int get gapMs {
    // Questions get a thinking pause
    if (content.trimRight().endsWith('?')) return 1500;

    switch (pacingHint) {
      case PacingHint.fast:
        return 800;
      case PacingHint.slow:
        return 1800;
      case PacingHint.normal:
        // Length-based for normal pacing
        final length = content.length;
        if (length < 50) return 800;
        if (length < 120) return 1200;
        return 1800;
    }
  }

  /// Split long narration messages at semantic boundaries.
  ///
  /// Messages under [maxLength] characters pass through unchanged.
  /// Longer messages split at paragraph breaks (\n\n) first, then
  /// at sentence endings (. ! ?) if still too long.
  /// Never splits mid-sentence.
  static List<NarrationMessage> semanticSplit(
    List<NarrationMessage> messages, {
    int maxLength = 100,
  }) {
    final result = <NarrationMessage>[];
    for (final msg in messages) {
      if (msg.content.length <= maxLength) {
        result.add(msg);
        continue;
      }
      final splits = _splitAtBoundaries(msg.content, maxLength);
      for (final split in splits) {
        if (split.trim().isNotEmpty) {
          result.add(NarrationMessage(
            content: split.trim(),
            characterId: msg.characterId,
            pacingHint: msg.pacingHint,
            imageAssetPath: msg.imageAssetPath,
          ));
        }
      }
    }
    return result;
  }

  /// Split text at paragraph breaks or sentence boundaries.
  static List<String> _splitAtBoundaries(String text, int maxLength) {
    // First try paragraph breaks
    if (text.contains('\n\n')) {
      final paragraphs =
          text.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
      if (paragraphs.length > 1) return paragraphs;
    }

    // Then try sentence boundaries
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (parts.length <= 1) return [text]; // Can't split further

    // Group short sentences together up to maxLength
    final sentences = <String>[];
    String current = '';
    for (final part in parts) {
      if (current.isEmpty) {
        current = part;
      } else if ('$current $part'.length <= maxLength) {
        current = '$current $part';
      } else {
        sentences.add(current);
        current = part;
      }
    }
    if (current.isNotEmpty) sentences.add(current);

    return sentences.length > 1 ? sentences : [text];
  }

  @override
  String toString() =>
      'NarrationMessage("${content.length > 40 ? '${content.substring(0, 40)}...' : content}")';
}

/// A message for the INTERACTION channel (main chat area).
///
/// InteractionMessages are:
/// - Displayed in the central chat UI where the user types
/// - Questions requiring user input, answer evaluations, explanations
/// - User responds to these messages in the main chat
/// - AI evaluates answers and provides feedback here
class InteractionMessage {
  final String id;
  final String role; // 'assistant' or 'user'
  final String content;
  final String? characterName;
  final String? characterId;
  final bool isStreaming;
  final DateTime timestamp;

  InteractionMessage({
    required this.id,
    required this.role,
    required this.content,
    this.characterName,
    this.characterId,
    this.isStreaming = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  InteractionMessage copyWith({
    String? content,
    bool? isStreaming,
    String? characterName,
  }) {
    return InteractionMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      characterName: characterName ?? this.characterName,
      characterId: characterId,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp,
    );
  }

  /// Create a user message for the interaction channel.
  factory InteractionMessage.user(String content) {
    return InteractionMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
    );
  }

  /// Create an assistant message for the interaction channel.
  factory InteractionMessage.assistant(
    String content, {
    String? characterName,
    String? characterId,
    bool isStreaming = false,
  }) {
    return InteractionMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: content,
      characterName: characterName,
      characterId: characterId,
      isStreaming: isStreaming,
    );
  }

  @override
  String toString() =>
      'InteractionMessage($role, "${content.length > 40 ? '${content.substring(0, 40)}...' : content}")';
}
