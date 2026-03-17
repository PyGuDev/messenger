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

  const MessagesLoaded({
    required this.messages,
    this.hasReachedMax = false,
    required this.currentUserId,
  });

  MessagesLoaded copyWith({
    List<MessageModel>? messages,
    bool? hasReachedMax,
    String? currentUserId,
  }) {
    return MessagesLoaded(
      messages: messages ?? this.messages,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  List<Object?> get props => [messages, hasReachedMax, currentUserId];
}

class MessagesError extends MessagesState {
  final String message;

  const MessagesError(this.message);

  @override
  List<Object?> get props => [message];
}
