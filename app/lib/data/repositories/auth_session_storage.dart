import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Persists profile in SharedPreferences and JWT in platform secure storage.
class AuthSessionStorage {
  static const _userKey = 'auth_user';
  static const _tokenKey = 'auth_access_token';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = Map<String, dynamic>.from(user.toJson())
      ..remove('access_token');
    await prefs.setString(_userKey, jsonEncode(profile));

    final token = user.accessToken;
    if (token != null && token.isNotEmpty) {
      await _secure.write(key: _tokenKey, value: token);
    } else {
      await _secure.delete(key: _tokenKey);
    }
  }

  Future<UserModel?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = Map<String, dynamic>.from(
        jsonDecode(raw) as Map<dynamic, dynamic>,
      );

      // Migrate legacy plaintext token out of SharedPreferences.
      final legacyToken = json['access_token']?.toString();
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await _secure.write(key: _tokenKey, value: legacyToken);
        json.remove('access_token');
        await prefs.setString(_userKey, jsonEncode(json));
      }

      final token = await _secure.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        await clear();
        return null;
      }

      return UserModel.fromJson({...json, 'access_token': token});
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await _secure.delete(key: _tokenKey);
  }
}
