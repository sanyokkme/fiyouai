import 'package:flutter/material.dart';
import 'package:flutter_app/services/notification_service.dart';
import 'package:flutter_app/services/theme_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/constants/app_fonts.dart';

// Імпорти екранів
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/basic/login_screen.dart';
import 'screens/basic/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/basic/splash_screen.dart';
import 'screens/basic/confirmation_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/recipe_book_screen.dart';
import 'screens/food_search_screen.dart';

void main() async {
  try {
    // 1. Обов'язкова ініціалізація
    WidgetsFlutterBinding.ensureInitialized();

    // Ініціалізація сервісу теми
    await ThemeService().init();

    // Ініціалізація сповіщень
    await NotificationService().init();
    await NotificationService().requestPermissions();

    // 2. Ініціалізація камер
    initCameras().then((_) => debugPrint("Cameras initialized"));

    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');

    runApp(MyApp(isLoggedIn: userId != null && userId.isNotEmpty));
  } catch (e, stackTrace) {
    debugPrint("CRITICAL STARTUP ERROR: $e");
    debugPrint(stackTrace.toString());
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService().isDarkModeNotifier,
      builder: (context, isDark, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeService().primaryColorNotifier,
          builder: (context, primaryColor, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'NutritionAI',
              theme: ThemeData(
                brightness: isDark ? Brightness.dark : Brightness.light,
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  },
                ),
                primaryColor: primaryColor,
                scaffoldBackgroundColor: isDark
                    ? const Color(0xFF0F0F0F)
                    : const Color(0xFFF5F5F7),
                textTheme: AppFonts.mainTextTheme(Theme.of(context).textTheme)
                    .apply(
                      bodyColor: isDark ? Colors.white : Colors.black,
                      displayColor: isDark ? Colors.white : Colors.black,
                    ),
                // Додаємо стиль для кнопок, щоб він був універсальним
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                colorScheme: isDark
                    ? ColorScheme.dark(
                        primary: primaryColor,
                        secondary: primaryColor,
                        surface: const Color(0xFF1E1E1E),
                      )
                    : ColorScheme.light(
                        primary: primaryColor,
                        secondary: primaryColor,
                        surface: const Color(0xFFFFFFFF),
                      ),
              ),

              // Початковий екран залежно від сесії
              home: isLoggedIn ? const MainScreen() : const WelcomeScreen(),

              // Маршрутизація
              onGenerateRoute: (settings) {
                // Обробка спеціального маршруту реєстрації з передачею даних Onboarding
                if (settings.name == '/register') {
                  final args =
                      settings.arguments as Map<String, dynamic>? ?? {};
                  return MaterialPageRoute(
                    builder: (context) => RegisterScreen(onboardingData: args),
                  );
                }

                // Обробка маршруту підтвердження з передачею даних
                if (settings.name == '/confirmation') {
                  final args =
                      settings.arguments as Map<String, dynamic>? ?? {};
                  return MaterialPageRoute(
                    builder: (context) =>
                        ConfirmationScreen(onboardingData: args),
                  );
                }

                switch (settings.name) {
                  case '/welcome':
                    return MaterialPageRoute(
                      builder: (_) => const WelcomeScreen(),
                    );
                  case '/onboarding':
                    // Використовуємо ключ, щоб щоразу створювати новий стан екрана
                    return MaterialPageRoute(
                      builder: (_) => OnboardingScreen(key: UniqueKey()),
                    );
                  case '/login':
                    return MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    );
                  case '/home':
                    return MaterialPageRoute(
                      builder: (_) => const MainScreen(),
                    );
                  case '/camera':
                    return MaterialPageRoute(
                      builder: (_) => const CameraScreen(),
                    );
                  case '/profile':
                    return MaterialPageRoute(
                      builder: (_) => const MainScreen(),
                    ); // Navigate to MainScreen, it tracks index
                  case '/recipes':
                    return MaterialPageRoute(
                      builder: (_) => const MainScreen(),
                    ); // Navigate to MainScreen
                  case '/recipe_book':
                    return MaterialPageRoute(
                      builder: (_) => const RecipeBookScreen(),
                    );
                  case '/food_search':
                    return MaterialPageRoute(
                      builder: (_) => const FoodSearchScreen(),
                    );
                  case '/splash':
                    return MaterialPageRoute(builder: (_) => SplashScreen());
                  default:
                    return MaterialPageRoute(
                      builder: (_) => isLoggedIn
                          ? const MainScreen()
                          : const WelcomeScreen(),
                    );
                }
              },
            );
          },
        );
      },
    );
  }
}
