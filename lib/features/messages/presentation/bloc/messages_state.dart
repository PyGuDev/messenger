import 'package:equatable/equatable.dart';
import '../../data/models/message_model.dart';

abstract class MessagesState extends Equatable {
  final String chatId;

  const MessagesState(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class MessagesInitial extends MessagesState {
  const MessagesInitial(super.chatId);
}

class MessagesLoading extends MessagesState {
  const MessagesLoading(super.chatId);
}

class MessagesOfflineUnavailable extends MessagesState {
  const MessagesOfflineUnavailable(super.chatId);
}

class MessagesLoaded extends MessagesState {
  final List<MessageModel> messages;
  final bool hasReachedMax;
  final String currentUserId; // Used to identify own vs other messages
  final Map<String, String> userNames; // userId -> displayName

  const MessagesLoaded({
    required String chatId,
    required this.messages,
    this.hasReachedMax = false,
    required this.currentUserId,
    this.userNames = const {},
  }) : super(chatId);

  MessagesLoaded copyWith({
    String? chatId,
    List<MessageModel>? messages,
    bool? hasReachedMax,
    String? currentUserId,
    Map<String, String>? userNames,
  }) {
    return MessagesLoaded(
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentUserId: currentUserId ?? this.currentUserId,
      userNames: userNames ?? this.userNames,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    messages,
    hasReachedMax,
    currentUserId,
    userNames,
  ];
}

class MessagesError extends MessagesState {
  final String message;

  const MessagesError(super.chatId, this.message);

  @override
  List<Object?> get props => [...super.props, message];
}
