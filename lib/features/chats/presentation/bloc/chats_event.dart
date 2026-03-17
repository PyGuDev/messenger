import 'package:equatable/equatable.dart';

abstract class ChatsEvent extends Equatable {
  const ChatsEvent();

  @override
  List<Object?> get props => [];
}

class LoadChats extends ChatsEvent {}

class LoadMoreChats extends ChatsEvent {}

class CreateChat extends ChatsEvent {
  final String userId;

  const CreateChat(this.userId);

  @override
  List<Object?> get props => [userId];
}

class OnWebSocketEvent extends ChatsEvent {
  final Map<String, dynamic> event;
  const OnWebSocketEvent(this.event);

  @override
  List<Object?> get props => [event];
}
