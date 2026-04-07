import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String email;
  final String firstName;
  final String lastName;
  final String password;
  final String confirmPassword;
  final String phone;

  const RegisterRequested({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.confirmPassword,
    required this.phone,
  });

  @override
  List<Object> get props => [email, firstName, lastName, password, confirmPassword, phone];
}

class LogoutRequested extends AuthEvent {}
