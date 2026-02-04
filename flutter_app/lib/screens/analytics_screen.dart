import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
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
  int _avgCalories = 0;
  String? _aiSummary;

  @override
  void initState() {
    super.initState();
    _fetchFullAnalytics();
  }

  Future<void> _fetchFullAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    // --- 1. СПРОБА ЗАВАНТАЖИТИ З КЕШУ (МИТТЄВО) ---
    final cachedStatus = prefs.getString('cache_analytics_status_$userId');
    final cachedHistory = prefs.getString('cache_analytics_history_$userId');
    final cachedTips = prefs.getString('cache_analytics_tips_$userId');

    if (cachedStatus != null && cachedHistory != null) {
      _processData(
        jsonDecode(cachedStatus),
        jsonDecode(cachedHistory),
        cachedTips != null ? jsonDecode(cachedTips) : null,
      );
    }

    try {
      // --- 2. ЗАПИТ НА СЕРВЕР (У ФОНІ) ---
      final responses = await Future.wait([
        http.get(
          Uri.parse('${AuthService.baseUrl}/user_status/$userId'),
        ),
        http.get(
          Uri.parse('${AuthService.baseUrl}/analytics/$userId'),
        ),
        http.get(
          Uri.parse('${AuthService.baseUrl}/get_tips/$userId'),
        ),
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

    // 2. Рахуємо середнє
    int total = 0;
    int activeDays = 0;
    for (var item in historyList) {
      int val = (item['value'] as num).toInt();
      if (val > 0) {
        total += val;
        activeDays++;
      }
    }
    int avg = activeDays > 0 ? (total / activeDays).round() : 0;

    // 3. AI
    String aiText = "Аналізуємо ваші дані...";
    if (aiData != null) {
      aiText = aiData['summary'] ?? "Продовжуйте стежити за раціоном!";
    }

    if (mounted) {
      setState(() {
        _data = statusData;
        _chartData = filledData;
        _avgCalories = avg;
        _aiSummary = aiText;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _fillMissingDays(List rawData) {
    List<Map<String, dynamic>> result = [];
    DateTime today = DateTime.now();
    Map<String, int> dataMap = {};

    for (var item in rawData) {
      dataMap[item['day']] = (item['value'] as num).toInt();
    }

    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      result.add({
        'day': dateKey,
        'value': dataMap[dateKey] ?? 0,
        'dateObj': date,
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
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              width: 200,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
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
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          "Аналітика",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
          ),
        ),
        // Якщо завантаження і немає даних - показуємо скелетон
        child: _isLoading && _chartData.isEmpty
            ? _buildSkeleton()
            : RefreshIndicator(
                onRefresh: _fetchFullAnalytics,
                color: Colors.greenAccent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 25),

                      const Text(
                        "Деталі раціону (сьогодні)",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildMacrosDetailCard(),

                      const SizedBox(height: 25),
                      const Text(
                        "Динаміка за 7 днів",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildChartCard(),

                      const SizedBox(height: 25),
                      if (_aiSummary != null) _buildAiSummaryCard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            "Середнє",
            "$_avgCalories",
            "ккал",
            Icons.speed,
            Colors.orangeAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            "Ціль",
            "${_data['target'] ?? 2000}",
            "ккал",
            Icons.flag,
            Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: " $unit",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final double target = (_data['target'] ?? 2000).toDouble();

    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 35, 20, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _calculateMaxY(target),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < _chartData.length) {
                    int val = _chartData[index]['value'];
                    if (val == 0) return const SizedBox.shrink();
                    return Center(
                      child: Text(
                        "$val",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < _chartData.length) {
                    DateTime date = _chartData[index]['dateObj'];
                    bool isToday =
                        date.day == DateTime.now().day &&
                        date.month == DateTime.now().month;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _getDayName(date),
                        style: TextStyle(
                          color: isToday ? Colors.white : Colors.white38,
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
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 500,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _chartData.asMap().entries.map((e) {
            final double value = (e.value['value'] as int).toDouble();
            final bool isOverTarget = value > target;
            final bool isZero = value == 0;

            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: value,
                  gradient: isZero
                      ? null
                      : LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isOverTarget
                              ? [
                                  Colors.orange.withValues(alpha: 0.8),
                                  Colors.redAccent,
                                ]
                              : [
                                  Colors.tealAccent.withValues(alpha: 0.8),
                                  Colors.greenAccent,
                                ],
                        ),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: !isZero,
                    toY: target * 1.25,
                    color: Colors.white.withValues(alpha: 0.02),
                  ),
                ),
              ],
            );
          }).toList(),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: target,
                color: Colors.white.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  labelResolver: (line) => "Ціль: ${target.toInt()}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateMaxY(double target) {
    double maxVal = 0;
    for (var item in _chartData) {
      double v = (item['value'] as int).toDouble();
      if (v > maxVal) maxVal = v;
    }
    return (maxVal > target ? maxVal : target) * 1.35;
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
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
              style: const TextStyle(
                color: Colors.white,
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
                    text: " / ${target}г",
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
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
                color: Colors.white10,
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
            Colors.greenAccent.withValues(alpha: 0.15),
            Colors.greenAccent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.greenAccent,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                "AI Аналіз тижня",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiSummary!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
