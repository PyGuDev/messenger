import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/navigation/router.dart';
import 'package:messenger/core/network/file_service.dart';
import 'package:messenger/core/network/network_info.dart';
import 'package:messenger/core/network/runtime_environment_profile.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:messenger/core/network/websocket_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'package:messenger/features/messages/data/datasources/messages_local_data_source.dart';
import 'package:messenger/features/messages/data/models/message_model.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_bloc.dart';

class _TokenStorage implements TokenStorage {
  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<String?> getUserId() async => 'user-1';

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {}

  @override
  Future<void> saveUserId(String userId) async {}
}

class _NetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _MessagesCache implements MessagesLocalDataSource {
  @override
  Future<void> deleteMessage(String messageId) async {}

  @override
  Future<List<MessageModel>> getMessages(String chatId) async =>
      const <MessageModel>[];

  @override
  Future<void> replaceMessagesForChat(
    String chatId,
    List<MessageModel> messages,
  ) async {}

  @override
  Future<void> saveMessage(MessageModel message) async {}

  @override
  Future<void> saveMessages(List<MessageModel> messages) async {}

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {}
}

class _TrackingMessagesBloc extends MessagesBloc {
  _TrackingMessagesBloc()
    : super(
        Dio(),
        WebSocketService(
          _TokenStorage(),
          _NetworkInfo(),
          const RuntimeEnvironmentProfile(
            environmentName: 'test',
            authBaseUrl: 'https://auth.example.com',
            chatBaseUrl: 'https://chat.example.com',
            fileBaseUrl: 'https://files.example.com',
            wsBaseUrl: 'wss://chat.example.com',
          ),
        ),
        _TokenStorage(),
        _NetworkInfo(),
        UserService(Dio()),
        FileService(
          Dio(),
          const RuntimeEnvironmentProfile(
            environmentName: 'test',
            authBaseUrl: 'https://auth.example.com',
            chatBaseUrl: 'https://chat.example.com',
            fileBaseUrl: 'https://files.example.com',
            wsBaseUrl: 'wss://chat.example.com',
          ),
        ),
        _MessagesCache(),
      );

  bool closedByRoute = false;

  @override
  Future<void> close() {
    closedByRoute = true;
    return super.close();
  }
}

class _BlocProbe extends StatelessWidget {
  const _BlocProbe(this.onBuild);

  final ValueChanged<MessagesBloc> onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(context.read<MessagesBloc>());
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('each Chat Session receives and disposes its own MessagesBloc', (
    tester,
  ) async {
    final created = <_TrackingMessagesBloc>[];
    MessagesBloc? observed;

    Widget session(String chatId) => MaterialApp(
      home: buildChatSession(
        chatId: chatId,
        createMessagesBloc: () {
          final bloc = _TrackingMessagesBloc();
          created.add(bloc);
          return bloc;
        },
        child: _BlocProbe((bloc) => observed = bloc),
      ),
    );

    await tester.pumpWidget(session('chat-1'));
    final first = observed;

    await tester.pumpWidget(session('chat-2'));
    final second = observed;

    expect(created, hasLength(2));
    expect(first, same(created.first));
    expect(second, same(created.last));
    expect(second, isNot(same(first)));
    expect(created.first.closedByRoute, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(created.last.closedByRoute, isTrue);
  });
}
