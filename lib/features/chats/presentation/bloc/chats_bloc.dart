import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/network/user_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/models/chat_model.dart';
import '../../data/datasources/chats_local_data_source.dart';
import 'chats_event.dart';
import 'chats_state.dart';

class ChatsBloc extends Bloc<ChatsEvent, ChatsState> {
  final Dio _dio;
  final WebSocketService _wsService;
  final UserService _userService;
  final TokenStorage _tokenStorage;
  final ChatsLocalDataSource _localDataSource;
  StreamSubscription? _wsSubscription;

  ChatsBloc(this._dio, this._wsService, this._userService, this._tokenStorage, this._localDataSource) : super(ChatsInitial()) {
    on<LoadChats>(_onLoadChats);
    on<LoadMoreChats>(_onLoadMoreChats);
    on<CreateChat>(_onCreateChat);
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
    var userId = await _tokenStorage.getUserId();
    if (userId != null) return userId;

    // Fallback: extract from JWT token
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      userId = UserService.extractUserIdFromToken(token);
      if (userId != null) {
        // Save it for future use
        await _tokenStorage.saveUserId(userId);
      }
    }
    return userId;
  }

  /// For personal chats (type=1), resolve the other member's name.
  /// If members are empty in the chat list, fetch individual chat details.
  Future<List<ChatModel>> _resolvePersonalChatNames(List<ChatModel> chats) async {
    final currentUserId = await _getCurrentUserId();
    if (currentUserId == null) return chats;

    final resolved = <ChatModel>[];
    for (final chat in chats) {
      if (chat.type == 1 && (chat.title == null || chat.title!.isEmpty)) {
        var members = chat.members;

        // If members list is empty, fetch individual chat details
        if (members.isEmpty) {
          try {
            final detailResponse = await _dio.get('/chats/${chat.id}');
            final detailData = detailResponse.data as Map<String, dynamic>;
            final chatData = detailData['data'] as Map<String, dynamic>? ?? detailData;
            final membersList = chatData['members'] as List<dynamic>? ?? [];
            members = membersList
                .map((e) => MemberModel.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (_) {
            // If fetching details fails, keep empty members
          }
        }

        // Find the other member
        final otherMember = members.where((m) => m.userId != currentUserId);
        if (otherMember.isNotEmpty) {
          final profile = await _userService.getUser(otherMember.first.userId);
          resolved.add(chat.copyWith(title: profile.displayName));
        } else {
          resolved.add(chat);
        }
      } else {
        resolved.add(chat);
      }
    }
    return resolved;
  }

  Future<void> _onLoadChats(LoadChats event, Emitter<ChatsState> emit) async {
    emit(ChatsLoading());
    try {
      final localChats = await _localDataSource.getChats();
      if (localChats.isNotEmpty) {
        emit(ChatsLoaded(localChats, hasReachedMax: false));
      }

      final response = await _dio.get('/chats', queryParameters: {
        'limit': 20,
        'offset': 0,
      });
      
      final Map<String, dynamic> responseData = response.data;
      if (responseData['status'] == 'error') {
        throw ChatApiException.fromJson(responseData);
      }
      
      final List<dynamic> chatsData = responseData['data']['chats'] ?? [];
      var chats = chatsData.map((json) => ChatModel.fromJson(json)).toList();

      chats = await _resolvePersonalChatNames(chats);
      
      await _localDataSource.clearAll();
      await _localDataSource.saveChats(chats);
      
      emit(ChatsLoaded(chats, hasReachedMax: chats.length < 20));
    } catch (e) {
      if (state is ChatsLoaded) {
        // If we already have cached chats displayed, don't replace them with an error screen.
        // Also set hasReachedMax: true to stop the bottom spinner from rotating endlessly.
        emit((state as ChatsLoaded).copyWith(hasReachedMax: true));
        return;
      }
      emit(ChatsError(e.toString()));
    }
  }

  Future<void> _onLoadMoreChats(LoadMoreChats event, Emitter<ChatsState> emit) async {
    if (state is ChatsLoaded) {
      final currentState = state as ChatsLoaded;
      if (currentState.hasReachedMax || currentState.chats.isEmpty) return;

      try {
        final offset = currentState.chats.length;
        final response = await _dio.get('/chats', queryParameters: {
          'limit': 20,
          'offset': offset,
        });

        final Map<String, dynamic> responseData = response.data;
        if (responseData['status'] == 'error') {
          throw ChatApiException.fromJson(responseData);
        }

        final List<dynamic> newChatsData = responseData['data']['chats'] ?? [];
        var newChats = newChatsData.map((json) => ChatModel.fromJson(json)).toList();

        newChats = await _resolvePersonalChatNames(newChats);

        await _localDataSource.saveChats(newChats);

        emit(currentState.copyWith(
          chats: List.from(currentState.chats)..addAll(newChats),
          hasReachedMax: newChats.length < 20,
        ));
      } catch (e) {
        // Silently fail pagination error for now, but hide the bottom spinner
        emit(currentState.copyWith(hasReachedMax: true));
      }
    }
  }

  Future<void> _onCreateChat(CreateChat event, Emitter<ChatsState> emit) async {
    try {
      final response = await _dio.post('/chats', data: {
        'type': 1, // Private chat
        'member_ids': [event.userId],
      });
      
      if (response.data['status'] == 'error') {
        throw ChatApiException.fromJson(response.data);
      }
      
      // Reload chats to get the new chat with full metadata
      add(LoadChats());
    } catch (e) {
      emit(ChatsError(e.toString()));
      add(LoadChats()); // Revert to loaded state
    }
  }

  Future<void> _onWebSocketEvent(OnWebSocketEvent event, Emitter<ChatsState> emit) async {
    if (state is ChatsLoaded) {
      final currentState = state as ChatsLoaded;
      final eventData = event.event;

      if (eventData['type'] == 'new_message') {
        final payload = eventData['payload'];
        if (payload == null) return;
        
        final chatId = payload['chat_id']?.toString();
        final messageData = payload['message'];
        if (messageData == null || chatId == null) return;
        
        final existingChatIndex = currentState.chats.indexWhere((c) => c.id == chatId);
        
        if (existingChatIndex != -1) {
          final chat = currentState.chats[existingChatIndex];
          final updatedChat = chat.copyWith(
            lastMessage: LastMessageModel.fromJson(messageData),
            unreadCount: chat.unreadCount + 1,
            updatedAt: DateTime.tryParse((messageData['created_at'] ?? messageData['CreatedAt'])?.toString() ?? '') ?? chat.updatedAt,
          );
          
          final updatedChats = List<ChatModel>.from(currentState.chats)
            ..removeAt(existingChatIndex)
            ..insert(0, updatedChat); // Move to top
            
          await _localDataSource.saveChat(updatedChat);
          emit(currentState.copyWith(chats: updatedChats));
        } else {
          // If chat not in list, reload all
          add(LoadChats());
        }
      } else if (eventData['type'] == 'message_read') {
        final payload = eventData['payload'];
        if (payload == null) return;
        
        final chatId = payload['chat_id']?.toString();
        final readerId = payload['user_id']?.toString();
        if (chatId == null) return;

        final currentUserIdFromStorage = await _getCurrentUserId();
        final myId = (currentUserIdFromStorage ?? '').trim();
        final rId = readerId?.trim();
        
        if (rId == null || rId == myId) {
          final existingChatIndex = currentState.chats.indexWhere((c) => c.id == chatId);
          if (existingChatIndex != -1) {
            final chat = currentState.chats[existingChatIndex];
            final updatedChat = chat.copyWith(unreadCount: 0);
            
            final updatedChats = List<ChatModel>.from(currentState.chats)
              ..[existingChatIndex] = updatedChat;
              
            await _localDataSource.saveChat(updatedChat);
            emit(currentState.copyWith(chats: updatedChats));
          }
        }
      }
    }
  }
}
