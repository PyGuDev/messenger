import 'dart:async';
import 'dart:convert';

import 'package:messenger/core/network/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ProfileCache {
  Stream<String> get invalidatedUserIds;

  Future<UserProfile?> read(String userId);

  Future<void> write(String userId, UserProfile profile);

  Future<void> remove(String userId);

  Future<void> discardLegacyEntry();
}

class SharedPreferencesProfileCache implements ProfileCache {
  SharedPreferencesProfileCache(this._preferences);

  final SharedPreferences _preferences;
  final StreamController<String> _invalidations =
      StreamController<String>.broadcast();

  static const String _legacyKey = 'cached_user_profile';
  static const String _scopedKeyPrefix = 'cached_user_profile:';

  @override
  Stream<String> get invalidatedUserIds => _invalidations.stream;

  @override
  Future<UserProfile?> read(String userId) async {
    if (userId.trim().isEmpty) return null;

    final encoded = _preferences.getString(_keyFor(userId));
    if (encoded == null) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      return UserProfile.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String userId, UserProfile profile) async {
    if (userId.trim().isEmpty) return;

    await _preferences.setString(
      _keyFor(userId),
      jsonEncode(<String, dynamic>{
        'id': profile.id,
        'firstName': profile.firstName,
        'lastName': profile.lastName,
        'phone': profile.phone,
        'email': profile.email,
      }),
    );
  }

  @override
  Future<void> remove(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      await _preferences.remove(_keyFor(userId));
    } finally {
      _invalidations.add(userId);
    }
  }

  @override
  Future<void> discardLegacyEntry() async {
    await _preferences.remove(_legacyKey);
  }

  String _keyFor(String userId) => '$_scopedKeyPrefix$userId';
}
