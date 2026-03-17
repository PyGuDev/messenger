import 'package:equatable/equatable.dart';

abstract class NetworkEvent extends Equatable {
  const NetworkEvent();

  @override
  List<Object?> get props => [];
}

class NetworkChanged extends NetworkEvent {
  final bool isConnected;

  const NetworkChanged(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}
