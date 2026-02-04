import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/models/chat_message_extended.dart';
import '../../data/repositories/chat_repository.dart';
import 'chat_bubble.dart';
import 'typing_indicator.dart';

/// Messenger-Style Chat Window
/// Full chat interface that appears when floating button is tapped
class MessengerChatWindow extends StatefulWidget {
  const MessengerChatWindow({super.key});

  @override
  State<MessengerChatWindow> createState() => _MessengerChatWindowState();
}

class _MessengerChatWindowState extends State<MessengerChatWindow> {
  final _chatRepo = ChatRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  bool _isLoading = true;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _chatRepo.initialize();
      
      if (!mounted) return;
      
      setState(() {
        if (_chatRepo.conversationHistory.isEmpty) {
          _messages.add(_chatRepo.getGreeting());
        } else {
          _messages.addAll(_chatRepo.conversationHistory);
        }
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      print('⚠️ Error initializing chat: $e');
      
      if (!mounted) return;
      
      setState(() {
        _messages.add(_chatRepo.getGreeting());
        _isLoading = false;
      });
      
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    _controller.clear();
    
    final userMsg = ChatMessage.user(text);
    setState(() {
      _messages.add(userMsg);
      _isStreaming = true;
    });
    
    _scrollToBottom();

    ChatMessage? aiMessage;
    
    await for (final message in _chatRepo.sendMessageStream(text)) {
      setState(() {
        if (message.role == 'user') {
          return;
        }
        
        if (aiMessage == null) {
          aiMessage = message;
          _messages.add(message);
        } else {
          final index = _messages.indexOf(aiMessage!);
          if (index != -1) {
            _messages[index] = message;
            aiMessage = message;
          }
        }
      });
      
      _scrollToBottom();

      if (!message.isStreaming && message.role == 'assistant') {
        setState(() {
          _isStreaming = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Wrap in MediaQuery to handle keyboard properly
    return MediaQuery.removePadding(
      context: context,
      removeTop: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - FIXED HEIGHT
              _buildHeader(),

              const Divider(height: 1),

              // Messages - FLEXIBLE
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.s8,
                          vertical: AppSizes.s8,
                        ),
                        itemCount: _messages.length + (_isStreaming ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isStreaming) {
                            return const TypingIndicator();
                          }
                          return ChatBubble(message: _messages[index]);
                        },
                      ),
              ),

              // Input Area - FIXED AT BOTTOM with AnimatedPadding
              AnimatedPadding(
                duration: const Duration(milliseconds: 100),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: _buildInputArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSizes.radiusL),
          topRight: Radius.circular(AppSizes.radiusL),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: AppColors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: AppSizes.s12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aristotle',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Your AI Science Companion',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 48,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _controller.text.isEmpty
                    ? null
                    : AppColors.primaryGradient,
                color: _controller.text.isEmpty
                    ? Colors.grey.shade300
                    : null,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _controller.text.isEmpty ? null : _sendMessage,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}