import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';
import '../security/token_storage.dart';
import 'runtime_environment_profile.dart';

class NetworkModule {
  static Dio createFileDio(
    RuntimeEnvironmentProfile profile,
    TokenStorage tokenStorage,
    Dio authDio, {
    required void Function() onTokenExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: profile.fileBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(tokenStorage, authDio, onTokenExpired: onTokenExpired),
    );
    _addLoggingIfDebug(dio);

    return dio;
  }

  static Dio createAuthDio(
    RuntimeEnvironmentProfile profile,
    TokenStorage tokenStorage,
    Dio refreshDio, {
    required void Function() onTokenExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: profile.authBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(tokenStorage, refreshDio, onTokenExpired: onTokenExpired),
    );

    _addLoggingIfDebug(dio);

    return dio;
  }

  static Dio createChatDio(
    RuntimeEnvironmentProfile profile,
    TokenStorage tokenStorage,
    Dio authDio, {
    required void Function() onTokenExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: profile.chatBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Order matters: Auth first, then Retry, then Logging
    dio.interceptors.add(
      AuthInterceptor(tokenStorage, authDio, onTokenExpired: onTokenExpired),
    );
    dio.interceptors.add(RetryInterceptor(maxRetries: 3));
    _addLoggingIfDebug(dio);

    return dio;
  }

  static void _addLoggingIfDebug(Dio dio) {
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }
}
