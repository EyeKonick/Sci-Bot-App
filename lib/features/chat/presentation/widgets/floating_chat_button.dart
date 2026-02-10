import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_feedback.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../services/preferences/shared_prefs_service.dart';
import '../../data/providers/character_provider.dart';
import '../../data/services/aristotle_greeting_service.dart';
import '../../../lessons/data/providers/lesson_chat_provider.dart';
import 'messenger_chat_window.dart';

/// Floating Chat Button - Messenger Style
/// Draggable button that opens inline chat window with speech bubble tooltip
class FloatingChatButton extends ConsumerStatefulWidget {
  const FloatingChatButton({super.key});

  @override
  ConsumerState<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends ConsumerState<FloatingChatButton> with TickerProviderStateMixin {
  Offset _position = const Offset(300, 200);
  Offset? _closedPosition; // Stores position when chat is closed
  bool _hasNotification = false;
  bool _isDragging = false;
  bool _isChatOpen = false;
  bool _showSpeechBubble = true; // Show speech bubble greeting
  bool _isDisposed = false; // Phase 0: Guard against post-dispose timer creation

  // Phase 3/6: Character switch transition
  String? _previousCharacterId;
  bool _isCharacterTransitioning = false;
  bool _justSwitchedCharacter = false; // Phase 6: flag for handoff bubbles
  String? _switchedFromCharacterId; // Phase 6: track outgoing character
  late AnimationController _characterTransitionController;
  late Animation<double> _characterFadeAnimation;

  // Speech bubble message cycling
  int _currentBubbleIndex = 0;
  Timer? _bubbleCycleTimer;
  Timer? _idleTimer;
  int _bubbleCycleCount = 0; // Track how many full cycles we've shown

  // Bubble mode state machine
  BubbleMode? _lastBubbleMode;
  int _timerGeneration = 0; // Cancellation token for Future.delayed callbacks

  // Dynamic greeting: single idle bubble for display
  NarrationMessage? _currentIdleBubble;

  late AnimationController _snapAnimationController;
  late Animation<Offset> _snapAnimation;

  late AnimationController _openAnimationController;
  late Animation<double> _openAnimation;

  late AnimationController _speechBubbleController;
  late Animation<double> _speechBubbleAnimation;

  @override
  void initState() {
    super.initState();

    // Snap animation controller
    _snapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: _position,
    ).animate(CurvedAnimation(
      parent: _snapAnimationController,
      curve: Curves.elasticOut,
    ));

    // Open/close animation controller
    _openAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _openAnimation = CurvedAnimation(
      parent: _openAnimationController,
      curve: Curves.easeInOut,
    );

    // Speech bubble animation - Phase 5: 200ms subtle fade-in
    _speechBubbleController = AnimationController(
      duration: AppFeedback.bubbleFadeDuration,
      vsync: this,
    );
    _speechBubbleAnimation = CurvedAnimation(
      parent: _speechBubbleController,
      curve: Curves.easeIn,
    );

    // Phase 3: Character transition animation (500ms fade)
    _characterTransitionController = AnimationController(
      duration: AppFeedback.characterTransitionDuration,
      vsync: this,
    );
    _characterFadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _characterTransitionController, curve: Curves.easeInOut),
    );

    _loadPosition();

    // For Aristotle: don't show any bubbles until AI greeting is ready.
    // For other characters: show static bubbles after delay.
    final character = ref.read(activeCharacterProvider);
    if (character.id == 'aristotle') {
      // Only fetch AI greeting - bubbles show when it arrives
      _fetchAristotleGreeting();
    } else {
      final gen = _timerGeneration;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) return;
        _showNextBubble();
      });
    }
  }

  /// Cancel all bubble timers and invalidate in-flight Future.delayed callbacks
  void _cancelAllBubbleTimers() {
    _bubbleCycleTimer?.cancel();
    _bubbleCycleTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    _timerGeneration++; // All pending Future.delayed callbacks become no-ops
  }

  /// Fetch dynamic AI greeting for Aristotle's chathead bubbles.
  /// Waits for AI response, then starts the bubble display cycle.
  /// No static bubbles are shown before this completes.
  Future<void> _fetchAristotleGreeting() async {
    final character = ref.read(activeCharacterProvider);
    if (character.id != 'aristotle') return;

    final gen = _timerGeneration;
    final service = AristotleGreetingService();
    final isFirstLaunch = SharedPrefsService.isFirstLaunch;
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : (hour < 18 ? 'afternoon' : 'evening');
    final prevContext = ref.read(previousContextProvider);
    final lastTopic = prevContext?.currentTopicId;

    await service.generateGreeting(
      isFirstLaunch: isFirstLaunch,
      timeOfDay: timeOfDay,
      lastTopicExplored: lastTopic,
    );

    // Mark first launch complete after first greeting generated
    if (isFirstLaunch) {
      await SharedPrefsService.setFirstLaunchComplete();
    }

    // Only show bubbles if we haven't been cancelled/disposed
    if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) return;

    // Cancel any existing timers before starting fresh
    _cancelAllBubbleTimers();

    setState(() {
      _currentBubbleIndex = 0;
      _bubbleCycleCount = 0;
      _currentIdleBubble = null;
    });

    // Small delay before first bubble appears (feels natural)
    final gen2 = _timerGeneration;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (gen2 != _timerGeneration || _isDisposed || !mounted || _isChatOpen) return;
      _showNextBubble();
    });
  }

  /// Handle bubble mode transitions. Called from build() when mode changes.
  void _handleBubbleModeTransition(BubbleMode mode) {
    if (mode == _lastBubbleMode) return;
    _lastBubbleMode = mode;

    _cancelAllBubbleTimers();
    _speechBubbleController.stop();

    // Use post-frame callback since this is triggered during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !mounted) return;

      switch (mode) {
        case BubbleMode.greeting:
          // Restart greeting cycle from scratch
          setState(() {
            _currentBubbleIndex = 0;
            _bubbleCycleCount = 0;
            _showSpeechBubble = false;
            _currentIdleBubble = null;
          });
          final character = ref.read(activeCharacterProvider);
          if (character.id == 'aristotle') {
            // For Aristotle: fetch fresh AI greeting
            AristotleGreetingService().invalidateCache();
            _fetchAristotleGreeting();
          } else {
            // For experts: show static bubbles after delay
            final gen = _timerGeneration;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) return;
              _showNextBubble();
            });
          }

        case BubbleMode.waitingForNarrative:
          // Immediately hide everything — no greetings, no narrative yet
          _speechBubbleController.reverse();
          setState(() => _showSpeechBubble = false);

        case BubbleMode.narrative:
          // Narrative started — show first message
          setState(() {
            _currentBubbleIndex = 0;
            _showSpeechBubble = false;
          });
          final gen = _timerGeneration;
          Future.delayed(const Duration(milliseconds: 200), () {
            if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) return;
            _showNextBubble();
          });
      }
    });
  }

  /// Get contextual speech bubble messages for the current character.
  ///
  /// Returns [NarrationMessage] list to enforce that only narration-channel
  /// content appears in speech bubbles. Questions and evaluative content
  /// must use the interaction channel (main chat) instead.
  List<NarrationMessage> _getBubbleMessages() {
    // Check bubble mode — use ref.read (NOT ref.watch) to prevent rebuilds
    // on every narrative sub-state change (e.g., nextMessage index advances)
    final mode = ref.read(bubbleModeProvider);
    if (mode == BubbleMode.narrative) {
      final narrativeState = ref.read(lessonNarrativeBubbleProvider);
      if (narrativeState.isActive && narrativeState.messages.isNotEmpty) {
        return narrativeState.messages;
      }
    }

    // Otherwise, build contextual greetings as NarrationMessages
    final character = ref.read(activeCharacterProvider);
    final prevContext = ref.read(previousContextProvider);
    final previousCharacter = prevContext?.currentTopicId != null
        ? AiCharacter.getCharacterForTopic(prevContext!.currentTopicId!)
        : null;

    // Check if user just came from a lesson/module in the same topic
    final wasInLesson = prevContext?.currentLessonId != null;
    final sameCharacter = previousCharacter?.id == character.id;

    // Phase 6: Determine outgoing character for handoff messages
    final switchedFrom = _switchedFromCharacterId != null
        ? AiCharacter.getCharacterById(_switchedFromCharacterId)
        : null;
    final isHandoff = _justSwitchedCharacter && switchedFrom != null;

    // Helper to wrap greeting strings as NarrationMessages with semantic splitting
    List<NarrationMessage> narrate(List<String> texts, {PacingHint pacing = PacingHint.normal}) {
      final messages = texts.map((t) => NarrationMessage(
        content: t,
        characterId: character.id,
        pacingHint: pacing,
      )).toList();
      // Phase 5: Split long messages at sentence boundaries
      return NarrationMessage.semanticSplit(messages);
    }

    // Phase 6: Character handoff sequence
    // When a character switch just happened, show structured introduction
    if (isHandoff) {
      // Clear the flag after building handoff messages (consumed once)
      _justSwitchedCharacter = false;

      if (character.id == 'aristotle') {
        // Invalidate cache and fetch fresh AI greeting for return context
        AristotleGreetingService().invalidateCache();
        _fetchAristotleGreeting();
        // Return placeholder - actual bubbles will show when AI greeting arrives
        return narrate(['...']);
      } else {
        // Switching to a topic expert - introduction handoff
        return narrate([
          'Meet ${character.name}, your specialist in ${character.specialization.toLowerCase()}!',
          character.greeting,
          'Starting fresh conversation with ${character.name}.',
        ], pacing: PacingHint.normal);
      }
    }

    switch (character.id) {
      case 'aristotle':
        // ONLY show AI-generated greetings - no static text
        final service = AristotleGreetingService();
        if (service.hasGreeting) {
          return service.cachedGreeting!;
        }
        // AI greeting not ready yet - return single invisible placeholder
        // (bubbles won't show because _showNextBubble is not called until fetch completes)
        return narrate(['...']);

      case 'herophilus':
        if (wasInLesson && sameCharacter) {
          return narrate([
            'So, how was the lesson? Did it make sense?',
            'Learning about circulation can be tricky! Need any clarification?',
            'Ready to continue with another module? I\'m here if you need help!',
          ]);
        }
        if (previousCharacter != null && previousCharacter.id != 'herophilus') {
          return narrate([
            'Hello! Coming from ${previousCharacter.name}\'s class? Let\'s study circulation!',
            'Did you know the heart beats about 100,000 times a day? Let me tell you more!',
            'Tap me if you want to learn how blood flows through your body.',
          ]);
        }
        return narrate([
          'I\'m Herophilus, your guide to the circulatory system!',
          'Did you know your blood vessels could wrap around the Earth twice?',
          'Ask me anything about how your heart and lungs work together!',
        ]);

      case 'mendel':
        if (wasInLesson && sameCharacter) {
          return narrate([
            'How was the lesson? Genetics can be fascinating!',
            'Did everything make sense? I can clarify anything you found confusing.',
            'Ready to explore more? Pick another module or ask me questions!',
          ]);
        }
        if (previousCharacter != null && previousCharacter.id != 'mendel') {
          return narrate([
            'Welcome! Finished studying ${previousCharacter.specialization.toLowerCase()}? Now let\'s explore heredity!',
            'Ever wonder why you look like your parents? I can explain the science behind it!',
            'Tap me and let\'s discover how traits pass from one generation to the next.',
          ]);
        }
        return narrate([
          'Hello! I\'m Gregor Mendel, the father of genetics.',
          'Did you know I studied over 28,000 pea plants to discover inheritance patterns?',
          'Ask me about dominant traits, Punnett squares, or anything about heredity!',
        ]);

      case 'odum':
        if (wasInLesson && sameCharacter) {
          return narrate([
            'So, how did you find the lesson?',
            'Energy flow and ecosystems can be complex! Any questions?',
            'Ready for the next module? I\'m here to help!',
          ]);
        }
        if (previousCharacter != null && previousCharacter.id != 'odum') {
          return narrate([
            'Hi there! Coming from ${previousCharacter.name}\'s lesson? Perfect timing!',
            'Let me show you how energy flows through every living thing in an ecosystem.',
            'Tap me to learn about food chains, energy pyramids, and more!',
          ]);
        }
        return narrate([
          'I\'m Eugene Odum, your ecosystem expert!',
          'Everything in nature is connected through energy. Want to see how?',
          'Ask me about food chains, photosynthesis, or how ecosystems work!',
        ]);

      default:
        return narrate([
          'Hey! I\'m ${character.name}. Ask me anything.',
          'Tap on me to start a conversation about science!',
        ]);
    }
  }

  /// Show next speech bubble message with animation.
  /// Uses _timerGeneration to cancel stale callbacks from previous mode transitions.
  void _showNextBubble() {
    if (_isDisposed || !mounted || _isChatOpen || _isDragging) return;

    final gen = _timerGeneration;
    final mode = ref.read(bubbleModeProvider);
    final messages = _getBubbleMessages();

    // Narrative mode: use narrative provider's index
    if (mode == BubbleMode.narrative) {
      final narrativeState = ref.read(lessonNarrativeBubbleProvider);
      final currentIndex = narrativeState.currentIndex;
      debugPrint('💬 _showNextBubble: Narrative mode, index $currentIndex of ${messages.length}');

      if (currentIndex >= messages.length) {
        debugPrint('💬 Narrative finished - hiding bubble');
        _speechBubbleController.reverse().then((_) {
          if (!_isDisposed && mounted) {
            setState(() => _showSpeechBubble = false);
          }
        });
        return;
      }

      if (messages.isNotEmpty && currentIndex < messages.length) {
        final msgContent = messages[currentIndex].content;
        final messagePreview = msgContent.substring(0, msgContent.length.clamp(0, 40));
        debugPrint('💬 Displaying: "$messagePreview..."');
      }

      setState(() {
        _showSpeechBubble = true;
        _currentBubbleIndex = currentIndex;
      });

      _speechBubbleController.forward(from: 0.0);

      _bubbleCycleTimer?.cancel();

      // Don't auto-advance past last message
      if (currentIndex >= messages.length - 1) return;

      // Phase 5: Variable display timing based on message content
      final currentMsg = messages[currentIndex];
      final displayDuration = Duration(milliseconds: currentMsg.displayMs);
      _bubbleCycleTimer = Timer(displayDuration, () {
        if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) return;
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) return;
          ref.read(lessonNarrativeBubbleProvider.notifier).nextMessage();
          final gapDuration = Duration(milliseconds: currentMsg.gapMs);
          Future.delayed(gapDuration, () {
            if (gen != _timerGeneration || _isDisposed || !mounted) return;
            _showNextBubble();
          });
        });
      });
    } else if (mode == BubbleMode.greeting) {
      // Greeting cycling logic
      if (_currentBubbleIndex >= messages.length) {
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || gen != _timerGeneration) return;
          setState(() => _showSpeechBubble = false);
          _bubbleCycleCount++;
          // Aristotle: show greeting once, then switch to idle AI bubbles
          // Other characters: allow up to 3 cycles of static greetings
          final character = ref.read(activeCharacterProvider);
          final maxCycles = character.id == 'aristotle' ? 1 : 3;
          if (_bubbleCycleCount < maxCycles) {
            _startIdleTimer();
          }
        });
        return;
      }

      setState(() => _showSpeechBubble = true);

      _speechBubbleController.forward(from: 0.0);

      _bubbleCycleTimer?.cancel();
      final currentMsg = messages[_currentBubbleIndex.clamp(0, messages.length - 1)];
      final displayDuration = Duration(milliseconds: currentMsg.displayMs);
      _bubbleCycleTimer = Timer(displayDuration, () {
        if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) return;
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) return;
          final gapDuration = Duration(milliseconds: currentMsg.gapMs);
          setState(() => _currentBubbleIndex++);
          Future.delayed(gapDuration, () {
            if (gen != _timerGeneration || _isDisposed || !mounted) return;
            _showNextBubble();
          });
        });
      });
    }
    // BubbleMode.waitingForNarrative: do nothing (bubbles suppressed)
  }

  /// Start idle timer - after period of inactivity, show bubbles again.
  /// For Aristotle: fetches a dynamic AI-generated idle bubble.
  /// For experts: restarts the static greeting cycle.
  void _startIdleTimer() {
    if (_isDisposed) return;
    _idleTimer?.cancel();
    final gen = _timerGeneration;
    // Randomize idle interval between 30-60 seconds
    final idleSeconds = 30 + (DateTime.now().second % 31);
    _idleTimer = Timer(Duration(seconds: idleSeconds), () async {
      if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen || _showSpeechBubble) return;

      final character = ref.read(activeCharacterProvider);
      if (character.id == 'aristotle') {
        // Fetch AI-generated idle bubble for Aristotle
        final bubble = await AristotleGreetingService().generateIdleBubble();
        if (bubble != null && mounted && !_isDisposed && gen == _timerGeneration && !_isChatOpen) {
          _currentIdleBubble = bubble;
          setState(() {
            _currentBubbleIndex = 0;
            _showSpeechBubble = true;
          });
          _speechBubbleController.forward(from: 0.0);
          // Auto-hide after display duration
          _bubbleCycleTimer?.cancel();
          _bubbleCycleTimer = Timer(Duration(milliseconds: bubble.displayMs), () {
            if (_isDisposed || !mounted || gen != _timerGeneration) return;
            _speechBubbleController.reverse().then((_) {
              if (_isDisposed || !mounted) return;
              setState(() => _showSpeechBubble = false);
              _currentIdleBubble = null;
              _bubbleCycleCount++;
              if (_bubbleCycleCount < 5) _startIdleTimer();
            });
          });
        }
      } else {
        // Non-Aristotle: existing behavior - restart greeting cycle
        setState(() {
          _currentBubbleIndex = 0;
        });
        _showNextBubble();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true; // Phase 0: Prevent post-dispose timer creation
    _cancelAllBubbleTimers();
    _snapAnimationController.dispose();
    _openAnimationController.dispose();
    _speechBubbleController.dispose();
    _characterTransitionController.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    // Always start at the default initial position when app opens
    const defaultPosition = Offset(300, 200);
    setState(() {
      _position = defaultPosition;
      _closedPosition = defaultPosition;
    });
  }

  void _savePosition(Offset position) {
    // Position is only kept in memory for current session
    // Chathead always returns to default position on app restart
  }

  /// Snap to nearest edge with animation
  void _snapToEdge(Offset dragEndPosition, Size screenSize) {
    const buttonSize = 70.0;
    const edgePadding = 16.0;
    
    final screenCenter = screenSize.width / 2;
    final isLeftSide = dragEndPosition.dx < screenCenter;
    
    final snapX = isLeftSide 
        ? edgePadding
        : screenSize.width - buttonSize - edgePadding;
    
    final minY = MediaQuery.of(context).padding.top + edgePadding;
    final maxY = screenSize.height - buttonSize - MediaQuery.of(context).padding.bottom - edgePadding;
    final snapY = dragEndPosition.dy.clamp(minY, maxY);
    
    final snapPosition = Offset(snapX, snapY);
    
    _snapAnimation = Tween<Offset>(
      begin: dragEndPosition,
      end: snapPosition,
    ).animate(CurvedAnimation(
      parent: _snapAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _snapAnimationController.forward(from: 0.0).then((_) {
      setState(() {
        _position = snapPosition;
        _closedPosition = snapPosition;
      });
      _savePosition(snapPosition);
    });
  }

  /// Open chat window - move bubble to top-right
  /// ✅ ONLY works for Aristotle - experts use inline chat only
  void _openChat() {
    if (_isDragging || _isChatOpen) return;

    // ✅ FIX: Only allow messenger popup for Aristotle
    final character = ref.read(activeCharacterProvider);
    if (character.id != 'aristotle') {
      // For experts, just hide bubble and do nothing
      // (Expert guidance happens inline in modules)
      setState(() {
        _showSpeechBubble = false;
      });
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    const buttonSize = 70.0;
    const topPadding = 16.0;
    const rightPadding = 16.0;

    // Save current position as closed position
    _closedPosition = _position;

    // Calculate top-right position
    final topRightPosition = Offset(
      screenSize.width - buttonSize - rightPadding,
      MediaQuery.of(context).padding.top + topPadding,
    );

    // Animate bubble to top-right
    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: topRightPosition,
    ).animate(CurvedAnimation(
      parent: _snapAnimationController,
      curve: Curves.easeInOut,
    ));

    // Cancel speech bubble timers
    _bubbleCycleTimer?.cancel();
    _idleTimer?.cancel();

    setState(() {
      _isChatOpen = true;
      _showSpeechBubble = false;
    });

    _snapAnimationController.forward(from: 0.0).then((_) {
      setState(() {
        _position = topRightPosition;
      });
    });

    // Animate chat window open
    _openAnimationController.forward();
  }

  /// Close chat window - return bubble to original position
  void _closeChat() {
    if (!_isChatOpen) return;

    // Animate chat window close
    _openAnimationController.reverse().then((_) {
      setState(() {
        _isChatOpen = false;
      });
      // Restart idle timer so bubble reappears after inactivity
      if (_bubbleCycleCount < 3) {
        setState(() {
          _currentBubbleIndex = 0;
        });
        _startIdleTimer();
      }
    });
    
    // Animate bubble back to closed position
    if (_closedPosition != null) {
      _snapAnimation = Tween<Offset>(
        begin: _position,
        end: _closedPosition!,
      ).animate(CurvedAnimation(
        parent: _snapAnimationController,
        curve: Curves.easeInOut,
      ));
      
      _snapAnimationController.forward(from: 0.0).then((_) {
        setState(() {
          _position = _closedPosition!;
        });
      });
    }
  }

  /// Toggle chat open/close
  void _toggleChat() {
    if (_isDragging) return;
    
    if (_isChatOpen) {
      _closeChat();
    } else {
      _openChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Watch bubble mode in build() for reliable provider subscription.
    // Handle mode transitions (greeting ↔ narrative ↔ waitingForNarrative).
    final bubbleMode = ref.watch(bubbleModeProvider);
    _handleBubbleModeTransition(bubbleMode);

    // Phase 6: Detect character switch and trigger 800ms visual bridge with handoff bubbles
    final currentCharacter = ref.watch(activeCharacterProvider);
    if (_previousCharacterId != null &&
        _previousCharacterId != currentCharacter.id &&
        !_isCharacterTransitioning) {
      _isCharacterTransitioning = true;
      _switchedFromCharacterId = _previousCharacterId;

      // Cancel any ongoing bubble animations during transition
      _bubbleCycleTimer?.cancel();
      _idleTimer?.cancel();
      _speechBubbleController.reverse();
      _showSpeechBubble = false;

      // Fade out → pause → fade in transition (800ms)
      _characterFadeAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: ConstantTween(0.0),
          weight: 20,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
      ]).animate(_characterTransitionController);

      _characterTransitionController.forward(from: 0.0).then((_) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isCharacterTransitioning = false;
            _justSwitchedCharacter = true;
            _currentBubbleIndex = 0;
            _bubbleCycleCount = 0;
          });
          // Show handoff bubbles after transition completes
          if (!_isChatOpen) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!_isDisposed && mounted && !_isChatOpen) {
                _showNextBubble();
              }
            });
          }
        }
      });
    }
    _previousCharacterId = currentCharacter.id;

    return Stack(
      children: [
        // Chat Window
        if (_isChatOpen)
          AnimatedBuilder(
            animation: _openAnimation,
            builder: (context, child) {
              final bubbleBottom = MediaQuery.of(context).padding.top + 16 + 70;
              final chatWindowTop = bubbleBottom + 8;

              return Positioned(
                top: chatWindowTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: Transform.scale(
                  scale: _openAnimation.value,
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: _openAnimation.value,
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 35),
                          child: CustomPaint(
                            size: const Size(20, 10),
                            painter: _TrianglePainter(
                              color: ref.watch(activeCharacterProvider).themeColor,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: MessengerChatWindow(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        // Speech Bubble Tooltip (when chat is closed)
        if (_showSpeechBubble && !_isChatOpen && !_isDragging)
          AnimatedBuilder(
            animation: _speechBubbleAnimation,
            builder: (context, child) {
              final currentPos = _isDragging ? _position : _snapAnimation.value;
              final isOnRight = currentPos.dx > screenSize.width / 2;
              const buttonSize = 70.0;

              return Positioned(
                top: currentPos.dy + 8,
                left: isOnRight ? null : currentPos.dx + buttonSize + 4,
                right: isOnRight ? screenSize.width - currentPos.dx + 4 : null,
                // Phase 5: Subtle fade-in only (no scale transform)
                child: Opacity(
                  opacity: _speechBubbleAnimation.value.clamp(0.0, 1.0),
                  child: _buildSpeechBubble(isOnRight),
                ),
              );
            },
          ),

        // Floating Button
        AnimatedBuilder(
          animation: _snapAnimation,
          builder: (context, child) {
            final currentPosition = _isDragging ? _position : _snapAnimation.value;

            return Positioned(
              left: currentPosition.dx,
              top: currentPosition.dy,
              child: Draggable(
                feedback: _buildButton(isDragging: true),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildButton(),
                ),
                onDragStarted: () {
                  setState(() {
                    _isDragging = true;
                    _showSpeechBubble = false;
                  });
                },
                onDragEnd: (details) {
                  setState(() {
                    _isDragging = false;
                    _position = details.offset;
                  });

                  if (!_isChatOpen) {
                    _snapToEdge(details.offset, MediaQuery.of(context).size);
                  }
                },
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSpeechBubble = false;
                    });
                    _toggleChat();
                  },
                  child: _buildButton(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build speech bubble tooltip next to the FAB
  Widget _buildSpeechBubble(bool isOnRight) {
    final character = ref.watch(activeCharacterProvider);
    // Use idle bubble if available, otherwise use greeting cycle messages
    final String currentMessage;
    if (_currentIdleBubble != null) {
      currentMessage = _currentIdleBubble!.content;
    } else {
      final messages = _getBubbleMessages();
      final safeIndex = _currentBubbleIndex.clamp(0, messages.length - 1);
      currentMessage = messages[safeIndex].content;
    }

    return GestureDetector(
      onTap: () {
        _bubbleCycleTimer?.cancel();
        _idleTimer?.cancel();
        setState(() {
          _showSpeechBubble = false;
        });
        _toggleChat();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.s12,
          vertical: AppSizes.s8,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(
            color: character.themeColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          currentMessage,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.grey900,
            fontWeight: FontWeight.w500,
            height: 1.3,
            backgroundColor: Colors.transparent,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildButton({bool isDragging = false}) {
    final size = isDragging ? 78.0 : 70.0;

    // Get current character from provider
    final character = ref.watch(activeCharacterProvider);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Character avatar with Phase 3 fade transition
          Center(
            child: AnimatedBuilder(
              animation: _characterFadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _isCharacterTransitioning
                      ? _characterFadeAnimation.value.clamp(0.0, 1.0)
                      : 1.0,
                  child: child,
                );
              },
              child: ClipOval(
                child: Image.asset(
                  character.avatarAsset,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: size,
                      height: size,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        size: 36,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Notification badge
          if (_hasNotification && !isDragging && !_isChatOpen)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFFB800)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Breathing animation
          if (!isDragging && !_isChatOpen)
            Positioned.fill(
              child: _BreathingAnimation(),
            ),
        ],
      ),
    );
  }

  void showNotification() {
    setState(() {
      _hasNotification = true;
    });
  }

  void clearNotification() {
    setState(() {
      _hasNotification = false;
    });
  }
}

class _BreathingRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BreathingRingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * (0.9 + (progress * 0.1));
    final opacity = 1.0 - progress;

    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BreathingRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _BreathingAnimation extends StatefulWidget {
  const _BreathingAnimation();

  @override
  State<_BreathingAnimation> createState() => _BreathingAnimationState();
}

class _BreathingAnimationState extends State<_BreathingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _BreathingRingPainter(
            progress: _animation.value,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => false;
}