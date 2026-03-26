import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'profile_event.dart';
import 'profile_state.dart';

import 'package:messenger/core/network/user_service.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  // ignore: unused_field
  final Dio _dio;

  ProfileBloc(this._dio) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final response = await _dio.get('/profile');
      final profile = UserProfile.fromJson(response.data);
      
      emit(ProfileLoaded(
        id: profile.id,
        firstName: profile.firstName,
        lastName: profile.lastName,
        email: profile.email,
        phone: profile.phone,
      ));
    } catch (e) {
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
        
        emit(ProfileLoaded(
          id: profile.id.isNotEmpty ? profile.id : currentState.id,
          firstName: profile.firstName.isNotEmpty ? profile.firstName : currentState.firstName,
          lastName: profile.lastName.isNotEmpty ? profile.lastName : currentState.lastName,
          email: profile.email.isNotEmpty ? profile.email : currentState.email,
          phone: profile.phone.isNotEmpty ? profile.phone : currentState.phone,
        ));
      } catch (e) {
        emit(ProfileError(e.toString()));
        emit(currentState); // Revert to previous state on error
      }
    }
  }
}
