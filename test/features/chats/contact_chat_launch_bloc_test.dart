import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/network/network_info.dart';
import 'package:messenger/core/network/runtime_environment_profile.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:messenger/core/network/websocket_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'package:messenger/features/chats/data/datasources/chats_local_data_source.dart';
import 'package:messenger/features/chats/data/models/chat_model.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_event.dart';
import 'package:messenger/features/chats/presentation/bloc/contact_chat_launch_bloc.dart';

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> getAccessToken() async => 'token';

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<String?> getUserId() async => 'user-1';

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {}

  @override
  Future<void> saveUserId(String userId) async {}
}

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _FakeChatsLocalDataSource implements ChatsLocalDataSource {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> deleteChat(String chatId) async {}

  @override
  Future<List<ChatModel>> getChats() async => const <ChatModel>[];

  @override
  Future<void> saveChat(ChatModel chat) async {}

  @override
  Future<void> saveChats(List<ChatModel> chats) async {}
}

class _RecordingChatsBloc extends ChatsBloc {
  _RecordingChatsBloc(RuntimeEnvironmentProfile profile)
    : super(
        Dio(),
        WebSocketService(_FakeTokenStorage(), _FakeNetworkInfo(), profile),
        UserService(Dio()),
        _FakeTokenStorage(),
        _FakeChatsLocalDataSource(),
      );

  final List<ChatsEvent> recordedEvents = <ChatsEvent>[];

  @override
  void add(ChatsEvent event) {
    recordedEvents.add(event);
  }
}

void main() {
  late RuntimeEnvironmentProfile profile;

  setUp(() {
    profile = const RuntimeEnvironmentProfile(
      environmentName: 'test',
      authBaseUrl: 'https://auth.example.com/auth/api/v1',
      chatBaseUrl: 'https://chat.example.com/room/api/v1',
      fileBaseUrl: 'https://files.example.com/file',
      wsBaseUrl: 'wss://chat.example.com/room/ws',
    );
  });

  test('reuses an existing direct chat before creating one', () async {
    final dio = Dio();
    final chatsBloc = _RecordingChatsBloc(profile);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET' && options.path == '/chats/personal') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': {'chat_id': 'chat-existing'},
                },
              ),
            );
            return;
          }

          fail(
            'POST /chats should not be called when a direct chat already exists',
          );
        },
      ),
    );

    final bloc = ContactChatLaunchBloc(dio, chatsBloc);

    await bloc.launchConversation(userId: 'user-2', displayName: 'Alice');

    expect(bloc.state.status, ContactChatLaunchStatus.navigating);
    expect(bloc.state.resolvedChatId, 'chat-existing');
    expect(chatsBloc.recordedEvents.whereType<LoadChats>(), hasLength(1));

    await bloc.close();
    await chatsBloc.close();
  });

  test(
    'collapses duplicate taps while the same launch request is in flight',
    () async {
      final dio = Dio();
      final chatsBloc = _RecordingChatsBloc(profile);
      final completer = Completer<void>();
      var getRequests = 0;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.method == 'GET' && options.path == '/chats/personal') {
              getRequests += 1;
              await completer.future;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': 'ok',
                    'data': {'chat_id': 'chat-existing'},
                  },
                ),
              );
              return;
            }

            fail('Unexpected request: ${options.method} ${options.path}');
          },
        ),
      );

      final bloc = ContactChatLaunchBloc(dio, chatsBloc);

      final first = bloc.launchConversation(
        userId: 'user-2',
        displayName: 'Alice',
      );
      final second = bloc.launchConversation(
        userId: 'user-2',
        displayName: 'Alice',
      );

      completer.complete();
      await Future.wait([first, second]);

      expect(getRequests, 1);
      expect(bloc.state.resolvedChatId, 'chat-existing');

      await bloc.close();
      await chatsBloc.close();
    },
  );
}
