import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/models/chat_message_extended.dart';

/// Chat Bubble Widget
/// Displays messages with character-specific styling
/// 
/// Week 3 Day 1 Implementation
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  const ChatBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';

    if (isSystem) {
      return _buildSystemMessage();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s16,
        vertical: AppSizes.s8,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (for assistant only)
          if (!isUser && showAvatar) ...[
            _buildAvatar(),
            const SizedBox(width: AppSizes.s8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSizes.s12),
              decoration: BoxDecoration(
                color: _getBubbleColor(isUser),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? AppSizes.radiusM : AppSizes.radiusS),
                  topRight: Radius.circular(isUser ? AppSizes.radiusS : AppSizes.radiusM),
                  bottomLeft: const Radius.circular(AppSizes.radiusM),
                  bottomRight: const Radius.circular(AppSizes.radiusM),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Character name (for assistant)
                  if (!isUser && message.characterName != null) ...[
                    Text(
                      message.characterName!,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getTextColor(isUser).withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: AppSizes.s4),
                  ],

                  // Message content
                  Text(
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _getTextColor(isUser),
                    ),
                  ),

                  // Streaming indicator
                  if (message.isStreaming) ...[
                    const SizedBox(height: AppSizes.s4),
                    _buildStreamingCursor(),
                  ],
                ],
              ),
            ),
          ),

          // Spacing for user messages
          if (isUser && showAvatar) const SizedBox(width: AppSizes.s40),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getAvatarInitial(),
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s16,
        vertical: AppSizes.s8,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.s12,
            vertical: AppSizes.s8,
          ),
          decoration: BoxDecoration(
            color: AppColors.grey300,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Text(
            message.content,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingCursor() {
    return Container(
      width: 2,
      height: 16,
      color: AppColors.primary,
      child: const _BlinkingCursor(),
    );
  }

  Color _getBubbleColor(bool isUser) {
    if (isUser) {
      return const Color(0xFFE8F5E9); // Light green
    }

    // Character-specific colors
    switch (message.characterName) {
      case 'Aristotle':
        return const Color(0xFFE3F2FD); // Light blue
      case 'Herophilus':
        return const Color(0xFFFCE4EC); // Light pink
      case 'Gregor Mendel':
        return const Color(0xFFF3E5F5); // Light purple
      case 'Edward Wilson':
        return const Color(0xFFFFF3E0); // Light orange
      default:
        return const Color(0xFFE3F2FD);
    }
  }

  Color _getTextColor(bool isUser) {
    if (isUser) {
      return const Color(0xFF388E3C); // Dark green
    }

    switch (message.characterName) {
      case 'Aristotle':
        return const Color(0xFF1976D2); // Dark blue
      case 'Herophilus':
        return AppColors.error; // Pink
      case 'Gregor Mendel':
        return const Color(0xFF9C27B0); // Purple
      case 'Edward Wilson':
        return AppColors.warning; // Orange
      default:
        return const Color(0xFF1976D2);
    }
  }

  String _getAvatarInitial() {
    if (message.characterName == null) return 'A';
    return message.characterName!.substring(0, 1).toUpperCase();
  }
}

/// Blinking cursor animation
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        color: AppColors.primary,
      ),
    );
  }
}