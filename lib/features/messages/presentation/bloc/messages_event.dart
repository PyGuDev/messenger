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

  const SendMessage({required this.chatId, required this.text});

  @override
  List<Object?> get props => [chatId, text];
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

