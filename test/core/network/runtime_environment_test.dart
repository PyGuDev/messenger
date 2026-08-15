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

    test('prefers Dart defines over .env values', () {
      final profile = RuntimeEnvironmentProfile.fromSources(
        dotenvValues: const <String, String>{
          'APP_ENVIRONMENT_NAME': 'dotenv',
          'APP_AUTH_BASE_URL': 'https://dotenv.example.com/auth',
          'APP_CHAT_BASE_URL': 'https://dotenv.example.com/chat',
          'APP_FILE_BASE_URL': 'https://dotenv.example.com/files',
          'APP_WS_BASE_URL': 'wss://dotenv.example.com/ws',
        },
        dartDefines: const <String, String>{
          'APP_ENVIRONMENT_NAME': 'release',
          'APP_AUTH_BASE_URL': 'https://define.example.com/auth',
          'APP_CHAT_BASE_URL': 'https://define.example.com/chat',
          'APP_FILE_BASE_URL': 'https://define.example.com/files',
          'APP_WS_BASE_URL': 'wss://define.example.com/ws',
        },
      );

      expect(profile.environmentName, 'release');
      expect(profile.authBaseUrl, 'https://define.example.com/auth');
      expect(profile.chatBaseUrl, 'https://define.example.com/chat');
      expect(profile.fileBaseUrl, 'https://define.example.com/files');
      expect(profile.wsBaseUrl, 'wss://define.example.com/ws');
    });

    test('does not fall back to .env for an empty Dart define', () {
      final profile = RuntimeEnvironmentProfile.fromSources(
        dotenvValues: const <String, String>{
          'APP_AUTH_BASE_URL': 'https://dotenv.example.com/auth',
        },
        dartDefines: const <String, String>{'APP_AUTH_BASE_URL': ''},
      );

      expect(profile.authBaseUrl, isEmpty);
      expect(profile.validate()!.missingKeys, contains('APP_AUTH_BASE_URL'));
    });
  });
}
