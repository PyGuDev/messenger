import 'dart:convert';
import 'package:dio/dio.dart';

class UserProfile {
  final String firstName;
  final String lastName;
  final String phone;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
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

      final response = await _dio.get('/users/search', queryParameters: queryParams);
      final data = response.data;
      
      if (data is List) {
        return data.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
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
