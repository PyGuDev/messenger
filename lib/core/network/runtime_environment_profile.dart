import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'configuration_error_state.dart';

class RuntimeEnvironmentProfile {
  static const _requiredFlowNames = <String>[
    'authentication',
    'chat messaging',
    'file transfers',
    'websocket updates',
  ];

  final String environmentName;
  final String authBaseUrl;
  final String chatBaseUrl;
  final String fileBaseUrl;
  final String wsBaseUrl;

  const RuntimeEnvironmentProfile({
    required this.environmentName,
    required this.authBaseUrl,
    required this.chatBaseUrl,
    required this.fileBaseUrl,
    required this.wsBaseUrl,
  });

  factory RuntimeEnvironmentProfile.fromEnvironment() {
    const undefined = '__runtime_environment_undefined__';
    final dartDefines = Map<String, String>.fromEntries(
      _supportedKeys.map(
        (key) =>
            MapEntry(key, String.fromEnvironment(key, defaultValue: undefined)),
      ),
    )..removeWhere((_, value) => value == undefined);

    return RuntimeEnvironmentProfile.fromSources(
      dotenvValues: dotenv.env,
      dartDefines: dartDefines,
    );
  }

  factory RuntimeEnvironmentProfile.fromSources({
    required Map<String, String> dotenvValues,
    required Map<String, String> dartDefines,
  }) {
    String getEnv(String key, {String defaultValue = ''}) {
      return dartDefines[key] ?? dotenvValues[key] ?? defaultValue;
    }

    return RuntimeEnvironmentProfile(
      environmentName: getEnv('APP_ENVIRONMENT_NAME', defaultValue: 'local'),
      authBaseUrl: getEnv('APP_AUTH_BASE_URL'),
      chatBaseUrl: getEnv('APP_CHAT_BASE_URL'),
      fileBaseUrl: getEnv('APP_FILE_BASE_URL'),
      wsBaseUrl: getEnv('APP_WS_BASE_URL'),
    );
  }

  static const _supportedKeys = <String>[
    'APP_ENVIRONMENT_NAME',
    'APP_AUTH_BASE_URL',
    'APP_CHAT_BASE_URL',
    'APP_FILE_BASE_URL',
    'APP_WS_BASE_URL',
  ];

  ConfigurationErrorState? validate() {
    final invalidKeys = <String>[];

    if (!_isValidHttpUrl(authBaseUrl)) invalidKeys.add('APP_AUTH_BASE_URL');
    if (!_isValidHttpUrl(chatBaseUrl)) invalidKeys.add('APP_CHAT_BASE_URL');
    if (!_isValidHttpUrl(fileBaseUrl)) invalidKeys.add('APP_FILE_BASE_URL');
    if (!_isValidWsUrl(wsBaseUrl)) invalidKeys.add('APP_WS_BASE_URL');

    if (invalidKeys.isEmpty) {
      return null;
    }

    return ConfigurationErrorState(
      code: 'runtime_configuration_invalid',
      message:
          'Required runtime environment values are missing or invalid. '
          'Update the app dart-defines before starting the client.',
      missingKeys: invalidKeys,
      affectedFlows: _requiredFlowNames,
    );
  }

  bool _isValidHttpUrl(String value) {
    if (value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool _isValidWsUrl(String value) {
    if (value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'ws' || uri.scheme == 'wss') &&
        uri.host.isNotEmpty;
  }
}
