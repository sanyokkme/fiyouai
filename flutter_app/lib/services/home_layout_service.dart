import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeLayoutService {
  static final HomeLayoutService _instance = HomeLayoutService._internal();
  factory HomeLayoutService() => _instance;
  HomeLayoutService._internal();

  final List<String> defaultOrder = [
    'dashboard_stats',
    'mood_tracker',
    'water_tracker',
    'sleep_calculator',
    'vitamins_section',
    'activity_timeline',
  ];

  ValueNotifier<List<String>> orderNotifier = ValueNotifier<List<String>>([]);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('home_widgets_order');
    // Ensure all default keys exist in the loaded order, to prevent missing widgets if we add new ones later
    if (order != null && order.isNotEmpty) {
      final validOrder = order.where((k) => defaultOrder.contains(k)).toList();
      for (final def in defaultOrder) {
        if (!validOrder.contains(def)) validOrder.add(def);
      }
      orderNotifier.value = validOrder;
    } else {
      orderNotifier.value = List.from(defaultOrder);
    }
  }

  Future<void> saveOrder(List<String> newOrder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_widgets_order', newOrder);
    orderNotifier.value = List.from(newOrder); // Clone so listeners fire
  }
}
