import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/data_manager.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  List<Achievement> _achievements = [];
  bool _isLoading = true;
  int _totalXP = 0;
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadAchievements();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements({bool isBackground = false}) async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    if (!isBackground && mounted) setState(() => _isLoading = true);

    final box = Hive.box('offlineDataBox');

    // Trigger background update while showing cache (only once)
    if (!isBackground) {
      DataManager().prefetchAllData().then((_) {
        if (mounted) _loadAchievements(isBackground: true);
      });
    }

    // Load analytics history for computing achievements
    final cachedHistory =
        box.get('cached_analytics_history_$userId') as String?;
    final cachedStatus = box.get('cached_status_$userId') as String?;

    List historyData = [];
    Map<String, dynamic> statusData = {};

    if (cachedHistory != null) {
      historyData = jsonDecode(cachedHistory);
    }
    if (cachedStatus != null) {
      statusData = jsonDecode(cachedStatus);
    }

    // Calculate achievements
    final achievements = _calculateAchievements(historyData, statusData);

    // Calculate XP and Level
    int xp = 0;
    for (var a in achievements) {
      if (a.isUnlocked) xp += a.xpReward;
    }

    if (mounted) {
      setState(() {
        _achievements = achievements;
        _totalXP = xp;
        _level = (xp / 100).floor() + 1;
        _isLoading = false;
      });
    }
  }

  List<Achievement> _calculateAchievements(
    List history,
    Map<String, dynamic> status,
  ) {
    // Count history days
    int daysWithCalories = history
        .where((d) => (d['calories'] ?? 0) > 0)
        .length;
    int daysWithWater = history.where((d) => (d['water'] ?? 0) > 0).length;
    int totalWater = 0;
    int totalCaloriesDays = 0;

    for (var day in history) {
      totalWater += ((day['water'] ?? 0) as num).toInt();
      if ((day['calories'] ?? 0) > 0) totalCaloriesDays++;
    }

    // Calculate streak from status
    int currentStreak = 0;
    for (int i = history.length - 1; i >= 0; i--) {
      if ((history[i]['calories'] ?? 0) > 0) {
        currentStreak++;
      } else {
        break;
      }
    }

    return [
      // 🔥 Streak Achievements
      Achievement(
        id: 'streak_3',
        title: 'Перші кроки',
        description: '3 дні поспіль трекінг їжі',
        icon: Icons.local_fire_department,
        color: Colors.orangeAccent,
        category: 'Стрік',
        currentValue: currentStreak,
        targetValue: 3,
        xpReward: 25,
      ),
      Achievement(
        id: 'streak_7',
        title: 'Тижнева звичка',
        description: '7 днів поспіль трекінг',
        icon: Icons.local_fire_department,
        color: Colors.deepOrangeAccent,
        category: 'Стрік',
        currentValue: currentStreak,
        targetValue: 7,
        xpReward: 50,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Місяць дисципліни',
        description: '30 днів поспіль!',
        icon: Icons.whatshot,
        color: Colors.redAccent,
        category: 'Стрік',
        currentValue: currentStreak,
        targetValue: 30,
        xpReward: 200,
      ),

      // 💧 Water Achievements
      Achievement(
        id: 'water_first',
        title: 'Перший ковток',
        description: 'Запишіть воду хоча б 1 день',
        icon: Icons.water_drop,
        color: Colors.lightBlueAccent,
        category: 'Вода',
        currentValue: daysWithWater,
        targetValue: 1,
        xpReward: 10,
      ),
      Achievement(
        id: 'water_week',
        title: 'Водний тиждень',
        description: 'Пийте воду 7 днів поспіль',
        icon: Icons.water_drop,
        color: Colors.blueAccent,
        category: 'Вода',
        currentValue: daysWithWater,
        targetValue: 7,
        xpReward: 50,
      ),
      Achievement(
        id: 'water_10l',
        title: 'Океан здоров\'я',
        description: 'Випийте 10 літрів води загалом',
        icon: Icons.waves,
        color: Colors.blue,
        category: 'Вода',
        currentValue: totalWater,
        targetValue: 10000,
        xpReward: 75,
      ),

      // 🍎 Nutrition Achievements
      Achievement(
        id: 'log_first',
        title: 'Перший запис',
        description: 'Запишіть калорії хоча б 1 день',
        icon: Icons.restaurant,
        color: Colors.greenAccent,
        category: 'Харчування',
        currentValue: daysWithCalories,
        targetValue: 1,
        xpReward: 10,
      ),
      Achievement(
        id: 'log_10',
        title: 'Стабільний трекінг',
        description: 'Запишіть калорії 10 днів',
        icon: Icons.trending_up,
        color: Colors.tealAccent,
        category: 'Харчування',
        currentValue: totalCaloriesDays,
        targetValue: 10,
        xpReward: 75,
      ),
      Achievement(
        id: 'log_50',
        title: 'Майстер харчування',
        description: 'Запишіть калорії 50 днів',
        icon: Icons.emoji_events,
        color: Colors.amberAccent,
        category: 'Харчування',
        currentValue: totalCaloriesDays,
        targetValue: 50,
        xpReward: 150,
      ),

      // 🏆 Special Achievements
      Achievement(
        id: 'explorer',
        title: 'Дослідник',
        description: 'Відкрийте екран досягнень',
        icon: Icons.explore,
        color: Colors.purpleAccent,
        category: 'Спеціальні',
        currentValue: 1,
        targetValue: 1,
        xpReward: 5,
      ),
    ];
  }

  // ── Glass Card ──────────────────────────────────────────────
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
                    Text(
                      'Досягнення',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amberAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Colors.amberAccent,
                            size: 13,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'XP',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildLevelCard(),
                            const SizedBox(height: 24),
                            _buildStatsRow(),
                            const SizedBox(height: 28),
                            // Unlocked
                            ..._buildCategorySection(
                              'Розблоковані',
                              _achievements.where((a) => a.isUnlocked).toList(),
                              showAll: true,
                            ),
                            const SizedBox(height: 20),
                            // Locked
                            ..._buildCategorySection(
                              'В процесі',
                              _achievements
                                  .where((a) => !a.isUnlocked)
                                  .toList(),
                              showAll: true,
                            ),
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

  Widget _buildLevelCard() {
    double xpInLevel = (_totalXP % 100).toDouble();
    double progress = xpInLevel / 100.0;

    return _glassCard(
      glowColor: AppColors.primaryColor,
      child: Column(
        children: [
          Row(
            children: [
              // Level badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor,
                      AppColors.primaryColor.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Рівень $_level',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalXP XP загалом',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // XP Progress bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${xpInLevel.toInt()} / 100 XP',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Рівень ${_level + 1}',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppColors.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryColor,
                      ),
                      minHeight: 8,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    int unlocked = _achievements.where((a) => a.isUnlocked).length;
    int total = _achievements.length;

    return Row(
      children: [
        Expanded(
          child: _glassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              children: [
                Icon(Icons.emoji_events, color: Colors.amberAccent, size: 28),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$unlocked/$total',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Зібрано',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              children: [
                Icon(Icons.bolt, color: AppColors.primaryColor, size: 28),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$_totalXP',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Загальний XP',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              children: [
                Icon(Icons.star, color: Colors.purpleAccent, size: 28),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Lvl $_level',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Рівень',
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
    );
  }

  List<Widget> _buildCategorySection(
    String title,
    List<Achievement> items, {
    bool showAll = false,
  }) {
    if (items.isEmpty) return [];

    return [
      Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${items.length}',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      ...items.map(
        (a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAchievementCard(a),
        ),
      ),
    ];
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final isUnlocked = achievement.isUnlocked;
    final progress = achievement.progress;

    return _glassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      glowColor: isUnlocked ? achievement.color : null,
      child: Row(
        children: [
          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? achievement.color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnlocked
                    ? achievement.color.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: achievement.color.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              achievement.icon,
              color: isUnlocked
                  ? achievement.color
                  : Colors.white.withValues(alpha: 0.2),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: TextStyle(
                          color: isUnlocked
                              ? AppColors.textWhite
                              : AppColors.textWhite.withValues(alpha: 0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${achievement.xpReward} XP',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (!isUnlocked) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  achievement.color.withValues(alpha: 0.6),
                                ),
                                minHeight: 5,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${achievement.currentValue}/${achievement.targetValue}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String category;
  final int currentValue;
  final int targetValue;
  final int xpReward;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.currentValue,
    required this.targetValue,
    required this.xpReward,
  });

  bool get isUnlocked => currentValue >= targetValue;
  double get progress =>
      (targetValue > 0 ? currentValue / targetValue : 0.0).clamp(0.0, 1.0);
}
