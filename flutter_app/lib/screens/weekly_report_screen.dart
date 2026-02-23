import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _report = {};

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final box = Hive.box('offlineDataBox');
    final cachedHistory =
        box.get('cached_analytics_history_$userId') as String?;
    final cachedStatus = box.get('cached_status_$userId') as String?;

    if (cachedHistory == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    List history = jsonDecode(cachedHistory);
    Map<String, dynamic> status = cachedStatus != null
        ? jsonDecode(cachedStatus)
        : {};

    // Last 7 days
    final last7 = history.length > 7
        ? history.sublist(history.length - 7)
        : history;
    // Previous 7 days
    final prev7 = history.length > 14
        ? history.sublist(history.length - 14, history.length - 7)
        : <Map<String, dynamic>>[];

    // Calculate averages
    double avgCalories = _avg(last7, 'calories');
    double avgCaloriesPrev = prev7.isNotEmpty ? _avg(prev7, 'calories') : 0;
    double avgWater = _avg(last7, 'water');
    double avgWaterPrev = prev7.isNotEmpty ? _avg(prev7, 'water') : 0;
    double avgProtein = _avg(last7, 'protein');
    double avgProteinPrev = prev7.isNotEmpty ? _avg(prev7, 'protein') : 0;

    // Calorie target
    int calorieTarget = (status['calorie_target'] ?? 2000) as int;
    int waterTarget = (status['water_target'] ?? 2000) as int;

    // Streak
    int streak = 0;
    for (int i = last7.length - 1; i >= 0; i--) {
      if ((last7[i]['calories'] ?? 0) > 0) {
        streak++;
      } else {
        break;
      }
    }

    // Generate insights
    List<Map<String, dynamic>> insights = [];

    double calorieChange = avgCalories - avgCaloriesPrev;
    if (avgCaloriesPrev > 0) {
      double pctChange = (calorieChange / avgCaloriesPrev * 100);
      if (pctChange.abs() > 5) {
        insights.add({
          'icon': pctChange > 0 ? Icons.trending_up : Icons.trending_down,
          'color': pctChange > 0 ? Colors.orangeAccent : Colors.greenAccent,
          'text':
              'Калорії ${pctChange > 0 ? "зросли" : "зменшились"} на ${pctChange.abs().toStringAsFixed(0)}% порівняно з минулим тижнем',
        });
      }
    }

    double waterChange = avgWater - avgWaterPrev;
    if (avgWaterPrev > 0 && waterChange.abs() > 100) {
      insights.add({
        'icon': waterChange > 0 ? Icons.water_drop : Icons.warning_amber,
        'color': waterChange > 0 ? Colors.blueAccent : Colors.orangeAccent,
        'text': waterChange > 0
            ? 'Споживання води зросло на ${waterChange.toStringAsFixed(0)} мл/день 💧'
            : 'Пийте більше води! Споживання впало на ${waterChange.abs().toStringAsFixed(0)} мл/день',
      });
    }

    if (avgProtein > 0 && avgProteinPrev > 0) {
      double proteinChange =
          ((avgProtein - avgProteinPrev) / avgProteinPrev * 100);
      if (proteinChange > 10) {
        insights.add({
          'icon': Icons.fitness_center,
          'color': Colors.tealAccent,
          'text':
              'Білок зріс на ${proteinChange.toStringAsFixed(0)}% — чудовий прогрес! 💪',
        });
      }
    }

    if (streak >= 5) {
      insights.add({
        'icon': Icons.local_fire_department,
        'color': Colors.redAccent,
        'text': 'Вогняний стрік $streak днів! Так тримати! 🔥',
      });
    }

    if (insights.isEmpty) {
      insights.add({
        'icon': Icons.lightbulb_outline,
        'color': AppColors.primaryColor,
        'text':
            'Продовжуйте записувати їжу і воду, щоб отримувати персоналізовані інсайти!',
      });
    }

    if (mounted) {
      setState(() {
        _report = {
          'avgCalories': avgCalories,
          'avgCaloriesPrev': avgCaloriesPrev,
          'avgWater': avgWater,
          'avgWaterPrev': avgWaterPrev,
          'avgProtein': avgProtein,
          'calorieTarget': calorieTarget,
          'waterTarget': waterTarget,
          'streak': streak,
          'daysLogged': last7.where((d) => (d['calories'] ?? 0) > 0).length,
          'insights': insights,
        };
        _isLoading = false;
      });
    }
  }

  double _avg(List data, String key) {
    if (data.isEmpty) return 0;
    double sum = 0;
    for (var d in data) {
      sum += ((d[key] ?? 0) as num).toDouble();
    }
    return sum / data.length;
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
                    const Expanded(
                      child: Text(
                        'Тижневий звіт',
                        style: TextStyle(
                          fontSize: 28,
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
                        color: AppColors.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primaryColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI',
                            style: TextStyle(
                              color: AppColors.primaryColor,
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
                            _buildOverviewCard(),
                            const SizedBox(height: 16),
                            _buildMetricsGrid(),
                            const SizedBox(height: 24),
                            _buildInsightsSection(),
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

  Widget _buildOverviewCard() {
    int daysLogged = _report['daysLogged'] ?? 0;
    int streak = _report['streak'] ?? 0;

    String emoji = '💪';
    String message = 'Чудовий тиждень!';
    if (daysLogged <= 2) {
      emoji = '📝';
      message = 'Спробуйте записувати частіше';
    } else if (daysLogged <= 4) {
      emoji = '👍';
      message = 'Непогано, але можна краще!';
    } else if (daysLogged >= 6) {
      emoji = '🏆';
      message = 'Фантастичний тиждень!';
    }

    return _glassCard(
      glowColor: AppColors.primaryColor,
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$daysLogged з 7 днів записано · Стрік: $streak',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    double avgCal = _report['avgCalories'] ?? 0;
    double avgCalPrev = _report['avgCaloriesPrev'] ?? 0;
    double avgWater = _report['avgWater'] ?? 0;
    double avgWaterPrev = _report['avgWaterPrev'] ?? 0;
    int calTarget = _report['calorieTarget'] ?? 2000;
    int waterTarget = _report['waterTarget'] ?? 2000;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Калорії',
                avgCal.toStringAsFixed(0),
                'з $calTarget ціль',
                Icons.local_fire_department,
                AppColors.primaryColor,
                avgCalPrev > 0 ? (avgCal - avgCalPrev) / avgCalPrev * 100 : 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Вода',
                '${avgWater.toStringAsFixed(0)} мл',
                'з $waterTarget мл',
                Icons.water_drop,
                Colors.blueAccent,
                avgWaterPrev > 0
                    ? (avgWater - avgWaterPrev) / avgWaterPrev * 100
                    : 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Білок',
                '${(_report['avgProtein'] ?? 0).toStringAsFixed(0)} г',
                'в середньому',
                Icons.fitness_center,
                Colors.tealAccent,
                null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Стрік',
                '${_report['streak'] ?? 0}',
                'днів поспіль',
                Icons.local_fire_department,
                Colors.orangeAccent,
                null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    double? change,
  ) {
    return _glassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              if (change != null && change != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (change > 0 ? Colors.greenAccent : Colors.redAccent)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${change > 0 ? "+" : ""}${change.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: change > 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    final insights = (_report['insights'] as List<Map<String, dynamic>>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              'AI Інсайти',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...insights.map(
          (insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _glassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 18,
              glowColor: insight['color'] as Color?,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (insight['color'] as Color).withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      insight['icon'] as IconData,
                      color: insight['color'] as Color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      insight['text'] as String,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
