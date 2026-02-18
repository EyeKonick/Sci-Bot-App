import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/models/chat_message_extended.dart';
import '../../../../shared/models/ai_character_model.dart';
import '../../../../shared/widgets/neumorphic_styles.dart';

/// Chat Bubble Widget
/// Clean, modern chat bubbles with per-character theming
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  const ChatBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
  });

  /// Get the character for this message
  AiCharacter get _character =>
      AiCharacter.getCharacterById(message.characterId);

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isSystem) {
      return _buildSystemMessage(isDark);
    }

    final bubbleColor = isUser
        ? (isDark ? AppColors.darkPrimary : AppColors.primary)
        : (isDark ? AppColors.darkSurface : AppColors.surfaceTint);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s12,
        vertical: AppSizes.s4,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (for assistant only)
          if (!isUser && showAvatar) ...[
            _buildAvatar(),
            const SizedBox(width: AppSizes.s8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s16,
                vertical: AppSizes.s12,
              ),
              decoration: NeumorphicStyles.chatBubble(
                context,
                color: bubbleColor,
                isUser: isUser,
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
                        color: _character.themeColor,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Message content with bold support
                  _buildMessageContent(isUser, isDark),

                  // Streaming indicator
                  if (message.isStreaming) ...[
                    const SizedBox(height: 4),
                    _buildStreamingCursor(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build message content with bold text support
  /// Supports **bold** markdown syntax
  Widget _buildMessageContent(bool isUser, bool isDark) {
    final text = message.content;
    final textColor = isUser
        ? AppColors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);

    // Parse bold markers (**text**)
    final spans = _parseBoldText(text, textColor);

    return RichText(
      text: TextSpan(
        style: AppTextStyles.chatMessage.copyWith(
          color: textColor,
          height: 1.45,
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
        children: spans,
      ),
    );
  }

  /// Parse **bold** markers in text
  List<TextSpan> _parseBoldText(String text, Color baseColor) {
    final spans = <TextSpan>[];
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      // Add text before the bold
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            backgroundColor: Colors.transparent,
            decoration: TextDecoration.none,
          ),
        ));
      }
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: baseColor,
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
      ));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
      ));
    }

    // If no bold markers found, return plain text
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: TextStyle(
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
      ));
    }

    return spans;
  }

  /// Build character avatar icon (small circular image)
  Widget _buildAvatar() {
    final character = _character;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: character.themeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          character.avatarAsset,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 32,
              height: 32,
              color: character.themeColor.withValues(alpha: 0.15),
              child: Center(
                child: Text(
                  character.name.substring(0, 1),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: character.themeColor,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSystemMessage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s16,
        vertical: AppSizes.s8,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.s12,
            vertical: AppSizes.s4,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Text(
            message.content,
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontSize: 11,
              backgroundColor: Colors.transparent,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingCursor() {
    return _BlinkingCursor(color: _character.themeColor);
  }

  /// Split a long message into paragraph-based chunks for display
  /// Returns a list of content strings split at paragraph boundaries
  static List<String> splitLongMessage(String content, {int maxCharsPerBubble = 300}) {
    // Don't split short messages
    if (content.length <= maxCharsPerBubble) return [content];

    // Split by double newlines (paragraphs) first
    final paragraphs = content.split(RegExp(r'\n\n+'));

    if (paragraphs.length > 1) {
      // Group paragraphs into chunks that stay under the limit
      final chunks = <String>[];
      String currentChunk = '';

      for (final paragraph in paragraphs) {
        if (currentChunk.isEmpty) {
          currentChunk = paragraph;
        } else if (currentChunk.length + paragraph.length + 2 <= maxCharsPerBubble) {
          currentChunk += '\n\n$paragraph';
        } else {
          chunks.add(currentChunk.trim());
          currentChunk = paragraph;
        }
      }
      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
      }
      return chunks;
    }

    // Single long paragraph - split by sentences
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    String currentChunk = '';

    for (final sentence in sentences) {
      if (currentChunk.isEmpty) {
        currentChunk = sentence;
      } else if (currentChunk.length + sentence.length + 1 <= maxCharsPerBubble) {
        currentChunk += ' $sentence';
      } else {
        chunks.add(currentChunk.trim());
        currentChunk = sentence;
      }
    }
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks.isEmpty ? [content] : chunks;
  }
}

/// Blinking cursor animation for streaming
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

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
        width: 2,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
