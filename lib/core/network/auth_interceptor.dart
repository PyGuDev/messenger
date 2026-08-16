import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../security/token_storage.dart';

/// Handles 401 errors by refreshing the access token.
/// Uses a Completer-based queue to prevent multiple concurrent refresh calls.
class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _refreshDio;
  final void Function() onTokenExpired;

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor(
    this._tokenStorage,
    this._refreshDio, {
    required this.onTokenExpired,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      _log('401 received, attempting token refresh');

      try {
        final newToken = await _refreshToken();
        if (newToken != null) {
          _log('token refresh succeeded, retrying original request');
          // Retry the original request with the new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';

          // Create a temporary dio instance with the same base URL for the retry
          final retryDio = Dio(BaseOptions(baseUrl: options.baseUrl));
          final retryResponse = await retryDio.fetch(options);

          return handler.resolve(retryResponse);
        } else {
          _log('token refresh returned no token');
          await _tokenStorage.clearTokens();
          onTokenExpired();
        }
      } catch (e) {
        _log('token refresh failed: $e');
        // Refresh failed — clear tokens and potentially redirect to login
        await _tokenStorage.clearTokens();
        onTokenExpired();
      }
    }
    return handler.next(err);
  }

  /// Queue-based token refresh to avoid concurrent refresh calls.
  Future<String?> _refreshToken() async {
    if (_isRefreshing) {
      // Wait for the ongoing refresh to complete
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String;
      await _tokenStorage.saveTokens(newAccessToken, newRefreshToken);

      _refreshCompleter!.complete(newAccessToken);
      return newAccessToken;
    } catch (e) {
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AuthInterceptor] $message');
    }
  }
}
