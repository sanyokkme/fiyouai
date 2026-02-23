import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_app/constants/app_colors.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_app/widgets/weight_update_sheet.dart';
import 'package:flutter_app/widgets/goal_speed_sheet.dart';
import 'package:flutter_app/services/data_manager.dart';

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _history = [];
  double _currentWeight = 0;
  double? _startWeight;
  double? _targetWeight;
  double? _weeklyGoal;
  String? _goalType; // 'lose', 'gain', 'maintain'

  // Validation / Message state
  String? _statusMessage;
  Color _statusColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('uk');
    _loadFromCache();
    _fetchWeightData();
  }

  Future<void> _loadFromCache() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final cachedJson = await DataManager().getCachedWeightHistory(userId);
    if (cachedJson != null) {
      try {
        final data = jsonDecode(cachedJson);
        _parseData(data);
      } catch (e) {
        debugPrint("Error parsing cached weight data: $e");
      }
    }
  }

  void _parseData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _history = data['history'] ?? [];
      _currentWeight = (data['current_weight'] as num).toDouble();

      if (data['start_weight'] != null) {
        _startWeight = (data['start_weight'] as num).toDouble();
      }
      if (data['target_weight'] != null) {
        _targetWeight = (data['target_weight'] as num).toDouble();
      }
      if (data['weekly_change_goal'] != null) {
        _weeklyGoal = (data['weekly_change_goal'] as num).toDouble();
      }
      // Determine Goal Type based on start/target if not explicit
      // Or assume from weeklyGoal sign
      if (_weeklyGoal != null) {
        if (_weeklyGoal! < -0.01) {
          _goalType = 'lose';
        } else if (_weeklyGoal! > 0.01)
          _goalType = 'gain';
        else
          _goalType = 'maintain';
      } else if (_targetWeight != null && _startWeight != null) {
        if (_targetWeight! < _startWeight!) {
          _goalType = 'lose';
        } else if (_targetWeight! > _startWeight!)
          _goalType = 'gain';
        else
          _goalType = 'maintain';
      }

      _calculateStatus();
      _isLoading = false;
    });
  }

  Future<void> _fetchWeightData() async {
    final token = await AuthService.getAccessToken();
    final userId = await AuthService.getStoredUserId();
    if (userId == null || token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/weight/history/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _parseData(data);
      }
    } catch (e) {
      debugPrint("Error fetching weight history: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStatus() {
    if (_targetWeight == null) return;

    bool reached = false;
    bool offTrack = false;

    if (_goalType == 'lose') {
      if (_currentWeight <= _targetWeight!) {
        reached = true;
      } else if (_currentWeight > (_startWeight ?? _currentWeight) + 1.0)
        offTrack = true; // Gained 1kg+ instead of losing
    } else if (_goalType == 'gain') {
      if (_currentWeight >= _targetWeight!) {
        reached = true;
      } else if (_currentWeight < (_startWeight ?? _currentWeight) - 1.0)
        offTrack = true; // Lost 1kg+ instead of gaining
    }

    if (reached) {
      _statusMessage = "ЦІЛЬ ДОСЯГНУТА! 🎉";
      _statusColor = Colors.greenAccent;
    } else if (offTrack) {
      _statusMessage = "Увага: Рух у зворотньому напрямку";
      _statusColor = Colors.orangeAccent;
    } else {
      _statusMessage = null;
    }
  }

  void _openAddWeightSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WeightUpdateSheet(
        currentWeight: _currentWeight,
        onWeightUpdated: (newWeight) {},
      ),
    );

    if (result != null) {
      _fetchWeightData();
    }
  }

  void _openGoalSpeedSheet() {
    bool isGain = true;
    if (_goalType == 'lose') {
      isGain = false;
    } else if (_goalType == 'gain')
      isGain = true;
    else {
      // Fallback
      if (_targetWeight != null && _currentWeight > _targetWeight!) {
        isGain = false;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GoalSpeedSheet(
        currentSpeed: _weeklyGoal ?? 0.5,
        isGain: isGain,
        onSpeedUpdated: (newSpeed) {
          setState(() {
            _weeklyGoal = newSpeed;
            if (_weeklyGoal! < 0) {
              _goalType = 'lose';
            } else if (_weeklyGoal! > 0)
              _goalType = 'gain';
          });
          // Also triggers recalculation locally visually if needed
          _calculateStatus();
          // Ideally confirm with backend? The sheet should handle backend update.
          // Re-fetch to be safe.
          _fetchWeightData();
        },
      ),
    );
  }

  void _openChangeTargetDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChangeGoalSheet(
        currentWeight: _currentWeight,
        onGoalUpdated: _fetchWeightData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),

                            // Success/Warning Message ABOVE Chart
                            if (_statusMessage != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: _statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: _statusColor.withOpacity(0.5),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: _statusColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _statusMessage!,
                                            style: TextStyle(
                                              color: _statusColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // If goal reached, show button to change goal
                                    if (_statusMessage!.contains(
                                      "ЦІЛЬ ДОСЯГНУТА",
                                    )) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _openChangeTargetDialog,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _statusColor
                                                .withOpacity(0.2),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            "Обрати нову ціль",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            _buildChartContainer(),
                            const SizedBox(height: 25),

                            // Stats Grid
                            _buildStatsGrid(),

                            const SizedBox(height: 20),

                            // Goal Speed / Adjustment
                            _buildSpeedControl(),

                            // (Removed status message from here)
                            const SizedBox(height: 30),
                            _buildHistoryList(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          onPressed: _openAddWeightSheet,
          backgroundColor: AppColors.primaryColor,
          elevation: 5,
          icon: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
          label: const Text(
            "Додати вагу",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            "Трекер ваги",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer() {
    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _history.isEmpty && _startWeight == null
          ? Center(
              child: Text(
                "Немає даних",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : LineChart(_mainData()),
    );
  }

  LineChartData _mainData() {
    List<FlSpot> spots = [];

    // Calculate timeline
    // Includes start_weight at implicit time 0 if empty history?
    // Or sort history by date.

    // Combine start weight with history for plotting
    // Start weight date? Usually creation date.
    // If not available, we can just put it at 0 index if history is empty,
    // or assume it's older than any history.

    List<dynamic> sortedHistory = List.from(_history);
    sortedHistory.sort(
      (a, b) => DateTime.parse(
        a['created_at'],
      ).compareTo(DateTime.parse(b['created_at'])),
    );

    // Ensure start weight is in the list effectively
    // If we have history, check if the first item is roughly the same as start weight?
    // User requested: "default see value obtained at onboarding screen".

    // Construct points
    // Map dates to X axis (days from start)? Or just index?
    // Index is smoother for visual if dates vary wildly.

    double minWeight = _currentWeight;
    double maxWeight = _currentWeight;

    if (_startWeight != null) {
      if (_startWeight! < minWeight) minWeight = _startWeight!;
      if (_startWeight! > maxWeight) maxWeight = _startWeight!;
    }
    if (_targetWeight != null) {
      if (_targetWeight! < minWeight) minWeight = _targetWeight!;
      if (_targetWeight! > maxWeight) maxWeight = _targetWeight!;
    }

    // Adding points
    // 0: Start Weight (if distinct)
    // 1..N: History

    int xIndex = 0;

    // Always add Start Weight at 0 if it exists
    if (_startWeight != null) {
      spots.add(FlSpot(xIndex.toDouble(), _startWeight!));
      xIndex++;
    }

    // Add history points
    for (var entry in sortedHistory) {
      double w = (entry['weight'] as num).toDouble();

      // Update min/max for scaling
      if (w < minWeight) minWeight = w;
      if (w > maxWeight) maxWeight = w;

      spots.add(FlSpot(xIndex.toDouble(), w));
      xIndex++;
    }

    // If only one point (start weight), add current weight as second point to make a line
    if (spots.length == 1 && _startWeight != null && sortedHistory.isEmpty) {
      // Start == Current essentially if no history
      spots.add(FlSpot(1, _currentWeight));
      xIndex++;
    }

    double buffer = 2.0;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles:
                false, // Cleaner look without dates on X for now, or just start/end
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX:
          (spots.length - 1).toDouble() +
          (spots.isEmpty ? 1 : 0), // Extra space
      minY: minWeight - buffer,
      maxY: maxWeight + buffer,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primaryColor,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: AppColors.backgroundDark,
                strokeWidth: 2,
                strokeColor: AppColors.primaryColor,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor.withOpacity(0.2),
                AppColors.primaryColor.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (_targetWeight != null)
            HorizontalLine(
              y: _targetWeight!,
              color: Colors.greenAccent.withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                labelResolver: (line) =>
                    "ЦІЛЬ: ${_targetWeight!.toStringAsFixed(1)}",
              ),
            ),
          if (_startWeight != null)
            HorizontalLine(
              y: _startWeight!,
              color: Colors.white.withOpacity(0.2),
              strokeWidth: 1,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                style: TextStyle(color: Colors.white38, fontSize: 10),
                labelResolver: (line) =>
                    "СТАРТ: ${_startWeight!.toStringAsFixed(1)}",
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    double difference = 0;
    // Calculate total diff from START
    if (_startWeight != null) {
      difference = _currentWeight - _startWeight!;
    } else if (_history.isNotEmpty) {
      // Fallback to first history entry
      // difference = _currentWeight - _history.last['weight'];
      // Or keep backend provided 'difference' which is 'since last entry' usually.
      // User wants "Difference" - usually Total Difference is most useful, or
      // "Since last". Let's use Total Difference if Start is available.
    }

    // For specific "since last" just look at current vs last history
    // But conceptually Total Progress is better.
    // Let's show TOTAL Difference (Current - Start).

    // Forecast Calculation
    String forecast = "—";
    String forecastSubtitle = "днів до цілі";

    if (_targetWeight != null &&
        _weeklyGoal != null &&
        _weeklyGoal!.abs() > 0) {
      double dist = (_targetWeight! - _currentWeight).abs();
      double rate = _weeklyGoal!.abs();
      int days = ((dist / rate) * 7).ceil();

      if (_goalType == 'lose' && _currentWeight <= _targetWeight!) {
        forecast = "✅";
      } else if (_goalType == 'gain' && _currentWeight >= _targetWeight!)
        forecast = "✅";
      else
        forecast = days.toString();

      if (forecast == "✅") forecastSubtitle = "Готово!";
    }

    return Row(
      children: [
        Expanded(
          child: _buildAnimStatCard(
            "Прогрес",
            "${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)}",
            "кг",
            difference < 0
                ? Colors.greenAccent
                : (difference > 0 ? Colors.orangeAccent : Colors.white),
            icon: Icons.show_chart,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildAnimStatCard(
            "Прогноз",
            forecast,
            forecastSubtitle,
            AppColors.primaryColor,
            icon: Icons.calendar_today_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedControl() {
    // "Швидкість зміни ваги"
    String speedText = "0.5 кг/тиждень";
    if (_weeklyGoal != null) {
      speedText = "${_weeklyGoal!.abs().toStringAsFixed(1)} кг/тиждень";
    }

    return GestureDetector(
      onTap: _openGoalSpeedSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.glassCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.speed, color: AppColors.primaryColor, size: 24),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Швидкість зміни",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  speedText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimStatCard(
    String title,
    String value,
    String unit,
    Color valueColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, val, child) {
                  // Opacity or scale transition for the text
                  return Opacity(
                    opacity: val.clamp(0.0, 1.0),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Text(
            "Історія",
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 15),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final entry = _history[index];
            DateTime date = DateTime.parse(entry['created_at']);
            double weight = (entry['weight'] as num).toDouble();
            double? diff = entry['difference'] != null
                ? (entry['difference'] as num).toDouble()
                : null;

            // Animation for list items
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + (index * 100)),
              curve: Curves.easeOutQuad,
              builder: (context, val, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - val)),
                  child: Opacity(opacity: val, child: child),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd.MM', 'uk').format(date),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      "${weight.toStringAsFixed(1)} кг",
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (diff != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (diff == 0
                                      ? Colors.grey
                                      : (diff < 0
                                            ? Colors.green
                                            : Colors.orange))
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}",
                          style: TextStyle(
                            color: diff == 0
                                ? AppColors.textSecondary
                                : (diff < 0
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ChangeGoalSheet extends StatefulWidget {
  final double currentWeight;
  final VoidCallback onGoalUpdated;

  const _ChangeGoalSheet({
    required this.currentWeight,
    required this.onGoalUpdated,
  });

  @override
  State<_ChangeGoalSheet> createState() => _ChangeGoalSheetState();
}

class _ChangeGoalSheetState extends State<_ChangeGoalSheet> {
  String _selectedGoal = 'lose'; // lose, gain, maintain
  final TextEditingController _weightController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // No pre-fill, rely on hint
  }

  String get _hintText {
    if (_selectedGoal == 'lose') {
      return (widget.currentWeight - 10).toStringAsFixed(1);
    } else if (_selectedGoal == 'gain') {
      return (widget.currentWeight + 10).toStringAsFixed(1);
    }
    return "70.0";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Яка ваша мета?",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Selection Cards
          _buildGoalOption(
            "lose",
            "Схуднути",
            "Знизити % жиру та вагу",
            Icons.trending_down,
          ),
          const SizedBox(height: 10),
          _buildGoalOption(
            "maintain",
            "Підтримувати",
            "Залишатися у цій формі",
            Icons.balance,
          ),
          const SizedBox(height: 10),
          _buildGoalOption(
            "gain",
            "Набрати",
            "Збільшити м'язову масу",
            Icons.trending_up,
          ),

          const SizedBox(height: 30),

          // Input Section with Smooth Animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedGoal != 'maintain') ...[
                  Text(
                    "Бажана вага",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardColor,
                      hintText: "Наприклад: $_hintText",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      suffixText: "кг",
                      suffixStyle: TextStyle(color: AppColors.textSecondary),
                      errorText: _errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: AppColors.primaryColor),
                      ),
                    ),
                    onChanged: (_) => setState(() => _errorText = null),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Поточна вага: ${widget.currentWeight} кг",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            "Ми адаптуємо план харчування для підтримки ваги ${widget.currentWeight} кг.",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: AppColors.primaryColor.withOpacity(0.4),
              ),
              child: const Text(
                "Зберегти ціль",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildGoalOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    bool isSelected = _selectedGoal == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = value;
          _errorText = null;
          if (value == 'maintain') {
            _weightController.text = widget.currentWeight.toString();
          } else {
            // Clear for others so the hint shows
            _weightController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : AppColors.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black.withOpacity(0.1)
                    : AppColors.backgroundDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.black.withOpacity(0.6)
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Future<void> _saveGoal() async {
    double? targetW;

    if (_selectedGoal == 'maintain') {
      targetW = widget.currentWeight;
    } else {
      targetW = double.tryParse(_weightController.text.replaceAll(',', '.'));
      if (targetW == null) {
        setState(() => _errorText = "Введіть коректне число");
        return;
      }

      // Validation
      if (_selectedGoal == 'lose' && targetW >= widget.currentWeight) {
        setState(
          () =>
              _errorText = "Для схуднення ціль має бути меншою за поточну вагу",
        );
        return;
      }
      if (_selectedGoal == 'gain' && targetW <= widget.currentWeight) {
        setState(
          () => _errorText = "Для набору ціль має бути більшою за поточну вагу",
        );
        return;
      }
    }

    // Determine weekly change goal default
    double weeklyChange = 0;
    if (_selectedGoal == 'lose') {
      weeklyChange = -0.5;
    } else if (_selectedGoal == 'gain')
      weeklyChange = 0.25;
    else
      weeklyChange = 0;

    String goalText = _selectedGoal == 'lose'
        ? "Lose Weight"
        : (_selectedGoal == 'gain' ? "Gain Muscle" : "Maintain Weight");

    try {
      await AuthService.updateProfile("goal", goalText);
      await AuthService.updateProfile("target_weight", targetW);
      await AuthService.updateProfile("weekly_change_goal", weeklyChange);

      if (mounted) Navigator.pop(context);
      widget.onGoalUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Помилка: $e")));
      }
    }
  }
}
