import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'profile_event.dart';
import 'profile_state.dart';

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
      final data = response.data;
      
      emit(ProfileLoaded(
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'],
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
          if (event.firstName != null) 'first_name': event.firstName,
          if (event.lastName != null) 'last_name': event.lastName,
          if (event.phone != null) 'phone': event.phone,
        });
        
        final data = response.data;
        
        emit(ProfileLoaded(
          firstName: data['first_name'] ?? currentState.firstName,
          lastName: data['last_name'] ?? currentState.lastName,
          email: currentState.email,
          phone: data['phone'] ?? currentState.phone,
        ));
      } catch (e) {
        emit(ProfileError(e.toString()));
        emit(currentState); // Revert to previous state on error
      }
    }
  }
}
