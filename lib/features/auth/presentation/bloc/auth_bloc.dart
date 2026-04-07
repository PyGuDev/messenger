import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:messenger/core/security/token_storage.dart';
import '../../../../core/network/websocket_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  final WebSocketService _wsService;

  AuthBloc(this._dio, this._tokenStorage, this._wsService) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }


  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) {
        _wsService.connect();
        emit(AuthAuthenticated());
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _dio.post('/auth/signin', data: {
        'email': event.email,
        'password': event.password,
      });
      
      final responseData = response.data;
      final data = responseData['data'] ?? responseData;
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      final userId = (data['user_id'] ?? data['id']).toString();
      
      await _tokenStorage.saveTokens(accessToken, refreshToken);
      await _tokenStorage.saveUserId(userId);
      _wsService.connect();
      emit(AuthAuthenticated());
    } on DioException catch (e) {
      String? message;
      if (e.response?.statusCode == 400) {
        message = 'Не верное имя пользователя или пароль';
      } else if (e.response?.data is Map) {
        message = e.response?.data['message'] ?? e.response?.data['error'];
      }
      message ??= e.message ?? 'Authentication failed';
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onRegisterRequested(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _dio.post('/auth/signup', data: {
        'email': event.email,
        'firstName': event.firstName,
        'lastName': event.lastName,
        'password': event.password,
        'confirmPassword': event.confirmPassword,
        'phone': event.phone,
      });
      
      final responseData = response.data;
      final data = responseData['data'] ?? responseData;
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      final userId = (data['user_id'] ?? data['id']).toString();
      
      await _tokenStorage.saveTokens(accessToken, refreshToken);
      await _tokenStorage.saveUserId(userId);
      _wsService.connect();
      emit(AuthAuthenticated());
    } on DioException catch (e) {
      String? message;
      if (e.response?.data is Map) {
        message = e.response?.data['message'];
      }
      message ??= e.message ?? 'Registration failed';
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _tokenStorage.clearTokens();
    _wsService.disconnect();
    emit(AuthUnauthenticated());
  }
}
