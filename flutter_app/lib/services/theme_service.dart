import 'package:flutter/material.dart';
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

  // --- DARK MODE ---
  ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);
  bool get isDarkMode => isDarkModeNotifier.value;

  // Ініціалізація сервісу (завантаження збереженого кольору та теми)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Color
    final int? colorValue = prefs.getInt('theme_primary_color');
    if (colorValue != null) {
      primaryColorNotifier.value = Color(colorValue);
    }

    // Load Theme Mode
    final bool? darkMode = prefs.getBool('theme_is_dark_mode');
    if (darkMode != null) {
      isDarkModeNotifier.value = darkMode;
    }
  }

  // Зміна основного кольору
  Future<void> setPrimaryColor(Color color) async {
    primaryColorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_primary_color', color.value);
  }

  // Перемикання теми
  Future<void> toggleTheme(bool isDark) async {
    isDarkModeNotifier.value = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark_mode', isDark);
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
