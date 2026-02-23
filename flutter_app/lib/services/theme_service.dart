import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal();

  // Основний колір за замовчуванням (зелений)
  static const Color defaultPrimaryColor = Color.fromARGB(255, 34, 176, 133);

  // Поточний основний колір
  ValueNotifier<Color> primaryColorNotifier = ValueNotifier<Color>(
    defaultPrimaryColor,
  );

  Color get primaryColor => primaryColorNotifier.value;

  // --- THEME MODE ---
  ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  bool get isDarkMode {
    if (themeModeNotifier.value == ThemeMode.system) {
      return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
    return themeModeNotifier.value == ThemeMode.dark;
  }

  // Ініціалізація сервісу (завантаження збереженого кольору та теми)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Color
    final int? colorValue = prefs.getInt('theme_primary_color');
    if (colorValue != null) {
      primaryColorNotifier.value = Color(colorValue);
    }

    // Load Theme Mode
    final int? themeModeIndex = prefs.getInt('theme_mode');
    if (themeModeIndex != null) {
      themeModeNotifier.value = ThemeMode.values[themeModeIndex];
    }
  }

  // Зміна основного кольору
  Future<void> setPrimaryColor(Color color) async {
    primaryColorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_primary_color', color.value);
  }

  // Перемикання режиму теми
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  // Список доступних кольорів для вибору
  static const List<Color> availableColors = [
    Color.fromARGB(255, 34, 176, 133), // Default Green
    Color(0xFF12DCEF), // Bright Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF2196F3), // Blue
  ];
}
