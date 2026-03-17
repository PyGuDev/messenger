import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {}

class UpdateProfile extends ProfileEvent {
  final String? firstName;
  final String? lastName;
  final String? phone;

  const UpdateProfile({this.firstName, this.lastName, this.phone});

  @override
  List<Object?> get props => [firstName, lastName, phone];
}
