import 'package:flutter/material.dart';

/// Централізовані кольори додатку FiYou AI
/// Змініть тут кольори для застосування по всьому додатку
import 'package:flutter_app/services/theme_service.dart';

/// Централізовані кольори додатку FiYou AI
/// Тепер кольори динамічні і залежать від налаштувань користувача
class AppColors {
  // --- DYNAMIC GETTERS ---
  // Ці кольори тепер геттери, тому що вони залежать від ThemeService

  static Color get primaryColor => ThemeService().primaryColor;

  // Обчислюємо яскравішу версію основного кольору або використовуємо комплементарний
  static Color get brightPrimaryColor => HSVColor.fromColor(
    primaryColor,
  ).withValue(1.0).withSaturation(0.8).toColor();

  // Accent color - світліша версія primary
  static Color get accentColor => HSVColor.fromColor(
    primaryColor,
  ).withSaturation(0.5).withValue(1.0).toColor();

  // Темний акцент фону - дуже темна версія primary
  static Color get backgroundDarkAccent =>
      Color.alphaBlend(primaryColor.withValues(alpha: 0.15), backgroundDark);

  // --- STATIC CONSTANTS ---
  // --- DYNAMIC BASE COLORS ---
  // Кольори, які змінюються в залежності від теми (світла/темна)

  static bool get isDark => ThemeService().isDarkMode;

  static Color get backgroundDark => isDark
      ? const Color(0xFF070707)
      : const Color(0xFFF5F5F7); // Softer light background

  static Color get textWhite =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  static Color get textGrey =>
      isDark ? const Color(0xFFB0B0B0) : const Color(0xFF505050);

  // --- SEMANTIC COLORS ---
  static Color get cardColor =>
      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);

  static Color get glassCardColor =>
      isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

  static Color get iconColor =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  static Color get textSecondary => isDark ? Colors.white54 : Colors.black54;

  // --- DYNAMIC BLUR SPOTS ---
  static Color get blurSpot1 => Color.alphaBlend(
    primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
    backgroundDark,
  );

  static Color get blurSpot2 =>
      isDark ? primaryColor : primaryColor.withValues(alpha: 0.6);

  /// Темний фон з тонкими розмитими плямами
  static BoxDecoration darkBackgroundWithBlur() {
    return BoxDecoration(color: backgroundDark);
  }

  /// Віджет для фону з розмитими плямами відповідного кольору
  static Widget buildBackgroundWithBlurSpots({required Widget child}) {
    // Отримуємо поточні кольори (вони будуть оновлені при перебудові віджета)
    final color1 = blurSpot1;
    final color2 = blurSpot2;
    final accent = accentColor;
    final bg = backgroundDark;
    final dark = isDark;

    return Container(
      decoration: BoxDecoration(color: bg),
      child: Stack(
        children: [
          // Пляма 1 - зверху ліворуч
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color1.withValues(alpha: dark ? 0.3 : 0.15),
                    color1.withValues(alpha: dark ? 0.1 : 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Пляма 2 - справа по центру
          Positioned(
            top: 200,
            right: -150,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color2.withValues(alpha: dark ? 0.2 : 0.1),
                    color2.withValues(alpha: dark ? 0.05 : 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Пляма 3 - знизу ліворуч
          Positioned(
            bottom: -100,
            left: 50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: dark ? 0.15 : 0.1),
                    accent.withValues(alpha: dark ? 0.05 : 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Контент поверх фону
          child,
        ],
      ),
    );
  }
}
