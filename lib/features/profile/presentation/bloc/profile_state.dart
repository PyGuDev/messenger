import 'package:equatable/equatable.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;

  const ProfileLoaded({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
  });

  @override
  List<Object?> get props => [id, firstName, lastName, email, phone];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
