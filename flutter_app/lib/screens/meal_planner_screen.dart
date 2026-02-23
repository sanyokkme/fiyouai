import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  bool _isLoading = false;
  bool _isGenerated = false;
  Map<String, dynamic> _mealPlan = {};
  int _calorieTarget = 2000;

  @override
  void initState() {
    super.initState();
    _loadTarget();
    _loadCachedPlan();
  }

  Future<void> _loadTarget() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;
    final box = Hive.box('offlineDataBox');
    final cachedStatus = box.get('cached_status_$userId') as String?;
    if (cachedStatus != null) {
      final status = jsonDecode(cachedStatus);
      if (mounted) {
        setState(() {
          _calorieTarget = (status['calorie_target'] ?? 2000) as int;
        });
      }
    }
  }

  Future<void> _loadCachedPlan() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;
    final box = Hive.box('offlineDataBox');
    final cached = box.get('cached_meal_plan_$userId') as String?;
    if (cached != null && mounted) {
      setState(() {
        _mealPlan = jsonDecode(cached);
        _isGenerated = true;
      });
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _isLoading = true);

    try {
      final userId = await AuthService.getStoredUserId();
      if (userId == null) return;

      // Trigger a background data refresh while we build the plan
      AuthService.authGet('/get_tips/$userId');

      // Generate a local meal plan based on calorie target
      // This can later be replaced with a real AI endpoint
      final plan = _buildLocalMealPlan(_calorieTarget);

      final box = Hive.box('offlineDataBox');
      await box.put('cached_meal_plan_$userId', jsonEncode(plan));

      if (mounted) {
        setState(() {
          _mealPlan = plan;
          _isGenerated = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Meal plan error: $e');
      // Generate offline plan anyway
      final plan = _buildLocalMealPlan(_calorieTarget);
      if (mounted) {
        setState(() {
          _mealPlan = plan;
          _isGenerated = true;
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildLocalMealPlan(int target) {
    // Distribute calories: Breakfast 25%, Lunch 35%, Dinner 30%, Snack 10%
    int breakfast = (target * 0.25).round();
    int lunch = (target * 0.35).round();
    int dinner = (target * 0.30).round();
    int snack = (target * 0.10).round();

    return {
      'target': target,
      'meals': [
        {
          'type': 'Сніданок',
          'icon': '🌅',
          'time': '08:00 - 09:00',
          'calories': breakfast,
          'items': [
            {
              'name': 'Вівсянка з бананом та медом',
              'cal': (breakfast * 0.6).round(),
              'protein': 12,
              'fat': 5,
              'carbs': 45,
            },
            {
              'name': 'Грецький йогурт',
              'cal': (breakfast * 0.25).round(),
              'protein': 10,
              'fat': 3,
              'carbs': 8,
            },
            {
              'name': 'Зелений чай',
              'cal': (breakfast * 0.05).round(),
              'protein': 0,
              'fat': 0,
              'carbs': 1,
            },
          ],
        },
        {
          'type': 'Обід',
          'icon': '☀️',
          'time': '12:30 - 13:30',
          'calories': lunch,
          'items': [
            {
              'name': 'Куряча грудка на грилі',
              'cal': (lunch * 0.4).round(),
              'protein': 35,
              'fat': 4,
              'carbs': 0,
            },
            {
              'name': 'Бурий рис з овочами',
              'cal': (lunch * 0.35).round(),
              'protein': 5,
              'fat': 2,
              'carbs': 48,
            },
            {
              'name': 'Салат зі свіжих овочів',
              'cal': (lunch * 0.15).round(),
              'protein': 2,
              'fat': 5,
              'carbs': 8,
            },
            {
              'name': 'Оливкова олія (заправка)',
              'cal': (lunch * 0.1).round(),
              'protein': 0,
              'fat': 14,
              'carbs': 0,
            },
          ],
        },
        {
          'type': 'Вечеря',
          'icon': '🌙',
          'time': '18:30 - 19:30',
          'calories': dinner,
          'items': [
            {
              'name': 'Лосось запечений',
              'cal': (dinner * 0.45).round(),
              'protein': 30,
              'fat': 15,
              'carbs': 0,
            },
            {
              'name': 'Картопля запечена з зеленню',
              'cal': (dinner * 0.35).round(),
              'protein': 3,
              'fat': 2,
              'carbs': 35,
            },
            {
              'name': 'Овочі на парі',
              'cal': (dinner * 0.2).round(),
              'protein': 3,
              'fat': 1,
              'carbs': 10,
            },
          ],
        },
        {
          'type': 'Перекус',
          'icon': '🍎',
          'time': '15:00 - 16:00',
          'calories': snack,
          'items': [
            {
              'name': 'Горіхи мікс (30г)',
              'cal': (snack * 0.6).round(),
              'protein': 5,
              'fat': 14,
              'carbs': 4,
            },
            {
              'name': 'Яблуко',
              'cal': (snack * 0.4).round(),
              'protein': 0,
              'fat': 0,
              'carbs': 19,
            },
          ],
        },
      ],
      'shopping': [
        'Вівсянка',
        'Банан',
        'Мед',
        'Грецький йогурт',
        'Куряча грудка',
        'Бурий рис',
        'Свіжі овочі',
        'Оливкова олія',
        'Лосось',
        'Картопля',
        'Горіхи мікс',
        'Яблука',
        'Зелений чай',
      ],
    };
  }

  // Glass Card
  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    double borderRadius = 24,
    Color? glowColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.textWhite,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Планувальник меню',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepPurpleAccent.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: Colors.deepPurpleAccent,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.deepPurpleAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      if (!_isGenerated) _buildEmptyState(),
                      if (_isGenerated) ...[
                        _buildCalorieSummary(),
                        const SizedBox(height: 20),
                        ...(_mealPlan['meals'] as List? ?? []).map(
                          (meal) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildMealCard(meal),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildShoppingList(),
                        const SizedBox(height: 16),
                        _buildRegenerateButton(),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 60),
        _glassCard(
          glowColor: Colors.deepPurpleAccent,
          child: Column(
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                'AI Планувальник меню',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Отримайте персоналізований план харчування на день, '
                'розрахований на вашу калорійну ціль ($_calorieTarget ккал)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isLoading ? null : _generatePlan,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurpleAccent,
                        Colors.deepPurpleAccent.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Згенерувати план',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieSummary() {
    int total = 0;
    for (var meal in (_mealPlan['meals'] as List? ?? [])) {
      total += (meal['calories'] as int?) ?? 0;
    }

    return _glassCard(
      glowColor: AppColors.primaryColor,
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$total',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'kkал/день',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Column(
            children: [
              Text(
                '$_calorieTarget',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'ціль',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Column(
            children: [
              Text(
                '4',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'прийоми',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final mealColors = {
      'Сніданок': Colors.orangeAccent,
      'Обід': Colors.amberAccent,
      'Вечеря': Colors.indigoAccent,
      'Перекус': Colors.greenAccent,
    };
    final color = mealColors[meal['type']] ?? AppColors.primaryColor;

    return _glassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meal['icon'] ?? '🍽️', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal['type'] ?? '',
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${meal['time']} · ${meal['calories']} ккал',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 8),
          ...(meal['items'] as List? ?? []).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['name'] ?? '',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${item['cal']} ккал',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingList() {
    final items = (_mealPlan['shopping'] as List?) ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return _glassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Список покупок',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      item.toString(),
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegenerateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _generatePlan,
      child: _glassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        borderRadius: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh, color: AppColors.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Згенерувати новий план',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
