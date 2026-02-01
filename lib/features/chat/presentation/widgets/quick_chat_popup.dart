import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/models/chat_message_extended.dart';
import '../../data/repositories/chat_repository.dart';
import 'chat_bubble.dart';
import 'typing_indicator.dart';

/// Quick Chat Popup
/// Compact chat interface for quick interactions
/// 
/// Week 3 Day 1 Implementation
class QuickChatPopup extends StatefulWidget {
  const QuickChatPopup({super.key});

  @override
  State<QuickChatPopup> createState() => _QuickChatPopupState();
}

class _QuickChatPopupState extends State<QuickChatPopup> {
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
    await _chatRepo.initialize();
    
    setState(() {
      // Show greeting if no history
      if (_chatRepo.conversationHistory.isEmpty) {
        _messages.add(_chatRepo.getGreeting());
      } else {
        // Show last 3 messages
        final history = _chatRepo.conversationHistory;
        if (history.length > 3) {
          _messages.addAll(history.sublist(history.length - 3));
        } else {
          _messages.addAll(history);
        }
      }
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    _controller.clear();
    setState(() {
      _isStreaming = true;
    });

    await for (final message in _chatRepo.sendMessageStream(text)) {
      setState(() {
        // Update or add message
        final index = _messages.indexWhere((m) => 
          m.role == message.role && m.timestamp == message.timestamp);
        
        if (index != -1) {
          _messages[index] = message;
        } else {
          _messages.add(message);
        }
      });
      
      _scrollToBottom();

      // Stop streaming indicator when complete
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
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              _buildHeader(),

              const Divider(height: 1),

              // Messages
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
                        itemCount: _messages.length + (_isStreaming ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isStreaming) {
                            return const TypingIndicator();
                          }
                          return ChatBubble(message: _messages[index]);
                        },
                      ),
              ),

              // Input
              _buildInput(),

              // Open full chat link
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/chat');
                },
                child: const Text('Open Full Chat →'),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.smart_toy_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Name
          Text(
            'Aristotle',
            style: AppTextStyles.headingSmall,
          ),
          
          const Spacer(),
          
          // Close button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        border: Border(
          top: BorderSide(color: AppColors.grey300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask Aristotle...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isStreaming,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          IconButton(
            icon: Icon(
              Icons.send,
              color: _isStreaming ? AppColors.grey300 : AppColors.primary,
            ),
            onPressed: _isStreaming ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}