import 'dart:async';
import 'package:dio/dio.dart';

/// Retries failed requests due to transient network errors (timeouts, 5xx).
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      final delay = retryDelay * (retryCount + 1); // Linear backoff
      await Future.delayed(delay);

      try {
        final options = err.requestOptions;
        options.extra['retryCount'] = retryCount + 1;
        final response = await Dio().fetch(options);
        return handler.resolve(response);
      } catch (e) {
        // Will be caught by the next retry or propagated
        if (e is DioException) {
          return handler.next(e);
        }
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    // Retry on connection timeouts and server errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on 5xx server errors
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }

    return false;
  }
}
