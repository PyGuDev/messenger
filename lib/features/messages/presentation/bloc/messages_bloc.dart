import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/network/user_service.dart';
import 'package:flutter/foundation.dart' as import_foundation;
import 'package:messenger/core/security/token_storage.dart';
import '../../data/models/message_model.dart';
import 'messages_event.dart';
import 'messages_state.dart';

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  final Dio _dio;
  final WebSocketService _wsService;
  final TokenStorage _tokenStorage;
  final UserService _userService;
  StreamSubscription? _wsSubscription;
  
  String? _currentUserId;

  MessagesBloc(this._dio, this._wsService, this._tokenStorage, this._userService) : super(MessagesInitial()) {
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

  /// Get the current user ID — first try TokenStorage, then extract from JWT.
  Future<String?> _getCurrentUserId() async {
    if (_currentUserId != null) return _currentUserId;

    _currentUserId = await _tokenStorage.getUserId();
    
    // Always try to extract from JWT if it matches what's in headers
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      final extractedId = UserService.extractUserIdFromToken(token);
      if (extractedId != null) {
        _currentUserId = extractedId;
        await _tokenStorage.saveUserId(extractedId);
      }
    }
    
    return _currentUserId;
  }

  /// Resolve display names for unique author IDs in the messages.
  Future<Map<String, String>> _resolveUserNames(
    List<MessageModel> messages,
    Map<String, String> existingNames,
  ) async {
    final names = Map<String, String>.from(existingNames);
    final unknownIds = messages
        .map((m) => m.authorId)
        .toSet()
        .where((id) => !names.containsKey(id));

    for (final userId in unknownIds) {
      final profile = await _userService.getUser(userId);
      names[userId] = profile.displayName;
    }
    return names;
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<MessagesState> emit) async {
    emit(MessagesLoading());
    try {
      await _getCurrentUserId();
      
      final response = await _dio.get('/chats/${event.chatId}/messages', queryParameters: {
        'limit': 50,
      });
      
      final Map<String, dynamic> responseData = response.data;
      final List<dynamic> messagesData = responseData['data']['messages'];
      final messages = messagesData.map((json) => MessageModel.fromJson(json)).toList();

      final userNames = await _resolveUserNames(messages, {});
      
      emit(MessagesLoaded(
        chatId: event.chatId,
        messages: messages,
        currentUserId: _currentUserId ?? '',
        hasReachedMax: messagesData.length < 50,
        userNames: userNames,
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

        final userNames = await _resolveUserNames(newMessages, currentState.userNames);
        
        emit(currentState.copyWith(
          messages: List.from(currentState.messages)..addAll(newMessages),
          hasReachedMax: newMessagesData.length < 50,
          userNames: userNames,
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
        replyToMessageId: event.replyToMessageId,
      );
      
      final updatedMessages = List<MessageModel>.from(currentState.messages)..insert(0, newMessage);
      emit(currentState.copyWith(messages: updatedMessages));
      
      try {
        final data = <String, dynamic>{
          'body': event.text,
          'client_message_id': clientMessageId,
        };
        if (event.replyToMessageId != null) {
          data['reply_to_message_id'] = event.replyToMessageId;
        }

        final response = await _dio.post('/chats/${event.chatId}/messages', data: data);
        
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
        final payload = eventData['payload'];
        if (payload == null) return;
        
        final chatId = payload['chat_id']?.toString();
        final messageData = payload['message'];
        if (messageData == null) return;
        
        // Only if it's the current chat and not my own message (already handled via optimistic UI)
        if (currentState.chatId == chatId &&
            (messageData['AuthorID'] ?? messageData['author_id'] ?? messageData['sender_id'])?.toString() != _currentUserId) {
          
          try {
            final newMessage = MessageModel.fromJson(messageData);
            final updatedMessages = List<MessageModel>.from(currentState.messages)..insert(0, newMessage);

            // Resolve name for new author if needed
            final userNames = await _resolveUserNames([newMessage], currentState.userNames);
            
            emit(currentState.copyWith(messages: updatedMessages, userNames: userNames));
          } catch (e) {
            // Log parse error and prevent the bloc from crashing
            import_foundation.debugPrint('Error parsing websocket message: $e');
          }
        }
      } else if (eventData['type'] == 'chat_read' || eventData['type'] == 'message_read') {
        final payload = eventData['payload'];
        if (payload == null) return;
        
        // Debug logging to understand server response
        import_foundation.debugPrint('Received read event: $eventData');
        
        // Debug logging to understand server response
        import_foundation.debugPrint('Received read event payload keys: ${payload.keys.toList()}');
        
        String? chatId;
        String? readerId;
        String? upToStr;

        // Exhaustive search for keys
        payload.forEach((key, value) {
          final k = key.toString().toLowerCase();
          final v = value?.toString();
          if (v == null) return;

          if (k.contains('chat_id') || k == 'id') {
            chatId ??= v;
          } else if (k.contains('user_id') || k.contains('reader') || (k.contains('sender') && !k.contains('author'))) {
            readerId ??= v;
          } else if (k.contains('up_to') || k.contains('timestamp') || k.contains('created_at')) {
            upToStr ??= v;
          }
        });
        
        final currentChatId = currentState.chatId;
        if (chatId == null || upToStr == null || currentChatId != chatId) {
          import_foundation.debugPrint('Read event ignored: chatId=$chatId, upTo=$upToStr, currentChatId=$currentChatId');
          return;
        }
        
        DateTime? upTo = DateTime.tryParse(upToStr!);
        String? upToId;
        if (upTo == null) {
          // If not a date, maybe it's a message ID?
          upToId = upToStr;
        }

        // Ensure we have myId
        final myIdFromStorage = await _getCurrentUserId();
        final myId = (myIdFromStorage ?? currentState.currentUserId).trim();
        final rId = readerId?.trim();
        
        // Find index if we have an ID-based upTo
        int? upToIndex;
        if (upToId != null) {
          upToIndex = currentState.messages.indexWhere((m) => m.id == upToId);
        }

        final updatedMessages = List<MessageModel>.from(currentState.messages);
        for (int i = 0; i < updatedMessages.length; i++) {
          final m = updatedMessages[i];
          final authorId = m.authorId.trim();
          bool shouldMarkAsRead = false;

          if (rId == null || rId != myId) {
            shouldMarkAsRead = (authorId == myId);
          } else {
            shouldMarkAsRead = (authorId != myId);
          }

          if (shouldMarkAsRead && m.status != MessageStatus.read) {
            bool isBefore = false;
            if (upTo != null) {
              // Use a small buffer (1sec) for safety with timestamps
              final upToBuffered = upTo.add(const Duration(seconds: 1));
              isBefore = m.createdAt.isBefore(upToBuffered);
            } else if (upToIndex != null) {
              // If we are at or "above" (older) than the message with upToId
              // Note: list is usually reversed (newest first), so index >= upToIndex depends on order.
              // Assuming latest messages are at the BEGINNING of the list (typical for list.map)
              // But list is typically 0: latest, N: oldest in our bloc.
              // So messages from index to end are OLDER.
              isBefore = (i >= upToIndex);
            }

            if (isBefore) {
              updatedMessages[i] = m.copyWith(status: MessageStatus.read);
            }
          }
        }

        emit(currentState.copyWith(messages: updatedMessages));
      } else if (eventData['type'] == 'message_status_changed') {
        final payload = eventData['payload'];
        if (payload == null) return;
        
        final chatId = payload['chat_id']?.toString() ?? payload['ChatID']?.toString();
        final messageId = payload['message_id']?.toString() ?? payload['MessageID']?.toString() ?? payload['id']?.toString() ?? payload['ID']?.toString();
        final statusRaw = payload['status'] ?? payload['Status'];
        
        if (chatId == null || messageId == null || currentState.chatId != chatId) return;
        
        MessageStatus newStatus = MessageStatus.sent;
        if (statusRaw is int) {
          if (statusRaw == 3) { newStatus = MessageStatus.read; }
          else if (statusRaw == 2) { newStatus = MessageStatus.delivered; }
          else if (statusRaw == 1) { newStatus = MessageStatus.sent; }
          else if (statusRaw == 0) { newStatus = MessageStatus.sending; }
        } else if (statusRaw is String) {
          final s = statusRaw.toLowerCase();
          if (s == 'read' || s == 'seen') { newStatus = MessageStatus.read; }
          else if (s == 'delivered') { newStatus = MessageStatus.delivered; }
          else if (s == 'sent') { newStatus = MessageStatus.sent; }
        }

        final updatedMessages = List<MessageModel>.from(currentState.messages);
        final index = updatedMessages.indexWhere((m) => m.id == messageId || m.clientMessageId == messageId);
        
        if (index != -1) {
          final msg = updatedMessages[index];
          if (newStatus.index > msg.status.index) {
            updatedMessages[index] = msg.copyWith(status: newStatus);
            emit(currentState.copyWith(messages: updatedMessages));
          }
        }
      }
    }
  }
}
