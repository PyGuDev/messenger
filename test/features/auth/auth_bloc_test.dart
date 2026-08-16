import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/cache/profile_cache.dart';
import 'package:messenger/core/network/network_info.dart';
import 'package:messenger/core/network/runtime_environment_profile.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:messenger/core/network/websocket_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'package:messenger/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:messenger/features/auth/presentation/bloc/auth_event.dart';
import 'package:messenger/features/auth/presentation/bloc/auth_state.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_event.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_state.dart';

class _FakeTokenStorage implements TokenStorage {
  String? userId = 'account-a';
  bool cleared = false;

  @override
  Future<void> clearTokens() async {
    cleared = true;
    userId = null;
  }

  @override
  Future<String?> getAccessToken() async => 'token';

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<String?> getUserId() async => userId;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {}

  @override
  Future<void> saveUserId(String userId) async {
    this.userId = userId;
  }
}

class _RecordingProfileCache implements ProfileCache {
  _RecordingProfileCache(this.tokenStorage, {this.throwOnRemove = false});

  final _FakeTokenStorage tokenStorage;
  final bool throwOnRemove;
  final Map<String, UserProfile> entries = <String, UserProfile>{};
  final StreamController<String> _invalidations =
      StreamController<String>.broadcast();
  bool removedBeforeTokenClear = false;

  @override
  Stream<String> get invalidatedUserIds => _invalidations.stream;

  @override
  Future<void> discardLegacyEntry() async {}

  @override
  Future<UserProfile?> read(String userId) async => entries[userId];

  @override
  Future<void> remove(String userId) async {
    removedBeforeTokenClear =
        userId == 'account-a' && tokenStorage.userId == 'account-a';
    try {
      if (throwOnRemove) throw StateError('cache unavailable');
      entries.remove(userId);
    } finally {
      _invalidations.add(userId);
    }
  }

  @override
  Future<void> write(String userId, UserProfile profile) async {
    entries[userId] = profile;
  }
}

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream<List<ConnectivityResult>>.empty();
}

WebSocketService _webSocketService(TokenStorage tokenStorage) =>
    _FakeWebSocketService(
      tokenStorage,
      _FakeNetworkInfo(),
      const RuntimeEnvironmentProfile(
        environmentName: 'test',
        authBaseUrl: 'https://auth.example.com',
        chatBaseUrl: 'https://chat.example.com',
        fileBaseUrl: 'https://files.example.com',
        wsBaseUrl: 'wss://chat.example.com/ws',
      ),
    );

class _FakeWebSocketService extends WebSocketService {
  _FakeWebSocketService(super.tokenStorage, super.networkInfo, super.profile);

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}
}

void main() {
  test(
    'logout removes the User Account Cached Profile before ending the Authenticated Session',
    () async {
      final tokenStorage = _FakeTokenStorage();
      final cache = _RecordingProfileCache(tokenStorage);
      final bloc = AuthBloc(
        Dio(),
        tokenStorage,
        _webSocketService(tokenStorage),
        cache,
      );

      expectLater(
        bloc.stream,
        emitsInOrder(<AuthState>[AuthLoading(), AuthUnauthenticated()]),
      );
      bloc.add(LogoutRequested());
      await bloc.stream.firstWhere((state) => state is AuthUnauthenticated);

      expect(cache.removedBeforeTokenClear, isTrue);
      expect(tokenStorage.cleared, isTrue);

      await bloc.close();
    },
  );

  test(
    'logout still ends the Authenticated Session when Cached Profile removal fails',
    () async {
      final tokenStorage = _FakeTokenStorage();
      final cache = _RecordingProfileCache(tokenStorage, throwOnRemove: true);
      final bloc = AuthBloc(
        Dio(),
        tokenStorage,
        _webSocketService(tokenStorage),
        cache,
      );

      bloc.add(LogoutRequested());
      await bloc.stream.firstWhere((state) => state is AuthUnauthenticated);

      expect(tokenStorage.cleared, isTrue);

      await bloc.close();
    },
  );

  test(
    'switching User Accounts never emits the previous User Account Profile',
    () async {
      final tokenStorage = _FakeTokenStorage();
      final cache = _RecordingProfileCache(tokenStorage)
        ..entries['account-a'] = const UserProfile(
          id: 'account-a',
          firstName: 'Cached account A',
          lastName: 'Profile',
          phone: '+70000000001',
          email: 'account-a@example.com',
        );
      final authDio = Dio();
      authDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'access_token': 'token-b',
                'refresh_token': 'refresh-b',
                'user_id': 'account-b',
              },
            ),
          ),
        ),
      );
      final profileDio = Dio();
      final firstRequestStarted = Completer<void>();
      final firstResponse = Completer<void>();
      var profileRequests = 0;
      profileDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            profileRequests += 1;
            if (profileRequests == 1) {
              firstRequestStarted.complete();
              await firstResponse.future;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'id': 'account-a',
                    'firstName': 'Stale account A',
                    'lastName': 'Profile',
                    'phone': '+70000000001',
                    'email': 'account-a@example.com',
                  },
                ),
              );
              return;
            }

            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'id': 'account-b',
                  'firstName': 'Current account B',
                  'lastName': 'Profile',
                  'phone': '+70000000002',
                  'email': 'account-b@example.com',
                },
              ),
            );
          },
        ),
      );
      final authBloc = AuthBloc(
        authDio,
        tokenStorage,
        _webSocketService(tokenStorage),
        cache,
      );
      final profileBloc = ProfileBloc(profileDio, cache, tokenStorage);
      final emittedProfiles = <ProfileState>[];
      final subscription = profileBloc.stream.listen(emittedProfiles.add);

      profileBloc.add(LoadProfile());
      await firstRequestStarted.future;

      final unauthenticated = authBloc.stream.firstWhere(
        (state) => state is AuthUnauthenticated,
      );
      final profileCleared = profileBloc.stream.firstWhere(
        (state) => state is ProfileInitial,
      );
      authBloc.add(LogoutRequested());
      await Future.wait(<Future<Object?>>[unauthenticated, profileCleared]);
      expect(profileBloc.state, isA<ProfileInitial>());
      emittedProfiles.clear();

      final authenticated = authBloc.stream.firstWhere(
        (state) => state is AuthAuthenticated,
      );
      authBloc.add(const LoginRequested('account-b@example.com', 'password'));
      await authenticated;

      profileBloc.add(LoadProfile());
      await profileBloc.stream.firstWhere(
        (state) => state is ProfileLoaded && state.id == 'account-b',
      );
      firstResponse.complete();
      await Future<void>.delayed(Duration.zero);

      expect(
        emittedProfiles.whereType<ProfileLoaded>().map((state) => state.id),
        isNot(contains('account-a')),
      );
      expect(cache.entries['account-a'], isNull);
      expect(cache.entries['account-b']?.firstName, 'Current account B');

      await subscription.cancel();
      await profileBloc.close();
      await authBloc.close();
    },
  );
}
