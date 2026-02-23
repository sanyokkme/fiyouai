import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // To access globalNavigatorKey
import 'offline_sync_service.dart';

class AuthService {
  // 1. Зробили змінну статичною, щоб мати до неї доступ з інших файлів
  static const String _prodUrl = 'https://fiyouai.onrender.com';

  static const String _devUrl = 'http://172.20.10.2:8000';

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
    // Store last login timestamp
    await prefs.setString('last_login', DateTime.now().toIso8601String());
  }

  static Future<bool>? _refreshFuture;

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
  static Future<bool> refreshSession() {
    if (_refreshFuture != null) {
      debugPrint("🔄 Token refresh already in progress, waiting...");
      return _refreshFuture!;
    }
    _refreshFuture = _doRefreshSession();
    return _refreshFuture!.whenComplete(() => _refreshFuture = null);
  }

  static Future<bool> _doRefreshSession() async {
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
      } else {
        debugPrint(
          "Token Refresh Failed! Status: ${res.statusCode}, Body: ${res.body}",
        );
        // If the refresh token is dead, clear the session so the app returns to login screen
        await logout();
        if (globalNavigatorKey.currentContext != null) {
          // Push to /welcome to break the loop and force user to log in again
          Navigator.of(
            globalNavigatorKey.currentContext!,
          ).pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
        return false;
      }
    } catch (e) {
      debugPrint("Token Refresh Exception: $e");
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

  // --- AUTH WRAPPERS (AUTO-REFRESH) ---

  static Future<http.Response> authGet(String endpoint) async {
    final token = await getAccessToken();
    final url = Uri.parse('$baseUrl$endpoint');
    var headers = {'Authorization': 'Bearer $token'};

    var response = await http.get(url, headers: headers);

    if (response.statusCode == 401) {
      // Check if token was refreshed by another concurrent request while we were waiting
      final currentToken = await getAccessToken();
      bool refreshed = false;

      if (currentToken != null && currentToken != token) {
        debugPrint(
          "AuthService: Token was updated in the background. Retrying request directly...",
        );
        refreshed = true;
      } else {
        debugPrint("AuthService: 401 Unauthorized. Attempting refresh...");
        refreshed = await refreshSession();
      }

      if (refreshed) {
        final newToken = await getAccessToken();
        headers['Authorization'] = 'Bearer $newToken';
        response = await http.get(url, headers: headers);
      }
    }
    return response;
  }

  static Future<http.Response> authPost(
    String endpoint,
    Object? body, {
    bool bypassQueue = false,
  }) async {
    final token = await getAccessToken();
    final url = Uri.parse('$baseUrl$endpoint');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      var response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        final currentToken = await getAccessToken();
        bool refreshed = false;

        if (currentToken != null && currentToken != token) {
          debugPrint(
            "AuthService: Token was updated in the background. Retrying POST directly...",
          );
          refreshed = true;
        } else {
          debugPrint(
            "AuthService: 401 Unauthorized for POST. Attempting refresh...",
          );
          refreshed = await refreshSession();
        }

        if (refreshed) {
          final newToken = await getAccessToken();
          headers['Authorization'] = 'Bearer $newToken';
          response = await http
              .post(url, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 10));
        }
      }
      return response;
    } on SocketException catch (_) {
      return _handleOffline('POST', endpoint, body, bypassQueue);
    } on TimeoutException catch (_) {
      return _handleOffline('POST', endpoint, body, bypassQueue);
    } catch (e) {
      if (!bypassQueue) {
        return _handleOffline('POST', endpoint, body, bypassQueue);
      }
      rethrow;
    }
  }

  static Future<http.Response> authDelete(
    String endpoint, {
    bool bypassQueue = false,
  }) async {
    final token = await getAccessToken();
    final url = Uri.parse('$baseUrl$endpoint');
    var headers = {'Authorization': 'Bearer $token'};

    try {
      var response = await http
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        final currentToken = await getAccessToken();
        bool refreshed = false;

        if (currentToken != null && currentToken != token) {
          refreshed = true;
        } else {
          refreshed = await refreshSession();
        }

        if (refreshed) {
          final newToken = await getAccessToken();
          headers['Authorization'] = 'Bearer $newToken';
          response = await http
              .delete(url, headers: headers)
              .timeout(const Duration(seconds: 10));
        }
      }
      return response;
    } on SocketException catch (_) {
      return _handleOffline('DELETE', endpoint, null, bypassQueue);
    } on TimeoutException catch (_) {
      return _handleOffline('DELETE', endpoint, null, bypassQueue);
    } catch (e) {
      if (!bypassQueue) {
        return _handleOffline('DELETE', endpoint, null, bypassQueue);
      }
      rethrow;
    }
  }

  static Future<http.Response> _handleOffline(
    String method,
    String endpoint,
    Object? body,
    bool bypassQueue,
  ) async {
    if (!bypassQueue) {
      debugPrint(
        "📡 Мережа недоступна. Додаємо $method $endpoint в офлайн-чергу.",
      );
      await OfflineSyncService().enqueueRequest(method, endpoint, body);
      final bodyStr = jsonEncode({
        "status": "queued_offline",
        "detail": "Дію збережено офлайн",
      });
      return http.Response.bytes(
        utf8.encode(bodyStr),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } else {
      throw Exception("Неможливо виконати $method-запит: немає мережі.");
    }
  }

  // ВИХІД
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
