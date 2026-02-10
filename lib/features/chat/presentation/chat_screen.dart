import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_feedback.dart';
import '../../../shared/models/chat_message_extended.dart';
import '../../../shared/models/ai_character_model.dart';
import '../../../shared/models/scenario_model.dart';
import '../data/repositories/chat_repository.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/typing_indicator.dart';
import '../../../shared/widgets/loading_spinner.dart';

/// Full Chat Screen (INTERACTION CHANNEL ONLY)
///
/// This is an interaction-channel interface. All messages displayed here
/// are InteractionMessages or UserMessages. Narration content belongs
/// in the chathead speech bubbles (NarrationMessage), not here.
///
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

  /// Ensure the aristotle_general scenario is active when this screen opens.
  void _ensureAristotleScenario() {
    final scenario = ChatScenario.aristotleGeneral();
    _chatRepo.setScenario(scenario);
  }

  /// ✅ Listen to message stream for real-time updates from other interfaces
  void _listenToMessageUpdates() {
    _messageSubscription = _chatRepo.messageStream.listen((messages) {
      if (mounted) {
        setState(() {
          _messages.clear();

          // If no messages for this character, show greeting
          if (messages.isEmpty) {
            _messages.add(_chatRepo.getGreeting(
              character: AiCharacter.aristotle,
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
      _ensureAristotleScenario();
      await _chatRepo.initialize();
      
      if (!mounted) return;
      
      setState(() {
        // Load conversation history or show greeting
        if (_chatRepo.conversationHistory.isEmpty) {
          _messages.add(_chatRepo.getGreeting(
            character: AiCharacter.aristotle,
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
      
      setState(() {
        _messages.add(_chatRepo.getGreeting(
          character: AiCharacter.aristotle,
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

    await for (final message in _chatRepo.sendMessageStream(text, character: AiCharacter.aristotle)) {
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
      const character = AiCharacter.aristotle;
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

  /// Whether the chat is offline (OpenAI not configured)
  bool get _isOffline => !_chatRepo.isConfigured;

  /// Whether messages list only contains the initial greeting
  bool get _isWelcomeState =>
      _messages.length == 1 &&
      _messages.first.role == 'assistant' &&
      !_messages.first.isError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: Column(
        children: [
          _buildAppBar(),
          if (_isSearching) _buildSearchBar(),
          // Phase 4: Offline banner
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: _isLoading
                ? const LoadingSpinner(message: 'Loading chat...')
                : _buildMessagesList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    // Chat screen always uses Aristotle
    const character = AiCharacter.aristotle;
    
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

    // Search produced no results
    if (displayMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
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
      itemCount: displayMessages.length +
          (_isStreaming ? 1 : 0) +
          (_isWelcomeState ? 1 : 0), // Extra item for starters
      itemBuilder: (context, index) {
        // Typing indicator at the end
        final msgCount = displayMessages.length + (_isWelcomeState ? 1 : 0);
        if (index == msgCount && _isStreaming) {
          const character = AiCharacter.aristotle;
          return TypingIndicator(
            color: character.themeColor,
            characterName: character.name,
            avatarAsset: character.avatarAsset,
          );
        }

        // Phase 4: Conversation starters after greeting
        if (_isWelcomeState && index == 1) {
          return _buildConversationStarters();
        }

        // Adjust index for messages after starters widget
        final msgIndex = (_isWelcomeState && index > 1) ? index - 1 : index;
        if (msgIndex >= displayMessages.length) return const SizedBox.shrink();

        final message = displayMessages[msgIndex];

        // Phase 4: Error card with Retry
        if (message.isError) {
          return _buildErrorCard(message);
        }

        return ChatBubble(
          message: message,
          showAvatar: message.characterName != null,
        );
      },
    );
  }

  /// Phase 4: Offline banner when AI chat is unavailable
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s16,
        vertical: AppSizes.s12,
      ),
      color: AppFeedback.warningColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Text(
              'Lessons work offline, but chat requires internet.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phase 4: Conversation starter chips below greeting
  Widget _buildConversationStarters() {
    const character = AiCharacter.aristotle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.s16, AppSizes.s4, AppSizes.s16, AppSizes.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking:',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey600,
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          Wrap(
            spacing: AppSizes.s8,
            runSpacing: AppSizes.s8,
            children: character.conversationStarters.map((starter) {
              return ActionChip(
                label: Text(
                  starter,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: character.themeColor,
                  ),
                ),
                backgroundColor: character.themeColor.withValues(alpha: 0.08),
                side: BorderSide(
                  color: character.themeColor.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                onPressed: _isOffline
                    ? null
                    : () {
                        _controller.text = starter;
                        _sendMessage();
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Phase 4: Error card with Retry button
  Widget _buildErrorCard(ChatMessage errorMessage) {
    const character = AiCharacter.aristotle;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s12,
        vertical: AppSizes.s4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  AppFeedback.errorIcon,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Text(
                    'Connection Error',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              errorMessage.content,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isStreaming ? null : () => _retryLastMessage(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: character.themeColor,
                    side: BorderSide(color: character.themeColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s16,
                      vertical: AppSizes.s8,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s12),
                Text(
                  'Check your connection',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 4: Retry the last failed message
  Future<void> _retryLastMessage() async {
    const character = AiCharacter.aristotle;
    final retryStream = _chatRepo.retryLastMessage(character: character);

    if (retryStream == null) return;

    setState(() {
      _isStreaming = true;
    });

    await for (final message in retryStream) {
      if (!message.isStreaming && message.role == 'assistant') {
        setState(() {
          _isStreaming = false;
        });
      }
    }
  }

  Widget _buildInputArea() {
    const character = AiCharacter.aristotle;
    final bool isDisabled = _isStreaming;

    // Contextual hint text based on state
    final String hintText = isDisabled
        ? '${character.name} is thinking...'
        : 'Ask ${character.name} anything...';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSizes.s12, AppSizes.s12, AppSizes.s12, AppSizes.s12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
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
                    hintText: hintText,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: isDisabled
                          ? character.themeColor.withValues(alpha: 0.5)
                          : AppColors.grey600,
                      fontStyle: isDisabled ? FontStyle.italic : FontStyle.normal,
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
                  enabled: !isDisabled,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_controller.text.trim().isEmpty || isDisabled)
                    ? AppColors.grey300
                    : character.themeColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.white, size: 22),
                onPressed: (_controller.text.trim().isEmpty || isDisabled)
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
    const character = AiCharacter.aristotle;

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
    const character = AiCharacter.aristotle;

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