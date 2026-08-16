import 'dart:async';
import 'dart:io';

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

  void seed(String chatId, List<MessageModel> messages) {
    _storage[chatId] = List<MessageModel>.from(messages);
  }

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

class _FakeFileService extends FileService {
  _FakeFileService(RuntimeEnvironmentProfile profile) : super(Dio(), profile);

  @override
  Future<UploadResponse> uploadFile(String filePath, String fileName) async {
    return UploadResponse(
      accessKey: 'video-access-key',
      fileId: 'file-1',
      isDuplicate: false,
    );
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
        chatId: 'chat-1',
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
        chatId: 'chat-1',
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

  test(
    'a Chat Session ignores message actions owned by another chat',
    () async {
      final localDataSource = _InMemoryMessagesLocalDataSource()
        ..seed('chat-1', <MessageModel>[
          MessageModel(
            id: 'message-1',
            chatId: 'chat-1',
            authorId: 'user-2',
            text: 'Chat one history',
            createdAt: DateTime.utc(2026, 4, 22, 10),
            updatedAt: DateTime.utc(2026, 4, 22, 10),
            status: MessageStatus.sent,
          ),
        ]);
      final bloc = MessagesBloc(
        Dio(),
        WebSocketService(tokenStorage, _FakeNetworkInfo(false), profile),
        tokenStorage,
        _FakeNetworkInfo(false),
        UserService(Dio()),
        FileService(Dio(), profile),
        localDataSource,
        chatId: 'chat-1',
      );

      bloc.add(const LoadMessages('chat-1'));
      await bloc.stream.firstWhere((state) => state is MessagesLoaded);

      bloc.add(const SendMessage(chatId: 'chat-2', text: 'Must not leak'));
      await Future<void>.delayed(Duration.zero);

      final state = bloc.state as MessagesLoaded;
      expect(state.chatId, 'chat-1');
      expect(
        state.messages.map((message) => message.chatId),
        everyElement('chat-1'),
      );
      expect(
        state.messages.map((message) => message.text),
        isNot(contains('Must not leak')),
      );
      await bloc.close();
    },
  );

  test(
    'sends a video Attachment and replaces its optimistic Message with sent state',
    () async {
      final requests = <Map<String, dynamic>>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET') {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'status': 'ok',
                      'data': {'messages': <Map<String, dynamic>>[]},
                    },
                  ),
                );
                return;
              }

              requests.add(Map<String, dynamic>.from(options.data as Map));
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'data': {
                      'id': 'server-video-message',
                      'chat_id': 'chat-1',
                      'author_id': 'user-1',
                      'body': '',
                      'client_message_id': options.data['client_message_id'],
                      'created_at': '2026-08-16T09:00:00Z',
                      'attached_content': [
                        {
                          'id': 'video-1',
                          'type_content': 'video',
                          'access_key': 'video-access-key',
                          'file_name': 'video.mp4',
                          'file_size': 3,
                          'mime_type': 'video/mp4',
                        },
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );
      final file = File('${Directory.systemTemp.path}/messages_bloc_video.mp4');
      await file.writeAsBytes(<int>[0, 1, 2]);
      addTearDown(() => file.delete());

      final bloc = MessagesBloc(
        dio,
        WebSocketService(tokenStorage, _FakeNetworkInfo(true), profile),
        tokenStorage,
        _FakeNetworkInfo(true),
        UserService(Dio()),
        _FakeFileService(profile),
        _InMemoryMessagesLocalDataSource(),
        chatId: 'chat-1',
      );
      addTearDown(bloc.close);

      bloc.add(const LoadMessages('chat-1'));
      await bloc.stream.firstWhere((state) => state is MessagesLoaded);

      final sentState = bloc.stream
          .where((state) => state is MessagesLoaded)
          .cast<MessagesLoaded>()
          .firstWhere(
            (state) => state.messages.any(
              (message) =>
                  message.id == 'server-video-message' &&
                  message.status == MessageStatus.sent,
            ),
          );
      bloc.add(
        SendVideoMessage(
          chatId: 'chat-1',
          filePath: file.path,
          duration: const Duration(seconds: 1),
        ),
      );

      final state = await sentState;
      expect(requests, hasLength(1));
      expect(requests.single['body'], '');
      expect((requests.single['attached_content'] as List).single, {
        'type_content': 'video',
        'access_key': 'video-access-key',
        'file_name': 'messages_bloc_video.mp4',
        'file_size': 3,
        'mime_type': 'video/mp4',
      });
      expect(
        state.messages
            .singleWhere((message) => message.id == 'server-video-message')
            .attachedContent
            .single
            .localPath,
        file.path,
      );
    },
  );

  test(
    'marks an optimistic video Message as failed when Chat API rejects it',
    () async {
      final requests = <Map<String, dynamic>>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET') {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'status': 'ok',
                      'data': {'messages': <Map<String, dynamic>>[]},
                    },
                  ),
                );
                return;
              }

              requests.add(Map<String, dynamic>.from(options.data as Map));
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 422,
                    data: {
                      'status': 'error',
                      'error': {
                        'code': 'CHAT.VALIDATION_ERROR',
                        'message': 'body or attached_content is required',
                      },
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            },
          ),
        );
      final file = File(
        '${Directory.systemTemp.path}/messages_bloc_rejected_video.mp4',
      );
      await file.writeAsBytes(<int>[0, 1, 2]);
      addTearDown(() => file.delete());

      final bloc = MessagesBloc(
        dio,
        WebSocketService(tokenStorage, _FakeNetworkInfo(true), profile),
        tokenStorage,
        _FakeNetworkInfo(true),
        UserService(Dio()),
        _FakeFileService(profile),
        _InMemoryMessagesLocalDataSource(),
        chatId: 'chat-1',
      );
      addTearDown(bloc.close);

      bloc.add(const LoadMessages('chat-1'));
      await bloc.stream.firstWhere((state) => state is MessagesLoaded);

      final failedState = bloc.stream
          .where((state) => state is MessagesLoaded)
          .cast<MessagesLoaded>()
          .firstWhere(
            (state) => state.messages.any(
              (message) =>
                  message.status == MessageStatus.failed &&
                  message.attachedContent.single.typeContent == 'video',
            ),
          );
      bloc.add(
        SendVideoMessage(
          chatId: 'chat-1',
          filePath: file.path,
          duration: const Duration(seconds: 1),
        ),
      );

      final state = await failedState;
      expect(requests, hasLength(1));
      expect(requests.single['body'], '');
      expect(requests.single['attached_content'], isNotEmpty);
      expect(
        state.messages
            .singleWhere((message) => message.status == MessageStatus.failed)
            .attachedContent
            .single
            .localPath,
        file.path,
      );
    },
  );
}
