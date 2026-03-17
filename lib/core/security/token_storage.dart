import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TokenStorage {
  Future<void> saveTokens(String accessToken, String refreshToken);
  Future<void> saveUserId(String userId);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<String?> getUserId();
  Future<void> clearTokens();
}

class TokenStorageImpl implements TokenStorage {
  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;
  String? _accessToken;
  String? _userId;
  bool _useFallback = false;

  TokenStorageImpl(this._storage);

  Future<void> _initPrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
  }

  Future<T?> _runWithFallback<T>({
    required Future<T?> Function() secureAction,
    required Future<T?> Function() fallbackAction,
  }) async {
    if (_useFallback) {
      await _initPrefs();
      return await fallbackAction();
    }

    try {
      return await secureAction();
    } catch (e) {
      if (Platform.isMacOS && e is PlatformException) {
        // Handle keychain access error -34018
        _useFallback = true;
        await _initPrefs();
        return await fallbackAction();
      }
      rethrow;
    }
  }

  Future<void> _runWithFallbackVoid({
    required Future<void> Function() secureAction,
    required Future<void> Function() fallbackAction,
  }) async {
    if (_useFallback) {
      await _initPrefs();
      await fallbackAction();
      return;
    }

    try {
      await secureAction();
    } catch (e) {
      if (Platform.isMacOS && e is PlatformException) {
        _useFallback = true;
        await _initPrefs();
        await fallbackAction();
        return;
      }
      rethrow;
    }
  }

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    await _runWithFallbackVoid(
      secureAction: () async {
        await _storage.write(key: _accessTokenKey, value: accessToken);
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      },
      fallbackAction: () async {
        await _prefs?.setString(_accessTokenKey, accessToken);
        await _prefs?.setString(_refreshTokenKey, refreshToken);
      },
    );
  }

  @override
  Future<void> saveUserId(String userId) async {
    _userId = userId;
    await _runWithFallbackVoid(
      secureAction: () => _storage.write(key: _userIdKey, value: userId),
      fallbackAction: () async => await _prefs?.setString(_userIdKey, userId),
    );
  }

  @override
  Future<String?> getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    _accessToken = await _runWithFallback<String>(
      secureAction: () => _storage.read(key: _accessTokenKey),
      fallbackAction: () async => _prefs?.getString(_accessTokenKey),
    );
    return _accessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _runWithFallback<String>(
      secureAction: () => _storage.read(key: _refreshTokenKey),
      fallbackAction: () async => _prefs?.getString(_refreshTokenKey),
    );
  }

  @override
  Future<String?> getUserId() async {
    if (_userId != null) return _userId;
    _userId = await _runWithFallback<String>(
      secureAction: () => _storage.read(key: _userIdKey),
      fallbackAction: () async => _prefs?.getString(_userIdKey),
    );
    return _userId;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _userId = null;
    await _runWithFallbackVoid(
      secureAction: () async {
        await _storage.delete(key: _accessTokenKey);
        await _storage.delete(key: _refreshTokenKey);
        await _storage.delete(key: _userIdKey);
      },
      fallbackAction: () async {
        await _prefs?.remove(_accessTokenKey);
        await _prefs?.remove(_refreshTokenKey);
        await _prefs?.remove(_userIdKey);
      },
    );
  }
}
