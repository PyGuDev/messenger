class ChatApiException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  ChatApiException({
    required this.code,
    required this.message,
    this.details,
  });

  factory ChatApiException.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>?;
    return ChatApiException(
      code: error?['code']?.toString() ?? 'UNKNOWN_ERROR',
      message: error?['message']?.toString() ?? 'An unknown error occurred',
      details: error?['details'],
    );
  }

  @override
  String toString() => 'ChatApiException(code: $code, message: $message)';
}
