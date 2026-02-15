/// Calculate reading time for messages based on word count.
///
/// Uses the same proven formula as NarrationMessage for speech bubbles:
/// ~300ms per word, with min/max bounds to prevent edge cases.
///
/// Based on average reading speed for Grade 9 students (14-15 years old):
/// approximately 200 words per minute, which equals 300ms per word.
class ReadingTime {
  /// Calculate display time (how long message should be visible for reading).
  ///
  /// Formula: word count × 300ms, clamped between 1500ms and 10000ms
  ///
  /// Examples:
  /// - Short messages (1-10 words): 1500-3000ms
  /// - Medium messages (10-20 words): 3000-6000ms
  /// - Long messages (20+ words): 6000-10000ms
  ///
  /// Returns milliseconds the message should be displayed for reading.
  static int calculateDisplayMs(String text) {
    if (text.isEmpty) return 1500; // Minimum for empty/image-only messages

    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    // ~300ms per word, min 1500ms, max 10000ms
    return (wordCount * 300).clamp(1500, 10000);
  }

  /// Calculate gap time (pause after message before next one appears).
  ///
  /// Based on message characteristics:
  /// - Questions: Longer pause (1500ms) for thinking time
  /// - Short messages (<50 chars): Quick transition (600ms)
  /// - Medium messages (50-120 chars): Standard pause (1000ms)
  /// - Long messages (>120 chars): Extended pause (1500ms)
  ///
  /// Returns milliseconds to pause after the message.
  static int calculateGapMs(String text) {
    // Questions need extra thinking time
    if (text.trimRight().endsWith('?')) return 1500;

    final length = text.length;
    if (length < 50) return 600;   // Quick transition for short messages
    if (length < 120) return 1000;  // Standard pause for medium messages
    return 1500;                    // Extended pause for long messages
  }

  /// Combined total: display time + gap time.
  ///
  /// This is the total time from when a message appears until the next
  /// message should appear. Includes both reading time and thinking pause.
  ///
  /// Returns total milliseconds before showing next message.
  static int calculateTotalMs(String text) {
    return calculateDisplayMs(text) + calculateGapMs(text);
  }
}
