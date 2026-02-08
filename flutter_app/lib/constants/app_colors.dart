import 'package:flutter/material.dart';

/// Централізовані кольори додатку FiYou AI
/// Змініть тут кольори для застосування по всьому додатку
class AppColors {
  // Основні кольори
  static const Color primaryColor = Color.fromARGB(255, 34, 176, 133);
  static const Color brightPrimaryColor = Color(0xFF12DCEF);
  static const Color accentColor = Color(0xFF5DFFD9);

  // Фонові кольори
  static const Color backgroundDark = Color(0xFF070707);
  static const Color backgroundDarkAccent = Color(0xFF0D2818);

  // Текст
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFB0B0B0);

  // Розмиті плями для фону
  static const Color blurSpot1 = Color(0xFF1A4D2E); // Темно-зелена пляма
  static const Color blurSpot2 = Color(0xFF33BC65); // Яскрава зелена пляма

  /// Темний фон з тонкими зеленими розмитими плямами
  static BoxDecoration darkBackgroundWithBlur() {
    return BoxDecoration(
      color: backgroundDark,
      // Можна додати image з blur ефектом або використовувати Stack з позиціонованими контейнерами
    );
  }

  /// Віджет для фону з розмитими зеленими плямами
  static Widget buildBackgroundWithBlurSpots({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(color: backgroundDark),
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
                    blurSpot1.withValues(alpha: 0.3),
                    blurSpot1.withValues(alpha: 0.1),
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
                    blurSpot2.withValues(alpha: 0.2),
                    blurSpot2.withValues(alpha: 0.05),
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
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.05),
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
