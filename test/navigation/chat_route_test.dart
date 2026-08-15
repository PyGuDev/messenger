import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/core/network/camera_service.dart';
import 'package:messenger/core/navigation/router.dart';
import 'package:messenger/core/network/file_service.dart';
import 'package:messenger/core/network/network_info.dart';
import 'package:messenger/core/network/runtime_environment_profile.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:messenger/core/network/websocket_service.dart';
import 'package:messenger/core/network/voice_recorder_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'package:messenger/features/chats/data/datasources/chats_local_data_source.dart';
import 'package:messenger/features/chats/data/models/chat_model.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_event.dart';
import 'package:messenger/features/chats/presentation/bloc/contact_chat_launch_bloc.dart';
import 'package:messenger/features/contacts/presentation/screens/contact_profile_screen.dart';
import 'package:messenger/features/messages/data/datasources/messages_local_data_source.dart';
import 'package:messenger/features/messages/data/models/message_model.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:messenger/features/messages/presentation/screens/messages_screen.dart';
import 'package:messenger/features/messages/presentation/widgets/video_recording_overlay.dart';
import 'package:messenger/features/messages/presentation/widgets/voice_recorder_widget.dart';
import 'package:messenger/l10n/app_localizations.dart';

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
  const _NetworkInfo([this.connected = false]);

  final bool connected;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _MessagesCache implements MessagesLocalDataSource {
  _MessagesCache([this.messagesByChat = const {}]);

  final Map<String, List<MessageModel>> messagesByChat;

  @override
  Future<void> deleteMessage(String messageId) async {}

  @override
  Future<List<MessageModel>> getMessages(String chatId) async =>
      List<MessageModel>.from(messagesByChat[chatId] ?? const <MessageModel>[]);

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
  _TrackingMessagesBloc(String chatId)
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
        chatId: chatId,
      );

  bool closedByRoute = false;

  @override
  Future<void> close() {
    closedByRoute = true;
    return super.close();
  }
}

class _TrackingCameraService implements ChatCameraService {
  int resetCount = 0;
  int disposeCount = 0;
  int startCount = 0;

  @override
  CameraController? get controller => null;

  @override
  bool get isRecording => startCount > 0;

  @override
  bool get isSwitching => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startRecording() async {
    startCount++;
  }

  @override
  Future<XFile?> stopRecording() async => null;

  @override
  Future<void> switchCamera() async {}

  @override
  Future<void> reset() async {
    resetCount++;
    startCount = 0;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await reset();
  }
}

class _TrackingVoiceRecordingService implements VoiceRecordingService {
  _TrackingVoiceRecordingService([this.startGate]);

  final Completer<void>? startGate;
  int cancelCount = 0;
  int disposeCount = 0;
  int startCount = 0;

  @override
  Stream<double> get amplitudeStream => const Stream<double>.empty();

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await cancel();
  }

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<void> start() async {
    startCount++;
    await startGate?.future;
  }

  @override
  Future<String?> stop() async => null;
}

class _EmptyChatsCache implements ChatsLocalDataSource {
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
  _RecordingChatsBloc()
    : super(
        Dio(),
        WebSocketService(
          _TokenStorage(),
          const _NetworkInfo(),
          const RuntimeEnvironmentProfile(
            environmentName: 'test',
            authBaseUrl: 'https://auth.example.com',
            chatBaseUrl: 'https://chat.example.com',
            fileBaseUrl: 'https://files.example.com',
            wsBaseUrl: 'wss://chat.example.com',
          ),
        ),
        UserService(Dio()),
        _TokenStorage(),
        _EmptyChatsCache(),
      );

  final List<ChatsEvent> events = <ChatsEvent>[];

  @override
  void add(ChatsEvent event) {
    events.add(event);
  }
}

MessagesBloc _sessionBloc(
  String chatId,
  _MessagesCache cache, {
  bool connected = false,
}) {
  const profile = RuntimeEnvironmentProfile(
    environmentName: 'test',
    authBaseUrl: 'https://auth.example.com',
    chatBaseUrl: 'https://chat.example.com',
    fileBaseUrl: 'https://files.example.com',
    wsBaseUrl: 'wss://chat.example.com',
  );
  final dio = Dio();
  if (connected) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final messages = cache.messagesByChat[chatId] ?? const [];
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: options.method == 'GET'
                  ? {
                      'status': 'ok',
                      'data': {
                        'messages': messages
                            .map(
                              (message) => {
                                'id': message.id,
                                'chat_id': message.chatId,
                                'author_id': message.authorId,
                                'body': message.text,
                                'created_at': message.createdAt
                                    .toIso8601String(),
                                'updated_at': message.updatedAt
                                    .toIso8601String(),
                                'attached_content': message.attachedContent
                                    .map((content) => content.toJson())
                                    .toList(),
                              },
                            )
                            .toList(),
                      },
                    }
                  : const {'status': 'ok'},
            ),
          );
        },
      ),
    );
  }
  final networkInfo = _NetworkInfo(connected);
  return MessagesBloc(
    dio,
    WebSocketService(_TokenStorage(), networkInfo, profile),
    _TokenStorage(),
    networkInfo,
    UserService(Dio()),
    FileService(Dio(), profile),
    cache,
    chatId: chatId,
  );
}

