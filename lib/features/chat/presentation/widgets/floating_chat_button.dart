import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import 'quick_chat_popup.dart';

/// Floating Aristotle Chat Button
/// Draggable button that opens quick chat popup
/// 
/// Week 3 Day 1 Implementation
class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton> {
  Offset _position = const Offset(20, 100);
  bool _hasNotification = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble('chat_button_x') ?? 20;
    final y = prefs.getDouble('chat_button_y') ?? 100;
    setState(() {
      _position = Offset(x, y);
    });
  }

  Future<void> _savePosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('chat_button_x', position.dx);
    await prefs.setDouble('chat_button_y', position.dy);
  }

  void _openQuickChat() {
    if (_isDragging) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickChatPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildButton(isDragging: true),
        childWhenDragging: Container(),
        onDragStarted: () {
          setState(() {
            _isDragging = true;
          });
        },
        onDragEnd: (details) {
          setState(() {
            _isDragging = false;
            // Keep within screen bounds
            final x = details.offset.dx.clamp(0.0, screenSize.width - 70);
            final y = details.offset.dy.clamp(0.0, screenSize.height - 150);
            _position = Offset(x, y);
          });
          _savePosition(_position);
        },
        child: GestureDetector(
          onTap: _openQuickChat,
          child: _buildButton(),
        ),
      ),
    );
  }

  Widget _buildButton({bool isDragging = false}) {
    final size = isDragging ? 64.0 : 56.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDragging ? 0.3 : 0.2),
            blurRadius: isDragging ? 12 : 8,
            offset: Offset(0, isDragging ? 6 : 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Placeholder icon (robot/person icon)
          Center(
            child: Icon(
              Icons.smart_toy_outlined,
              size: 32,
              color: Colors.white,
            ),
          ),

          // Notification badge
          if (_hasNotification && !isDragging)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),

          // Speech bubble hint (optional)
          if (!isDragging)
            Positioned(
              bottom: -30,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Ask me!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show notification badge
  void showNotification() {
    setState(() {
      _hasNotification = true;
    });
  }

  /// Clear notification badge
  void clearNotification() {
    setState(() {
      _hasNotification = false;
    });
  }
}