import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'auth_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;

  OfflineSyncService._internal();

  final String _boxName = 'offlineSyncBox';
  bool _isSyncing = false;

  Future<void> init() async {
    await Hive.openBox(_boxName);

    // Слухаємо зміну мережі
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        syncPendingRequests();
      }
    });

    // Спроба синхронізації при старті
    syncPendingRequests();
  }

  // Додавання запиту в чергу
  Future<void> enqueueRequest(
    String method,
    String endpoint,
    Object? body,
  ) async {
    final box = Hive.box(_boxName);

    final requestData = {
      'method': method,
      'endpoint': endpoint,
      'body': body != null ? jsonEncode(body) : null,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await box.add(jsonEncode(requestData));
    debugPrint("📥 Дані додано в офлайн-чергу: $method $endpoint");
  }

  // Виконання всіх запитів з черги
  Future<void> syncPendingRequests() async {
    if (_isSyncing) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.first == ConnectivityResult.none)
      return; // Немає мережі

    final box = Hive.box(_boxName);
    if (box.isEmpty) return; // Черга порожня

    _isSyncing = true;
    debugPrint(
      "🔄 Починаємо синхронізувати офлайн-чергу (записів: ${box.length})...",
    );

    final keys = box.keys.toList();

    for (var key in keys) {
      try {
        final String rawData = box.get(key);
        final data = jsonDecode(rawData);

        final method = data['method'];
        final endpoint = data['endpoint'];
        final bodyStr = data['body'];
        final body = bodyStr != null ? jsonDecode(bodyStr) : null;

        bool success = false;

        debugPrint("👉 Синхронізація: $method $endpoint");

        if (method == 'POST') {
          final res = await AuthService.authPost(
            endpoint,
            body,
            bypassQueue: true,
          );
          success = res.statusCode == 200 || res.statusCode == 201;
        } else if (method == 'DELETE') {
          final res = await AuthService.authDelete(endpoint, bypassQueue: true);
          success = res.statusCode == 200;
        } else if (method == 'GET') {
          final res = await AuthService.authGet(endpoint);
          success = res.statusCode == 200;
        }

        if (success) {
          await box.delete(key);
          debugPrint("✅ Успішно синхронізовано та видалено: $method $endpoint");
        } else {
          debugPrint(
            "❌ Помилка синхронізації (Сервер повернув помилку): $method $endpoint",
          );
        }
      } catch (e) {
        debugPrint("⚠️ Помилка синхронізації елементу $key: $e");
        break; // Відкладаємо до наступного разу (можливо зник інтернет)
      }
    }

    _isSyncing = false;
    debugPrint("🛑 Завершено синхронізацію офлайн-черги.");
  }
}
