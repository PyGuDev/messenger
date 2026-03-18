import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_event.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_state.dart';
import '../../data/models/message_model.dart';

import 'package:messenger/shared/widgets/error_display.dart';

class MessagesScreen extends StatefulWidget {
  final String chatId;
  final String title;

  const MessagesScreen({super.key, required this.chatId, required this.title});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendButtonActive = false;
  bool _emojiVisible = false;

  @override
  void initState() {
    super.initState();
    context.read<MessagesBloc>().add(LoadMessages(widget.chatId));

    _textController.addListener(() {
      final isNotEmpty = _textController.text.trim().isNotEmpty;
      if (isNotEmpty != _isSendButtonActive) {
        setState(() {
          _isSendButtonActive = isNotEmpty;
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        context.read<MessagesBloc>().add(LoadMoreMessages(widget.chatId));
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<MessagesBloc>().add(SendMessage(chatId: widget.chatId, text: text));
      _textController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat.Hm().format(time); // HH:mm
  }

  Widget _buildMessageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: AppColors.textOnAccent);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: AppColors.textOnAccent);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: AppColors.textOnAccent);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blueAccent);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 12, color: Colors.redAccent);
    }
  }

  Widget _buildMessageBubble(MessageModel message, String currentUserId, Map<String, String> userNames) {
    final isMine = message.authorId == currentUserId;
    final authorName = userNames[message.authorId] ?? 'User';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMine ? AppColors.bgMessageOut : AppColors.bgMessageIn,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              Text(
                authorName,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: isMine ? AppColors.textOnAccent : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isMine ? AppColors.textOnAccent.withValues(alpha: 0.7) : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  if (message.status == MessageStatus.failed)
                    GestureDetector(
                      onTap: () {
                        context.read<MessagesBloc>().add(ResendMessage(
                          chatId: widget.chatId,
                          clientMessageId: message.clientMessageId ?? '',
                        ));
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 12, color: Colors.redAccent),
                          Text('Retry', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                        ],
                      ),
                    )
                  else
                    _buildMessageStatus(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 48,
        leading: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: AppColors.accentBlue),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.textSecondary, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderDefault, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<MessagesBloc, MessagesState>(
              listener: (context, state) {
                if (state is MessagesLoaded) {
                  context.read<MessagesBloc>().add(MarkMessagesAsRead(chatId: widget.chatId, upTo: DateTime.now()));
                }
              },
              builder: (context, state) {
                if (state is MessagesLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is MessagesLoaded) {
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length + (state.hasReachedMax ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (index >= state.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildMessageBubble(state.messages[index], state.currentUserId, state.userNames);
                    },
                  );
                } else if (state is MessagesError) {
                  return ErrorDisplay(
                    message: state.message,
                    onRetry: () => context.read<MessagesBloc>().add(LoadMessages(widget.chatId)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildMessageInput(),
          _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.attach_file, color: AppColors.textTertiary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _emojiVisible = !_emojiVisible;
                        });
                        if (_emojiVisible) {
                          FocusScope.of(context).unfocus();
                        }
                      },
                      child: Icon(
                        _emojiVisible ? Icons.keyboard : Icons.sentiment_satisfied_alt,
                        color: _emojiVisible ? AppColors.accentBlue : AppColors.textTertiary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: AppColors.textTertiary,
                            fontFamily: 'Inter',
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSendButtonActive ? _sendMessage : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isSendButtonActive ? AppColors.accentBlue : AppColors.borderDefault,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _isSendButtonActive ? Icons.send : Icons.mic,
                    color: _isSendButtonActive ? Colors.white : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Offstage(
      offstage: !_emojiVisible,
      child: EmojiPicker(
        textEditingController: _textController,
        onEmojiSelected: (Category? category, Emoji emoji) {
          setState(() {
            _isSendButtonActive = _textController.text.trim().isNotEmpty;
          });
        },
        config: Config(
          height: 256,
          checkPlatformCompatibility: false,
          emojiTextStyle: GoogleFonts.notoColorEmoji(
            fontSize: 28,
          ),
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28 *
                (foundation.defaultTargetPlatform == TargetPlatform.iOS
                    ? 1.2
                    : 1.0),
            columns: 7,
            backgroundColor: AppColors.bgPrimary,
            noRecents: const Text(
              'Нет недавних эмодзи',
              style: TextStyle(fontSize: 16, color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: AppColors.bgPrimary,
            indicatorColor: AppColors.accentBlue,
            iconColorSelected: AppColors.accentBlue,
            iconColor: AppColors.textTertiary,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(
            showBackspaceButton: true,
            showSearchViewButton: true,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: AppColors.bgPrimary,
            buttonIconColor: AppColors.textTertiary,
            hintText: 'Поиск эмодзи...',
          ),
        ),
      ),
    );
  }
}
