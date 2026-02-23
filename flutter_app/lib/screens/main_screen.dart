import 'package:flutter/material.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import 'basic/home_screen.dart';
import 'analytics_screen.dart';
import 'tips_screen.dart';
import 'basic/profile_screen.dart';
import 'recipes_screen.dart';
import '../constants/app_colors.dart';
import 'package:flutter_app/widgets/weight_update_sheet.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'ai_logger_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();

  // List of screens for the IndexedStack
  // Order must match the BottomNavBar logic:
  // 0: Home
  // 1: Analytics
  // 2: Tips
  // 3: Profile
  // 4: Recipes (Special case from center button)
  late final List<Widget> _screens = [
    HomeScreen(key: _homeScreenKey),
    const AnalyticsScreen(),
    const TipsScreen(),
    const ProfileScreen(),
    const RecipesScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onCenterButtonTapped() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppColors.cardColor),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [_buildMenuGrid(), const SizedBox(height: 40)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      children: [
        // Row 1: Vitamins & Weight
        Row(
          children: [
            Expanded(
              child: _buildGridItem(
                icon: Icons.medication,
                title: "Вітаміни",
                color: Colors.orangeAccent,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (c) => const AddVitaminSheet(),
                  );
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGridItem(
                icon: Icons.monitor_weight,
                title: "Вага",
                color: Colors.greenAccent,
                onTap: () async {
                  Navigator.pop(context);
                  double currentWeight = 70.0;
                  final userId = await AuthService.getStoredUserId();
                  if (userId != null) {
                    final prefs = await SharedPreferences.getInstance();
                    String? cachedProfile = prefs.getString(
                      'cached_profile_\$userId',
                    );
                    if (cachedProfile != null) {
                      var profileData = jsonDecode(cachedProfile);
                      if (profileData['weight'] != null) {
                        currentWeight =
                            double.tryParse(profileData['weight'].toString()) ??
                            70.0;
                      }
                    }
                  }
                  if (mounted) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => WeightUpdateSheet(
                        currentWeight: currentWeight,
                        onWeightUpdated: (newWeight) {},
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 2: Add Water (Big) & Find Food/Recipes
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildGridItem(
                icon: Icons.water_drop,
                title: "Додати воду\n(+250мл)",
                color: Colors.blueAccent,
                height: 165,
                isBig: true,
                onTap: () {
                  Navigator.pop(context);
                  _homeScreenKey.currentState?.addWater(250);
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                children: [
                  _buildGridItem(
                    icon: Icons.search,
                    title: "Знайти продукт",
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/food_search');
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildGridItem(
                    icon: Icons.menu_book,
                    title: "Мої рецепти",
                    color: Colors.amberAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/recipe_book');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // AI Tools
        Row(
          children: [
            Expanded(
              child: _buildGridItem(
                icon: Icons.auto_awesome,
                title: "Записати їжу",
                color: AppColors.primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AILoggerScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGridItem(
                icon: Icons.restaurant_menu,
                title: "AI Рецепт",
                color: Colors.deepPurpleAccent,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 4);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Meals
        Row(
          children: [
            Expanded(
              child: _buildGridItem(
                icon: Icons.wb_sunny_outlined,
                title: "Сніданок",
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/food_search',
                    arguments: {'mealType': 'breakfast'},
                  );
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGridItem(
                icon: Icons.wb_sunny,
                title: "Обід",
                color: Colors.yellow,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/food_search',
                    arguments: {'mealType': 'lunch'},
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildGridItem(
                icon: Icons.nightlight_round,
                title: "Вечеря",
                color: Colors.indigoAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/food_search',
                    arguments: {'mealType': 'dinner'},
                  );
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGridItem(
                icon: Icons.apple,
                title: "Перекус",
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/food_search',
                    arguments: {'mealType': 'snack'},
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // 🍽️ Meal Planner (food-related, fits center button)
        Row(
          children: [
            Expanded(
              child: _buildGridItem(
                icon: Icons.restaurant_menu,
                title: "Планування їжі",
                color: Colors.deepPurpleAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/meal_planner');
                },
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    double? height,
    bool isBig = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? (isBig ? 140 : 75),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.glassCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardColor),
        ),
        child: isBig
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundDark,
      // Use IndexedStack to preserve state of each key screen
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          // Persistent Bottom Bar
          FloatingBottomNavBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            onAddPressed: _onCenterButtonTapped,
          ),
        ],
      ),
    );
  }
}
