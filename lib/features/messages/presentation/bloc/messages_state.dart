import 'package:equatable/equatable.dart';
import '../../data/models/message_model.dart';

abstract class MessagesState extends Equatable {
  const MessagesState();

  @override
  List<Object?> get props => [];
}

class MessagesInitial extends MessagesState {}

class MessagesLoading extends MessagesState {}

class MessagesLoaded extends MessagesState {
  final List<MessageModel> messages;
  final bool hasReachedMax;
  final String currentUserId; // Used to identify own vs other messages
  final Map<String, String> userNames; // userId -> displayName

  const MessagesLoaded({
    required this.messages,
    this.hasReachedMax = false,
    required this.currentUserId,
    this.userNames = const {},
  });

  MessagesLoaded copyWith({
    List<MessageModel>? messages,
    bool? hasReachedMax,
    String? currentUserId,
    Map<String, String>? userNames,
  }) {
    return MessagesLoaded(
      messages: messages ?? this.messages,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentUserId: currentUserId ?? this.currentUserId,
      userNames: userNames ?? this.userNames,
    );
  }

  @override
  List<Object?> get props => [messages, hasReachedMax, currentUserId, userNames];
}

class MessagesError extends MessagesState {
  final String message;

  const MessagesError(this.message);

  @override
  List<Object?> get props => [message];
}
