import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_feedback.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../services/preferences/shared_prefs_service.dart';
import '../../../../shared/models/scenario_model.dart';
import '../../data/providers/character_provider.dart';
import '../../data/services/aristotle_greeting_service.dart';
import '../../data/services/expert_greeting_service.dart';
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
  bool _isGeneratingGreeting = false; // Show "Thinking..." while generating greeting

  // Bubble mode state machine
  BubbleMode? _lastBubbleMode;
  String? _lastScenarioId; // Track scenario to detect screen changes within same mode
  int _timerGeneration = 0; // Cancellation token for Future.delayed callbacks
  bool _lastNarrativeIsPaused = false; // Track pause state to detect resume

  // Dynamic greeting: single idle bubble for display
  NarrationMessage? _currentIdleBubble;

  // Drag interruption state - preserves bubble sequence
  int? _bubbleIndexWhenDragStarted;
  BubbleMode? _bubbleModeWhenDragStarted;
  List<NarrationMessage>? _messagesWhenDragStarted;

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
      curve: Curves.easeOutCubic,
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

    // For Aristotle: invalidate cached greeting and fetch fresh AI greeting.
    // For experts on lesson menu: fetch scenario-aware AI greeting.
    // For other contexts: show static bubbles after delay.
    final character = ref.read(activeCharacterProvider);
    final scenario = ref.read(currentScenarioProvider);
    if (character.id == 'aristotle') {
      // Always invalidate cache on init so every app launch gets fresh greetings
      AristotleGreetingService().invalidateCache();  // Clear all scenarios on app launch
      _fetchAristotleGreeting();
    } else if (scenario != null && scenario.type == ScenarioType.lessonMenu) {
      _fetchExpertGreeting();
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
  /// Shows "Thinking..." bubble while generating.
  Future<void> _fetchAristotleGreeting() async {
    final character = ref.read(activeCharacterProvider);
    if (character.id != 'aristotle') return;

    final gen = _timerGeneration;
    debugPrint('🤖 [ARISTOTLE] Starting greeting generation... (gen: $gen, _isGeneratingGreeting: $_isGeneratingGreeting)');

    // Show "Thinking..." bubble while generating
    setState(() {
      _isGeneratingGreeting = true;
      _showSpeechBubble = true;
    });
    _speechBubbleController.forward();
    debugPrint('🤖 [ARISTOTLE] Showing "Thinking..." bubble');

    final service = AristotleGreetingService();
    final scenario = ref.read(currentScenarioProvider);
    final scenarioId = scenario?.id ?? 'aristotle_general';
    final isFirstLaunch = SharedPrefsService.isFirstLaunch;
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : (hour < 18 ? 'afternoon' : 'evening');
    final prevContext = ref.read(previousContextProvider);
    final lastTopic = prevContext?.currentTopicId;

    debugPrint('🤖 [ARISTOTLE] Context - Scenario: $scenarioId, First Launch: $isFirstLaunch, Time: $timeOfDay, Last Topic: $lastTopic');

    final startTime = DateTime.now();
    await service.generateGreeting(
      scenarioId: scenarioId,
      generationToken: gen,
      isFirstLaunch: isFirstLaunch,
      timeOfDay: timeOfDay,
      lastTopicExplored: lastTopic,
    );
    final duration = DateTime.now().difference(startTime);
    debugPrint('🤖 [ARISTOTLE] Greeting generated in ${duration.inMilliseconds}ms');

    // Mark first launch complete after first greeting generated
    if (isFirstLaunch) {
      await SharedPrefsService.setFirstLaunchComplete();
      debugPrint('🤖 [ARISTOTLE] First launch marked complete');
    }

    // Only show bubbles if we haven't been cancelled/disposed
    if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) {
      debugPrint('🤖 [ARISTOTLE] ⚠️ Greeting cancelled (widget state changed)');
      setState(() => _isGeneratingGreeting = false);
      return;
    }

    // Stop showing "Thinking..." and hide bubble to prepare for smooth fade-in
    setState(() {
      _isGeneratingGreeting = false;
      _showSpeechBubble = false;  // Hide bubble so _showNextBubble can animate it in cleanly
    });
    debugPrint('🤖 [ARISTOTLE] ✅ Ready to display greeting bubbles');

    // Cancel any existing timers before starting fresh
    _cancelAllBubbleTimers();

    setState(() {
      _currentBubbleIndex = 0;
      _bubbleCycleCount = 0;
      _currentIdleBubble = null;
    });

    // Small delay before first bubble appears (feels natural)
    final gen2 = _timerGeneration;
    debugPrint('🤖 [ARISTOTLE] Scheduling bubble display in 500ms...');
    Future.delayed(const Duration(milliseconds: 500), () {
      if (gen2 != _timerGeneration || _isDisposed || !mounted || _isChatOpen) {
        debugPrint('🤖 [ARISTOTLE] ⚠️ Bubble display cancelled (gen2: $gen2, _timerGeneration: $_timerGeneration, disposed: $_isDisposed, mounted: $mounted, chatOpen: $_isChatOpen)');
        return;
      }
      debugPrint('🤖 [ARISTOTLE] Calling _showNextBubble() now...');
      _showNextBubble();
    });
  }

  /// Fetch dynamic AI greeting for an expert character's chathead bubbles.
  /// Uses ExpertGreetingService keyed by scenario ID.
  /// Shows "Thinking..." bubble while generating.
  Future<void> _fetchExpertGreeting() async {
    final scenario = ref.read(currentScenarioProvider);
    if (scenario == null || scenario.type != ScenarioType.lessonMenu) return;

    final character = ref.read(activeCharacterProvider);
    if (character.id == 'aristotle') return;

    final gen = _timerGeneration;
    debugPrint('🤖 [${character.name.toUpperCase()}] Starting greeting generation... (gen: $gen, _isGeneratingGreeting: $_isGeneratingGreeting)');

    // Show "Thinking..." bubble while generating
    setState(() {
      _isGeneratingGreeting = true;
      _showSpeechBubble = true;
    });
    _speechBubbleController.forward();

    final service = ExpertGreetingService();
    final topicId = scenario.context['topicId'] ?? '';

    // Derive a display-friendly topic name from the topicId
    final topicName = switch (topicId) {
      'topic_body_systems' => 'Body Systems',
      'topic_heredity' => 'Heredity',
      'topic_energy' => 'Energy in Ecosystems',
      _ => topicId,
    };

    await service.generateGreeting(
      scenarioId: scenario.id,
      character: character,
      topicName: topicName,
    );

    // Only show bubbles if we haven't been cancelled/disposed
    if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) {
      setState(() => _isGeneratingGreeting = false);
      return;
    }

    // Stop showing "Thinking..." and hide bubble to prepare for smooth fade-in
    setState(() {
      _isGeneratingGreeting = false;
      _showSpeechBubble = false;  // Hide bubble so _showNextBubble can animate it in cleanly
    });

    _cancelAllBubbleTimers();

    setState(() {
      _currentBubbleIndex = 0;
      _bubbleCycleCount = 0;
      _currentIdleBubble = null;
    });

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
            _isDragging = false; // Reset drag state to allow bubbles to show
          });
          final character = ref.read(activeCharacterProvider);
          final scenario = ref.read(currentScenarioProvider);
          if (character.id == 'aristotle') {
            // For Aristotle: fetch fresh AI greeting for current scenario
            final scenarioId = scenario?.id ?? 'aristotle_general';
            AristotleGreetingService().invalidateScenario(scenarioId);
            _fetchAristotleGreeting();
          } else if (scenario != null && scenario.type == ScenarioType.lessonMenu) {
            // For experts on lesson menu: fetch scenario-aware AI greeting
            _fetchExpertGreeting();
          } else {
            // Fallback: show static bubbles after delay
            final gen = _timerGeneration;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) return;
              _showNextBubble();
            });
          }

        case BubbleMode.waitingForNarrative:
          // Immediately hide everything — no greetings, no narrative yet
          // Set local state INSTANTLY to prevent flash
          setState(() {
            _showSpeechBubble = false;
            _isDragging = false; // Reset drag state for clean module entry
          });
          _speechBubbleController.reverse(); // Animation happens AFTER state update

        case BubbleMode.narrative:
          // Narrative started — show first message
          setState(() {
            _currentBubbleIndex = 0;
            _showSpeechBubble = false;
            _isDragging = false; // Reset drag state to allow bubbles to show
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
        final scenario = ref.read(currentScenarioProvider);
        final scenarioId = scenario?.id ?? 'aristotle_general';
        AristotleGreetingService().invalidateScenario(scenarioId);
        _fetchAristotleGreeting();
        // Return placeholder - actual bubbles will show when AI greeting arrives
        return narrate(['...']);
      } else {
        // Switching to a topic expert - fetch AI greeting via service
        final scenario = ref.read(currentScenarioProvider);
        if (scenario != null && scenario.type == ScenarioType.lessonMenu) {
          _fetchExpertGreeting();
        }
        // Show introduction handoff while AI greeting loads
        return narrate([
          'Meet ${character.name}, your specialist in ${character.specialization.toLowerCase()}!',
          character.greeting,
          'Starting fresh conversation with ${character.name}.',
        ], pacing: PacingHint.normal);
      }
    }

    // Aristotle: always use AI-generated greetings (scenario-aware)
    if (character.id == 'aristotle') {
      final service = AristotleGreetingService();
      final scenario = ref.read(currentScenarioProvider);
      final scenarioId = scenario?.id ?? 'aristotle_general';

      if (service.hasGreeting(scenarioId)) {
        return service.getCachedGreeting(scenarioId)!;
      }
      return narrate(['...']);
    }

    // Expert characters: use ExpertGreetingService when on lesson menu scenario
    final scenario = ref.read(currentScenarioProvider);
    if (scenario != null && scenario.type == ScenarioType.lessonMenu) {
      final expertService = ExpertGreetingService();
      if (expertService.hasGreeting(scenario.id)) {
        return expertService.getCachedGreeting(scenario.id)!;
      }
      // AI greeting not ready yet - placeholder
      return narrate(['...']);
    }

    // Fallback for experts outside lesson menu (e.g. module context)
    return narrate([
      'Hey! I\'m ${character.name}. Ask me anything.',
      'Tap on me to start a conversation about science!',
    ]);
  }

  /// Show next speech bubble message with animation.
  /// Uses _timerGeneration to cancel stale callbacks from previous mode transitions.
  void _showNextBubble() {
    debugPrint('💬 _showNextBubble() called');

    if (_isDisposed || !mounted || _isChatOpen || _isDragging) {
      debugPrint('💬 _showNextBubble() blocked: disposed=$_isDisposed, mounted=$mounted, chatOpen=$_isChatOpen, dragging=$_isDragging');
      return;
    }

    final gen = _timerGeneration;
    final mode = ref.read(bubbleModeProvider);
    debugPrint('💬 Current bubble mode: $mode');

    final messages = _getBubbleMessages();
    debugPrint('💬 Got ${messages.length} messages to display');

    // Narrative mode: use narrative provider's index
    if (mode == BubbleMode.narrative) {
      final narrativeState = ref.read(lessonNarrativeBubbleProvider);
      final currentIndex = narrativeState.currentIndex;
      debugPrint('💬 _showNextBubble: Narrative mode, index $currentIndex of ${messages.length}');

      if (currentIndex >= messages.length) {
        debugPrint('💬 Narrative finished - hiding bubble smoothly');
        // Instantly hide bubble (no blink effect) when transitioning to next step
        if (!_isDisposed && mounted) {
          setState(() => _showSpeechBubble = false);
        }
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
        debugPrint('⏰ [TIMER] Display timer fired for bubble $currentIndex');
        if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) {
          debugPrint('⏰ [TIMER] Cancelled - disposed/unmounted/chatOpen/staleGen');
          return;
        }

        // Check if narrative is paused (e.g., exit dialog showing)
        final narrativeState = ref.read(lessonNarrativeBubbleProvider);
        debugPrint('⏰ [TIMER] Checking isPaused: ${narrativeState.isPaused}');
        if (narrativeState.isPaused) {
          debugPrint('⏰ [TIMER] BLOCKED - narrative is paused, not advancing');
          return;
        }

        debugPrint('⏰ [TIMER] Starting bubble reverse animation');
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) {
            debugPrint('⏰ [TIMER] Animation complete but widget disposed/unmounted/chatOpen/staleGen');
            return;
          }

          // Check again before advancing
          final narrativeState2 = ref.read(lessonNarrativeBubbleProvider);
          debugPrint('⏰ [TIMER] Animation complete, checking isPaused again: ${narrativeState2.isPaused}');
          if (narrativeState2.isPaused) {
            debugPrint('⏰ [TIMER] BLOCKED after animation - narrative is paused');
            return;
          }

          debugPrint('⏰ [TIMER] Calling nextMessage() to advance bubble');
          ref.read(lessonNarrativeBubbleProvider.notifier).nextMessage();
          final gapDuration = Duration(milliseconds: currentMsg.gapMs);
          Future.delayed(gapDuration, () {
            if (gen != _timerGeneration || _isDisposed || !mounted) return;

            // Check if paused before showing next bubble
            final narrativeState3 = ref.read(lessonNarrativeBubbleProvider);
            if (narrativeState3.isPaused) return;

            _showNextBubble();
          });
        });
      });
    } else if (mode == BubbleMode.greeting) {
      // Greeting cycling logic
      if (_currentBubbleIndex >= messages.length) {
        debugPrint('💬 _showNextBubble: Greeting finished - all ${messages.length} bubbles shown');
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || gen != _timerGeneration) return;
          setState(() => _showSpeechBubble = false);

          final character = ref.read(activeCharacterProvider);

          // Aristotle: always start idle timer to show encouraging messages
          if (character.id == 'aristotle') {
            _startIdleTimer();
          } else {
            // Other characters: allow up to 3 cycles of static greetings
            _bubbleCycleCount++;
            if (_bubbleCycleCount < 3) {
              _startIdleTimer();
            }
          }
        });
        return;
      }

      final currentMsg = messages[_currentBubbleIndex.clamp(0, messages.length - 1)];
      final msgPreview = currentMsg.content.substring(0, currentMsg.content.length.clamp(0, 50));
      debugPrint('💬 _showNextBubble: Greeting mode, bubble ${_currentBubbleIndex + 1}/${messages.length}');
      debugPrint('💬   Content: "$msgPreview${currentMsg.content.length > 50 ? '...' : ''}"');
      debugPrint('💬   Display: ${currentMsg.displayMs}ms, Gap: ${currentMsg.gapMs}ms, Pacing: ${currentMsg.pacingHint.name}');

      setState(() => _showSpeechBubble = true);

      _speechBubbleController.forward(from: 0.0);

      _bubbleCycleTimer?.cancel();
      final displayDuration = Duration(milliseconds: currentMsg.displayMs);
      _bubbleCycleTimer = Timer(displayDuration, () {
        if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) return;
        debugPrint('💬   Hiding bubble after ${currentMsg.displayMs}ms display time');
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || _isChatOpen || gen != _timerGeneration) return;
          final gapDuration = Duration(milliseconds: currentMsg.gapMs);
          setState(() => _currentBubbleIndex++);
          debugPrint('💬   Waiting ${currentMsg.gapMs}ms gap before next bubble');
          Future.delayed(gapDuration, () {
            if (gen != _timerGeneration || _isDisposed || !mounted) return;
            _showNextBubble();
          });
        });
      });
    }
    // BubbleMode.waitingForNarrative: do nothing (bubbles suppressed)
  }

  /// Resume bubble sequence after drag interruption.
  /// Maintains continuity - doesn't restart from beginning.
  void _resumeBubbleSequenceAfterDrag() {
    if (_isDisposed || !mounted || _isChatOpen) {
      _clearDragState();
      return;
    }

    if (_bubbleModeWhenDragStarted != null && _bubbleIndexWhenDragStarted != null) {
      final currentMode = ref.read(bubbleModeProvider);
      final gen = _timerGeneration;

      // Mode changed during drag - let new mode handle it
      if (currentMode != _bubbleModeWhenDragStarted) {
        debugPrint('💬 Mode changed during drag - deferring to new mode');
        _clearDragState();
        return;
      }

      // Same mode - resume from where we left off
      debugPrint('💬 Resuming bubble sequence from index $_bubbleIndexWhenDragStarted');

      // Capture the value before clearing drag state to avoid null race condition
      final resumeIndex = _bubbleIndexWhenDragStarted;
      _clearDragState();

      if (resumeIndex == null) return;

      Future.delayed(const Duration(milliseconds: 600), () {
        if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen) return;

        setState(() {
          _currentBubbleIndex = resumeIndex;
        });

        _showNextBubble();
      });

      return;
    }

    _clearDragState();
  }

  /// Clear drag state after resuming or when not needed.
  void _clearDragState() {
    _bubbleIndexWhenDragStarted = null;
    _bubbleModeWhenDragStarted = null;
    _messagesWhenDragStarted = null;
  }

  /// Start idle timer - after period of inactivity, show bubbles again.
  /// For Aristotle: fetches a dynamic AI-generated idle bubble.
  /// For experts: restarts the static greeting cycle.
  void _startIdleTimer() {
    if (_isDisposed) return;
    _idleTimer?.cancel();
    final gen = _timerGeneration;
    // Show idle encouragement every 15 seconds
    const idleSeconds = 15;
    debugPrint('⏰ [IDLE TIMER] Starting idle timer for 15 seconds (gen: $gen)');
    _idleTimer = Timer(const Duration(seconds: idleSeconds), () async {
      debugPrint('⏰ [IDLE TIMER] Timer fired! Checking conditions...');
      if (gen != _timerGeneration || _isDisposed || !mounted || _isChatOpen || _showSpeechBubble) {
        debugPrint('⏰ [IDLE TIMER] ❌ Conditions failed - gen:$gen vs $_timerGeneration, disposed:$_isDisposed, mounted:$mounted, chatOpen:$_isChatOpen, bubbleShowing:$_showSpeechBubble');
        return;
      }

      debugPrint('⏰ [IDLE TIMER] ✅ Conditions passed, fetching idle bubble...');
      final character = ref.read(activeCharacterProvider);
      if (character.id == 'aristotle') {
        // Fetch AI-generated idle bubble for Aristotle
        final bubble = await AristotleGreetingService().generateIdleBubble();
        debugPrint('⏰ [IDLE TIMER] Generated bubble: ${bubble != null ? "\"${bubble.content}\"" : "null"}');
        if (bubble != null && mounted && !_isDisposed && gen == _timerGeneration && !_isChatOpen) {
          debugPrint('⏰ [IDLE TIMER] 🎉 Displaying idle bubble!');
          _currentIdleBubble = bubble;
          setState(() {
            _currentBubbleIndex = 0;
            _showSpeechBubble = true;
          });
          _speechBubbleController.forward(from: 0.0);
          // Auto-hide after display duration (minimum 5 seconds for idle bubbles)
          _bubbleCycleTimer?.cancel();
          final displayDuration = bubble.displayMs < 5000 ? 5000 : bubble.displayMs;
          debugPrint('⏰ [IDLE TIMER] Displaying for ${displayDuration}ms');
          _bubbleCycleTimer = Timer(Duration(milliseconds: displayDuration), () {
            if (_isDisposed || !mounted || gen != _timerGeneration) return;
            _speechBubbleController.reverse().then((_) {
              if (_isDisposed || !mounted) return;
              setState(() => _showSpeechBubble = false);
              _currentIdleBubble = null;
              _bubbleCycleCount++;
              // Keep showing idle encouragements indefinitely
              _startIdleTimer();
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
      curve: Curves.easeOutCubic,
    ));
    
    _snapAnimationController.forward(from: 0.0).then((_) {
      setState(() {
        _position = snapPosition;
        _closedPosition = snapPosition;
      });
      _savePosition(snapPosition);
    });
  }

  /// Check if messenger window can open based on current scenario context.
  ///
  /// Allows messenger in:
  /// - ScenarioType.general (Aristotle on home/topics)
  /// - ScenarioType.lessonMenu (Expert on lesson selection screen)
  /// - null scenario with Aristotle (fallback for home screen before scenario loads)
  ///
  /// Blocks messenger in:
  /// - ScenarioType.module (Expert in module - narration only)
  /// - null scenario with expert character
  bool _canOpenMessenger() {
    final scenario = ref.read(currentScenarioProvider);

    // If no scenario set yet, allow messenger for Aristotle only
    // (handles timing issue on home screen before scenario loads)
    if (scenario == null) {
      final character = ref.read(activeCharacterProvider);
      return character.id == 'aristotle';
    }

    // Allow messenger in general context and lesson menus
    // Block in modules and other restricted contexts
    return scenario.type == ScenarioType.general ||
           scenario.type == ScenarioType.lessonMenu;
  }

  /// Open chat window - move bubble to top-right
  /// Works for Aristotle (general) and experts in lesson menus
  void _openChat() {
    if (_isDragging || _isChatOpen) return;

    // Check if messenger can open based on context (not just character ID)
    if (!_canOpenMessenger()) {
      // For modules/restricted contexts, just hide bubble silently
      setState(() => _showSpeechBubble = false);
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
      // Use same openability check for consistency
      if (_canOpenMessenger()) {
        _openChat();
      } else {
        // In modules, tap just hides bubble
        setState(() => _showSpeechBubble = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Watch bubble mode in build() for reliable provider subscription.
    // Handle mode transitions (greeting ↔ narrative ↔ waitingForNarrative).
    final bubbleMode = ref.watch(bubbleModeProvider);
    _handleBubbleModeTransition(bubbleMode);

    // Detect scenario changes (screen navigation) even when bubble mode stays the same.
    // Without this, quickly navigating between screens that both use BubbleMode.greeting
    // (e.g. Topics → Lessons) would let old bubbles leak into the new screen.
    final currentScenario = ref.watch(currentScenarioProvider);
    final currentScenarioId = currentScenario?.id;
    if (currentScenarioId != _lastScenarioId && _lastScenarioId != null) {
      if (bubbleMode == BubbleMode.greeting && bubbleMode == _lastBubbleMode) {
        // Same mode but different screen — force a greeting restart
        _lastBubbleMode = null; // Reset so _handleBubbleModeTransition re-fires
        _handleBubbleModeTransition(bubbleMode);
      }
    }
    _lastScenarioId = currentScenarioId;

    // Detect narrative resume (isPaused: true → false) and restart bubble timers
    if (bubbleMode == BubbleMode.narrative) {
      final narrativeState = ref.watch(lessonNarrativeBubbleProvider);
      // If just resumed (was paused, now not paused), restart bubble display
      if (_lastNarrativeIsPaused && !narrativeState.isPaused && narrativeState.isActive) {
        // Schedule a call to _showNextBubble to restart timers
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isChatOpen) {
            _showNextBubble();
          }
        });
      }
      _lastNarrativeIsPaused = narrativeState.isPaused;
    }

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
        // Check isInstantHide flag to prevent flash during channel transitions
        if (_showSpeechBubble && !_isChatOpen && !_isDragging && !ref.watch(lessonNarrativeBubbleProvider).isInstantHide)
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
                feedback: Transform.scale(
                  scale: 1.15,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: currentCharacter.themeColor.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildButton(isDragging: true),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildButton(),
                ),
                onDragStarted: () {
                  // Capture state before hiding bubble
                  _bubbleIndexWhenDragStarted = _currentBubbleIndex;
                  _bubbleModeWhenDragStarted = ref.read(bubbleModeProvider);
                  _messagesWhenDragStarted = _getBubbleMessages();

                  // Hide bubble immediately and animate out
                  _speechBubbleController.reverse();

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

                  _resumeBubbleSequenceAfterDrag();
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

  /// Parse markdown-style **bold** text into TextSpan with styling
  TextSpan _parseMarkdownText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in boldPattern.allMatches(text)) {
      // Add normal text before the bold
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      // Add bold text (without the ** markers)
      spans.add(TextSpan(
        text: match.group(1), // Text inside **...**
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));

      lastIndex = match.end;
    }

    // Add remaining text after last bold
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }

  /// Build speech bubble tooltip next to the FAB
  Widget _buildSpeechBubble(bool isOnRight) {
    final character = ref.watch(activeCharacterProvider);
    final narrativeBubbleState = ref.watch(lessonNarrativeBubbleProvider);

    // Check if AI is thinking/generating a response
    final String currentMessage;
    if (_isGeneratingGreeting) {
      // Show thinking while generating greeting
      currentMessage = 'Thinking...';
    } else if (narrativeBubbleState.isThinking) {
      // Show thinking during lesson Q&A
      currentMessage = 'Thinking...';
    } else if (_currentIdleBubble != null) {
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left tail (when bubble is on left side, tail points right toward avatar)
          if (!isOnRight)
            CustomPaint(
              size: const Size(8, 12),
              painter: _BubbleTailPainter(
                color: AppColors.white,
                borderColor: character.themeColor.withOpacity(0.2),
                pointsRight: true,
              ),
            ),
          // Speech bubble container
          Container(
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
            child: RichText(
              text: _parseMarkdownText(
                currentMessage,
                AppTextStyles.bodySmall.copyWith(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  backgroundColor: Colors.transparent,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          // Right tail (when bubble is on right side, tail points left toward avatar)
          if (isOnRight)
            CustomPaint(
              size: const Size(8, 12),
              painter: _BubbleTailPainter(
                color: AppColors.white,
                borderColor: character.themeColor.withOpacity(0.2),
                pointsRight: false,
              ),
            ),
        ],
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

/// Custom painter for speech bubble tail pointing toward the avatar
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool pointsRight;

  _BubbleTailPainter({
    required this.color,
    required this.borderColor,
    required this.pointsRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the tail fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final fillPath = Path();
    if (pointsRight) {
      // Tail pointing right (when bubble is on left)
      fillPath.moveTo(0, size.height / 2);
      fillPath.lineTo(size.width, 0);
      fillPath.lineTo(size.width, size.height);
      fillPath.close();
    } else {
      // Tail pointing left (when bubble is on right)
      fillPath.moveTo(size.width, size.height / 2);
      fillPath.lineTo(0, 0);
      fillPath.lineTo(0, size.height);
      fillPath.close();
    }

    canvas.drawPath(fillPath, fillPaint);

    // Draw the tail border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final borderPath = Path();
    if (pointsRight) {
      borderPath.moveTo(0, size.height / 2);
      borderPath.lineTo(size.width, 0);
      borderPath.lineTo(size.width, size.height);
    } else {
      borderPath.moveTo(size.width, size.height / 2);
      borderPath.lineTo(0, 0);
      borderPath.lineTo(0, size.height);
    }

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.pointsRight != pointsRight;
}