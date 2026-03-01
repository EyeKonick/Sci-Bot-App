import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_feedback.dart';
import '../../../../shared/models/chat_message_extended.dart';
import '../../../../shared/models/scenario_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/providers/character_provider.dart';
import '../../../profile/data/providers/user_profile_provider.dart';
import 'chat_bubble.dart';
import 'chat_date_divider.dart';
import 'typing_indicator.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../../shared/widgets/neumorphic_styles.dart';

/// Messenger-Style Chat Window (INTERACTION CHANNEL ONLY)
///
/// This is an interaction-channel interface. All messages displayed here
/// are InteractionMessages or UserMessages. Narration content belongs
/// in the chathead speech bubbles (NarrationMessage), not here.
///
/// Full chat interface that appears when floating button is tapped
class MessengerChatWindow extends ConsumerStatefulWidget {
  const MessengerChatWindow({super.key});

  @override
  ConsumerState<MessengerChatWindow> createState() => _MessengerChatWindowState();
}

class _MessengerChatWindowState extends ConsumerState<MessengerChatWindow> {
  /// Topic-specific conversation starters for each expert character
  static const Map<String, List<String>> _expertConversationStarters = {
    'herophilus': [
      'How does blood flow through the heart?',
      'Explain the difference between arteries and veins',
      'What happens during gas exchange in the lungs?',
      'Why is the circulatory system important?',
    ],
    'mendel': [
      'How do traits pass from parents to offspring?',
      'What is a Punnett square used for?',
      'Explain dominant and recessive alleles',
      'What causes genetic variation?',
    ],
    'odum': [
      'How does energy flow in an ecosystem?',
      'What is a food chain vs food web?',
      'Why are decomposers important?',
      'Explain the energy pyramid levels',
    ],
    'aristotle': [
      'What topics can I study today?',
      'How do I navigate the lessons?',
      'Tell me about the AI tutors',
      'How does progress tracking work?',
    ],
  };

  final _chatRepo = ChatRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = true;
  bool _isStreaming = false;

  // Track keyboard visibility for auto-scroll
  double _previousBottomInset = 0;

