import 'package:hive_flutter/hive_flutter.dart';
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
      _fetchAndCache(
        userId,
        '/weight/history/$userId',
        'cached_weight_history_$userId',
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
      final res = await AuthService.authGet(endpoint);

      if (res.statusCode == 200) {
        final box = Hive.box('offlineDataBox');
        await box.put(cacheKey, res.body);
      } else {
        debugPrint(
          "⚠️ DataManager Backend Error ($endpoint): Status ${res.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("⚠️ DataManager Error ($endpoint): $e");
    }
  }

  // --- РОЗУМНА ЛОГІКА ПОРАД ---
  Future<void> _manageTipsLogic(String userId) async {
    final box = Hive.box('offlineDataBox');

    // Перевіряємо, чи переглянув користувач попередні поради
    bool previouslyViewed =
        box.get(keyTipsViewed) ??
        true; // За замовчуванням true, щоб при першому запуску згенерувало
    String? existingTips = box.get('${keyTips}_$userId');

    // Якщо порад немає ВЗАГАЛІ або користувач їх вже ПЕРЕГЛЯНУВ -> Генеруємо нові
    // ВАЖЛИВО: якщо existingTips == null, ЗАВЖДИ генеруємо (незалежно від прапорця viewed)
    if (existingTips == null || previouslyViewed) {
      debugPrint("🤖 AI: Генерую нові поради...");

      try {
        final res = await AuthService.authGet('/get_tips/$userId');

        if (res.statusCode == 200) {
          // Зберігаємо нові поради
          await box.put('${keyTips}_$userId', res.body);
          // Скидаємо прапорець перегляду (тепер у нас є нові, непрочитані)
          await box.put(keyTipsViewed, false);
          debugPrint("🤖 AI: Нові поради готові!");
        } else {
          debugPrint("⚠️ AI Tips Error: Status ${res.statusCode}");
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
    final box = Hive.box('offlineDataBox');
    await box.put(keyTipsViewed, true);
    debugPrint("👀 User: Поради переглянуто. Наступного разу згенеруємо нові.");
  }

  // --- ДОДАТКОВІ МЕТОДИ КЕШУВАННЯ ---

  String? getCachedDataSync(String key) {
    var box = Hive.box('offlineDataBox');
    return box.get(key) as String?;
  }

  Future<void> saveCachedData(String key, String data) async {
    var box = Hive.box('offlineDataBox');
    await box.put(key, data);
  }

  Future<String?> getCachedWeightHistory(String userId) async {
    return getCachedDataSync('cached_weight_history_$userId');
  }
}
