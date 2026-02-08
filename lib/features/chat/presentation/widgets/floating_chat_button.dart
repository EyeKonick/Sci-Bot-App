import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../data/providers/character_provider.dart';
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
  Offset _position = const Offset(20, 100);
  Offset? _closedPosition; // Stores position when chat is closed
  bool _hasNotification = false;
  bool _isDragging = false;
  bool _isChatOpen = false;
  bool _showSpeechBubble = true; // Show speech bubble greeting
  bool _isDisposed = false; // Phase 0: Guard against post-dispose timer creation

  // Speech bubble message cycling
  int _currentBubbleIndex = 0;
  Timer? _bubbleCycleTimer;
  Timer? _idleTimer;
  int _bubbleCycleCount = 0; // Track how many full cycles we've shown

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

    // Speech bubble animation
    _speechBubbleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _speechBubbleAnimation = CurvedAnimation(
      parent: _speechBubbleController,
      curve: Curves.elasticOut,
    );

    _loadPosition();

    // Show first speech bubble after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!_isDisposed && mounted && !_isChatOpen) {
        _showNextBubble();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Watch for narrative state changes
    final narrativeState = ref.watch(lessonNarrativeBubbleProvider);

    // ✅ FIX: When narrative becomes ACTIVE (lesson starts), immediately take over
    if (narrativeState.isActive && narrativeState.messages.isNotEmpty) {
      // Cancel any ongoing greeting animations
      _bubbleCycleTimer?.cancel();
      _idleTimer?.cancel();
      _speechBubbleController.stop();

      // Reset to narrative mode
      setState(() {
        _currentBubbleIndex = 0;
        _showSpeechBubble = false; // Hide any existing bubble
      });

      // Small delay then show first narrative message
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isDisposed && mounted && !_isChatOpen) {
          _showNextBubble();
        }
      });
      return;
    }

    // If narrative just became inactive and we're not in chat, restart greetings
    if (!narrativeState.isActive &&
        narrativeState.messages.isEmpty &&
        !_isChatOpen &&
        !_showSpeechBubble) {
      // Reset and show contextual greeting immediately
      setState(() {
        _currentBubbleIndex = 0;
        _bubbleCycleCount = 0;
      });
      // Small delay then show greeting
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isDisposed && mounted && !_isChatOpen) {
          _showNextBubble();
        }
      });
    }
  }

  /// Get contextual speech bubble messages for the current character
  List<String> _getBubbleMessages() {
    // Check if lesson narrative is active (takes priority)
    final narrativeState = ref.watch(lessonNarrativeBubbleProvider);
    if (narrativeState.isActive && narrativeState.messages.isNotEmpty) {
      // Show lesson narrative messages
      return narrativeState.messages;
    }

    // Otherwise, show contextual greetings
    final character = ref.read(activeCharacterProvider);
    final prevContext = ref.read(previousContextProvider);
    final previousCharacter = prevContext?.currentTopicId != null
        ? AiCharacter.getCharacterForTopic(prevContext!.currentTopicId!)
        : null;

    // Check if user just came from a lesson/module in the same topic
    final wasInLesson = prevContext?.currentLessonId != null;
    final sameCharacter = previousCharacter?.id == character.id;

    switch (character.id) {
      case 'aristotle':
        if (previousCharacter != null && previousCharacter.id != 'aristotle') {
          return [
            'Welcome back! You just studied ${previousCharacter.specialization.toLowerCase()} with ${previousCharacter.name}.',
            'So how did it go? Did you learn something new about ${previousCharacter.specialization.toLowerCase()}?',
            'If you want, I can help you review what you learned or explore a new topic!',
          ];
        }
        return [
          'Hey! I\'m ${character.name}, your science guide.',
          'Ready to explore some Grade 9 Science? Pick a topic and let\'s get started!',
          'Tap on me if you have any questions about your lessons.',
        ];

      case 'herophilus':
        // ✅ Enhanced casual messages when returning from module
        if (wasInLesson && sameCharacter) {
          return [
            'So, how was the lesson? Did it make sense?',
            'Learning about circulation can be tricky! Need any clarification?',
            'Ready to continue with another module? I\'m here if you need help!',
          ];
        }
        if (previousCharacter != null && previousCharacter.id != 'herophilus') {
          return [
            'Hello! Coming from ${previousCharacter.name}\'s class? Let\'s study circulation!',
            'Did you know the heart beats about 100,000 times a day? Let me tell you more!',
            'Tap me if you want to learn how blood flows through your body.',
          ];
        }
        return [
          'I\'m Herophilus, your guide to the circulatory system!',
          'Did you know your blood vessels could wrap around the Earth twice?',
          'Ask me anything about how your heart and lungs work together!',
        ];

      case 'mendel':
        // ✅ Enhanced casual messages when returning from module
        if (wasInLesson && sameCharacter) {
          return [
            'How was the lesson? Genetics can be fascinating!',
            'Did everything make sense? I can clarify anything you found confusing.',
            'Ready to explore more? Pick another module or ask me questions!',
          ];
        }
        if (previousCharacter != null && previousCharacter.id != 'mendel') {
          return [
            'Welcome! Finished studying ${previousCharacter.specialization.toLowerCase()}? Now let\'s explore heredity!',
            'Ever wonder why you look like your parents? I can explain the science behind it!',
            'Tap me and let\'s discover how traits pass from one generation to the next.',
          ];
        }
        return [
          'Hello! I\'m Gregor Mendel, the father of genetics.',
          'Did you know I studied over 28,000 pea plants to discover inheritance patterns?',
          'Ask me about dominant traits, Punnett squares, or anything about heredity!',
        ];

      case 'odum':
        // ✅ Enhanced casual messages when returning from module
        if (wasInLesson && sameCharacter) {
          return [
            'So, how did you find the lesson?',
            'Energy flow and ecosystems can be complex! Any questions?',
            'Ready for the next module? I\'m here to help!',
          ];
        }
        if (previousCharacter != null && previousCharacter.id != 'odum') {
          return [
            'Hi there! Coming from ${previousCharacter.name}\'s lesson? Perfect timing!',
            'Let me show you how energy flows through every living thing in an ecosystem.',
            'Tap me to learn about food chains, energy pyramids, and more!',
          ];
        }
        return [
          'I\'m Eugene Odum, your ecosystem expert!',
          'Everything in nature is connected through energy. Want to see how?',
          'Ask me about food chains, photosynthesis, or how ecosystems work!',
        ];

      default:
        return [
          'Hey! I\'m ${character.name}. Ask me anything.',
          'Tap on me to start a conversation about science!',
        ];
    }
  }

  /// Show next speech bubble message with animation
  void _showNextBubble() {
    if (_isDisposed || !mounted || _isChatOpen || _isDragging) return;

    final messages = _getBubbleMessages();
    final narrativeState = ref.read(lessonNarrativeBubbleProvider);

    // If narrative is active, use narrative index
    if (narrativeState.isActive) {
      final currentIndex = narrativeState.currentIndex;
      print('💬 _showNextBubble: Narrative active, showing index $currentIndex of ${messages.length}');

      if (currentIndex >= messages.length) {
        // Narrative finished - hide bubble
        print('💬 Narrative finished - hiding bubble');
        _speechBubbleController.reverse().then((_) {
          if (!_isDisposed && mounted) {
            setState(() {
              _showSpeechBubble = false;
            });
          }
        });
        return;
      }

      if (messages.isNotEmpty && currentIndex < messages.length) {
        final messagePreview = messages[currentIndex].substring(0, messages[currentIndex].length.clamp(0, 40));
        print('💬 Displaying: "$messagePreview..."');
      }

      setState(() {
        _showSpeechBubble = true;
        _currentBubbleIndex = currentIndex;
      });

      // Animate in
      _speechBubbleController.forward(from: 0.0);

      // Auto-advance narrative after delay (only if not on last message)
      _bubbleCycleTimer?.cancel();

      // Check if this is the last message
      final isLastMessage = currentIndex >= messages.length - 1;

      if (isLastMessage) {
        // Don't cycle - keep last message visible
        // User will tap Next when ready
        return;
      }

      // ✅ FIX: Increased timing from 4s to 6s for better readability
      _bubbleCycleTimer = Timer(const Duration(seconds: 6), () {
        if (_isDisposed || !mounted || _isChatOpen) return;
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || _isChatOpen) return;
          ref.read(lessonNarrativeBubbleProvider.notifier).nextMessage();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!_isDisposed && mounted) _showNextBubble();
          });
        });
      });
    } else {
      // Use existing greeting cycling logic
      if (_currentBubbleIndex >= messages.length) {
        // Finished one cycle - hide bubble and start idle timer
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted) return;
          setState(() {
            _showSpeechBubble = false;
          });
          _bubbleCycleCount++;
          if (_bubbleCycleCount < 3) {
            _startIdleTimer();
          }
        });
        return;
      }

      setState(() {
        _showSpeechBubble = true;
      });

      // Animate in
      _speechBubbleController.forward(from: 0.0);

      // Schedule transition to next message after display time
      _bubbleCycleTimer?.cancel();
      _bubbleCycleTimer = Timer(const Duration(seconds: 5), () {
        if (_isDisposed || !mounted || _isChatOpen) return;
        _speechBubbleController.reverse().then((_) {
          if (_isDisposed || !mounted || _isChatOpen) return;
          setState(() {
            _currentBubbleIndex++;
          });
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!_isDisposed && mounted) _showNextBubble();
          });
        });
      });
    }
  }

  /// Start idle timer - after period of inactivity, show bubbles again
  void _startIdleTimer() {
    if (_isDisposed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 30), () {
      if (_isDisposed || !mounted || _isChatOpen || _showSpeechBubble) return;
      setState(() {
        _currentBubbleIndex = 0;
      });
      _showNextBubble();
    });
  }

  @override
  void dispose() {
    _isDisposed = true; // Phase 0: Prevent post-dispose timer creation
    _bubbleCycleTimer?.cancel();
    _idleTimer?.cancel();
    _snapAnimationController.dispose();
    _openAnimationController.dispose();
    _speechBubbleController.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble('chat_button_x') ?? 20;
    final y = prefs.getDouble('chat_button_y') ?? 100;
    setState(() {
      _position = Offset(x, y);
      _closedPosition = _position;
    });
  }

  Future<void> _savePosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('chat_button_x', position.dx);
    await prefs.setDouble('chat_button_y', position.dy);
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
                child: Transform.scale(
                  scale: _speechBubbleAnimation.value,
                  alignment: isOnRight ? Alignment.centerRight : Alignment.centerLeft,
                  child: Opacity(
                    opacity: _speechBubbleAnimation.value.clamp(0.0, 1.0),
                    child: _buildSpeechBubble(isOnRight),
                  ),
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
    final messages = _getBubbleMessages();
    final safeIndex = _currentBubbleIndex.clamp(0, messages.length - 1);
    final currentMessage = messages[safeIndex];

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
          // Character avatar
          Center(
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
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 36,
                      color: Colors.white,
                    ),
                  );
                },
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