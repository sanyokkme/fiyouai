import 'package:flutter/material.dart';
import 'package:flutter_app/services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Імпорти екранів
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/basic/login_screen.dart';
import 'screens/basic/register_screen.dart';
import 'screens/basic/home_screen.dart';
import 'screens/basic/splash_screen.dart';
import 'screens/basic/confirmation_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/recipe_book_screen.dart';
import 'screens/basic/profile_screen.dart';
import 'screens/recipes_screen.dart';

void main() async {
  // 1. Обов'язкова ініціалізація
  WidgetsFlutterBinding.ensureInitialized();
  // Ініціалізація сповіщень
  await NotificationService().init();
  await NotificationService().requestPermissions();

  // 2. Ініціалізація камер
  initCameras().then((_) => debugPrint("Cameras initialized"));

  final prefs = await SharedPreferences.getInstance();
  final String? userId = prefs.getString('user_id');

  runApp(MyApp(isLoggedIn: userId != null && userId.isNotEmpty));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutritionAI',
      theme: ThemeData(
        brightness: Brightness.dark,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        primaryColor: Colors.greenAccent,
        scaffoldBackgroundColor: Color(0xFF0F0F0F),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        // Додаємо стиль для кнопок, щоб він був універсальним
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            textStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      // Початковий екран залежно від сесії
      home: isLoggedIn ? HomeScreen() : WelcomeScreen(),

      // Маршрутизація
      onGenerateRoute: (settings) {
        // Обробка спеціального маршруту реєстрації з передачею даних Onboarding
        if (settings.name == '/register') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder: (context) => RegisterScreen(onboardingData: args),
          );
        }

        // Обробка маршруту підтвердження з передачею даних
        if (settings.name == '/confirmation') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder: (context) => ConfirmationScreen(onboardingData: args),
          );
        }

        switch (settings.name) {
          case '/welcome':
            return MaterialPageRoute(builder: (_) => WelcomeScreen());
          case '/onboarding':
            // Використовуємо ключ, щоб щоразу створювати новий стан екрана
            return MaterialPageRoute(
              builder: (_) => OnboardingScreen(key: UniqueKey()),
            );
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => HomeScreen());
          case '/camera':
            return MaterialPageRoute(builder: (_) => CameraScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => ProfileScreen());
          case '/recipes':
            return MaterialPageRoute(builder: (_) => RecipesScreen());
          case '/recipe_book':
            return MaterialPageRoute(builder: (_) => RecipeBookScreen());
          case '/splash':
            return MaterialPageRoute(builder: (_) => SplashScreen());
          default:
            return MaterialPageRoute(
              builder: (_) => isLoggedIn ? HomeScreen() : WelcomeScreen(),
            );
        }
      },
    );
  }
}
