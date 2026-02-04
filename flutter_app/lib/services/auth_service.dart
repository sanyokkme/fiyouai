import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Твій серверний IP
  static const String serverIp = '172.20.10.3';
  final String baseUrl = 'http://$serverIp:8000';

  // Збереження даних сесії локально
  Future<void> _saveSession(String userId, String? token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    if (token != null) {
      await prefs.setString('access_token', token);
    }
  }

  static Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // РЕЄСТРАЦІЯ (Оновлено: додано обробку токена)
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
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (data['user_id'] != null) {
        // Зберігаємо ID та токен (якщо бекенд його повертає)
        await _saveSession(data['user_id'], data['access_token']);
      }
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Помилка реєстрації');
    }
  }

  // Перевірка зв'язку з сервером (SplashScreen)
  Future<bool> checkConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final response = await http.post(
      Uri.parse('http://${AuthService.serverIp}:8000/auth/reset_password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Помилка надсилання листа");
    }
  }

  Future<void> updateUserPassword(String newPassword) async {
    final response = await http.post(
      Uri.parse('http://${AuthService.serverIp}:8000/auth/update_password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"password": newPassword}),
    );

    if (response.statusCode != 200) {
      throw Exception("Не вдалося змінити пароль");
    }
  }

  // ВХІД (Оновлено)
  Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await _saveSession(data['user_id'], data['access_token']);
    } else {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Помилка входу');
    }
  }

  // ВИХІД (ПОВНЕ ОЧИЩЕННЯ)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Видаляє всі ключі, щоб почати з нуля
  }
}
