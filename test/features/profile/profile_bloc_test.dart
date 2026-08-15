import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/cache/profile_cache.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_event.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_state.dart';

class _MemoryProfileCache implements ProfileCache {
  final Map<String, UserProfile> entries = <String, UserProfile>{};
  final StreamController<String> _invalidations =
      StreamController<String>.broadcast();
  UserProfile? legacyEntry;
  bool legacyDiscarded = false;

  @override
  Stream<String> get invalidatedUserIds => _invalidations.stream;

  @override
  Future<void> discardLegacyEntry() async {
    legacyEntry = null;
    legacyDiscarded = true;
  }

  @override
  Future<UserProfile?> read(String userId) async =>
      entries[userId] ?? legacyEntry;

  @override
  Future<void> remove(String userId) async {
    entries.remove(userId);
    _invalidations.add(userId);
  }

  @override
  Future<void> write(String userId, UserProfile profile) async {
    entries[userId] = profile;
  }
}

class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage(this.userId);

  String? userId;

  @override
  Future<void> clearTokens() async {
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

void main() {
  test(
    'loads only the User Account Cached Profile before backend refresh',
    () async {
      final cache = _MemoryProfileCache()
        ..entries['account-a'] = const UserProfile(
          id: 'account-a',
          firstName: 'Cached',
          lastName: 'Account A',
          phone: '+70000000001',
          email: 'cached-a@example.com',
        )
        ..entries['account-b'] = const UserProfile(
          id: 'account-b',
          firstName: 'Private',
          lastName: 'Account B',
          phone: '+70000000002',
          email: 'private-b@example.com',
        );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'id': 'account-a',
                  'firstName': 'Server',
                  'lastName': 'Account A',
                  'phone': '+70000000003',
                  'email': 'server-a@example.com',
                },
              ),
            );
          },
        ),
      );
      final bloc = ProfileBloc(dio, cache, _FakeTokenStorage('account-a'));

      expectLater(
        bloc.stream,
        emitsInOrder(<ProfileState>[
          ProfileLoading(),
          const ProfileLoaded(
            id: 'account-a',
            firstName: 'Cached',
            lastName: 'Account A',
            phone: '+70000000001',
            email: 'cached-a@example.com',
          ),
          const ProfileLoaded(
            id: 'account-a',
            firstName: 'Server',
            lastName: 'Account A',
            phone: '+70000000003',
            email: 'server-a@example.com',
          ),
        ]),
      );

      bloc.add(LoadProfile());
      await bloc.stream.firstWhere(
        (state) => state is ProfileLoaded && state.firstName == 'Server',
      );

      expect(cache.entries['account-a']?.firstName, 'Server');
      expect(cache.entries['account-b']?.firstName, 'Private');
      expect(cache.legacyDiscarded, isTrue);

      await bloc.close();
    },
  );

  test(
    'update failure retains confirmed Profile and retry caches backend success',
    () async {
      final cache = _MemoryProfileCache();
      final dio = Dio();
      var patchAttempts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'id': 'account-a',
                    'firstName': 'Confirmed',
                    'lastName': 'Profile',
                    'phone': '+70000000001',
                    'email': 'confirmed@example.com',
                  },
                ),
              );
              return;
            }

            patchAttempts += 1;
            if (patchAttempts == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<void>(
                    requestOptions: options,
                    statusCode: 500,
                  ),
                ),
              );
              return;
            }

            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'id': 'account-a',
                  'firstName': 'Accepted',
                  'lastName': 'Profile',
                  'phone': '+70000000001',
                  'email': 'accepted@example.com',
                },
              ),
            );
          },
        ),
      );
      final bloc = ProfileBloc(dio, cache, _FakeTokenStorage('account-a'));
      bloc.add(LoadProfile());
      await bloc.stream.firstWhere(
        (state) => state is ProfileLoaded && state.firstName == 'Confirmed',
      );

      final failedUpdate = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const ProfileUpdateInProgress(
            id: 'account-a',
            firstName: 'Confirmed',
            lastName: 'Profile',
            phone: '+70000000001',
            email: 'confirmed@example.com',
          ),
          isA<ProfileUpdateFailure>()
              .having(
                (state) => state.firstName,
                'retained first name',
                'Confirmed',
              )
              .having((state) => state.message, 'error message', isNotEmpty),
        ]),
      );
      bloc.add(const UpdateProfile(firstName: 'Rejected'));
      await failedUpdate;

      expect(cache.entries['account-a']?.firstName, 'Confirmed');

      final successfulRetry = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const ProfileUpdateInProgress(
            id: 'account-a',
            firstName: 'Confirmed',
            lastName: 'Profile',
            phone: '+70000000001',
            email: 'confirmed@example.com',
          ),
          const ProfileUpdateSuccess(
            id: 'account-a',
            firstName: 'Accepted',
            lastName: 'Profile',
            phone: '+70000000001',
            email: 'accepted@example.com',
          ),
        ]),
      );
      bloc.add(const UpdateProfile(firstName: 'Accepted'));
      await successfulRetry;

      expect(cache.entries['account-a']?.firstName, 'Accepted');
      expect(patchAttempts, 2);

      await bloc.close();
    },
  );

  test(
    'ignores a stale Profile response after switching User Accounts',
    () async {
      final firstResponse = Completer<void>();
      final tokenStorage = _FakeTokenStorage('account-a');
      final cache = _MemoryProfileCache();
      final dio = Dio();
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requests += 1;
            if (requests == 1) {
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
      final bloc = ProfileBloc(dio, cache, tokenStorage);
      final emittedStates = <ProfileState>[];
      final subscription = bloc.stream.listen(emittedStates.add);

      bloc.add(LoadProfile());
      await Future<void>.delayed(Duration.zero);
      tokenStorage.userId = 'account-b';
      bloc.add(LoadProfile());
      await bloc.stream.firstWhere(
        (state) => state is ProfileLoaded && state.id == 'account-b',
      );
      firstResponse.complete();
      await Future<void>.delayed(Duration.zero);

      expect(
        emittedStates.whereType<ProfileLoaded>().map((state) => state.id),
        isNot(contains('account-a')),
      );
      expect(cache.entries['account-a'], isNull);
      expect(cache.entries['account-b']?.firstName, 'Current account B');

      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'failed backend refresh retains the User Account Cached Profile',
    () async {
      final cache = _MemoryProfileCache()
        ..entries['account-a'] = const UserProfile(
          id: 'account-a',
          firstName: 'Cached',
          lastName: 'Profile',
          phone: '+70000000001',
          email: 'cached@example.com',
        );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(requestOptions: options, error: 'offline'),
          ),
        ),
      );
      final bloc = ProfileBloc(dio, cache, _FakeTokenStorage('account-a'));

      final loaded = bloc.stream.firstWhere((state) => state is ProfileLoaded);
      bloc.add(LoadProfile());
      await loaded;
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<ProfileLoaded>());
      expect((bloc.state as ProfileLoaded).firstName, 'Cached');

      await bloc.close();
    },
  );

  test(
    'failed backend refresh without a Cached Profile emits a load error',
    () async {
      final cache = _MemoryProfileCache()
        ..entries['account-b'] = const UserProfile(
          id: 'account-b',
          firstName: 'Other account',
          lastName: 'Profile',
          phone: '+70000000002',
          email: 'other@example.com',
        );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(requestOptions: options, error: 'offline'),
          ),
        ),
      );
      final bloc = ProfileBloc(dio, cache, _FakeTokenStorage('account-a'));

      final errorState = bloc.stream.firstWhere(
        (state) => state is ProfileError,
      );
      bloc.add(LoadProfile());
      final error = await errorState;

      expect(error, isA<ProfileError>());
      expect(bloc.state, isNot(isA<ProfileLoaded>()));

      await bloc.close();
    },
  );

  test('ignores repeated submissions while profile update is active', () async {
    final patchResponse = Completer<void>();
    final patchStarted = Completer<void>();
    final cache = _MemoryProfileCache();
    final dio = Dio();
    var patchRequests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.method == 'GET') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'id': 'account-a',
                  'firstName': 'Confirmed',
                  'lastName': 'Profile',
                  'phone': '+70000000001',
                  'email': 'confirmed@example.com',
                },
              ),
            );
            return;
          }

          patchRequests += 1;
          if (!patchStarted.isCompleted) patchStarted.complete();
          await patchResponse.future;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'id': 'account-a',
                'firstName': 'Accepted',
                'lastName': 'Profile',
                'phone': '+70000000001',
                'email': 'confirmed@example.com',
              },
            ),
          );
        },
      ),
    );
    final bloc = ProfileBloc(dio, cache, _FakeTokenStorage('account-a'));
    final loaded = bloc.stream.firstWhere((state) => state is ProfileLoaded);
    bloc.add(LoadProfile());
    await loaded;

    final updating = bloc.stream.firstWhere(
      (state) => state is ProfileUpdateInProgress,
    );
    bloc.add(const UpdateProfile(firstName: 'Accepted'));
    bloc.add(const UpdateProfile(firstName: 'Duplicate'));
    await updating;
    await patchStarted.future;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(patchRequests, 1);

    final success = bloc.stream.firstWhere(
      (state) => state is ProfileUpdateSuccess,
    );
    patchResponse.complete();
    await success;
    await bloc.close();
  });

  test(
    'discards an ownerless legacy Cached Profile before scoped read',
    () async {
      final cache = _MemoryProfileCache()
        ..legacyEntry = const UserProfile(
          id: 'unknown-owner',
          firstName: 'Legacy identity',
          lastName: 'Must not render',
          phone: '+70000000000',
          email: 'legacy@example.com',
        );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'id': 'account-a',
                'firstName': 'Current identity',
                'lastName': 'Profile',
                'phone': '+70000000001',
                'email': 'current@example.com',
              },
            ),
          ),
        ),
      );
      final bloc = ProfileBloc(dio, cache, _FakeTokenStorage('account-a'));
      final emitted = <ProfileState>[];
      final subscription = bloc.stream.listen(emitted.add);

      bloc.add(LoadProfile());
      await bloc.stream.firstWhere(
        (state) => state is ProfileLoaded && state.id == 'account-a',
      );

      expect(
        emitted.whereType<ProfileLoaded>().map((state) => state.id),
        isNot(contains('unknown-owner')),
      );
      expect(cache.legacyEntry, isNull);
      expect(cache.entries['account-a']?.firstName, 'Current identity');

      await subscription.cancel();
      await bloc.close();
    },
  );

  test('uses empty fields accepted by the backend as authoritative', () async {
    final cache = _MemoryProfileCache();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: options.method == 'GET'
                ? <String, dynamic>{
                    'id': 'account-a',
                    'firstName': 'Confirmed',
                    'lastName': 'Profile',
                    'phone': '+70000000001',
                    'email': 'confirmed@example.com',
                  }
                : <String, dynamic>{
                    'id': '',
                    'firstName': '',
                    'lastName': '',
                    'phone': '',
                    'email': '',
                  },
          ),
        ),
      ),
    );
    final bloc = ProfileBloc(dio, cache, _FakeTokenStorage('account-a'));
    final loaded = bloc.stream.firstWhere((state) => state is ProfileLoaded);
    bloc.add(LoadProfile());
    await loaded;

    final success = bloc.stream.firstWhere(
      (state) => state is ProfileUpdateSuccess,
    );
    bloc.add(const UpdateProfile(firstName: 'Submitted'));
    final state = await success as ProfileUpdateSuccess;

    expect(state.firstName, isEmpty);
    expect(state.email, isEmpty);
    expect(cache.entries['account-a']?.firstName, isEmpty);

    await bloc.close();
  });
}
