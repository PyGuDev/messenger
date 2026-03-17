import 'package:equatable/equatable.dart';
import '../../data/models/chat_model.dart';

abstract class ChatsState extends Equatable {
  const ChatsState();

  @override
  List<Object?> get props => [];
}

class ChatsInitial extends ChatsState {}

class ChatsLoading extends ChatsState {}

class ChatsLoaded extends ChatsState {
  final List<ChatModel> chats;
  final bool hasReachedMax;

  const ChatsLoaded(this.chats, {this.hasReachedMax = false});

  ChatsLoaded copyWith({
    List<ChatModel>? chats,
    bool? hasReachedMax,
  }) {
    return ChatsLoaded(
      chats ?? this.chats,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [chats, hasReachedMax];
}


class ChatsError extends ChatsState {
  final String message;

  const ChatsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ChatCreatedSuccess extends ChatsState {
  final String chatId;

  const ChatCreatedSuccess(this.chatId);

  @override
  List<Object?> get props => [chatId];
}
