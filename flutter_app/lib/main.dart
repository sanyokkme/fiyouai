import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_app/services/notification_service.dart';
import 'package:flutter_app/services/theme_service.dart';
import 'package:flutter_app/services/home_layout_service.dart';
import 'package:flutter_app/services/offline_sync_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/constants/app_fonts.dart';
import 'package:flutter_app/services/auth_service.dart';

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
import 'screens/error_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/weekly_report_screen.dart';
import 'screens/meal_planner_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/smart_sleep_screen.dart';

// Глобальний ключ для навігації з будь-якого місця (потрібен для показу екрану помилок)
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  try {
    // 1. Обов'язкова ініціалізація
    WidgetsFlutterBinding.ensureInitialized();

    // Ініціалізація сервісу теми
    await ThemeService().init();

    // Ініціалізація бази даних Hive для Offline Mode
    await Hive.initFlutter();
    await Hive.openBox('offlineDataBox');

    // Ініціалізація офлайн-черги
    await OfflineSyncService().init();

    // Ініціалізація сповіщень
    await NotificationService().init();
    await NotificationService().requestPermissions();

    // Ініціалізація макета головного екрана
    await HomeLayoutService().init();

    // 2. Ініціалізація камер
    initCameras().then((_) => debugPrint("Cameras initialized"));

    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');

    // If user is logged in, proactively try to refresh the session
    // This prevents stale tokens from causing 401 cascades on app resume
    bool sessionValid = false;
    if (userId != null && userId.isNotEmpty) {
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken != null) {
        sessionValid = await AuthService.refreshSession();
        if (!sessionValid) {
          debugPrint(
            "⚠️ Startup: Session refresh failed. Redirecting to login.",
          );
        } else {
          debugPrint("✅ Startup: Session refreshed successfully.");
        }
      }
    }

    final bool isLoggedIn = userId != null && userId.isNotEmpty && sessionValid;

    // Перевизначення глобального обробника помилок Flutter (для помилок рендерингу/віджетів)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return CustomErrorScreen(errorDetails: details);
    };

    // Перехоплення синхронних помилок Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _navigateToErrorScreen(details);
    };

    // Перехоплення асинхронних помилок (PlatformException тощо)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final details = FlutterErrorDetails(exception: error, stack: stack);
      _navigateToErrorScreen(details);
      return true;
    };

    runApp(MyApp(isLoggedIn: isLoggedIn));
  } catch (e, stackTrace) {
    debugPrint("CRITICAL STARTUP ERROR: $e");
    debugPrint(stackTrace.toString());
  }
}

bool _isNavigatingToError = false;

void _navigateToErrorScreen(FlutterErrorDetails details) {
  if (_isNavigatingToError) return; // Уникаємо дублювання екранів

  final context = globalNavigatorKey.currentContext;
  if (context != null) {
    _isNavigatingToError = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CustomErrorScreen(errorDetails: details),
          ),
        )
        .then((_) {
          _isNavigatingToError = false;
        });
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeModeNotifier,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeService().primaryColorNotifier,
          builder: (context, primaryColor, child) {
            ThemeData buildTheme(bool isDark) {
              return ThemeData(
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
              );
            }

            return MaterialApp(
              navigatorKey: globalNavigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'NutritionAI',
              themeMode: themeMode,
              theme: buildTheme(false),
              darkTheme: buildTheme(true),

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
                  case '/achievements':
                    return MaterialPageRoute(
                      builder: (_) => const AchievementsScreen(),
                    );
                  case '/weekly_report':
                    return MaterialPageRoute(
                      builder: (_) => const WeeklyReportScreen(),
                    );
                  case '/meal_planner':
                    return MaterialPageRoute(
                      builder: (_) => const MealPlannerScreen(),
                    );
                  case '/challenges':
                    return MaterialPageRoute(
                      builder: (_) => const ChallengesScreen(),
                    );
                  case '/smart_sleep':
                    return MaterialPageRoute(
                      builder: (_) => const SmartSleepScreen(),
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
