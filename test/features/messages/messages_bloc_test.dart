import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/network/file_service.dart';
import 'package:messenger/core/network/network_info.dart';
import 'package:messenger/core/network/runtime_environment_profile.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:messenger/core/network/websocket_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'package:messenger/features/messages/data/datasources/messages_local_data_source.dart';
import 'package:messenger/features/messages/data/models/message_model.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_event.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_state.dart';

class _FakeTokenStorage implements TokenStorage {
  String? accessToken = 'token';
  String? userId = 'user-1';

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    userId = null;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<String?> getUserId() async => userId;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    this.accessToken = accessToken;
  }

  @override
  Future<void> saveUserId(String userId) async {
    this.userId = userId;
  }
}

class _FakeNetworkInfo implements NetworkInfo {
  _FakeNetworkInfo(this._isConnected);

  final bool _isConnected;

  @override
  Future<bool> get isConnected async => _isConnected;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _InMemoryMessagesLocalDataSource implements MessagesLocalDataSource {
  final Map<String, List<MessageModel>> _storage = {};

  @override
  Future<void> deleteMessage(String messageId) async {
    for (final entry in _storage.entries) {
      entry.value.removeWhere(
        (message) =>
            message.id == messageId || message.clientMessageId == messageId,
      );
    }
  }

  @override
  Future<List<MessageModel>> getMessages(String chatId) async =>
      List<MessageModel>.from(_storage[chatId] ?? const <MessageModel>[]);

  @override
  Future<void> replaceMessagesForChat(
    String chatId,
    List<MessageModel> messages,
  ) async {
    _storage[chatId] = List<MessageModel>.from(messages);
  }

  @override
  Future<void> saveMessage(MessageModel message) async {
    final messages = _storage.putIfAbsent(
      message.chatId,
      () => <MessageModel>[],
    );
    messages.removeWhere(
      (item) =>
          item.id == message.id ||
          item.clientMessageId == message.clientMessageId,
    );
    messages.add(message);
  }

  @override
  Future<void> saveMessages(List<MessageModel> messages) async {
    for (final message in messages) {
      await saveMessage(message);
    }
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    for (final entry in _storage.entries) {
      final index = entry.value.indexWhere(
        (message) =>
            message.id == messageId || message.clientMessageId == messageId,
      );
      if (index != -1) {
        entry.value[index] = entry.value[index].copyWith(status: status);
      }
    }
  }
}

void main() {
  late _FakeTokenStorage tokenStorage;
  late RuntimeEnvironmentProfile profile;

  setUp(() {
    tokenStorage = _FakeTokenStorage();
    profile = const RuntimeEnvironmentProfile(
      environmentName: 'test',
      authBaseUrl: 'https://auth.example.com/auth/api/v1',
      chatBaseUrl: 'https://chat.example.com/room/api/v1',
      fileBaseUrl: 'https://files.example.com/file',
      wsBaseUrl: 'wss://chat.example.com/room/ws',
    );
  });

  test(
    'emits offline unavailable when a chat has no cache and the device is offline',
    () async {
      final localDataSource = _InMemoryMessagesLocalDataSource();
      final bloc = MessagesBloc(
        Dio(),
        WebSocketService(tokenStorage, _FakeNetworkInfo(false), profile),
        tokenStorage,
        _FakeNetworkInfo(false),
        UserService(Dio()),
        FileService(Dio(), profile),
        localDataSource,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isA<MessagesLoading>(),
          isA<MessagesOfflineUnavailable>(),
        ]),
      );

      bloc.add(const LoadMessages('chat-1'));

      await expectation;
      await bloc.close();
    },
  );

  test(
    'reconciles network messages by chat and identity before caching',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': {
                    'messages': [
                      {
                        'id': 'server-1',
                        'chat_id': 'chat-1',
                        'author_id': 'user-2',
                        'body': 'latest',
                        'client_message_id': 'client-1',
                        'created_at': '2026-04-22T11:00:00Z',
                      },
                      {
                        'id': 'server-older',
                        'chat_id': 'chat-1',
                        'author_id': 'user-2',
                        'body': 'older duplicate',
                        'client_message_id': 'client-1',
                        'created_at': '2026-04-22T10:00:00Z',
                      },
                      {
                        'id': 'wrong-chat',
                        'chat_id': 'chat-2',
                        'author_id': 'user-3',
                        'body': 'ignore me',
                        'created_at': '2026-04-22T09:00:00Z',
                      },
                    ],
                  },
                },
              ),
            );
          },
        ),
      );

      final localDataSource = _InMemoryMessagesLocalDataSource();
      final bloc = MessagesBloc(
        dio,
        WebSocketService(tokenStorage, _FakeNetworkInfo(true), profile),
        tokenStorage,
        _FakeNetworkInfo(true),
        UserService(Dio()),
        FileService(Dio(), profile),
        localDataSource,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsThrough(
          isA<MessagesLoaded>().having(
            (state) => state.messages.map((message) => message.id).toList(),
            'message ids',
            ['server-1'],
          ),
        ),
      );

      bloc.add(const LoadMessages('chat-1'));

      await expectation;
      final cachedMessages = await localDataSource.getMessages('chat-1');
      expect(cachedMessages, hasLength(1));
      expect(cachedMessages.single.chatId, 'chat-1');
      await bloc.close();
    },
  );
}
