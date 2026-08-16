import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/core/cache/profile_cache.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_event.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_state.dart';
import 'package:messenger/features/profile/presentation/screens/edit_profile_screen.dart';

class _MemoryProfileCache implements ProfileCache {
  final Map<String, UserProfile> entries = <String, UserProfile>{};
  final StreamController<String> _invalidations =
      StreamController<String>.broadcast();

  @override
  Stream<String> get invalidatedUserIds => _invalidations.stream;

  @override
  Future<void> discardLegacyEntry() async {}

  @override
  Future<UserProfile?> read(String userId) async => entries[userId];

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
  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> getAccessToken() async => 'token';

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<String?> getUserId() async => 'account-a';

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {}

  @override
  Future<void> saveUserId(String userId) async {}
}

class _ControlledProfileBloc extends ProfileBloc {
  _ControlledProfileBloc({required this.updateSucceeds})
    : super(Dio(), _MemoryProfileCache(), _FakeTokenStorage()) {
    emit(_initialProfile);
  }

  final bool updateSucceeds;

  static const ProfileLoaded _initialProfile = ProfileLoaded(
    id: 'account-a',
    firstName: 'Initial',
    lastName: 'Profile',
    phone: '+70000000001',
    email: 'initial@example.com',
  );

  @override
  void add(ProfileEvent event) {
    if (event is! UpdateProfile) {
      super.add(event);
      return;
    }

    emit(
      const ProfileUpdateInProgress(
        id: 'account-a',
        firstName: 'Initial',
        lastName: 'Profile',
        phone: '+70000000001',
        email: 'initial@example.com',
      ),
    );
    Future<void>.delayed(Duration.zero, () {
      if (updateSucceeds) {
        emit(
          ProfileUpdateSuccess(
            id: 'account-a',
            firstName: event.firstName ?? 'Initial',
            lastName: event.lastName ?? 'Profile',
            phone: event.phone ?? '+70000000001',
            email: event.email ?? 'initial@example.com',
          ),
        );
      } else {
        emit(
          const ProfileUpdateFailure(
            id: 'account-a',
            firstName: 'Initial',
            lastName: 'Profile',
            phone: '+70000000001',
            email: 'initial@example.com',
            message: 'Не удалось обновить профиль. Попробуйте ещё раз.',
          ),
        );
      }
    });
  }
}

GoRouter _router() => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.push('/edit-profile'),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
  ],
);

Future<void> _openEditor(
  WidgetTester tester,
  ProfileBloc bloc,
  GoRouter router,
) async {
  await tester.pumpWidget(
    BlocProvider<ProfileBloc>.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('failed update keeps editor open with entered values', (
    tester,
  ) async {
    final bloc = _ControlledProfileBloc(updateSucceeds: false);
    final router = _router();
    await _openEditor(tester, bloc, router);

    await tester.enterText(find.byType(TextField).first, 'Retained input');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Редактирование'), findsOneWidget);
    expect(find.text('Retained input'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });

  testWidgets('successful update closes editor and confirms success', (
    tester,
  ) async {
    final bloc = _ControlledProfileBloc(updateSucceeds: true);
    final router = _router();
    await _openEditor(tester, bloc, router);

    await tester.enterText(find.byType(TextField).first, 'Accepted input');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Open editor'), findsOneWidget);
    expect(find.text('Профиль обновлен'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}
