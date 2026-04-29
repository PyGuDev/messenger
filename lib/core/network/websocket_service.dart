import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../security/token_storage.dart';
import 'network_info.dart';
import 'package:flutter/foundation.dart';
import 'runtime_environment_profile.dart';

enum WebSocketStatus { connected, disconnected, connecting }

class WebSocketService {
  final TokenStorage _tokenStorage;
  final NetworkInfo _networkInfo;
  final RuntimeEnvironmentProfile _profile;

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _eventController;
  StreamController<WebSocketStatus>? _statusController;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = false;
  StreamSubscription? _networkSubscription;

  WebSocketService(this._tokenStorage, this._networkInfo, this._profile) {
    _eventController = StreamController<Map<String, dynamic>>.broadcast();
    _statusController = StreamController<WebSocketStatus>.broadcast();

    _networkSubscription = _networkInfo.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (isConnected &&
          _shouldReconnect &&
          (_channel == null || _channel?.sink == null)) {
        _reconnectAttempts = 0;
        _establishConnection();
      }
    });
  }

  Stream<Map<String, dynamic>> get events => _eventController!.stream;
  Stream<WebSocketStatus> get status => _statusController!.stream;

  Future<void> connect() async {
    _log('connect requested');
    _shouldReconnect = true;
    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      _log('network unavailable, postponing websocket connection');
    }

    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      _log('connection aborted because access token is missing');
      _statusController?.add(WebSocketStatus.disconnected);
      return;
    }

    _statusController?.add(WebSocketStatus.connecting);
    final uri = Uri.parse('${_profile.wsBaseUrl}?token=${token.trim()}');

    try {
      _channel = WebSocketChannel.connect(uri);
      _log('connecting to ${uri.toString()}');

      _channel!.stream.listen(
        (data) {
          _log('received event payload');
          _reconnectAttempts = 0;
          _statusController?.add(WebSocketStatus.connected);
          try {
            final Map<String, dynamic> event = jsonDecode(data);
            _eventController?.add(event);
          } catch (e) {
            // Log parse error
          }
        },
        onDone: () {
          _log('connection closed');
          _handleDisconnection();
        },
        onError: (e) {
          _log('connection error: $e');
          _handleDisconnection();
        },
      );
    } catch (e) {
      _log('connection failed: $e');
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    _channel = null;
    _statusController?.add(WebSocketStatus.disconnected);
    if (_shouldReconnect) {
      _reconnect();
    }
  }

  void _reconnect() async {
    if (_reconnectTimer?.isActive ?? false) return;
    if (!await _networkInfo.isConnected) return; // Don't retry if offline

    final delaySeconds = _calculateDelay(_reconnectAttempts);
    _reconnectAttempts++;

    _statusController?.add(WebSocketStatus.connecting);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldReconnect) {
        _establishConnection();
      }
    });
  }

  int _calculateDelay(int attempt) {
    if (attempt == 0) return 1;
    if (attempt == 1) return 2;
    if (attempt == 2) return 4;
    if (attempt == 3) return 8;
    if (attempt == 4) return 16;
    return 60; // Max delay
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _statusController?.add(WebSocketStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _networkSubscription?.cancel();
    _eventController?.close();
    _statusController?.close();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[WebSocketService] $message');
    }
  }
}
