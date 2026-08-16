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

class ProfileUpdateInProgress extends ProfileLoaded {
  const ProfileUpdateInProgress({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    super.phone,
  });
}

class ProfileUpdateSuccess extends ProfileLoaded {
  const ProfileUpdateSuccess({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    super.phone,
  });
}

class ProfileUpdateFailure extends ProfileLoaded {
  final String message;

  const ProfileUpdateFailure({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    required this.message,
    super.phone,
  });

  @override
  List<Object?> get props => <Object?>[...super.props, message];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
