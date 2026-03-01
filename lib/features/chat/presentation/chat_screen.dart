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
import '../../profile/data/providers/user_profile_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_date_divider.dart';
import 'widgets/typing_indicator.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/neumorphic_styles.dart';

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

      // Set user's name for personalized AI responses
      final profile = await ref.read(userProfileProvider.future);
      _chatRepo.setUserName(profile?.name);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
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
                  color: AppColors.white.withValues(alpha: 0.2),
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
                        color: AppColors.white.withValues(alpha: 0.9),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      color: isDark ? AppColors.darkBackground : AppColors.background,
      child: TextField(
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceTint,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  /// Returns true when a date/time divider should be injected before [current].
  bool _needsDivider(ChatMessage? previous, ChatMessage current) {
    if (previous == null) return true;
    final prevDay = DateTime(
        previous.timestamp.year, previous.timestamp.month, previous.timestamp.day);
    final currDay = DateTime(
        current.timestamp.year, current.timestamp.month, current.timestamp.day);
    if (currDay != prevDay) return true;
    return current.timestamp.difference(previous.timestamp).inHours >= 4;
  }

  /// Builds the flat display list: DateTime entries become date dividers,
  /// ChatMessage entries become bubbles (long messages are split).
  /// Dividers are suppressed during search to avoid misleading temporal context.
  List<Object> _buildDisplayItems() {
    // Suppress dividers while the user is actively filtering by search query
    final showDividers = _searchQuery.isEmpty &&
        (_chatRepo.currentScenario?.type == ScenarioType.general ||
            _chatRepo.currentScenario?.type == ScenarioType.lessonMenu);

    final result = <Object>[];
    ChatMessage? lastVisible;

    for (final msg in _filteredMessages) {
      if (msg.role == 'system') continue;

      // session_return always gets a divider regardless of time elapsed
      final forcesDivider = msg.context == 'session_return';
      if (showDividers && (forcesDivider || _needsDivider(lastVisible, msg))) {
        result.add(msg.timestamp);
      }

      // Split long assistant messages into multiple bubbles
      if (msg.role == 'assistant' && !msg.isStreaming && msg.content.length > 300) {
        final chunks = ChatBubble.splitLongMessage(msg.content);
        for (int i = 0; i < chunks.length; i++) {
          result.add(msg.copyWith(
            content: chunks[i],
            characterName: i == 0 ? msg.characterName : null,
          ));
        }
      } else {
        result.add(msg);
      }

      lastVisible = msg;
    }
    return result;
  }

  Widget _buildMessagesList() {
    // Check for empty search results before building display items
    if (_searchQuery.isNotEmpty && _filteredMessages.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              'No messages found',
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final displayItems = _buildDisplayItems();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
      itemCount: displayItems.length +
          (_isStreaming ? 1 : 0) +
          (_isWelcomeState ? 1 : 0),
      itemBuilder: (context, index) {
        final msgCount = displayItems.length + (_isWelcomeState ? 1 : 0);

        // Typing indicator at the very end
        if (index == msgCount && _isStreaming) {
          const character = AiCharacter.aristotle;
          return TypingIndicator(
            color: character.themeColor,
            characterName: character.name,
            avatarAsset: character.avatarAsset,
          );
        }

        // Conversation starters after all display items (welcome state only)
        if (_isWelcomeState && index == displayItems.length) {
          return _buildConversationStarters();
        }

        if (index >= displayItems.length) return const SizedBox.shrink();

        final item = displayItems[index];

        // Date/time divider
        if (item is DateTime) {
          return ChatDateDivider(timestamp: item);
        }

        // Message bubble
        if (item is ChatMessage) {
          if (item.isError) return _buildErrorCard(item);
          return ChatBubble(
            message: item,
            showAvatar: item.characterName != null,
          );
        }

        return const SizedBox.shrink();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                color: AppColors.textSecondary,
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
                    color: AppColors.textSecondary,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSizes.s12, AppSizes.s12, AppSizes.s12, AppSizes.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
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
                decoration: NeumorphicStyles.inset(
                  context,
                  borderRadius: 24,
                ),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: isDisabled
                          ? character.themeColor.withValues(alpha: 0.5)
                          : AppColors.textSecondary,
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
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                    ? (isDark ? AppColors.darkBorder : AppColors.border)
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
                color: AppColors.textSecondary,
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