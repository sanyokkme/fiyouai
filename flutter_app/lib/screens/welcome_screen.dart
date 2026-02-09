import 'dart:async';
import '../constants/app_colors.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_app/screens/basic/login_screen.dart';
import 'package:flutter_app/screens/onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late Timer _timer;
  bool _isTransitioning = false;

  // Анімаційні контролери для фону
  late AnimationController _blob1Controller;
  late AnimationController _blob2Controller;
  late AnimationController _blob3Controller;

  final List<String> _titles = [
    "Персональний план\nхарчування",
    "Відстеження прогресу\nв реальному часі",
    "Розумні рецепти\nта поради",
    "Видимий результат\n- без жорстоких дієт",
  ];

  @override
  void initState() {
    super.initState();

    // Таймер для зміни тексту
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isTransitioning) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _titles.length;
        });
      }
    });

    // Ініціалізація анімацій для фону
    _blob1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _blob2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _blob3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _blob1Controller.dispose();
    _blob2Controller.dispose();
    _blob3Controller.dispose();
    super.dispose();
  }

  void _handleStart() {
    setState(() => _isTransitioning = true);

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim, secondAnim) =>
                const OnboardingScreen(),
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
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Анімований фон з переливами
          _buildAnimatedBackground(),

          // Контент
          Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // ОСНОВНИЙ ІНТЕРФЕЙС
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

                // СПЛЕШ-ТЕКСТ
                if (_isTransitioning)
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 40 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Маленькі кроки ведуть до великих результатів",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedOpacity(
      opacity: _isTransitioning ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 800),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _blob1Controller,
          _blob2Controller,
          _blob3Controller,
        ]),
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.backgroundDark,
            child: Stack(
              children: [
                // Blob 1 - великий зелений
                Positioned(
                  left: -100 + (200 * _blob1Controller.value),
                  top: 100 + (100 * sin(_blob1Controller.value * pi * 2)),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.25),
                          AppColors.primaryColor.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Blob 2 - середній зелений
                Positioned(
                  right: -50 + (150 * _blob2Controller.value),
                  top: 250 + (80 * cos(_blob2Controller.value * pi * 2)),
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.2),
                          AppColors.primaryColor.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Blob 3 - малий зелений внизу
                Positioned(
                  left:
                      MediaQuery.of(context).size.width * 0.3 +
                      (100 * _blob3Controller.value),
                  bottom: 150 + (120 * sin(_blob3Controller.value * pi * 3)),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.18),
                          AppColors.primaryColor.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Додатковий blob 4
                Positioned(
                  right: 50 + (80 * sin(_blob1Controller.value * pi * 1.5)),
                  bottom: 50 + (100 * _blob2Controller.value),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.15),
                          AppColors.primaryColor.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Blob 5 - центр ліворуч
                Positioned(
                  left: -80 + (120 * cos(_blob3Controller.value * pi * 2.5)),
                  top:
                      MediaQuery.of(context).size.height * 0.4 +
                      (60 * sin(_blob1Controller.value * pi)),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.22),
                          AppColors.primaryColor.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Blob 6 - малий зверху праворуч
                Positioned(
                  right: 100 + (60 * _blob2Controller.value),
                  top: 80 + (50 * cos(_blob3Controller.value * pi * 1.8)),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.12),
                          AppColors.primaryColor.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Blob 7 - внизу по центру
                Positioned(
                  left:
                      MediaQuery.of(context).size.width * 0.5 +
                      (80 * sin(_blob2Controller.value * pi * 2.2)),
                  bottom: -50 + (90 * _blob3Controller.value),
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.2),
                          AppColors.primaryColor.withValues(alpha: 0.07),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Легкий оверлей градієнт для плавного переходу
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryColor.withValues(alpha: 0.3),
                        AppColors.primaryColor.withValues(alpha: 0.1),
                        AppColors.primaryColor.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedText() {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Тільки плавний fade без вискакування
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
          style: TextStyle(
            color: AppColors.textWhite,
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
          backgroundColor: AppColors.primaryColor,
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
          text: TextSpan(
            text: "Уже є аккаунт? ",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            children: [
              TextSpan(
                text: "Увійти",
                style: TextStyle(
                  color: AppColors.primaryColor,
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
