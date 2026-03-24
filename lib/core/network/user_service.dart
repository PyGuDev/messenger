import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;

  const UserProfile({
    this.id = '',
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as String?) ?? (json['ID'] as String?) ?? (json['userId'] as String?) ?? (json['userID'] as String?) ?? '',
      firstName: (json['firstName'] as String?) ?? '',
      lastName: (json['lastName'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
    );
  }

  String get displayName {
    final parts = [lastName, firstName].where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(' ') : 'User';
  }
}

class UserService {
  final Dio _dio;
  final Map<String, UserProfile> _cache = {};

  UserService(this._dio);

  /// Extract userID from JWT token payload.
  static String? extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode base64url payload
      String payload = parts[1];
      // Add padding if needed
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return (json['userID'] ?? json['user_id'] ?? json['sub']) as String?;
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> getUser(String userId) async {
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }

    try {
      final response = await _dio.get('/users/$userId');
      final data = response.data;
      // Response is flat JSON: {"firstName":"...", "lastName":"...", "phone":"..."}
      final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final profile = UserProfile.fromJson(json);
      _cache[userId] = profile;
      return profile;
    } catch (e) {
      return const UserProfile(firstName: '', lastName: '', phone: '');
    }
  }

  Future<List<UserProfile>> searchUser({String? phone, String? email}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;
      if (email != null && email.isNotEmpty) queryParams['email'] = email;
      
      if (queryParams.isEmpty) return [];

      final response = await _dio.get(
        '/users/search', 
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.plain),
      );
      final rawBody = response.data as String;
      debugPrint('[UserService] searchUser RAW JSON BODY: $rawBody');
      
      // Parse the raw JSON manually
      final dynamic data;
      try {
        data = jsonDecode(rawBody);
      } catch (e) {
        debugPrint('[UserService] Failed to parse JSON: $e');
        return [];
      }
      debugPrint('[UserService] searchUser parsed data: $data');
      
      if (data is List) {
        for (final e in data) {
          if (e is Map<String, dynamic>) {
            debugPrint('[UserService] item keys: ${e.keys.toList()}, full item: $e');
          }
        }
        final results = data.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
        for (final p in results) {
          debugPrint('[UserService] parsed profile: id=${p.id}, firstName=${p.firstName}, phone=${p.phone}');
        }
        return results;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  void clearCache() {
    _cache.clear();
  }
}
