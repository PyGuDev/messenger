import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'chats_bloc.dart';
import 'chats_event.dart';

enum ContactChatLaunchStatus {
  idle,
  checkingExisting,
  creating,
  navigating,
  failed,
}

class ContactChatLaunchState extends Equatable {
  final ContactChatLaunchStatus status;
  final String? resolvedChatId;
  final String? failureMessage;
  final String? activeUserId;

  const ContactChatLaunchState({
    this.status = ContactChatLaunchStatus.idle,
    this.resolvedChatId,
    this.failureMessage,
    this.activeUserId,
  });

  bool get isInFlight =>
      status == ContactChatLaunchStatus.checkingExisting ||
      status == ContactChatLaunchStatus.creating ||
      status == ContactChatLaunchStatus.navigating;

  ContactChatLaunchState copyWith({
    ContactChatLaunchStatus? status,
    String? resolvedChatId,
    String? failureMessage,
    String? activeUserId,
    bool clearResolvedChatId = false,
    bool clearFailureMessage = false,
  }) {
    return ContactChatLaunchState(
      status: status ?? this.status,
      resolvedChatId: clearResolvedChatId
          ? null
          : (resolvedChatId ?? this.resolvedChatId),
      failureMessage: clearFailureMessage
          ? null
          : (failureMessage ?? this.failureMessage),
      activeUserId: activeUserId ?? this.activeUserId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    resolvedChatId,
    failureMessage,
    activeUserId,
  ];
}

class ContactChatLaunchBloc extends Cubit<ContactChatLaunchState> {
  final Dio _dio;
  final ChatsBloc _chatsBloc;

  ContactChatLaunchBloc(this._dio, this._chatsBloc)
    : super(const ContactChatLaunchState());

  Future<void> launchConversation({
    required String userId,
    required String displayName,
  }) async {
    if (userId.isEmpty) {
      emit(
        state.copyWith(
          status: ContactChatLaunchStatus.failed,
          failureMessage: 'Не удалось определить ID пользователя',
          clearResolvedChatId: true,
        ),
      );
      return;
    }

    if (state.isInFlight && state.activeUserId == userId) {
      return;
    }

    emit(
      ContactChatLaunchState(
        status: ContactChatLaunchStatus.checkingExisting,
        activeUserId: userId,
      ),
    );

    try {
      final existingChatId = await _findExistingDirectChat(userId);
      if (existingChatId != null) {
        _chatsBloc.add(LoadChats());
        emit(
          ContactChatLaunchState(
            status: ContactChatLaunchStatus.navigating,
            activeUserId: userId,
            resolvedChatId: existingChatId,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: ContactChatLaunchStatus.creating,
          clearFailureMessage: true,
          clearResolvedChatId: true,
        ),
      );

      final response = await _dio.post(
        '/chats',
        data: {
          'type': 1,
          'member_ids': [userId],
        },
      );

      final chatId = _extractChatId(response.data);
      if (chatId == null || chatId.isEmpty) {
        throw const FormatException('Chat id is missing in create response');
      }

      _chatsBloc.add(LoadChats());
      emit(
        ContactChatLaunchState(
          status: ContactChatLaunchStatus.navigating,
          activeUserId: userId,
          resolvedChatId: chatId,
        ),
      );
    } on DioException catch (error) {
      emit(
        ContactChatLaunchState(
          status: ContactChatLaunchStatus.failed,
          activeUserId: userId,
          failureMessage: _resolveFailureMessage(error),
        ),
      );
    } catch (_) {
      emit(
        ContactChatLaunchState(
          status: ContactChatLaunchStatus.failed,
          activeUserId: userId,
          failureMessage: 'Не удалось открыть чат',
        ),
      );
    }
  }

  void clearOutcome() {
    emit(const ContactChatLaunchState());
  }

  Future<String?> _findExistingDirectChat(String userId) async {
    try {
      final response = await _dio.get(
        '/chats/personal',
        queryParameters: {'user_id': userId},
      );
      return _extractChatId(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  String? _extractChatId(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return (data['chat_id'] ?? data['id'] ?? data['ID'])?.toString();
    }
    return (payload['chat_id'] ?? payload['id'] ?? payload['ID'])?.toString();
  }

  String _resolveFailureMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final nestedError = responseData['error'];
      if (nestedError is Map<String, dynamic>) {
        final message = nestedError['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      final message = responseData['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    return 'Не удалось открыть чат';
  }
}
