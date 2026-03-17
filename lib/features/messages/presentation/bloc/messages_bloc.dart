import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/websocket_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import '../../data/models/message_model.dart';
import 'messages_event.dart';
import 'messages_state.dart';

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  final Dio _dio;
  final WebSocketService _wsService;
  final TokenStorage _tokenStorage;
  StreamSubscription? _wsSubscription;
  
  String? _currentUserId;

  MessagesBloc(this._dio, this._wsService, this._tokenStorage) : super(MessagesInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendMessage>(_onSendMessage);
    on<ResendMessage>(_onResendMessage);
    on<MarkMessagesAsRead>(_onMarkMessagesAsRead);
    on<OnWebSocketEvent>(_onWebSocketEvent);

    _wsSubscription = _wsService.events.listen((event) {
      add(OnWebSocketEvent(event));
    });
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<MessagesState> emit) async {
    emit(MessagesLoading());
    try {
      _currentUserId ??= await _tokenStorage.getUserId();
      
      final response = await _dio.get('/chats/${event.chatId}/messages', queryParameters: {
        'limit': 50,
      });
      
      final Map<String, dynamic> responseData = response.data;
      final List<dynamic> messagesData = responseData['data']['messages'];
      final messages = messagesData.map((json) => MessageModel.fromJson(json)).toList();
      
      emit(MessagesLoaded(
        messages: messages,
        currentUserId: _currentUserId ?? '',
        hasReachedMax: messagesData.length < 50,
      ));
    } catch (e) {
      emit(MessagesError(e.toString()));
    }
  }

  Future<void> _onLoadMoreMessages(LoadMoreMessages event, Emitter<MessagesState> emit) async {
    if (state is MessagesLoaded) {
      final currentState = state as MessagesLoaded;
      if (currentState.hasReachedMax || currentState.messages.isEmpty) return;
      
      try {
        final lastMessageTimestamp = currentState.messages.last.createdAt.toIso8601String();
        final response = await _dio.get('/chats/${event.chatId}/messages', queryParameters: {
          'limit': 50,
          'before': lastMessageTimestamp,
        });
        
        final Map<String, dynamic> responseData = response.data;
        final List<dynamic> newMessagesData = responseData['data']['messages'];
        final newMessages = newMessagesData.map((json) => MessageModel.fromJson(json)).toList();
        
        emit(currentState.copyWith(
          messages: List.from(currentState.messages)..addAll(newMessages),
          hasReachedMax: newMessagesData.length < 50,
        ));
      } catch (e) {
        // Silently fail pagination error for now
      }
    }
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<MessagesState> emit) async {
    if (state is MessagesLoaded) {
      final currentState = state as MessagesLoaded;
      
      final clientMessageId = const Uuid().v4();
      final now = DateTime.now();
      final newMessage = MessageModel(
        id: clientMessageId,
        chatId: event.chatId,
        authorId: _currentUserId ?? '',
        text: event.text,
        createdAt: now,
        updatedAt: now,
        status: MessageStatus.sending,
        clientMessageId: clientMessageId,
      );
      
      final updatedMessages = List<MessageModel>.from(currentState.messages)..insert(0, newMessage);
      emit(currentState.copyWith(messages: updatedMessages));
      
      try {
        final response = await _dio.post('/chats/${event.chatId}/messages', data: {
          'body': event.text,
          'client_message_id': clientMessageId,
        });
        
        final serverMessage = MessageModel.fromJson(response.data['data']);
        
        final resolvedMessages = updatedMessages.map((m) {
          return m.clientMessageId == clientMessageId ? serverMessage : m;
        }).toList();
        
        emit(currentState.copyWith(messages: resolvedMessages));
      } catch (e) {
        final failedMessages = updatedMessages.map((m) {
          return m.clientMessageId == clientMessageId 
              ? m.copyWith(status: MessageStatus.failed) 
              : m;
        }).toList();
        
        emit(currentState.copyWith(messages: failedMessages));
      }
    }
  }

  Future<void> _onResendMessage(ResendMessage event, Emitter<MessagesState> emit) async {
    if (state is MessagesLoaded) {
      final currentState = state as MessagesLoaded;
      final messageToResend = currentState.messages.firstWhere((m) => m.clientMessageId == event.clientMessageId);
      
      final updatedMessages = currentState.messages.map((m) {
        return m.clientMessageId == event.clientMessageId 
            ? m.copyWith(status: MessageStatus.sending) 
            : m;
      }).toList();
      
      emit(currentState.copyWith(messages: updatedMessages));
      
      try {
        final response = await _dio.post('/chats/${event.chatId}/messages', data: {
          'body': messageToResend.text,
          'client_message_id': event.clientMessageId,
        });
        
        final serverMessage = MessageModel.fromJson(response.data['data']);
        
        final resolvedMessages = updatedMessages.map((m) {
          return m.clientMessageId == event.clientMessageId ? serverMessage : m;
        }).toList();
        
        emit(currentState.copyWith(messages: resolvedMessages));
      } catch (e) {
        final failedMessages = updatedMessages.map((m) {
          return m.clientMessageId == event.clientMessageId 
              ? m.copyWith(status: MessageStatus.failed) 
              : m;
        }).toList();
        
        emit(currentState.copyWith(messages: failedMessages));
      }
    }
  }


  Future<void> _onMarkMessagesAsRead(MarkMessagesAsRead event, Emitter<MessagesState> emit) async {
    try {
      await _dio.post('/chats/${event.chatId}/read', data: {
        'up_to': event.upTo.toUtc().toIso8601String(),
      });
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _onWebSocketEvent(OnWebSocketEvent event, Emitter<MessagesState> emit) async {
    if (state is MessagesLoaded) {
      final currentState = state as MessagesLoaded;
      final eventData = event.event;

      if (eventData['type'] == 'new_message') {
        final messageData = eventData['data'];
        if (messageData == null) return;
        
        final chatId = messageData['chat_id'];
        
        // Only if it's the current chat and not my own message (already handled via optimistic UI)
        if (currentState.messages.isNotEmpty && 
            currentState.messages.first.chatId == chatId &&
            messageData['sender_id'] != _currentUserId) {
          
          final newMessage = MessageModel.fromJson(messageData);
          final updatedMessages = List<MessageModel>.from(currentState.messages)..insert(0, newMessage);
          
          emit(currentState.copyWith(messages: updatedMessages));
        }
      }
    }
  }
}
