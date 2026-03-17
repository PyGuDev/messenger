import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/network_info.dart';
import 'network_event.dart';
import 'network_state.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  final NetworkInfo _networkInfo;
  StreamSubscription? _subscription;

  NetworkBloc(this._networkInfo) : super(NetworkInitial()) {
    on<NetworkChanged>((event, emit) {
      if (event.isConnected) {
        emit(NetworkConnected());
      } else {
        emit(NetworkDisconnected());
      }
    });

    _subscription = _networkInfo.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      add(NetworkChanged(isConnected));
    });

    // Initial check
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final isConnected = await _networkInfo.isConnected;
    add(NetworkChanged(isConnected));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