  // ✅ PHASE 3.1: Stream subscription for character switching
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
    // Ensure scenario is active. On home/topics screens this will be
    // aristotle_general (already set by HomeScreen). On topic-specific
    // screens the scenario will be set by the host screen in later phases.
    final currentScenario = _chatRepo.currentScenario;
    if (currentScenario == null) {
      // Fallback: if no scenario active yet, activate aristotle_general
      final scenario = ChatScenario.aristotleGeneral();
      _chatRepo.setScenario(scenario);
    }
  }

  /// ✅ PHASE 3.1: Listen to message stream for character switching
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

      // Set user's name for personalized AI responses
      final profile = await ref.read(userProfileProvider.future);
      _chatRepo.setUserName(profile?.name);

      if (!mounted) return;
      
      // Get active character and context manager
      final character = ref.read(activeCharacterProvider);
      final contextManager = ref.read(characterContextManagerProvider);
      final personalizedGreeting = contextManager.getPersonalizedGreeting();
      
      setState(() {
        if (_chatRepo.conversationHistory.isEmpty) {
          // Use personalized greeting based on context
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
    
    final userMsg = ChatMessage.user(text);
    setState(() {
      _messages.add(userMsg);
      _isStreaming = true;
    });
    
    _scrollToBottom();

    ChatMessage? aiMessage;
    
    // Get current character
    final character = ref.read(activeCharacterProvider);
    
    await for (final message in _chatRepo.sendMessageStream(text, character: character)) {
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
    _messageSubscription?.cancel(); // ✅ PHASE 3.1: Cancel subscription
    super.dispose();
  }

  /// Whether the chat is offline (OpenAI not configured)
  bool get _isOffline => !_chatRepo.isConfigured;

  /// Whether messages list only contains the initial greeting
  bool get _isWelcomeState =>
      _messages.length == 1 &&
      _messages.first.role == 'assistant' &&
      !_messages.first.isError;

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
  /// Dividers are only injected for general and lessonMenu scenarios.
  List<Object> _buildDisplayItems() {
    final showDividers =
        _chatRepo.currentScenario?.type == ScenarioType.general ||
        _chatRepo.currentScenario?.type == ScenarioType.lessonMenu;

    final result = <Object>[];
    ChatMessage? lastVisible;

    for (final msg in _messages) {
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

  @override
  Widget build(BuildContext context) {
    // Auto-scroll when keyboard opens so last message stays visible
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0 && _previousBottomInset == 0) {
      // Keyboard just opened — scroll after AnimatedPadding settles
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _scrollToBottom();
      });
    }
    _previousBottomInset = bottomInset;

    // CRITICAL FIX: Wrap in MediaQuery to handle keyboard properly
    return MediaQuery.removePadding(
      context: context,
      removeTop: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.shadowLight.withValues(alpha: 0.8),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - FIXED HEIGHT
              _buildHeader(),

              const Divider(height: 1),

              // Phase 4: Offline banner
              if (_isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.s12,
                    vertical: AppSizes.s8,
                  ),
                  color: AppFeedback.warningColor.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 14, color: AppColors.warning),
                      const SizedBox(width: AppSizes.s8),
                      Expanded(
                        child: Text(
                          'Chat requires internet connection.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages - FLEXIBLE
              Flexible(
                child: _isLoading
                    ? LoadingSpinner(
                        message: 'Loading chat...',
                        color: ref.watch(activeCharacterProvider).themeColor,
                      )
                    : Builder(
                        builder: (context) {
                          final displayItems = _buildDisplayItems();
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.s4,
                              vertical: AppSizes.s8,
                            ),
                            itemCount: displayItems.length +
                                (_isStreaming ? 1 : 0) +
                                (_isWelcomeState ? 1 : 0),
                            itemBuilder: (context, index) {
                              final msgCount = displayItems.length +
                                  (_isWelcomeState ? 1 : 0);

                              // Typing indicator at the very end
                              if (index == msgCount && _isStreaming) {
                                final character = ref.read(activeCharacterProvider);
                                return TypingIndicator(
                                  color: character.themeColor,
                                  characterName: character.name,
                                  avatarAsset: character.avatarAsset,
                                );
                              }

                              // Conversation starters after all display items
                              if (_isWelcomeState && index == displayItems.length) {
                                return _buildConversationStarters();
                              }

                              if (index >= displayItems.length) {
                                return const SizedBox.shrink();
                              }

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
    // Get current character from provider
    final character = ref.watch(activeCharacterProvider);

    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      decoration: BoxDecoration(
        gradient: character.themeGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSizes.radiusL),
          topRight: Radius.circular(AppSizes.radiusL),
        ),
      ),
      child: Row(
        children: [
          // Avatar - Use character's avatar
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

          // Title - Use character's name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  /// Phase 4: Conversation starter chips below greeting
  Widget _buildConversationStarters() {
    final character = ref.read(activeCharacterProvider);
    final starters = _expertConversationStarters[character.id] ??
        _expertConversationStarters['aristotle']!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.s12, AppSizes.s4, AppSizes.s12, AppSizes.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking:',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          Wrap(
            spacing: AppSizes.s8,
            runSpacing: AppSizes.s8,
            children: starters.map((starter) {
              return ActionChip(
                label: Text(
                  starter,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: character.themeColor,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: character.themeColor.withValues(alpha: 0.08),
                side: BorderSide(
                  color: character.themeColor.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
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
    final character = ref.read(activeCharacterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s8,
        vertical: AppSizes.s4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s12),
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
                  size: 18,
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Text(
                    'Connection Error',
                    style: AppTextStyles.bodySmall.copyWith(
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
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Row(
              children: [
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: _isStreaming ? null : () => _retryLastMessage(),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Retry', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: character.themeColor,
                      side: BorderSide(color: character.themeColor),
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  'Check your connection',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
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
    final character = ref.read(activeCharacterProvider);
    final retryStream = _chatRepo.retryLastMessage(character: character);

    if (retryStream == null) return;

    setState(() {
      _isStreaming = true;
    });

    ChatMessage? aiMessage;

    await for (final message in retryStream) {
      setState(() {
        if (message.role == 'user') return;

        if (aiMessage == null) {
          aiMessage = message;
          _messages.add(message);
        } else {
          final idx = _messages.indexOf(aiMessage!);
          if (idx != -1) {
            _messages[idx] = message;
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

  /// Get contextual placeholder text based on scenario
  String _getContextualPlaceholder() {
    final character = ref.read(activeCharacterProvider);
    final scenario = ref.read(currentScenarioProvider);

    if (scenario?.type == ScenarioType.lessonMenu) {
      final topicName = _getTopicNameFromId(scenario?.context['topicId'] ?? '');
      return 'Ask ${character.name} about $topicName...';
    }

    return 'Ask ${character.name} a question...';
  }

  /// Map topic IDs to display names
  String _getTopicNameFromId(String topicId) {
    switch (topicId) {
      case 'topic_body_systems':
        return 'Body Systems';
      case 'topic_heredity':
        return 'Heredity';
      case 'topic_energy':
        return 'Energy in Ecosystems';
      default:
        return 'Science';
    }
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final character = ref.watch(activeCharacterProvider);
    final bool isDisabled = _isStreaming;

    // Contextual hint text based on state
    final String hintText = isDisabled
        ? '${character.name} is thinking...'
        : _getContextualPlaceholder();

    return Material(
      color: isDark ? AppColors.darkBackground : AppColors.background,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.background,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text input with animated border
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
                    enabled: !isDisabled,
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
                gradient: (_controller.text.isEmpty || isDisabled)
                    ? null
                    : character.themeGradient,
                color: (_controller.text.isEmpty || isDisabled)
                    ? (isDark ? AppColors.darkBorder : AppColors.border)
                    : null,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (_controller.text.isEmpty || isDisabled) ? null : _sendMessage,
                  customBorder: const CircleBorder(),
                  child: const Icon(
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
    ), // Material widget close
    );
  }
}