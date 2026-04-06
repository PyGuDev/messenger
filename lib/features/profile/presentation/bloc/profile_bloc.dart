import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_event.dart';
import 'profile_state.dart';

import 'package:messenger/core/network/user_service.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  // ignore: unused_field
  final Dio _dio;
  final SharedPreferences _prefs;

  static const String _cacheKey = 'cached_user_profile';

  ProfileBloc(this._dio, this._prefs) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final cachedStr = _prefs.getString(_cacheKey);
      if (cachedStr != null) {
        final cachedJson = jsonDecode(cachedStr) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(cachedJson);
        emit(ProfileLoaded(
          id: profile.id,
          firstName: profile.firstName,
          lastName: profile.lastName,
          email: profile.email,
          phone: profile.phone,
        ));
      }

      final response = await _dio.get('/profile');
      final profile = UserProfile.fromJson(response.data);
      
      _prefs.setString(_cacheKey, jsonEncode({
        'id': profile.id,
        'firstName': profile.firstName,
        'lastName': profile.lastName,
        'phone': profile.phone,
        'email': profile.email,
      }));

      emit(ProfileLoaded(
        id: profile.id,
        firstName: profile.firstName,
        lastName: profile.lastName,
        email: profile.email,
        phone: profile.phone,
      ));
    } catch (e) {
      if (state is ProfileLoaded) {
        return;
      }
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onUpdateProfile(UpdateProfile event, Emitter<ProfileState> emit) async {
    if (state is ProfileLoaded) {
      final currentState = state as ProfileLoaded;
      emit(ProfileLoading());
      try {
        final response = await _dio.patch('/profile', data: {
          if (event.firstName != null) 'firstName': event.firstName,
          if (event.lastName != null) 'lastName': event.lastName,
          if (event.phone != null) 'phone': event.phone,
          if (event.email != null) 'email': event.email,
        });
        
        final profile = UserProfile.fromJson(response.data);
        
        final updatedState = ProfileLoaded(
          id: profile.id.isNotEmpty ? profile.id : currentState.id,
          firstName: profile.firstName.isNotEmpty ? profile.firstName : currentState.firstName,
          lastName: profile.lastName.isNotEmpty ? profile.lastName : currentState.lastName,
          email: profile.email.isNotEmpty ? profile.email : currentState.email,
          phone: profile.phone.isNotEmpty ? profile.phone : currentState.phone,
        );

        _prefs.setString(_cacheKey, jsonEncode({
          'id': updatedState.id,
          'firstName': updatedState.firstName,
          'lastName': updatedState.lastName,
          'phone': updatedState.phone,
          'email': updatedState.email,
        }));

        emit(updatedState);
      } catch (e) {
        emit(currentState); // Revert to previous state on error
      }
    }
  }
}
