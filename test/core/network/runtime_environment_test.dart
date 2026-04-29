import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/network/runtime_environment_profile.dart';

void main() {
  group('RuntimeEnvironmentProfile', () {
    test('validates a complete profile', () {
      const profile = RuntimeEnvironmentProfile(
        environmentName: 'test',
        authBaseUrl: 'https://auth.example.com/auth/api/v1',
        chatBaseUrl: 'https://chat.example.com/room/api/v1',
        fileBaseUrl: 'https://files.example.com/file',
        wsBaseUrl: 'wss://chat.example.com/room/ws',
      );

      expect(profile.validate(), isNull);
    });

    test('reports invalid and missing values', () {
      const profile = RuntimeEnvironmentProfile(
        environmentName: 'broken',
        authBaseUrl: '',
        chatBaseUrl: 'not-a-url',
        fileBaseUrl: 'https://files.example.com/file',
        wsBaseUrl: 'https://chat.example.com/room/ws',
      );

      final error = profile.validate();

      expect(error, isNotNull);
      expect(
        error!.missingKeys,
        containsAll(<String>[
          'APP_AUTH_BASE_URL',
          'APP_CHAT_BASE_URL',
          'APP_WS_BASE_URL',
        ]),
      );
    });
  });
}