MessageModel _message(String chatId, String text) => MessageModel(
  id: 'message-$chatId',
  chatId: chatId,
  authorId: 'user-2',
  text: text,
  createdAt: DateTime.utc(2026, 4, 22, 10),
  updatedAt: DateTime.utc(2026, 4, 22, 10),
  status: MessageStatus.sent,
);

MessageModel _messageWithDocument(String chatId, String text) => MessageModel(
  id: 'message-$chatId',
  chatId: chatId,
  authorId: 'user-2',
  text: text,
  createdAt: DateTime.utc(2026, 4, 22, 10),
  updatedAt: DateTime.utc(2026, 4, 22, 10),
  status: MessageStatus.sent,
  attachedContent: [
    AttachedContentModel(
      id: 'attachment-$chatId',
      fileName: 'chat-one-secret.pdf',
      fileSize: 42,
      mimeType: 'application/pdf',
      accessKey: 'secret-key',
      typeContent: 'document',
    ),
  ],
);

class _BlocProbe extends StatelessWidget {
  const _BlocProbe(this.onBuild);

  final ValueChanged<MessagesBloc> onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(context.read<MessagesBloc>());
    return const SizedBox.shrink();
  }
}

Future<void> _expectContactProfileToNavigateToChat(
  WidgetTester tester, {
  required bool existingChat,
}) async {
  final expectedChatId = existingChat ? 'chat-existing' : 'chat-new';
  final chatDio = Dio();
  final chatsBloc = _RecordingChatsBloc();
  final launchBloc = ContactChatLaunchBloc(chatDio, chatsBloc);
  final requestedPaths = <String>[];
  chatDio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requestedPaths.add('${options.method} ${options.path}');
        if (options.method == 'GET' && options.path == '/chats/personal') {
          expect(options.queryParameters, {'user_id': 'user-2'});
          if (existingChat) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const <String, dynamic>{
                  'data': <String, dynamic>{'chat_id': 'chat-existing'},
                },
              ),
            );
          } else {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
          }
          return;
        }

        expect(options.method, 'POST');
        expect(options.path, '/chats');
        expect(options.data, {
          'type': 1,
          'member_ids': ['user-2'],
        });
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 201,
            data: const <String, dynamic>{
              'data': <String, dynamic>{'chat_id': 'chat-new'},
            },
          ),
        );
      },
    ),
  );
  addTearDown(launchBloc.close);
  addTearDown(chatsBloc.close);

  final testRouter = GoRouter(
    initialLocation: '/contact-profile',
    routes: [
      GoRoute(
        path: '/contact-profile',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<ChatsBloc>.value(value: chatsBloc),
            BlocProvider<ContactChatLaunchBloc>.value(value: launchBloc),
          ],
          child: const ContactProfileScreen(
            name: 'Alice Example',
            phone: '+79990000000',
            color: Colors.blue,
            isOnline: true,
            inMessenger: true,
            userId: 'user-2',
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => Scaffold(
          body: Text(
            'Chat route: ${state.pathParameters['id']} / ${state.extra}',
          ),
        ),
      ),
    ],
  );
  addTearDown(testRouter.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
  await tester.tap(find.text('Написать'));
  await tester.pumpAndSettle();

  expect(
    find.text('Chat route: $expectedChatId / Alice Example'),
    findsOneWidget,
  );
  expect(
    requestedPaths,
    existingChat
        ? ['GET /chats/personal']
        : ['GET /chats/personal', 'POST /chats'],
  );
  expect(chatsBloc.events.whereType<LoadChats>(), hasLength(2));
  expect(launchBloc.state.status, ContactChatLaunchStatus.idle);
}

