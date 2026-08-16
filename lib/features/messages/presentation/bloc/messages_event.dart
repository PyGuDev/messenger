import 'package:equatable/equatable.dart';

abstract class MessagesEvent extends Equatable {
  const MessagesEvent();

  @override
  List<Object?> get props => [];
}

abstract class ChatSessionEvent extends MessagesEvent {
  String get chatId;

  const ChatSessionEvent();
}

class LoadMessages extends ChatSessionEvent {
  @override
  final String chatId;

  const LoadMessages(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class LoadMoreMessages extends ChatSessionEvent {
  @override
  final String chatId;

  const LoadMoreMessages(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class SendMessage extends ChatSessionEvent {
  @override
  final String chatId;
  final String text;
  final String? replyToMessageId;

  const SendMessage({
    required this.chatId,
    required this.text,
    this.replyToMessageId,
  });

  @override
  List<Object?> get props => [chatId, text, replyToMessageId];
}

class ResendMessage extends ChatSessionEvent {
  @override
  final String chatId;
  final String clientMessageId;

  const ResendMessage({required this.chatId, required this.clientMessageId});

  @override
  List<Object?> get props => [chatId, clientMessageId];
}

class MarkMessagesAsRead extends ChatSessionEvent {
  @override
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

class SendVoiceMessage extends ChatSessionEvent {
  @override
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

class EditMessage extends ChatSessionEvent {
  @override
  final String chatId;
  final String messageId;
  final String newBody;

  const EditMessage({
    required this.chatId,
    required this.messageId,
    required this.newBody,
  });

  @override
  List<Object?> get props => [chatId, messageId, newBody];
}

class DeleteMessage extends ChatSessionEvent {
  @override
  final String chatId;
  final String messageId;
  final bool forEveryone;

  const DeleteMessage({
    required this.chatId,
    required this.messageId,
    required this.forEveryone,
  });

  @override
  List<Object?> get props => [chatId, messageId, forEveryone];
}

class ForwardMessages extends ChatSessionEvent {
  @override
  final String chatId;
  final List<String> messageIds;

  const ForwardMessages({required this.chatId, required this.messageIds});

  @override
  List<Object?> get props => [chatId, messageIds];
}

class SendVideoMessage extends ChatSessionEvent {
  @override
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

class SendFileMessage extends ChatSessionEvent {
  @override
  final String chatId;
  final String filePath;
  final String fileName;
  final String typeContent;
  final String? replyToMessageId;

  const SendFileMessage({
    required this.chatId,
    required this.filePath,
    required this.fileName,
    required this.typeContent,
    this.replyToMessageId,
  });

  @override
  List<Object?> get props => [
    chatId,
    filePath,
    fileName,
    typeContent,
    replyToMessageId,
  ];
}
