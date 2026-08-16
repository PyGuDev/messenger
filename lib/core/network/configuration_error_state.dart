import 'package:equatable/equatable.dart';

class ConfigurationErrorState extends Equatable {
  final String code;
  final String message;
  final List<String> missingKeys;
  final List<String> affectedFlows;

  const ConfigurationErrorState({
    required this.code,
    required this.message,
    this.missingKeys = const [],
    this.affectedFlows = const [],
  });

  @override
  List<Object?> get props => [code, message, missingKeys, affectedFlows];
}
