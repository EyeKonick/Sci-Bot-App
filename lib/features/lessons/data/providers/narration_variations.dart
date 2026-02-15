import 'dart:math';

/// Centralized narration variations for dynamic, context-aware messaging.
///
/// All variations are hard-coded for offline-first operation.
/// Random selection provides natural variety without AI generation.
class NarrationVariations {
  static final _random = Random();

  /// TOPIC 1, LESSON 1, MODULE 1: Fa-SCI-nate
  static const List<String> _fascinateCompletions = [
    'Wow! You\'ve completed Fa-SCI-nate! Isn\'t science amazing?',
    'That was fascinating, right? Fa-SCI-nate complete!',
    'Your curiosity is amazing! Fa-SCI-nate finished!',
    'Science is incredible! You\'ve completed Fa-SCI-nate!',
    'Fa-SCI-nated yet? Module complete!',
    'Great job! Fa-SCI-nate is done!',
    'Excellent work! You\'ve finished Fa-SCI-nate!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 2: Goal SCI-tting
  static const List<String> _goalCompletions = [
    'Perfect! You\'ve set your learning goals!',
    'Great! You know where you\'re headed now!',
    'Excellent! Your learning destination is clear!',
    'Goal SCI-tting complete! Let\'s achieve those goals!',
    'You\'re ready to learn! Goals are set!',
    'Wonderful! Your learning path is clear!',
    'Well done! You know what you\'re aiming for!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 3: Pre-SCI-ntation
  static const List<String> _presentationCompletions = [
    'Great! You\'ve completed Pre-SCI-ntation!',
    'Excellent! Pre-SCI-ntation is done!',
    'Well done! You\'ve finished Pre-SCI-ntation!',
    'Perfect! Pre-SCI-ntation complete!',
    'Wonderful! You\'ve completed Pre-SCI-ntation!',
    'Great job! Pre-SCI-ntation finished!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 4: Inve-SCI-tigation
  static const List<String> _investigationCompletions = [
    'Amazing work, investigator! Inve-SCI-tigation complete!',
    'You\'ve uncovered the science! Investigation done!',
    'Excellent detective work! Module complete!',
    'You explored like a true scientist! Well done!',
    'Investigation complete! You\'re a natural explorer!',
    'Brilliant investigative work! Module finished!',
    'You\'ve discovered so much! Investigation complete!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 5: Self-A-SCI-ssment
  static const List<String> _assessmentCompletions = [
    'You\'re SCI-mazing! Assessment complete!',
    'Well done! You\'ve shown your understanding!',
    'Excellent! You\'ve proven your knowledge!',
    'Great job! Assessment finished!',
    'You did it! Self-A-SCI-ssment complete!',
    'Fantastic! You\'ve shown what you know!',
    'Wonderful! Assessment complete!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 6: SCI-pplementary
  static const List<String> _supplementaryCompletions = [
    'Great! You\'ve completed SCI-pplementary!',
    'Excellent! SCI-pplementary is done!',
    'Well done! You\'ve finished SCI-pplementary!',
    'Perfect! SCI-pplementary complete!',
    'Wonderful! You\'ve completed SCI-pplementary!',
    'Great job! SCI-pplementary finished!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 1: Fa-SCI-nate Welcomes
  static const List<String> _fascinateWelcomes = [
    'Welcome to Fa-SCI-nate! Get ready to be amazed!',
    'Let\'s get Fa-SCI-nated! Science is incredible!',
    'Welcome to Fa-SCI-nate! Prepare to be curious!',
    'Ready to explore? Welcome to Fa-SCI-nate!',
    'Let\'s discover something amazing! Welcome to Fa-SCI-nate!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 2: Goal SCI-tting Welcomes
  static const List<String> _goalWelcomes = [
    'Welcome to Goal SCI-tting! Let\'s set our learning targets!',
    'Time to set your goals! Welcome to Goal SCI-tting!',
    'Ready to aim high? Welcome to Goal SCI-tting!',
    'Let\'s plan your learning journey! Welcome to Goal SCI-tting!',
    'Let\'s chart your course! Welcome to Goal SCI-tting!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 3: Pre-SCI-ntation Welcomes
  static const List<String> _presentationWelcomes = [
    'Welcome to Pre-SCI-ntation!',
    'Let\'s learn something new! Welcome to Pre-SCI-ntation!',
    'Ready to discover? Welcome to Pre-SCI-ntation!',
    'Time to explore! Welcome to Pre-SCI-ntation!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 4: Inve-SCI-tigation Welcomes
  static const List<String> _investigationWelcomes = [
    'Welcome to Inve-SCI-tigation! Time to explore!',
    'Ready to investigate? Let\'s discover science!',
    'Welcome, investigator! Time to dig deeper!',
    'Let\'s uncover the science! Welcome to Inve-SCI-tigation!',
    'Time to explore like a scientist! Welcome to Inve-SCI-tigation!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 5: Self-A-SCI-ssment Welcomes
  static const List<String> _assessmentWelcomes = [
    'Welcome to Self-A-SCI-ssment! Let\'s check your understanding!',
    'Time to test your knowledge! Don\'t worry, you\'ve got this!',
    'Welcome to Self-A-SCI-ssment! Show what you\'ve learned!',
    'Ready to prove your skills? Welcome to Self-A-SCI-ssment!',
    'Let\'s see what you know! Welcome to Self-A-SCI-ssment!',
  ];

  /// TOPIC 1, LESSON 1, MODULE 6: SCI-pplementary Welcomes
  static const List<String> _supplementaryWelcomes = [
    'Welcome to SCI-pplementary!',
    'Time to learn more! Welcome to SCI-pplementary!',
    'Ready for extra science? Welcome to SCI-pplementary!',
    'Let\'s explore more! Welcome to SCI-pplementary!',
  ];

  /// -------------------------------------------------------------------------
  /// TRANSITION PHRASES
  /// -------------------------------------------------------------------------

  static const List<String> _transitionPhrases = [
    'Ready for the next one?',
    'Let\'s keep going!',
    'Here comes another question!',
    'Moving forward!',
    'Next question coming up!',
    'Let\'s explore more!',
    'Onward!',
    'Ready to continue?',
    'Let\'s keep learning!',
    'Next up!',
  ];

  /// -------------------------------------------------------------------------
  /// ENCOURAGEMENT VARIATIONS
  /// -------------------------------------------------------------------------

  static const List<String> _correctEncouragement = [
    'Excellent!',
    'Perfect!',
    'You got it!',
    'Spot on!',
    'Absolutely right!',
    'That\'s correct!',
    'Well done!',
    'Fantastic!',
    'You nailed it!',
    'Brilliant!',
  ];

  static const List<String> _partialEncouragement = [
    'You\'re on the right track!',
    'Almost there!',
    'Good thinking, but...',
    'Not quite, but close!',
    'You\'re close!',
    'Good effort! Let me clarify...',
    'You\'re getting there!',
  ];

  static const List<String> _wrongEncouragement = [
    'Let\'s try again!',
    'Think about it this way...',
    'Give it another shot!',
    'Let me help you...',
    'Let\'s work through this...',
    'Here\'s a hint...',
    'Don\'t worry, let\'s review...',
  ];

  /// -------------------------------------------------------------------------
  /// MAX ATTEMPTS ENCOURAGEMENT
  /// -------------------------------------------------------------------------

  static const List<String> _maxAttemptsEncouragement = [
    'That was a tough question! Let\'s move forward—you\'re doing great!',
    'This one was tricky! Don\'t worry, let\'s continue!',
    'That was challenging! You\'re learning so much!',
    'Good effort! Let\'s keep going—every attempt helps you learn!',
    'That was a hard one! Moving on, you\'re doing well!',
    'Tough question! Let\'s proceed—you\'re making progress!',
  ];

  /// -------------------------------------------------------------------------
  /// TOPIC-SPECIFIC ENCOURAGEMENT
  /// -------------------------------------------------------------------------

  static const Map<String, List<String>> _topicEncouragement = {
    'body_systems': [
      'You understand circulation!',
      'You\'ve got the heart of it!',
      'You know your anatomy!',
      'Your body systems knowledge is strong!',
      'You understand how blood flows!',
      'You know how your body works!',
    ],
    'heredity': [
      'You understand heredity!',
      'You\'ve got genetics down!',
      'You know your Punnett squares!',
      'Your genetics knowledge is strong!',
      'You understand inheritance!',
      'You know how traits are passed!',
    ],
    'energy': [
      'You understand ecosystems!',
      'You\'ve got energy flow down!',
      'You know how energy works!',
      'Your ecosystem knowledge is strong!',
      'You understand the food chain!',
      'You know how energy flows!',
    ],
  };

  /// -------------------------------------------------------------------------
  /// PUBLIC API
  /// -------------------------------------------------------------------------

  /// Get a random module completion message based on module type
  static String getModuleCompletion({
    required String moduleType,
    String? moduleName,
  }) {
    final lowerType = moduleType.toLowerCase();
    List<String> variations;

    if (lowerType.contains('fascinate')) {
      variations = _fascinateCompletions;
    } else if (lowerType.contains('goal')) {
      variations = _goalCompletions;
    } else if (lowerType.contains('presentation') || lowerType.contains('prescintation')) {
      variations = _presentationCompletions;
    } else if (lowerType.contains('investigation') || lowerType.contains('invescitigation')) {
      variations = _investigationCompletions;
    } else if (lowerType.contains('assessment') || lowerType.contains('ascissment')) {
      variations = _assessmentCompletions;
    } else if (lowerType.contains('supplementary') || lowerType.contains('scipplementary')) {
      variations = _supplementaryCompletions;
    } else {
      variations = ['Great work! Module complete!'];
    }

    return variations[_random.nextInt(variations.length)];
  }

  /// Get random module welcome based on module type
  static String getModuleWelcome(String moduleType) {
    final lowerType = moduleType.toLowerCase();
    List<String> variations;

    if (lowerType.contains('fascinate')) {
      variations = _fascinateWelcomes;
    } else if (lowerType.contains('goal')) {
      variations = _goalWelcomes;
    } else if (lowerType.contains('presentation') || lowerType.contains('prescintation')) {
      variations = _presentationWelcomes;
    } else if (lowerType.contains('investigation') || lowerType.contains('invescitigation')) {
      variations = _investigationWelcomes;
    } else if (lowerType.contains('assessment') || lowerType.contains('ascissment')) {
      variations = _assessmentWelcomes;
    } else if (lowerType.contains('supplementary') || lowerType.contains('scipplementary')) {
      variations = _supplementaryWelcomes;
    } else {
      variations = ['Welcome! Let\'s begin!'];
    }

    return variations[_random.nextInt(variations.length)];
  }

  /// Get a random transition phrase
  static String getTransition() {
    return _transitionPhrases[_random.nextInt(_transitionPhrases.length)];
  }

  /// Get random encouragement based on answer correctness
  static String getEncouragement(String correctnessLevel) {
    final lower = correctnessLevel.toLowerCase();
    List<String> variations;

    if (lower.contains('correct') && !lower.contains('partial')) {
      variations = _correctEncouragement;
    } else if (lower.contains('partial')) {
      variations = _partialEncouragement;
    } else {
      variations = _wrongEncouragement;
    }

    return variations[_random.nextInt(variations.length)];
  }

  /// Get random max attempts encouragement
  static String getMaxAttemptsEncouragement() {
    return _maxAttemptsEncouragement[_random.nextInt(_maxAttemptsEncouragement.length)];
  }

  /// Get topic-specific encouragement for correct answers
  static String getTopicEncouragement({
    required String topicId,
    required bool isCorrect,
  }) {
    if (!isCorrect) return getEncouragement('wrong');

    // Map topic IDs to topic keys
    final topicKey = topicId == '1' || topicId.contains('body') || topicId.contains('circulation')
        ? 'body_systems'
        : topicId == '2' || topicId.contains('heredity') || topicId.contains('genetics')
            ? 'heredity'
            : topicId == '3' || topicId.contains('energy') || topicId.contains('ecosystem')
                ? 'energy'
                : null;

    if (topicKey != null && _topicEncouragement.containsKey(topicKey)) {
      final variations = _topicEncouragement[topicKey]!;
      return variations[_random.nextInt(variations.length)];
    }

    // Fallback to generic correct encouragement
    return _correctEncouragement[_random.nextInt(_correctEncouragement.length)];
  }
}
