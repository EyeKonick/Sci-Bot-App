import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/chat_message_extended.dart';
import '../data/repositories/chat_repository.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/typing_indicator.dart';

/// Full Chat Screen
/// Complete chat interface with message history, search, and clear options
/// 
/// Week 3 Day 2 Implementation + Singleton Sync
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatRepo = ChatRepository(); // ✅ Now returns singleton instance
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  bool _isLoading = true;
  bool _isStreaming = false;
  bool _isSearching = false;
  String _searchQuery = '';
  
  // ✅ Stream subscription for real-time sync
  StreamSubscription<List<ChatMessage>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
    _listenToMessageUpdates();
  }

  /// ✅ Listen to message stream for real-time updates from other interfaces
  void _listenToMessageUpdates() {
    _messageSubscription = _chatRepo.messageStream.listen((messages) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _initialize() async {
    try {
      await _chatRepo.initialize();
      
      if (!mounted) return;
      
      setState(() {
        // Load conversation history or show greeting
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
    
    setState(() {
      _isStreaming = true;
    });
    
    _scrollToBottom();

    await for (final message in _chatRepo.sendMessageStream(text)) {
      // Messages are automatically synced via stream listener
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

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
      }
    });
  }

  List<ChatMessage> get _filteredMessages {
    if (_searchQuery.isEmpty) return _messages;
    
    return _messages.where((msg) {
      return msg.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will delete all your chat messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatRepo.clearHistory();
      setState(() {
        _messages.add(_chatRepo.getGreeting());
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(),
          if (_isSearching) _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessagesList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.s16,
            vertical: AppSizes.s12,
          ),
          child: Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aristotle',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.white,
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
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: AppColors.white,
                ),
                onPressed: _toggleSearch,
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.white,
                ),
                onPressed: _showMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      color: AppColors.grey100,
      child: TextField(
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          filled: true,
          fillColor: AppColors.white,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildMessagesList() {
    final displayMessages = _filteredMessages;

    if (displayMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.grey300,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              'No messages found',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.grey600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
      itemCount: displayMessages.length + (_isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayMessages.length && _isStreaming) {
          return const TypingIndicator();
        }
        return ChatBubble(message: displayMessages[index]);
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask Aristotle anything...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.s16,
                    vertical: AppSizes.s12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isStreaming,
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Container(
              decoration: BoxDecoration(
                color: _isStreaming ? AppColors.grey300 : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: AppColors.white),
                onPressed: _isStreaming ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Aristotle'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Clear History', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _clearHistory();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Aristotle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your AI Science Companion',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              'Aristotle is your personal AI tutor for Grade 9 Science. '
              'Ask questions, get explanations, and explore topics in:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSizes.s12),
            _buildInfoItem('• Circulation & Gas Exchange'),
            _buildInfoItem('• Heredity & Variation'),
            _buildInfoItem('• Energy in Ecosystems'),
            const SizedBox(height: AppSizes.s12),
            Text(
              'Powered by OpenAI GPT-4',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.grey600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSizes.s8, bottom: AppSizes.s4),
      child: Text(text, style: AppTextStyles.bodyMedium),
    );
  }
}