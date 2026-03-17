import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_event.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_state.dart';
import '../../data/models/message_model.dart';
import 'package:messenger/shared/widgets/custom_text_field.dart';
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

  Widget _buildMessageBubble(MessageModel message, String currentUserId) {
    final isMine = message.authorId == currentUserId;

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
                'User ${message.authorId}', // Placeholder name
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
        title: Text(widget.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bgPrimary,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<MessagesBloc, MessagesState>(
              listener: (context, state) {
                if (state is MessagesLoaded) {
                  // Mark as read when messages load
                  context.read<MessagesBloc>().add(MarkMessagesAsRead(chatId: widget.chatId, upTo: DateTime.now()));
                }
              },
              builder: (context, state) {
                if (state is MessagesLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is MessagesLoaded) {
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Display from bottom to top
                    itemCount: state.messages.length + (state.hasReachedMax ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (index >= state.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildMessageBubble(state.messages[index], state.currentUserId);
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
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: AppColors.bgPrimary,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _textController,
                hintText: AppLocalizations.of(context)!.messages,
                onSubmitted: (_) => _sendMessage(),
                // no prefix icon here to make more space for text
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isSendButtonActive ? AppColors.accentBlue : AppColors.borderDefault,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _isSendButtonActive ? _sendMessage : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
