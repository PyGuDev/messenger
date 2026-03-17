import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/websocket_service.dart';
import '../../data/models/chat_model.dart';
import 'chats_event.dart';
import 'chats_state.dart';

class ChatsBloc extends Bloc<ChatsEvent, ChatsState> {
  final Dio _dio;
  final WebSocketService _wsService;
  StreamSubscription? _wsSubscription;

  ChatsBloc(this._dio, this._wsService) : super(ChatsInitial()) {
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

  Future<void> _onLoadChats(LoadChats event, Emitter<ChatsState> emit) async {
    emit(ChatsLoading());
    try {
      final response = await _dio.get('/chats', queryParameters: {
        'limit': 20,
        'offset': 0,
      });
      
      final Map<String, dynamic> responseData = response.data;
      final List<dynamic> chatsData = responseData['data']['chats'];
      final chats = chatsData.map((json) => ChatModel.fromJson(json)).toList();
      
      emit(ChatsLoaded(chats, hasReachedMax: chats.length < 20));
    } catch (e) {
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
        final List<dynamic> newChatsData = responseData['data']['chats'];
        final newChats = newChatsData.map((json) => ChatModel.fromJson(json)).toList();

        emit(currentState.copyWith(
          chats: List.from(currentState.chats)..addAll(newChats),
          hasReachedMax: newChats.length < 20,
        ));
      } catch (e) {
        // Silently fail pagination error for now
      }
    }
  }

  Future<void> _onCreateChat(CreateChat event, Emitter<ChatsState> emit) async {
    try {
      await _dio.post('/chats', data: {
        'type': 1, // Private chat
        'member_ids': [event.userId],
      });
      
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
        final messageData = eventData['data'];
        if (messageData == null) return;
        
        final chatId = messageData['chat_id'];
        
        final existingChatIndex = currentState.chats.indexWhere((c) => c.id == chatId);
        
        if (existingChatIndex != -1) {
          final chat = currentState.chats[existingChatIndex];
          final updatedChat = chat.copyWith(
            lastMessage: LastMessageModel.fromJson(messageData),
            unreadCount: chat.unreadCount + 1,
            updatedAt: DateTime.parse(messageData['created_at']),
          );
          
          final updatedChats = List<ChatModel>.from(currentState.chats)
            ..removeAt(existingChatIndex)
            ..insert(0, updatedChat); // Move to top
            
          emit(currentState.copyWith(chats: updatedChats));
        } else {
          // If chat not in list, reload all
          add(LoadChats());
        }
      }
    }
  }
}