void main() {
  testWidgets(
    'contact profile reuses a resolved Direct Chat and navigates to its Chat route',
    (tester) =>
        _expectContactProfileToNavigateToChat(tester, existingChat: true),
  );

  testWidgets(
    'contact profile creates a Direct Chat and navigates to its Chat route',
    (tester) =>
        _expectContactProfileToNavigateToChat(tester, existingChat: false),
  );

  testWidgets('each Chat Session receives and disposes its own MessagesBloc', (
    tester,
  ) async {
    final created = <_TrackingMessagesBloc>[];
    MessagesBloc? observed;

    Widget session(String chatId) => MaterialApp(
      home: buildChatSession(
        chatId: chatId,
        createMessagesBloc: (_) {
          final bloc = _TrackingMessagesBloc(chatId);
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

  testWidgets(
    'switching Chat Sessions clears draft, reply, media, and recording state',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cache = _MessagesCache({
        'chat-1': [_messageWithDocument('chat-1', 'Chat one history')],
        'chat-2': [_message('chat-2', 'Chat two history')],
        'chat-3': [_message('chat-3', 'Chat three history')],
        'chat-4': [_message('chat-4', 'Chat four history')],
      });
      final cameras = <_TrackingCameraService>[];
      final recorders = <_TrackingVoiceRecordingService>[];
      final voiceStartGate = Completer<void>();

      late final GoRouter testRouter;
      testRouter = GoRouter(
        initialLocation: '/chat/chat-1',
        routes: [
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) {
              final chatId = state.pathParameters['id']!;
              return buildChatSession(
                chatId: chatId,
                createMessagesBloc: (id) =>
                    _sessionBloc(id, cache, connected: true),
                createCameraService: () {
                  final service = _TrackingCameraService();
                  cameras.add(service);
                  return service;
                },
                createVoiceRecordingService: () {
                  final service = _TrackingVoiceRecordingService(
                    voiceStartGate,
                  );
                  recorders.add(service);
                  return service;
                },
                child: MessagesScreen(chatId: chatId, title: 'Chat $chatId'),
              );
            },
          ),
        ],
      );
      addTearDown(testRouter.dispose);

      final app = MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: testRouter,
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Chat one history'), findsOneWidget);
      expect(find.text('chat-one-secret.pdf'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'private draft');
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('private draft'), findsOneWidget);
      expect(find.byKey(const Key('message-reply-preview')), findsOneWidget);

      testRouter.go('/chat/chat-2');
      await tester.pumpAndSettle();

      expect(find.text('Chat two history'), findsOneWidget);
      expect(find.text('Chat one history'), findsNothing);
      expect(find.text('chat-one-secret.pdf'), findsNothing);
      expect(find.text('private draft'), findsNothing);
      expect(find.byKey(const Key('message-reply-preview')), findsNothing);
      expect(find.byType(VideoRecordingOverlay), findsNothing);
      expect(cameras, hasLength(2));
      expect(cameras.first.resetCount, greaterThanOrEqualTo(1));
      expect(cameras.first.disposeCount, 1);

      await tester.longPress(find.byIcon(Icons.mic));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(VoiceRecorderWidget), findsOneWidget);
      expect(recorders, hasLength(1));
      expect(recorders.single.startCount, 1);

      testRouter.go('/chat/chat-3');
      await tester.pumpAndSettle();
      voiceStartGate.complete();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Chat three history'), findsOneWidget);
      expect(find.text('Chat two history'), findsNothing);
      expect(find.byType(VoiceRecorderWidget), findsNothing);
      expect(recorders.single.cancelCount, greaterThanOrEqualTo(1));
      expect(recorders.single.disposeCount, 1);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.longPress(find.byIcon(Icons.videocam));
      await tester.pump();
      expect(find.byType(VideoRecordingOverlay), findsOneWidget);
      expect(cameras[2].startCount, 1);

      testRouter.go('/chat/chat-4');
      await tester.pumpAndSettle();

      expect(find.text('Chat four history'), findsOneWidget);
      expect(find.text('Chat three history'), findsNothing);
      expect(find.byType(VideoRecordingOverlay), findsNothing);
      expect(cameras, hasLength(4));
      expect(cameras[2].resetCount, greaterThanOrEqualTo(1));
      expect(cameras[2].disposeCount, 1);
    },
  );

  for (final localeAndCopy in <(Locale, String)>[
    (
      const Locale('en'),
      'Chat history is unavailable offline until the first sync completes.',
    ),
    (
      const Locale('ru'),
      'История чата недоступна без подключения до завершения первой синхронизации.',
    ),
  ]) {
    testWidgets(
      'first-sync offline unavailable is localized for ${localeAndCopy.$1.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: localeAndCopy.$1,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: buildChatSession(
              chatId: 'never-synced',
              createMessagesBloc: (id) => _sessionBloc(id, _MessagesCache()),
              createCameraService: _TrackingCameraService.new,
              createVoiceRecordingService: _TrackingVoiceRecordingService.new,
              child: const MessagesScreen(
                chatId: 'never-synced',
                title: 'Offline chat',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(localeAndCopy.$2), findsOneWidget);
      },
    );
  }
}
