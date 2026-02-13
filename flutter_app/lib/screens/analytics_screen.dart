import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = true;
  String? _aiSummary;

  // Chart type state per section
  // true = Bar, false = Line
  final Map<String, bool> _chartTypes = {
    'calories': true,
    'water': true,
    'macros': true,
  };

  // Controller for the Macros Carousel
  late PageController _macroPageController;
  int _currentMacroIndex = 0;
  final List<String> _macroMetrics = ['protein', 'fat', 'carbs'];

  // Main metrics list (excluding individual macros as they are grouped)
  final List<String> _mainMetrics = ['calories', 'water'];

  // Colors for each metric
  final Map<String, Color> _metricColors = {
    'calories': AppColors.primaryColor,
    'water': Colors.cyanAccent,
    'protein': Colors.blueAccent,
    'fat': Colors.orangeAccent,
    'carbs': Colors.purpleAccent,
  };

  // Metric names in Ukrainian
  final Map<String, String> _metricNames = {
    'calories': 'Споживання калорій',
    'water': 'Споживання води',
    'protein': 'Білки',
    'fat': 'Жири',
    'carbs': 'Вуглеводи',
  };

  @override
  void initState() {
    super.initState();
    _macroPageController = PageController();
    _fetchFullAnalytics();
  }

  @override
  void dispose() {
    _macroPageController.dispose();
    super.dispose();
  }

  // ... (keeping _fetchFullAnalytics and _processData same but removing _avgCalories state use if calculated on fly)
  // Actually, _avgCalories was used. We can compute it per metric.

  Future<void> _fetchFullAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    // Очищуємо старий кеш після оновлення бекенду
    await prefs.remove('cache_analytics_status_$userId');
    await prefs.remove('cache_analytics_history_$userId');
    await prefs.remove('cache_analytics_tips_$userId');

    try {
      // --- ЗАПИТ НА СЕРВЕР ---
      // --- ЗАПИТ НА СЕРВЕР ---
      debugPrint('📱 ANALYTICS -> Fetching for UserID: $userId');
      final responses = await Future.wait([
        http.get(Uri.parse('${AuthService.baseUrl}/user_status/$userId')),
        http.get(Uri.parse('${AuthService.baseUrl}/analytics/$userId')),
        http.get(Uri.parse('${AuthService.baseUrl}/get_tips/$userId')),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        // Зберігаємо в кеш
        await prefs.setString(
          'cache_analytics_status_$userId',
          responses[0].body,
        );
        await prefs.setString(
          'cache_analytics_history_$userId',
          responses[1].body,
        );
        if (responses[2].statusCode == 200) {
          await prefs.setString(
            'cache_analytics_tips_$userId',
            responses[2].body,
          );
        }

        // Оновлюємо UI свіжими даними
        _processData(
          jsonDecode(responses[0].body),
          jsonDecode(responses[1].body),
          responses[2].statusCode == 200 ? jsonDecode(responses[2].body) : null,
        );
      }
    } catch (e) {
      print('Analytics error: $e');
      if (mounted && _chartData.isEmpty) setState(() => _isLoading = false);
    }
  }

  void _processData(
    Map<String, dynamic> statusData,
    List historyList,
    Map<String, dynamic>? aiData,
  ) {
    // 1. Заповнюємо пропуски
    final filledData = _fillMissingDays(historyList);

    // 3. AI
    String aiText = "Аналізуємо ваші дані...";
    if (aiData != null) {
      aiText = aiData['summary'] ?? "Продовжуйте стежити за раціоном!";
    }

    if (mounted) {
      setState(() {
        _data = statusData;
        _chartData = filledData;
        _aiSummary = aiText;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _fillMissingDays(List rawData) {
    List<Map<String, dynamic>> result = [];
    DateTime today = DateTime.now();

    // Створюємо Map з усіма метриками по днях
    Map<String, Map<String, dynamic>> dataMap = {};

    for (var item in rawData) {
      dataMap[item['day']] = {
        'calories': (item['calories'] as num?)?.toInt() ?? 0,
        'water': (item['water'] as num?)?.toInt() ?? 0,
        'protein': (item['protein'] as num?)?.toDouble() ?? 0.0,
        'fat': (item['fat'] as num?)?.toDouble() ?? 0.0,
        'carbs': (item['carbs'] as num?)?.toDouble() ?? 0.0,
      };
    }

    // Заповнюємо всі 7 днів (включно з пропущеними)
    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);

      final metrics =
          dataMap[dateKey] ??
          {'calories': 0, 'water': 0, 'protein': 0.0, 'fat': 0.0, 'carbs': 0.0};

      result.add({
        'day': dateKey,
        'dateObj': date,
        'calories': metrics['calories'],
        'water': metrics['water'],
        'protein': metrics['protein'],
        'fat': metrics['fat'],
        'carbs': metrics['carbs'],
      });
    }
    return result;
  }

  String _getDayName(DateTime date) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return days[date.weekday - 1];
  }

  // --- SKELETON LOADER ---
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                'Аналітика',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Shimmer.fromColors(
            baseColor: AppColors.textGrey.withValues(alpha: 0.1),
            highlightColor: AppColors.textGrey.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Macros detail card with 3 progress bars
                    Container(
                      height: 240,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: AppColors.glassCardColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          _buildSkeletonProgressBar(),
                          const SizedBox(height: 25),
                          _buildSkeletonProgressBar(),
                          const SizedBox(height: 25),
                          _buildSkeletonProgressBar(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Vertical charts skeleton
                    for (int i = 0; i < 3; i++) ...[
                      Container(
                        height: 20,
                        width: 150,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 15),
                      ),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: AppColors.glassCardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 25),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 60,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  // Helper to calculate average for any metric
  int _calculateAverage(String metric) {
    if (_chartData.isEmpty) return 0;

    double total = 0;
    int activeDays = 0;
    for (var item in _chartData) {
      double val = _getMetricValue(metric, item);
      if (val > 0) {
        total += val;
        activeDays++;
      }
    }
    return activeDays > 0 ? (total / activeDays).round() : 0;
  }

  // Helper to get target for any metric
  int _getTarget(String metric) {
    switch (metric) {
      case 'calories':
        return (_data['target'] ?? 2000) as int;
      case 'water':
        return (_data['water_target'] ?? 2000) as int;
      case 'protein':
        return (_data['target_p'] ?? 150) as int;
      case 'fat':
        return (_data['target_f'] ?? 80) as int;
      case 'carbs':
        return (_data['target_c'] ?? 250) as int;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppColors.buildBackgroundWithBlurSpots(
      child: SafeArea(
        child: _isLoading && _chartData.isEmpty
            ? _buildSkeleton()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Аналітика',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _fetchFullAnalytics,
                      color: AppColors.primaryColor,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Macros Detail (Today)
                            Text(
                              "Сьогодні",
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildMacrosDetailCard(),

                            const SizedBox(height: 30),

                            // 2. Charts List
                            // Render Calories and Water
                            ..._mainMetrics.map(
                              (metric) => Padding(
                                padding: const EdgeInsets.only(bottom: 25.0),
                                child: _buildMetricChartCard(metric),
                              ),
                            ),

                            // Render Macros Carousel
                            _buildMacrosCarouselCard(),

                            const SizedBox(height: 25),

                            if (_aiSummary != null) _buildAiSummaryCard(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMetricChartCard(String metric) {
    final int avg = _calculateAverage(metric);
    final int target = _getTarget(metric);
    final String unit = _getUnitForMetric(metric);
    final String title = _metricNames[metric] ?? metric;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.glassCardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChartTypeBtn(Icons.bar_chart, true, metric),
                  const SizedBox(width: 4),
                  _buildChartTypeBtn(Icons.show_chart, false, metric),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Info Row (Avg + Target)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Середнє значення",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "$avg",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                      TextSpan(
                        text: " $unit",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Ціль",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "$target",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                      TextSpan(
                        text: " $unit",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 15),

        // Chart Area
        Container(
          height: 250,
          width: double.infinity,
          // No padding/decoration to keep it clean like the design usually implies,
          // or minimal transparent bg.
          child: _buildSingleChart(metric),
        ),
      ],
    );
  }

  Widget _buildSingleChart(String metric) {
    // Check which toggle to use
    // If it's a macro, use the 'macros' key for the toggle state
    // If it's calories/water, use the metric key
    String toggleKey = _macroMetrics.contains(metric) ? 'macros' : metric;
    bool isBar = _chartTypes[toggleKey] ?? true;

    final double maxY = _calculateDynamicMaxY(metric);
    final double interval = _calculateGridInterval(maxY);

    // Determine target based on metric
    double target = 0;
    switch (metric) {
      case 'calories':
        target = (_data['target'] ?? 2000).toDouble();
        break;
      case 'water':
        target = (_data['water_target'] ?? 2000).toDouble();
        break;
      case 'protein':
        target = (_data['target_p'] ?? 150).toDouble();
        break;
      case 'fat':
        target = (_data['target_f'] ?? 80).toDouble();
        break;
      case 'carbs':
        target = (_data['target_c'] ?? 250).toDouble();
        break;
    }

    // Common Horizontal Line definition
    final targetLine = HorizontalLine(
      y: target,
      color: AppColors.textWhite.withValues(alpha: 0.5),
      strokeWidth: 1,
      dashArray: [5, 5],
      label: HorizontalLineLabel(
        show: true,
        alignment: Alignment.topRight,
        padding: const EdgeInsets.only(right: 5, bottom: 5),
        labelResolver: (_) => "Ціль: ${target.toInt()}",
        style: TextStyle(
          color: AppColors.textWhite,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
    );

    return isBar
        ? BarChart(
            BarChartData(
              maxY: maxY,
              titlesData: _buildTitlesData(),
              gridData: _buildGridData(interval),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(horizontalLines: [targetLine]),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final metricName = _metricNames[metric] ?? '';
                    final unit = _getUnitForMetric(metric);
                    return BarTooltipItem(
                      '$metricName\n${rod.toY.toInt()} $unit',
                      TextStyle(
                        color: _metricColors[metric],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              barGroups: _buildBarGroups(metric, maxY, target),
            ),
          )
        : LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.black87,
                  tooltipPadding: const EdgeInsets.all(8),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final metricName = _metricNames[metric] ?? '';
                      final unit = _getUnitForMetric(metric);
                      return LineTooltipItem(
                        '$metricName\n${spot.y.toInt()} $unit',
                        TextStyle(
                          color: _metricColors[metric],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: _buildTitlesData(),
              gridData: _buildGridData(interval),
              borderData: FlBorderData(show: false),
              lineBarsData: _buildLineData(metric, maxY, target),
              extraLinesData: ExtraLinesData(horizontalLines: [targetLine]),
            ),
          );
  }

  Widget _buildChartTypeBtn(IconData icon, bool isBar, String metric) {
    bool currentIsBar = _chartTypes[metric] ?? true;
    final isActive = currentIsBar == isBar;
    return GestureDetector(
      onTap: () => setState(() => _chartTypes[metric] = isBar),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive
              ? AppColors.primaryColor
              : AppColors.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildMacrosCarouselCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Toggle (applies to all macros in carousel)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Макронутрієнти",
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.glassCardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChartTypeBtn(Icons.bar_chart, true, 'macros'),
                  const SizedBox(width: 4),
                  _buildChartTypeBtn(Icons.show_chart, false, 'macros'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Carousel Container
        Container(
          height: 380, // Taller to accommodate individual macro info + chart
          decoration: BoxDecoration(
            color: AppColors.glassCardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassCardColor),
          ),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _macroPageController,
                  onPageChanged: (index) {
                    setState(() => _currentMacroIndex = index);
                  },
                  itemCount: _macroMetrics.length,
                  itemBuilder: (context, index) {
                    final metric = _macroMetrics[index];
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildSingleMacroPage(metric),
                    );
                  },
                ),
              ),
              // Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_macroMetrics.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 15,
                    ),
                    height: 6,
                    width: _currentMacroIndex == index ? 24 : 6,
                    decoration: BoxDecoration(
                      color: _currentMacroIndex == index
                          ? _metricColors[_macroMetrics[index]]
                          : AppColors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleMacroPage(String metric) {
    final int avg = _calculateAverage(metric);
    final int target = _getTarget(metric);
    final String unit = _getUnitForMetric(metric);
    final String title = _metricNames[metric] ?? metric;

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Середнє",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "$avg",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                      TextSpan(
                        text: " $unit",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Ціль",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "$target",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                      TextSpan(
                        text: " $unit",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),
        Expanded(child: _buildSingleChart(metric)),
      ],
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1, // Fix: Force interval to 1 to match data points indices
          getTitlesWidget: (value, meta) {
            int index = value.toInt();
            // Validate index is within range and matches the value exactly (to avoid potential float issues)
            if (index >= 0 &&
                index < _chartData.length &&
                (value - index).abs() < 0.01) {
              DateTime date = _chartData[index]['dateObj'];
              bool isToday =
                  date.day == DateTime.now().day &&
                  date.month == DateTime.now().month;
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _getDayName(date),
                  style: TextStyle(
                    color: isToday
                        ? AppColors.textWhite
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
          reservedSize: 30,
        ),
      ),
    );
  }

  FlGridData _buildGridData(double interval) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (value) => FlLine(
        color: AppColors.textWhite.withValues(alpha: 0.05),
        strokeWidth: 1,
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(
    String metric,
    double maxY,
    double target,
  ) {
    List<BarChartGroupData> groups = [];
    final double rodWidth = 16.0;
    final color = _metricColors[metric]!;
    // Create a darker version of the main color for the overflow
    final darkerColor = Color.lerp(color, Colors.black, 0.45)!;

    for (int i = 0; i < _chartData.length; i++) {
      final value = _getMetricValue(metric, _chartData[i]);

      // Calculate cutoff relative to THIS BAR'S height (value)
      // The gradient applies to the rod, so 1.0 is the top of the rod (value).
      double cutoff = 1.0;
      if (value > 0) {
        cutoff = target / value;
      }
      if (cutoff > 1.0) cutoff = 1.0;
      if (cutoff < 0.0) cutoff = 0.0;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              width: rodWidth,
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: [color, color, darkerColor],
                stops: [0.0, cutoff, 1.0],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: AppColors.textWhite.withValues(alpha: 0.02),
              ),
            ),
          ],
        ),
      );
    }
    return groups;
  }

  List<LineChartBarData> _buildLineData(
    String metric,
    double maxY,
    double target,
  ) {
    List<LineChartBarData> lines = [];
    final color = _metricColors[metric]!;
    final darkerColor = Color.lerp(color, Colors.black, 0.45)!;

    double maxDataVal = 0;
    List<FlSpot> spots = [];
    for (int i = 0; i < _chartData.length; i++) {
      final value = _getMetricValue(metric, _chartData[i]);
      spots.add(FlSpot(i.toDouble(), value));
      if (value > maxDataVal) maxDataVal = value;
    }

    // Calculate cutoff relative to the LINE'S bounding box height (maxDataVal)
    // The gradient on the line stroke generally maps to the min/max Y of the spots/data
    double cutoff = (maxDataVal > 0) ? (target / maxDataVal) : 1.0;
    if (cutoff > 1.0) cutoff = 1.0;
    if (cutoff < 0.0) cutoff = 0.0;

    lines.add(
      LineChartBarData(
        spots: spots,
        isCurved: true,
        gradient: LinearGradient(
          colors: [color, color, darkerColor],
          stops: [0.0, cutoff, 1.0],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            // Paint dot darker if it exceeds target
            Color dotColor = (spot.y > target) ? darkerColor : color;
            return FlDotCirclePainter(
              radius: 4,
              color: dotColor,
              strokeWidth: 2,
              strokeColor: Colors.black,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
    return lines;
  }

  double _getMetricValue(String metric, Map<String, dynamic> dataPoint) {
    final value = dataPoint[metric];
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }

  String _getUnitForMetric(String metric) {
    switch (metric) {
      case 'calories':
        return 'ккал';
      case 'water':
        return 'мл';
      case 'protein':
        return 'г';
      case 'fat':
        return 'г';
      case 'carbs':
        return 'г';
      default:
        return '';
    }
  }

  double _calculateDynamicMaxY(String metric) {
    double maxVal = 0;

    for (var day in _chartData) {
      double value = _getMetricValue(metric, day);
      if (value > maxVal) maxVal = value;
    }

    if (maxVal == 0) {
      return 100;
    }

    return (maxVal * 1.2).ceilToDouble();
  }

  double _calculateGridInterval(double maxY) {
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    if (maxY <= 2000) return 500;
    return 1000;
  }

  Widget _buildMacrosDetailCard() {
    int targetP = _data['target_p'] ?? 150;
    int targetF = _data['target_f'] ?? 80;
    int targetC = _data['target_c'] ?? 250;
    double currentP = (_data['protein'] ?? 0).toDouble();
    double currentF = (_data['fat'] ?? 0).toDouble();
    double currentC = (_data['carbs'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassCardColor),
      ),
      child: Column(
        children: [
          _buildMacroProgressBar("Білки", currentP, targetP, Colors.blueAccent),
          const SizedBox(height: 25),
          _buildMacroProgressBar(
            "Жири",
            currentF,
            targetF,
            Colors.orangeAccent,
          ),
          const SizedBox(height: 25),
          _buildMacroProgressBar(
            "Вуглеводи",
            currentC,
            targetC,
            Colors.purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgressBar(
    String label,
    double current,
    int target,
    Color color,
  ) {
    double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "${current.toInt()}",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: " / $targetг",
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
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.textWhite.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.6), color],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.15),
            AppColors.primaryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primaryColor, size: 24),
              const SizedBox(width: 10),
              Text(
                "AI Аналіз тижня",
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiSummary!,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
