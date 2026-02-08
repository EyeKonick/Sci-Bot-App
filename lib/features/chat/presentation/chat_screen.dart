import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/chat_message_extended.dart';
import '../data/repositories/chat_repository.dart';
import '../data/providers/character_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/typing_indicator.dart';

/// Full Chat Screen
/// Complete chat interface with message history, search, and clear options
/// Week 3 Day 2 Implementation + Singleton Sync + Week 3 Day 3 Character Integration
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ PHASE 3.1: Update repository when character changes
    // ✅ PHASE 3.4: Pass contextual greeting for returning characters
    final character = ref.read(activeCharacterProvider);
    final contextManager = ref.read(characterContextManagerProvider);
    final greeting = contextManager.getPersonalizedGreeting();
    final contextGreeting = greeting != character.greeting ? greeting : null;
    _chatRepo.setCharacter(character, contextGreeting: contextGreeting);
  }

  /// ✅ Listen to message stream for real-time updates from other interfaces
  void _listenToMessageUpdates() {
    _messageSubscription = _chatRepo.messageStream.listen((messages) {
      if (mounted) {
        setState(() {
          _messages.clear();

          // If no messages for this character, show greeting
          if (messages.isEmpty) {
            final character = ref.read(activeCharacterProvider);
            final contextManager = ref.read(characterContextManagerProvider);
            final personalizedGreeting = contextManager.getPersonalizedGreeting();

            _messages.add(_chatRepo.getGreeting(
              character: character,
              personalizedGreeting: personalizedGreeting,
            ));
          } else {
            _messages.addAll(messages);
          }
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _initialize() async {
    try {
      await _chatRepo.initialize();
      
      if (!mounted) return;
      
      // Get active character and context manager
      final character = ref.read(activeCharacterProvider);
      final contextManager = ref.read(characterContextManagerProvider);
      final personalizedGreeting = contextManager.getPersonalizedGreeting();

      setState(() {
        // Load conversation history or show greeting
        if (_chatRepo.conversationHistory.isEmpty) {
          _messages.add(_chatRepo.getGreeting(
            character: character,
            personalizedGreeting: personalizedGreeting,
          ));
        } else {
          _messages.addAll(_chatRepo.conversationHistory);
        }
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      print('⚠️ Error initializing chat: $e');
      
      if (!mounted) return;
      
      final character = ref.read(activeCharacterProvider);
      final contextManager = ref.read(characterContextManagerProvider);
      final personalizedGreeting = contextManager.getPersonalizedGreeting();

      setState(() {
        _messages.add(_chatRepo.getGreeting(
          character: character,
          personalizedGreeting: personalizedGreeting,
        ));
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

    // Get current character
    final character = ref.read(activeCharacterProvider);
    
    await for (final message in _chatRepo.sendMessageStream(text, character: character)) {
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
      final character = ref.read(activeCharacterProvider);
      setState(() {
        _messages.add(_chatRepo.getGreeting(character: character));
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
      backgroundColor: AppColors.grey50,
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
    // Get current character from provider
    final character = ref.watch(activeCharacterProvider);
    
    return Container(
      decoration: BoxDecoration(
        gradient: character.themeGradient,
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
              // Character Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    character.avatarAsset,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.smart_toy_outlined,
                        color: AppColors.white,
                        size: 24,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Text(
                      character.specialization,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white.withOpacity(0.9),
                        decoration: TextDecoration.none,
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

  /// Expand messages - split long assistant messages into multiple bubbles
  List<ChatMessage> get _expandedMessages {
    final expanded = <ChatMessage>[];
    for (final msg in _filteredMessages) {
      if (msg.role == 'assistant' && !msg.isStreaming && msg.content.length > 300) {
        final chunks = ChatBubble.splitLongMessage(msg.content);
        for (int i = 0; i < chunks.length; i++) {
          expanded.add(msg.copyWith(
            content: chunks[i],
            // Only first chunk shows character name
            characterName: i == 0 ? msg.characterName : null,
          ));
        }
      } else {
        expanded.add(msg);
      }
    }
    return expanded;
  }

  Widget _buildMessagesList() {
    final displayMessages = _expandedMessages;

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
        return ChatBubble(
          message: displayMessages[index],
          showAvatar: displayMessages[index].characterName != null,
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSizes.s12, AppSizes.s12, AppSizes.s12, AppSizes.s12),
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 48,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.grey300,
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask ${ref.read(activeCharacterProvider).name} anything...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.grey600,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    isDense: true,
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey900,
                    height: 1.4,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isStreaming,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _controller.text.trim().isEmpty || _isStreaming
                    ? AppColors.grey300
                    : ref.watch(activeCharacterProvider).themeColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.white, size: 22),
                onPressed: _controller.text.trim().isEmpty || _isStreaming
                    ? null
                    : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu() {
    final character = ref.read(activeCharacterProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('About ${character.name}'),
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
    final character = ref.read(activeCharacterProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About ${character.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              character.specialization,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              '${character.name} is your AI tutor for Grade 9 Science. '
              'Ask questions and get guided explanations.',
              style: AppTextStyles.bodyMedium,
            ),
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

}