import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Імпорти
import '../../services/data_manager.dart';
import '../../services/auth_service.dart';
import 'package:flutter_app/screens/basic/profile_screen.dart';
import 'package:flutter_app/screens/camera_screen.dart';
import 'package:flutter_app/screens/analytics_screen.dart';
import 'package:flutter_app/screens/recipes_screen.dart';
import 'package:flutter_app/screens/tips_screen.dart';
import 'package:flutter_app/screens/story_view_screen.dart';
import 'package:flutter_app/screens/food_search_screen.dart';

// Глобальна змінна
bool hasPlayedConfettiGlobal = false;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  bool _isLoading = true;
  late ConfettiController _confettiController;

  late PageController _pageController;
  // ignore: unused_field
  int _currentStoryIndex = 0;

  String _greetingText = "Привіт!";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _pageController = PageController(viewportFraction: 0.32);
    _fetchStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchStatus();
    }
  }

  void _updateGreeting(String? name) {
    String displayName = "Друже";
    if (name != null && name.trim().isNotEmpty) {
      String trimmed = name.trim();
      if (trimmed.length > 1) {
        displayName =
            trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
      } else {
        displayName = trimmed.toUpperCase();
      }
    }

    if (_greetingText.contains(displayName) && _greetingText != "Привіт!") {
      return;
    }

    final List<String> greetings = [
      "Привіт, $displayName!",
      "Вітаю, $displayName!",
      "Як успіхи, $displayName?",
      "Радий бачити, $displayName!",
      "До нових цілей, $displayName!",
      "Гарного дня, $displayName!",
    ];

    if (mounted) {
      setState(() {
        _greetingText = greetings[Random().nextInt(greetings.length)];
      });
    }
  }

  Future<void> _fetchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    String? cachedData = prefs.getString('cached_status_$userId');
    if (cachedData != null && _status == null) {
      if (mounted) {
        final data = jsonDecode(cachedData);
        setState(() {
          _status = data;
          _isLoading = false;
        });
        _updateGreeting(data['name'] ?? data['username']);
      }
    }

    DataManager().prefetchAllData().then((_) {
      debugPrint("Background sync finished");
    });

    try {
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/user_status/$userId'),
      );

      if (res.statusCode == 200) {
        await prefs.setString('cached_status_$userId', res.body);
        final data = jsonDecode(res.body);

        if (mounted) {
          setState(() {
            _status = data;
            _isLoading = false;
          });

          _updateGreeting(data['name'] ?? data['username']);

          bool waterGoalMet =
              (data['water'] ?? 0) >= (data['water_target'] ?? 2000);
          bool foodGoalMet =
              ((data['eaten'] ?? 0) >= (data['target'] ?? 2000)) &&
              ((data['eaten'] ?? 0) > 0);

          if ((waterGoalMet || foodGoalMet) && !hasPlayedConfettiGlobal) {
            _confettiController.play();
            hasPlayedConfettiGlobal = true;
          }
        }
      }
    } catch (e) {
      if (mounted && _status == null) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWater() async {
    try {
      final userId = await AuthService.getStoredUserId();
      final String timestamp = DateTime.now().toIso8601String();

      // Оптимістичне оновлення UI
      if (_status != null) {
        setState(() {
          _status!['water'] = (_status!['water'] ?? 0) + 250;
        });
      }

      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/add_water'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "amount": 250,
          "created_at": timestamp,
        }),
      );

      if (res.statusCode == 200) {
        // Ми не викликаємо повний _fetchStatus тут, щоб не перебудовувати все дерево,
        // оскільки ми вже оновили UI оптимістично.
        // Але можна зберегти кеш.
      }
    } catch (e) {
      debugPrint("Water Error: $e");
    }
  }

  // --- НОВЕ: Інтерактивне меню додавання ---
  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Дозволяє контенту займати більше місця
      builder: (context) {
        // Використовуємо StatefulBuilder, щоб оновлювати стан ЛИШЕ всередині модалки
        // (наприклад, анімацію галочки для води)
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Індикатор "тягнути"
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Швидка дія",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Сітка кнопок
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      // 1. ПОШУК (Синій)
                      _buildLargeQuickAction(
                        icon: Icons.search,
                        label: "Пошук їжі",
                        subLabel: "База продуктів",
                        color: Colors.blueAccent,
                        onTap: () async {
                          // Невелика затримка для візуального ефекту натискання
                          await Future.delayed(
                            const Duration(milliseconds: 150),
                          );
                          if (mounted) Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FoodSearchScreen(),
                            ),
                          );
                          _fetchStatus();
                        },
                      ),

                      // 2. КАМЕРА (Зелений)
                      _buildLargeQuickAction(
                        icon: Icons.camera_alt,
                        label: "Фото-сканер",
                        subLabel: "AI розпізнавання",
                        color: Colors.greenAccent,
                        onTap: () async {
                          await Future.delayed(
                            const Duration(milliseconds: 150),
                          );
                          if (mounted) Navigator.pop(context);
                          await Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const CameraScreen(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) => FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                            ),
                          );
                          _fetchStatus();
                        },
                      ),

                      // 3. ВОДА (Блакитний) - НЕ ЗАКРИВАЄ МЕНЮ
                      _buildLargeQuickAction(
                        icon: Icons.water_drop,
                        label: "Вода",
                        subLabel: "+250 мл",
                        color: Colors.cyanAccent,
                        isWater: true, // Спеціальний прапорець
                        onTap: () async {
                          // Тут ми не закриваємо меню!
                          await _addWater(); // Додаємо воду в базу і оновлюємо Home

                          // Показуємо локальний фідбек всередині модалки (якщо потрібно)
                          // або просто користувач бачить анімацію на кнопці (реалізовано в _buildLargeQuickAction)
                        },
                      ),

                      // 4. ГЕНЕРАЦІЯ РЕЦЕПТУ (Фіолетовий/Рожевий)
                      _buildLargeQuickAction(
                        icon: Icons.auto_awesome,
                        label: "AI Шеф",
                        subLabel: "Створити рецепт",
                        color: Colors.purpleAccent,
                        onTap: () async {
                          await Future.delayed(
                            const Duration(milliseconds: 150),
                          );
                          if (mounted) Navigator.pop(context);
                          // Переходимо на екран рецептів (або спеціальний екран генерації)
                          await Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const RecipesScreen(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) => FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Віджет великої кнопки для меню
  Widget _buildLargeQuickAction({
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
    bool isWater = false,
  }) {
    // Локальний стан для анімації кнопки (тільки для води)
    bool isPressed = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () async {
            if (isWater) {
              setState(() => isPressed = true);
              await Future.delayed(const Duration(milliseconds: 800));
              setState(() => isPressed = false);
            }
            onTap();
          },
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4, // 40% ширини
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            decoration: BoxDecoration(
              color: isPressed
                  ? color.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPressed ? color : color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Анімація іконки для води
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: isPressed && isWater
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('check'),
                          color: color,
                          size: 36,
                        )
                      : Icon(
                          icon,
                          key: const ValueKey('icon'),
                          color: color,
                          size: 36,
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  isPressed && isWater ? "Додано!" : label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.05),
      highlightColor: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(width: 150, height: 20, color: Colors.black),
            const SizedBox(height: 10),
            Container(width: 200, height: 30, color: Colors.black),
            const SizedBox(height: 30),
            Container(
              height: 115,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 25),
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesCarousel() {
    final stories = _status?['stories'] as List? ?? [];
    if (stories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 115,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: stories.length,
            itemBuilder: (context, index) {
              return _buildStoryCard(stories[index], index, stories);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoryCard(dynamic story, int index, List allStories) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) =>
                StoryViewScreen(stories: allStories, initialIndex: index),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.greenAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                story['image_url'] ?? "",
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.white10),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  story['title'] ?? "",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _status == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(child: _buildSkeletonLoader()),
        bottomNavigationBar: _buildBottomAppBar(),
      );
    }

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
        child: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _fetchStatus,
                color: Colors.greenAccent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildHeader(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildStoriesCarousel(),
                      const SizedBox(height: 25),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Сьогоднішня статистика",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildMultiChart(
                              _status?['eaten'] ?? 0,
                              _status?['target'] ?? 2000,
                            ),
                            const SizedBox(height: 25),
                            _buildWaterTracker(
                              _status?['water'] ?? 0,
                              _status?['water_target'] ?? 2000,
                            ),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAppBar(),
      // --- ЗМІНЕНО: FAB ---
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu, // Викликаємо меню замість переходу
        backgroundColor: Colors.greenAccent,
        elevation: 10,
        shape: const CircleBorder(), // Робимо ідеально круглим
        child: const Icon(Icons.add, color: Colors.black, size: 32), // Плюсик
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "FiYou AI",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.greenAccent,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              _greetingText,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Аватарка
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const ProfileScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                    transitionDuration: const Duration(milliseconds: 200),
                  ),
                );
                _fetchStatus();
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white10,
                backgroundImage: _status?['avatar_url'] != null
                    ? NetworkImage(_status?['avatar_url'])
                    : null,
                child: _status?['avatar_url'] == null
                    ? const Icon(Icons.person, color: Colors.white60)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      color: const Color(0xFF1A1A1A),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(Icons.home, "Головна", true, () {}),
            _navIcon(
              Icons.analytics_outlined,
              "Трекер",
              false,
              () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const AnalyticsScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 200),
                ),
              ),
            ),
            const SizedBox(width: 45), // Місце для FAB
            _navIcon(
              Icons.lightbulb_outline,
              "Поради",
              false,
              () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const TipsScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 200),
                ),
              ),
            ),
            _navIcon(
              Icons.restaurant_menu,
              "Рецепти",
              false,
              () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const RecipesScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 200),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.greenAccent : Colors.white38,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.greenAccent : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _buildMultiChart(int eaten, int target) {
    double p = (_status?['protein'] ?? 0).toDouble();
    double f = (_status?['fat'] ?? 0).toDouble();
    double c = (_status?['carbs'] ?? 0).toDouble();

    int targetP = _status?['target_p'] ?? 120;
    int targetF = _status?['target_f'] ?? 70;
    int targetC = _status?['target_c'] ?? 250;

    int targetCals = _status?['target'] ?? 2000;
    int eatenCals = _status?['eaten'] ?? 0;

    bool goalReached = eatenCals >= targetCals;
    int remaining = targetCals - eatenCals;

    final String goalType = _status?['goal'] ?? "maintain";
    String goalText = goalType == "lose"
        ? "Схуднення"
        : goalType == "gain"
        ? "Набір маси"
        : "Підтримка ваги";
    IconData goalIcon = goalType == "lose"
        ? Icons.trending_down
        : goalType == "gain"
        ? Icons.trending_up
        : Icons.remove_red_eye;

    return _buildStyledCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showCalorieInfo,
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _ring(c, targetC, 120, Colors.purpleAccent, 8),
                    _ring(p, targetP, 95, Colors.blueAccent, 8),
                    _ring(f, targetF, 70, Colors.orangeAccent, 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$eaten",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "ккал",
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 25),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(goalIcon, size: 14, color: Colors.greenAccent),
                          const SizedBox(width: 6),
                          Text(
                            goalText.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        goalReached ? "Статус" : "Залишилось",
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goalReached ? "Ціль досягнута! 🎉" : "$remaining ккал",
                        style: TextStyle(
                          fontSize: goalReached ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: goalReached
                              ? Colors.orangeAccent
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (eatenCals / targetCals).clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          color: Colors.greenAccent,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Ціль: $targetCals ккал",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _compactMacroItem(
                "Білки",
                "${p.toInt()}",
                targetP,
                const Color(0xFF42A5F5),
              ),
              _verticalDivider(),
              _compactMacroItem(
                "Жири",
                "${f.toInt()}",
                targetF,
                const Color(0xFFFFA726),
              ),
              _verticalDivider(),
              _compactMacroItem(
                "Вугл.",
                "${c.toInt()}",
                targetC,
                const Color(0xFFAB47BC),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(width: 1, height: 30, color: Colors.white10);

  Widget _compactMacroItem(
    String label,
    String value,
    int target,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => _showMacroInfo(
        label,
        "Детальна інформація про $label",
        color,
        Icons.info,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextSpan(
                  text: " / ${target}г",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(
    double curr,
    int total,
    double size,
    Color color,
    double stroke,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: total > 0 ? (curr / total).clamp(0.0, 1.0) : 0,
        strokeWidth: stroke,
        color: color,
        backgroundColor: color.withOpacity(0.1),
      ),
    );
  }

  void _showMacroInfo(
    String title,
    String description,
    Color color,
    IconData icon,
  ) => _showStyledModal(title, description, color, icon);

  Widget _buildWaterTracker(int current, int target) {
    const int totalGlasses = 5;
    double mlsPerGlass = target / totalGlasses;
    return _buildStyledCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(
                "$current / $target мл",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _addWater,
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.blueAccent,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(totalGlasses, (i) {
              double fillAmount = (current - (i * mlsPerGlass)) / mlsPerGlass;
              return _AnimatedGlass(fillAmount: fillAmount.clamp(0.0, 1.0));
            }),
          ),
        ],
      ),
    );
  }

  void _showCalorieInfo() => _showStyledModal(
    "Ваша Ціль",
    "Дотримуйтесь балансу для досягнення результату.",
    Colors.greenAccent,
    Icons.info_outline,
  );

  void _showStyledModal(String title, String text, Color color, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 25),
            Icon(icon, color: color, size: 50),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withOpacity(0.2),
                foregroundColor: color,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                "Зрозуміло",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedGlass extends StatelessWidget {
  final double fillAmount;
  const _AnimatedGlass({required this.fillAmount});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        const Icon(Icons.local_drink, size: 30, color: Colors.white12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fillAmount),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: value,
                child: Icon(
                  Icons.local_drink,
                  size: 30,
                  color: Colors.blueAccent.withOpacity(0.8),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
