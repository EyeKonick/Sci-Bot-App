import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import 'messenger_chat_window.dart';

/// Floating Aristotle Chat Button - Messenger Style
/// Draggable button that opens inline chat window
/// 
/// Week 3 BATCH 3 - Messenger Style Implementation
class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton> with TickerProviderStateMixin {
  Offset _position = const Offset(20, 100);
  Offset? _closedPosition; // Stores position when chat is closed
  bool _hasNotification = false;
  bool _isDragging = false;
  bool _isChatOpen = false;
  
  late AnimationController _snapAnimationController;
  late Animation<Offset> _snapAnimation;
  
  late AnimationController _openAnimationController;
  late Animation<double> _openAnimation;

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
    
    _loadPosition();
  }

  @override
  void dispose() {
    _snapAnimationController.dispose();
    _openAnimationController.dispose();
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
  void _openChat() {
    if (_isDragging || _isChatOpen) return;
    
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
    
    setState(() {
      _isChatOpen = true;
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
    return Stack(
      children: [
        // Chat Window - ✅ FIX: ALWAYS touch screen bottom (bottom: 0)
        // Let messenger_chat_window.dart handle internal spacing
        if (_isChatOpen)
          AnimatedBuilder(
            animation: _openAnimation,
            builder: (context, child) {
              final bubbleBottom = MediaQuery.of(context).padding.top + 16 + 70;
              final chatWindowTop = bubbleBottom + 8; // 8px gap below bubble
              
              return Positioned(
                top: chatWindowTop,
                left: 0,
                right: 0,
                bottom: 0, // ✅ CRITICAL FIX: Always 0, no manual positioning
                child: Transform.scale(
                  scale: _openAnimation.value,
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: _openAnimation.value,
                    child: Column(
                      children: [
                        // Triangle tail centered with bubble
                        Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 35),
                          child: CustomPaint(
                            size: const Size(20, 10),
                            painter: _TrianglePainter(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        // Chat window - expands to fill available space
                        Expanded(
                          child: const MessengerChatWindow(),
                        ),
                      ],
                    ),
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
                  });
                },
                onDragEnd: (details) {
                  setState(() {
                    _isDragging = false;
                    _position = details.offset;
                  });
                  
                  if (!_isChatOpen) {
                    final screenSize = MediaQuery.of(context).size;
                    _snapToEdge(details.offset, screenSize);
                  }
                },
                child: GestureDetector(
                  onTap: _toggleChat,
                  child: _buildButton(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildButton({bool isDragging = false}) {
    final size = isDragging ? 78.0 : 70.0;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Aristotle icon
          Center(
            child: ClipOval(
              child: Image.asset(
                'assets/icons/Aristotle_icon.png',
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