import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app/screens/basic/login_screen.dart';
import 'package:flutter_app/screens/onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _currentIndex = 0;
  late Timer _timer;
  bool _isTransitioning = false; // Прапорець для запуску сплеш-екрану

  final List<String> _titles = [
    "Персональний план\nхарчування",
    "Відстеження прогресу\nв реальному часі",
    "Розумні рецепти\nта поради",
    "Видимий результат\n- без жорстоких дієт",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isTransitioning) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _titles.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleStart() {
    setState(() => _isTransitioning = true);

    // Затримка перед переходом до OnboardingSteps
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim, secondAnim) => const OnboardingScreen(),
            transitionsBuilder: (context, anim, secondAnim, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
          ),
        ),
        child: Stack(
          children: [
            // ОСНОВНИЙ ІНТЕРФЕЙС (Зникає при натисканні)
            AnimatedOpacity(
              opacity: _isTransitioning ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 800),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),
                      _buildAnimatedText(),
                      const Spacer(flex: 3),
                      _buildStartButton(),
                      const SizedBox(height: 25),
                      _buildLoginLink(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // СПЛЕШ-ТЕКСТ (З'являється знизу)
            if (_isTransitioning)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 1),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 40 * (1 - value)), // Рух знизу вгору
                        child: child,
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Маленькі кроки ведуть до великих результатів",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedText() {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.bottomLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: Text(
          _titles[_currentIndex],
          key: ValueKey<int>(_currentIndex),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _handleStart,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          "ПОЧАТИ",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
        child: RichText(
          text: const TextSpan(
            text: "Уже є аккаунт? ",
            style: TextStyle(color: Colors.white70, fontSize: 16),
            children: [
              TextSpan(
                text: "Увійти",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
