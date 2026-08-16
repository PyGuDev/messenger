import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:messenger/core/cache/profile_cache.dart';
import 'package:messenger/core/security/token_storage.dart';
import 'profile_event.dart';
import 'profile_state.dart';

import 'package:messenger/core/network/user_service.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final Dio _dio;
  final ProfileCache _cache;
  final TokenStorage _tokenStorage;
  late final StreamSubscription<String> _cacheInvalidationSubscription;
  int _loadGeneration = 0;
  String? _activeUserId;

  ProfileBloc(this._dio, this._cache, this._tokenStorage)
    : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<CachedProfileInvalidated>(_onCachedProfileInvalidated);
    on<UpdateProfile>(_onUpdateProfile);
    _cacheInvalidationSubscription = _cache.invalidatedUserIds.listen(
      (userId) => add(CachedProfileInvalidated(userId)),
    );
  }

  void _onCachedProfileInvalidated(
    CachedProfileInvalidated event,
    Emitter<ProfileState> emit,
  ) {
    if (_activeUserId == event.userId) {
      _loadGeneration += 1;
      _activeUserId = null;
      emit(ProfileInitial());
    }
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    final generation = ++_loadGeneration;
    emit(ProfileLoading());
    final userId = (await _tokenStorage.getUserId())?.trim();
    if (generation == _loadGeneration) _activeUserId = userId;

    try {
      await _cache.discardLegacyEntry();
      if (userId != null && userId.isNotEmpty) {
        final cachedProfile = await _cache.read(userId);
        if (cachedProfile != null && await _isCurrentLoad(generation, userId)) {
          emit(_loaded(cachedProfile));
        }
      }

      final response = await _dio.get('/profile');
      final profile = UserProfile.fromJson(response.data);

      if (!await _isCurrentLoad(generation, userId)) return;

      if (!await _writeForCurrentSession(userId, profile)) return;

      if (generation != _loadGeneration) return;
      emit(_loaded(profile));
    } catch (e) {
      if (!await _isCurrentLoad(generation, userId)) return;
      if (state is ProfileLoaded) {
        return;
      }
      emit(ProfileError(e.toString()));
    }
  }

  ProfileLoaded _loaded(UserProfile profile) => ProfileLoaded(
    id: profile.id,
    firstName: profile.firstName,
    lastName: profile.lastName,
    email: profile.email,
    phone: profile.phone,
  );

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is ProfileUpdateInProgress) return;

    if (state is ProfileLoaded) {
      final currentState = state as ProfileLoaded;
      emit(
        ProfileUpdateInProgress(
          id: currentState.id,
          firstName: currentState.firstName,
          lastName: currentState.lastName,
          email: currentState.email,
          phone: currentState.phone,
        ),
      );
      final userId = (await _tokenStorage.getUserId())?.trim();
      try {
        final response = await _dio.patch(
          '/profile',
          data: {
            if (event.firstName != null) 'firstName': event.firstName,
            if (event.lastName != null) 'lastName': event.lastName,
            if (event.phone != null) 'phone': event.phone,
            if (event.email != null) 'email': event.email,
          },
        );

        final profile = UserProfile.fromJson(response.data);

        if (!await _sessionMatches(userId)) return;

        final updatedState = ProfileUpdateSuccess(
          id: profile.id,
          firstName: profile.firstName,
          lastName: profile.lastName,
          email: profile.email,
          phone: profile.phone,
        );

        if (!await _writeForCurrentSession(userId, profile)) return;

        emit(updatedState);
      } catch (e) {
        if (!await _sessionMatches(userId)) return;
        emit(
          ProfileUpdateFailure(
            id: currentState.id,
            firstName: currentState.firstName,
            lastName: currentState.lastName,
            email: currentState.email,
            phone: currentState.phone,
            message: _updateErrorMessage(e),
          ),
        );
      }
    }
  }

  Future<bool> _isCurrentLoad(int generation, String? userId) async =>
      generation == _loadGeneration && await _sessionMatches(userId);

  Future<bool> _sessionMatches(String? userId) async {
    final currentUserId = (await _tokenStorage.getUserId())?.trim();
    return currentUserId == userId;
  }

  Future<bool> _writeForCurrentSession(
    String? userId,
    UserProfile profile,
  ) async {
    if (!await _sessionMatches(userId)) return false;
    if (userId == null || userId.isEmpty) return true;

    await _cache.write(userId, profile);
    if (await _sessionMatches(userId)) return true;

    await _cache.remove(userId);
    return false;
  }

  String _updateErrorMessage(Object error) {
    if (error is DioException && error.response?.data is Map) {
      final data = error.response!.data as Map;
      final message = data['message'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return 'Не удалось обновить профиль. Попробуйте ещё раз.';
  }

  @override
  Future<void> close() async {
    await _cacheInvalidationSubscription.cancel();
    return super.close();
  }
}
