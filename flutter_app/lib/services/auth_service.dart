import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 1. Зробили змінну статичною, щоб мати до неї доступ з інших файлів
  static const String _prodUrl = 'https://fiyouai.onrender.com';

  static const String _devUrl = 'http://172.20.10.3:8000';

  // 3. Розумний геттер
  static String get baseUrl {
    if (kDebugMode) {
      // Якщо ми запустили через "Run" у VS Code/Xcode
      print("DEBUG MODE");
      return _devUrl;
    } else {
      // Якщо це Release версія (TestFlight / App Store)
      print("RELEASE MODE");
      return _prodUrl;
    }
  }

  // Збереження даних сесії локально
  Future<void> _saveSession(
    String userId,
    String? token,
    String? refreshToken,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'user_id',
      userId.replaceAll(RegExp(r'[^a-fA-F0-9-]'), ''),
    );
    if (token != null) {
      await prefs.setString('access_token', token);
    }
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  static Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final rawId = prefs.getString('user_id');
    if (rawId == null) return null;
    // Remove all characters except hex and dashes
    final cleanId = rawId.replaceAll(RegExp(r'[^a-fA-F0-9-]'), '');
    if (rawId != cleanId) {
      debugPrint("AuthService: Cleaned UserID from '$rawId' to '$cleanId'");
      // Auto-healed the stored value
      await prefs.setString('user_id', cleanId);
    }
    return cleanId;
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  // ОНОВЛЕННЯ ТОКЕНА
  static Future<bool> refreshSession() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final res = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        if (data['access_token'] != null) {
          await prefs.setString('access_token', data['access_token']);
        }
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Token Refresh Error: $e");
      return false;
    }
  }

  // РЕЄСТРАЦІЯ
  Future<Map<String, dynamic>> register(
    String email,
    String password, {
    required Map<String, dynamic> onboardingData,
  }) async {
    final Map<String, dynamic> requestBody = {
      'email': email,
      'password': password,
      'profile': onboardingData,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'), // Використовуємо baseUrl
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (data['user_id'] != null) {
        await _saveSession(
          data['user_id'],
          data['access_token'],
          data['refresh_token'],
        );
      }
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Помилка реєстрації');
    }
  }

  // Перевірка зв'язку з сервером
  Future<bool> checkConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/')) // Використовуємо baseUrl
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200 ||
          res.statusCode == 404; // 404 теж ок, значить сервер живий
    } catch (_) {
      return false;
    }
  }

  // ВИПРАВЛЕНО: тут був хардкод з :8000
  Future<void> sendPasswordResetEmail(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset_password'), // Тепер правильно
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Помилка надсилання листа");
    }
  }

  // ВИПРАВЛЕНО: тут був хардкод з :8000
  Future<void> updateUserPassword(String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/update_password'), // Тепер правильно
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"password": newPassword}),
    );

    if (response.statusCode != 200) {
      throw Exception("Не вдалося змінити пароль");
    }
  }

  // ВХІД
  Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await _saveSession(
        data['user_id'],
        data['access_token'],
        data['refresh_token'],
      );
    } else {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Помилка входу');
    }
  }

  // ВИДАЛЕННЯ АКАУНТУ
  static Future<void> deleteAccount(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/profile/delete?user_id=$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Помилка видалення акаунту');
    }

    // Після успішного видалення на бекенді, очищаємо дані локально
    await AuthService.logout();
  }

  // ОНОВЛЕННЯ ПРОФІЛЮ
  static Future<void> updateProfile(String field, dynamic value) async {
    final userId = await getStoredUserId();
    final token = await getAccessToken();
    if (userId == null || token == null) return;

    final response = await http.post(
      Uri.parse('$baseUrl/profile/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"user_id": userId, "field": field, "value": value}),
    );

    if (response.statusCode != 200) {
      throw Exception("Не вдалося оновити профіль: ${response.body}");
    }
  }

  // ВИХІД
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
