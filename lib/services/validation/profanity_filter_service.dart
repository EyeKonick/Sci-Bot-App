/// Profanity filter and name validation service
/// Validates student names for appropriate content (Grade 9 Filipino students)
class ProfanityFilterService {
  ProfanityFilterService._();

  // English profanity and inappropriate words
  static final _englishBadWords = <String>[
    'damn', 'hell', 'crap', 'shit', 'fuck', 'bitch', 'ass', 'bastard',
    'dick', 'cock', 'pussy', 'penis', 'vagina', 'sex', 'porn', 'nude',
    'rape', 'slut', 'whore', 'fag', 'nigger', 'retard', 'idiot', 'stupid',
    'dumb', 'kill', 'die', 'death', 'suicide', 'drug', 'weed', 'cocaine',
  ];

  // Filipino/Tagalog profanity and inappropriate words
  static final _filipinoBadWords = <String>[
    'gago', 'tanga', 'tarantado', 'putang', 'puta', 'tangina', 'puta',
    'bobo', 'ulol', 'inutil', 'hayop', 'peste', 'leche', 'yawa',
    'hudas', 'kupal', 'tamod', 'kantot', 'jakol', 'titi', 'puke',
    'bilat', 'burat', 'pakyu', 'animal', 'ungas', 'hinayupak',
  ];

  // Sexual content terms (both languages)
  static final _sexualTerms = <String>[
    'sex', 'sexy', 'porn', 'nude', 'naked', 'breast', 'boobs', 'tits',
    'penis', 'vagina', 'dick', 'cock', 'pussy', 'fuck', 'rape', 'kantot',
    'jakol', 'titi', 'puke', 'bilat', 'burat', 'tamod',
  ];

  /// Validate name for all requirements
  /// Returns ValidationResult with isValid flag and error message
  static ValidationResult validateName(String name) {
    final trimmed = name.trim();

    // Check if empty
    if (trimmed.isEmpty) {
      return const ValidationResult.invalid('Please enter your name');
    }

    // Check minimum length
    if (trimmed.length < 2) {
      return const ValidationResult.invalid('Name must be at least 2 characters');
    }

    // Check maximum length
    if (trimmed.length > 20) {
      return const ValidationResult.invalid('Name must be 20 characters or less');
    }

    // Check character set (letters, spaces, hyphens, Filipino chars)
    final validPattern = RegExp(r'^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-]+$');
    if (!validPattern.hasMatch(trimmed)) {
      return const ValidationResult.invalid(
        'Name can only contain letters, spaces, and hyphens'
      );
    }

    // Check for profanity and inappropriate content
    if (containsProfanity(trimmed)) {
      return const ValidationResult.invalid(
        'Please choose an appropriate name'
      );
    }

    return const ValidationResult.valid();
  }

  /// Check if text contains profanity or inappropriate words
  /// Uses word boundary detection to avoid false positives
  static bool containsProfanity(String text) {
    final lower = text.toLowerCase();

    // Combine all bad word lists
    final allBadWords = <String>[
      ..._englishBadWords,
      ..._filipinoBadWords,
      ..._sexualTerms,
    ];

    // Check against word lists
    for (final word in allBadWords) {
      // Use word boundary regex to match whole words only
      // This prevents false positives like "Cassandra" matching "ass"
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b',
          caseSensitive: false);
      if (pattern.hasMatch(lower)) return true;

      // Check with common substitutions (l33t speak)
      final normalized = _normalizeText(lower);
      if (pattern.hasMatch(normalized)) return true;
    }

    return false;
  }

  /// Normalize text by replacing common character substitutions
  /// Handles l33t speak: @ → a, 3 → e, 0 → o, etc.
  static String _normalizeText(String text) {
    return text
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('8', 'b')
        .replaceAll('@', 'a')
        .replaceAll('\$', 's')
        .replaceAll('!', 'i');
  }

  /// Check if name is appropriate for Grade 9 students
  /// Combines length, character, and content validation
  static bool isAppropriate(String name) {
    return validateName(name).isValid;
  }
}

/// Validation result with success flag and optional error message
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}
