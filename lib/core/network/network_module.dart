import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';
import '../security/token_storage.dart';

class NetworkModule {
  static const String authBaseUrl = 'http://192.168.8.236:8002/api/v1';
  static const String chatBaseUrl = 'http://192.168.8.236:8003/api/v1';
  static const String wsBaseUrl = 'ws://192.168.8.236:8003/ws';

  static Dio createAuthDio(
    TokenStorage tokenStorage,
    Dio refreshDio, {
    required void Function() onTokenExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: authBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(tokenStorage, refreshDio, onTokenExpired: onTokenExpired),
    );

    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

    return dio;
  }

  static Dio createChatDio(
    TokenStorage tokenStorage,
    Dio authDio, {
    required void Function() onTokenExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: chatBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Order matters: Auth first, then Retry, then Logging
    dio.interceptors.add(
      AuthInterceptor(tokenStorage, authDio, onTokenExpired: onTokenExpired),
    );
    dio.interceptors.add(RetryInterceptor(maxRetries: 3));

    // Add logging in debug
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

    return dio;
  }
}
