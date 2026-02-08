import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/models/chat_message_extended.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/providers/character_provider.dart';
import 'chat_bubble.dart';
import 'typing_indicator.dart';

/// Messenger-Style Chat Window
/// Full chat interface that appears when floating button is tapped
class MessengerChatWindow extends ConsumerStatefulWidget {
  const MessengerChatWindow({super.key});

  @override
  ConsumerState<MessengerChatWindow> createState() => _MessengerChatWindowState();
}

class _MessengerChatWindowState extends ConsumerState<MessengerChatWindow> {
  final _chatRepo = ChatRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = true;
  bool _isStreaming = false;

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
    // ✅ PHASE 3.1: Update repository when character changes
    // ✅ PHASE 3.4: Pass contextual greeting for returning characters
    final character = ref.read(activeCharacterProvider);
    final contextManager = ref.read(characterContextManagerProvider);
    final greeting = contextManager.getPersonalizedGreeting();
    // Only pass greeting if it differs from default (meaning there's context)
    final contextGreeting = greeting != character.greeting ? greeting : null;
    _chatRepo.setCharacter(character, contextGreeting: contextGreeting);
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

  /// Expand messages - split long assistant messages into multiple bubbles
  List<ChatMessage> get _expandedMessages {
    final expanded = <ChatMessage>[];
    for (final msg in _messages) {
      if (msg.role == 'assistant' && !msg.isStreaming && msg.content.length > 300) {
        final chunks = ChatBubble.splitLongMessage(msg.content);
        for (int i = 0; i < chunks.length; i++) {
          expanded.add(msg.copyWith(
            content: chunks[i],
            characterName: i == 0 ? msg.characterName : null,
          ));
        }
      } else {
        expanded.add(msg);
      }
    }
    return expanded;
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
                    ? Center(
                        child: CircularProgressIndicator(
                          color: ref.watch(activeCharacterProvider).themeColor,
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final displayMessages = _expandedMessages;
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.s4,
                              vertical: AppSizes.s8,
                            ),
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
                    color: AppColors.white.withOpacity(0.9),
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

  Widget _buildInputArea() {
    return Material(
      color: Colors.white,
      child: Container(
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
            Builder(
              builder: (context) {
                final character = ref.watch(activeCharacterProvider);
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _controller.text.isEmpty
                        ? null
                        : character.themeGradient,
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
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ), // Material widget close
    );
  }
}