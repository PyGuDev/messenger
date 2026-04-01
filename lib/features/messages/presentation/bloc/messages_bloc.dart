import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:messenger/core/network/file_service.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/network/user_service.dart';
import '../../../../core/network/api_exception.dart';
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
  final FileService _fileService;
  StreamSubscription? _wsSubscription;
  
  String? _currentUserId;

  MessagesBloc(this._dio, this._wsService, this._tokenStorage, this._userService, this._fileService) : super(MessagesInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendMessage>(_onSendMessage);
    on<SendVoiceMessage>(_onSendVoiceMessage);
    on<ResendMessage>(_onResendMessage);
    on<MarkMessagesAsRead>(_onMarkMessagesAsRead);
    on<OnWebSocketEvent>(_onWebSocketEvent);
    on<EditMessage>(_onEditMessage);
    on<DeleteMessage>(_onDeleteMessage);
    on<ForwardMessages>(_onForwardMessages);
    on<SendVideoMessage>(_onSendVideoMessage);

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
      if (responseData['status'] == 'error') {
        throw ChatApiException.fromJson(responseData);
      }
      
      final List<dynamic> messagesData = responseData['data']['messages'] ?? [];
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
        if (responseData['status'] == 'error') {
          throw ChatApiException.fromJson(responseData);
        }
        
        final List<dynamic> newMessagesData = responseData['data']['messages'] ?? [];
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
        
        if (response.data['status'] == 'error') {
          throw ChatApiException.fromJson(response.data);
        }
        
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
        
        if (response.data['status'] == 'error') {
          throw ChatApiException.fromJson(response.data);
        }
        
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
      } else if (eventData['type'] == 'message_read') {
        final payload = eventData['payload'];
        if (payload == null) return;
        
        final chatId = payload['chat_id']?.toString();
        final readerId = payload['user_id']?.toString();
        final upToStr = payload['read_up_to']?.toString();
        
        final currentChatId = currentState.chatId;
        if (chatId == null || upToStr == null || currentChatId != chatId) return;
        
        DateTime? upTo = DateTime.tryParse(upToStr);
        if (upTo == null) return;

        final myIdFromStorage = await _getCurrentUserId();
        final myId = (myIdFromStorage ?? currentState.currentUserId).trim();
        final rId = readerId?.trim();
        
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
            // Use a small buffer (1sec) for safety with timestamps
            final upToBuffered = upTo.add(const Duration(seconds: 1));
            if (m.createdAt.isBefore(upToBuffered)) {
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

  Future<void> _onSendVoiceMessage(
    SendVoiceMessage event,
    Emitter<MessagesState> emit,
  ) async {
    if (state is! MessagesLoaded) return;
    final currentState = state as MessagesLoaded;

    final clientMessageId = const Uuid().v4();
    final now = DateTime.now();

    // 1. Create optimistic message
    final tempMessage = MessageModel(
      id: clientMessageId,
      chatId: event.chatId,
      authorId: _currentUserId ?? '',
      text: '',
      createdAt: now,
      updatedAt: now,
      status: MessageStatus.sending,
      clientMessageId: clientMessageId,
      attachedContent: [
        AttachedContentModel(
          id: '',
          fileName: 'voice.m4a',
          fileSize: 0,
          accessKey: '',
          typeContent: 'voice',
          mimeType: 'audio/mp4',
        ),
      ],
    );

    final updatedMessages = [tempMessage, ...currentState.messages];
    emit(currentState.copyWith(messages: updatedMessages));

    try {
      // 2. Upload to File Service
      final file = File(event.filePath);
      final fileSize = await file.length();
      final fileName = event.filePath.split('/').last;

      final uploadRes = await _fileService.uploadFile(
        event.filePath,
        fileName,
      );

      // 3. Send to Chat API
      final response = await _dio.post(
        '/chats/${event.chatId}/messages',
        data: {
          'body': '',
          'client_message_id': clientMessageId,
          'reply_to_message_id': event.replyToMessageId,
          'attached_content': [
            {
              'type_content': 'voice',
              'access_key': uploadRes.accessKey,
              'file_name': fileName,
              'file_size': fileSize,
              'mime_type': 'audio/mp4',
            }
          ],
        },
      );

      import_foundation.debugPrint('MessagesBloc: POST /messages response: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final serverMessage = MessageModel.fromJson(response.data['data']);
        if (state is MessagesLoaded) {
          final currentStateNow = state as MessagesLoaded;
          final finalMessages = currentStateNow.messages.map((m) {
            return m.clientMessageId == clientMessageId ? serverMessage : m;
          }).toList();
          emit(currentStateNow.copyWith(messages: finalMessages));
        }
      }
    } catch (e) {
      if (state is MessagesLoaded) {
        final currentStateNow = state as MessagesLoaded;
        final errorMessages = currentStateNow.messages.map((m) {
          if (m.clientMessageId == clientMessageId) {
            return m.copyWith(status: MessageStatus.failed);
          }
          return m;
        }).toList();
        emit(currentStateNow.copyWith(messages: errorMessages));
      }
    }
  }

  Future<void> _onEditMessage(EditMessage event, Emitter<MessagesState> emit) async {
    if (state is MessagesLoaded) {
      final currentState = state as MessagesLoaded;
      try {
        final response = await _dio.patch(
          '/chats/${event.chatId}/messages/${event.messageId}',
          data: {'body': event.newBody},
        );

        if (response.data['status'] == 'error') {
          throw ChatApiException.fromJson(response.data);
        }

        final updatedMessage = MessageModel.fromJson(response.data['data']);
        final updatedMessages = currentState.messages.map((m) {
          return m.id == event.messageId ? updatedMessage : m;
        }).toList();

        emit(currentState.copyWith(messages: updatedMessages));
      } catch (e) {
        // Handle error (maybe re-emit state with error)
      }
    }
  }

  Future<void> _onDeleteMessage(DeleteMessage event, Emitter<MessagesState> emit) async {
    if (state is MessagesLoaded) {
      final currentState = state as MessagesLoaded;
      try {
        final response = await _dio.delete(
          '/chats/${event.chatId}/messages/${event.messageId}',
          data: {'for_everyone': event.forEveryone},
        );

        if (response.data != null && response.data != '' && response.data['status'] == 'error') {
          throw ChatApiException.fromJson(response.data);
        }

        final updatedMessages = List<MessageModel>.from(currentState.messages)
          ..removeWhere((m) => m.id == event.messageId);

        emit(currentState.copyWith(messages: updatedMessages));
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _onForwardMessages(ForwardMessages event, Emitter<MessagesState> emit) async {
    if (state is MessagesLoaded) {
      final currentState = state as MessagesLoaded;
      try {
        final response = await _dio.post(
          '/chats/${event.chatId}/messages/forward',
          data: {'message_ids': event.messageIds},
        );

        if (response.data['status'] == 'error') {
          throw ChatApiException.fromJson(response.data);
        }

        final List<dynamic> newMessagesData = response.data['data']['messages'];
        final newMessages = newMessagesData.map((json) => MessageModel.fromJson(json)).toList();

        final updatedMessages = List<MessageModel>.from(currentState.messages)..insertAll(0, newMessages);
        emit(currentState.copyWith(messages: updatedMessages));
      } catch (e) {
      }
    }
  }

  Future<void> _onSendVideoMessage(
    SendVideoMessage event,
    Emitter<MessagesState> emit,
  ) async {
    if (state is! MessagesLoaded) return;
    final currentState = state as MessagesLoaded;

    final clientMessageId = const Uuid().v4();
    final now = DateTime.now();

    // 1. Create optimistic message
    final tempMessage = MessageModel(
      id: clientMessageId,
      chatId: event.chatId,
      authorId: _currentUserId ?? '',
      text: '',
      createdAt: now,
      updatedAt: now,
      status: MessageStatus.sending,
      clientMessageId: clientMessageId,
      attachedContent: [
        AttachedContentModel(
          id: '',
          fileName: 'video.mp4',
          fileSize: 0,
          accessKey: '',
          typeContent: 'video',
          mimeType: 'video/mp4',
        ),
      ],
    );

    final updatedMessages = [tempMessage, ...currentState.messages];
    emit(currentState.copyWith(messages: updatedMessages));

    try {
      // 2. Upload to File Service
      final file = File(event.filePath);
      final fileSize = await file.length();
      final fileName = event.filePath.split('/').last;

      final uploadRes = await _fileService.uploadFile(
        event.filePath,
        fileName,
      );

      // 3. Send to Chat API
      final response = await _dio.post(
        '/chats/${event.chatId}/messages',
        data: {
          'body': '',
          'client_message_id': clientMessageId,
          'reply_to_message_id': event.replyToMessageId,
          'attached_content': [
            {
              'type_content': 'video',
              'access_key': uploadRes.accessKey,
              'file_name': fileName,
              'file_size': fileSize,
              'mime_type': 'video/mp4',
            }
          ],
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final serverMessage = MessageModel.fromJson(response.data['data']);
        if (state is MessagesLoaded) {
          final currentStateNow = state as MessagesLoaded;
          final finalMessages = currentStateNow.messages.map((m) {
            return m.clientMessageId == clientMessageId ? serverMessage : m;
          }).toList();
          emit(currentStateNow.copyWith(messages: finalMessages));
        }
      }
    } catch (e) {
      if (state is MessagesLoaded) {
        final currentStateNow = state as MessagesLoaded;
        final errorMessages = currentStateNow.messages.map((m) {
          if (m.clientMessageId == clientMessageId) {
            return m.copyWith(status: MessageStatus.failed);
          }
          return m;
        }).toList();
        emit(currentStateNow.copyWith(messages: errorMessages));
      }
    }
  }
}

