import 'package:equatable/equatable.dart';

abstract class MessagesEvent extends Equatable {
  const MessagesEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends MessagesEvent {
  final String chatId;
  
  const LoadMessages(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class LoadMoreMessages extends MessagesEvent {
  final String chatId;
  
  const LoadMoreMessages(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class SendMessage extends MessagesEvent {
  final String chatId;
  final String text;
  final String? replyToMessageId;

  const SendMessage({required this.chatId, required this.text, this.replyToMessageId});

  @override
  List<Object?> get props => [chatId, text, replyToMessageId];
}

class ResendMessage extends MessagesEvent {
  final String chatId;
  final String clientMessageId;

  const ResendMessage({required this.chatId, required this.clientMessageId});

  @override
  List<Object?> get props => [chatId, clientMessageId];
}

class MarkMessagesAsRead extends MessagesEvent {
  final String chatId;
  final DateTime upTo;

  const MarkMessagesAsRead({required this.chatId, required this.upTo});

  @override
  List<Object?> get props => [chatId, upTo];
}

class OnWebSocketEvent extends MessagesEvent {
  final Map<String, dynamic> event;
  const OnWebSocketEvent(this.event);

  @override
  List<Object?> get props => [event];
}

class SendVoiceMessage extends MessagesEvent {
  final String chatId;
  final String filePath;
  final Duration duration;
  final String? replyToMessageId;

  const SendVoiceMessage({
    required this.chatId,
    required this.filePath,
    required this.duration,
    this.replyToMessageId,
  });

  @override
  List<Object?> get props => [chatId, filePath, duration, replyToMessageId];
}

class EditMessage extends MessagesEvent {
  final String chatId;
  final String messageId;
  final String newBody;

  const EditMessage({required this.chatId, required this.messageId, required this.newBody});

  @override
  List<Object?> get props => [chatId, messageId, newBody];
}

class DeleteMessage extends MessagesEvent {
  final String chatId;
  final String messageId;
  final bool forEveryone;

  const DeleteMessage({required this.chatId, required this.messageId, required this.forEveryone});

  @override
  List<Object?> get props => [chatId, messageId, forEveryone];
}

class ForwardMessages extends MessagesEvent {
  final String chatId;
  final List<String> messageIds;

  const ForwardMessages({required this.chatId, required this.messageIds});

  @override
  List<Object?> get props => [chatId, messageIds];
}

class SendVideoMessage extends MessagesEvent {
  final String chatId;
  final String filePath;
  final Duration duration;
  final String? replyToMessageId;

  const SendVideoMessage({
    required this.chatId,
    required this.filePath,
    required this.duration,
    this.replyToMessageId,
  });

  @override
  List<Object?> get props => [chatId, filePath, duration, replyToMessageId];
}
