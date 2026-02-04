import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Для debugPrint
import 'auth_service.dart';

class DataManager {
  // Singleton - щоб цей клас був один на весь додаток
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // Ключі для кешу
  static const String keyTips = 'cached_tips_data';
  static const String keyTipsViewed = 'tips_have_been_viewed';

  // --- ГОЛОВНИЙ МЕТОД ЗАПУСКУ ---
  Future<void> prefetchAllData() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    debugPrint("🚀 DataManager: Починаємо фонове оновлення...");

    // Запускаємо запити паралельно
    await Future.wait([
      _fetchAndCache(userId, '/user_status/$userId', 'cached_status_$userId'),
      _fetchAndCache(
        userId,
        '/analytics/$userId',
        'cached_analytics_history_$userId',
      ),
      _manageTipsLogic(userId), // Розумна логіка порад
    ]);

    debugPrint("✅ DataManager: Фонове оновлення завершено!");
  }

  // Універсальна функція для кешування
  Future<void> _fetchAndCache(
    String userId,
    String endpoint,
    String cacheKey,
  ) async {
    try {
      final res = await http.get(
        Uri.parse('http://${AuthService.serverIp}:8000$endpoint'),
      );
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, res.body);
      }
    } catch (e) {
      debugPrint("⚠️ DataManager Error ($endpoint): $e");
    }
  }

  // --- РОЗУМНА ЛОГІКА ПОРАД ---
  Future<void> _manageTipsLogic(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // Перевіряємо, чи переглянув користувач попередні поради
    bool previouslyViewed =
        prefs.getBool(keyTipsViewed) ??
        true; // За замовчуванням true, щоб при першому запуску згенерувало
    String? existingTips = prefs.getString('${keyTips}_$userId');

    // Якщо порад немає ВЗАГАЛІ або користувач їх вже ПЕРЕГЛЯНУВ -> Генеруємо нові
    if (existingTips == null || previouslyViewed) {
      debugPrint("🤖 AI: Генерую нові поради, бо старі прочитані...");

      try {
        final res = await http.get(
          Uri.parse('http://${AuthService.serverIp}:8000/get_tips/$userId'),
        );

        if (res.statusCode == 200) {
          // Зберігаємо нові поради
          await prefs.setString('${keyTips}_$userId', res.body);
          // Скидаємо прапорець перегляду (тепер у нас є нові, непрочитані)
          await prefs.setBool(keyTipsViewed, false);
          debugPrint("🤖 AI: Нові поради готові!");
        }
      } catch (e) {
        debugPrint("AI Error: $e");
      }
    } else {
      debugPrint("🤖 AI: Старі поради ще не переглянуті. Нові не генеруємо.");
    }
  }

  // Метод, який викликається, коли користувач відкрив екран порад
  Future<void> markTipsAsViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyTipsViewed, true);
    debugPrint("👀 User: Поради переглянуто. Наступного разу згенеруємо нові.");
  }
}
